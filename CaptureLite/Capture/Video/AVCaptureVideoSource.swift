import AVFoundation
import CoreVideo
import CoreMedia

final class AVCaptureVideoSource: NSObject, VideoSource, @unchecked Sendable {
    let id: String
    let name: String
    let frames: AsyncStream<VideoFrame>

    private let device: AVCaptureDevice
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.capturelite.capture.video")
    private let continuation: AsyncStream<VideoFrame>.Continuation

    private var isRunning = false

    init(device: AVCaptureDevice) {
        self.device = device
        self.id = device.uniqueID
        self.name = device.localizedName

        let stream = AsyncStream.makeStream(of: VideoFrame.self, bufferingPolicy: .bufferingNewest(1))
        self.frames = stream.stream
        self.continuation = stream.continuation

        super.init()

        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    cont.resume(throwing: CaptureError.noDevice)
                    return
                }
                do {
                    try self.configureSession()
                    self.session.startRunning()
                    self.isRunning = true
                    Logger.info("Capture started: \(self.name)", category: .capture)
                    cont.resume()
                } catch {
                    Logger.error("Capture start failed: \(error)", category: .capture)
                    cont.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.isRunning = false
            self.removeInputs()
            Logger.info("Capture stopped: \(self.name)", category: .capture)
        }
    }

    func setFormat(width: Int, height: Int, fps: Double) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else {
                    cont.resume(throwing: CaptureError.noDevice)
                    return
                }
                do {
                    try self.applyFormat(width: width, height: height, fps: fps)
                    Logger.info("Format changed: \(width)x\(height)@\(fps)", category: .capture)
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private func applyFormat(width: Int, height: Int, fps: Double) throws {
        let candidates = device.formats.filter { format in
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return Int(dims.width) == width && Int(dims.height) == height
        }

        guard let format = candidates.first(where: { format in
            format.videoSupportedFrameRateRanges.contains { Self.supports($0, fps: fps) }
        }) else {
            Logger.error("applyFormat: no format supports \(width)x\(height)@\(fps)", category: .capture)
            throw FormatError.unsupportedFormat
        }

        guard let range = format.videoSupportedFrameRateRanges.first(where: { Self.supports($0, fps: fps) }) else {
            throw FormatError.unsupportedFormat
        }

        let targetFPS = min(max(fps, range.minFrameRate), range.maxFrameRate)
        let duration: CMTime
        if range.maxFrameDuration.isValid && range.maxFrameDuration.seconds > 0 {
            duration = range.maxFrameDuration
        } else {
            duration = CMTime(seconds: 1.0 / targetFPS, preferredTimescale: 600)
        }

        Logger.info("applyFormat: req \(width)x\(height)@\(fps) -> target \(targetFPS), duration \(duration.seconds), ranges \(format.videoSupportedFrameRateRanges.map { "\($0.minFrameRate)-\($0.maxFrameRate)" }.joined(separator: ","))", category: .capture)

        let wasRunning = session.isRunning
        if wasRunning {
            session.stopRunning()
        }

        try device.lockForConfiguration()
        device.activeFormat = format
        device.activeVideoMaxFrameDuration = duration
        device.activeVideoMinFrameDuration = duration
        device.unlockForConfiguration()

        if wasRunning {
            session.startRunning()
        }
    }

    private static func supports(_ range: AVFrameRateRange, fps: Double) -> Bool {
        fps >= range.minFrameRate - 0.01 && fps <= range.maxFrameRate + 0.01
    }

    deinit {
        continuation.finish()
    }

    private func configureSession() throws {
        session.beginConfiguration()

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        } else {
            session.commitConfiguration()
            throw CaptureError.sessionConfigurationFailed("无法添加视频输出")
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CaptureError.sessionConfigurationFailed("无法添加设备输入")
        }
        session.addInput(input)
        session.commitConfiguration()
    }

    private func removeInputs() {
        session.beginConfiguration()
        for input in session.inputs {
            session.removeInput(input)
        }
        session.commitConfiguration()
    }
}

extension AVCaptureVideoSource: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let frame = VideoFrame(pixelBuffer: pixelBuffer, timestamp: timestamp)
        continuation.yield(frame)
    }
}
