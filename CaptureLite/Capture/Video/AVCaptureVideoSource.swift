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

        guard let format = candidates.first(where: { f in
            f.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= fps }
        }) else {
            throw FormatError.unsupportedFormat
        }

        let duration = CMTime(value: 100, timescale: CMTimeScale(fps * 100))
        try device.lockForConfiguration()
        device.activeFormat = format
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
        device.unlockForConfiguration()
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
