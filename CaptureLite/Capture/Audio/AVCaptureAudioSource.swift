import AVFoundation
import CoreMedia

final class AVCaptureAudioSource: NSObject, AudioSource, @unchecked Sendable {
    let id: String
    let name: String
    let frames: AsyncStream<AudioFrame>

    private let device: AVCaptureDevice
    private let session = AVCaptureSession()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.capturelite.capture.audio")
    private let continuation: AsyncStream<AudioFrame>.Continuation

    var sampleRate: Double {
        let desc = device.activeFormat.formatDescription
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc) else { return 48_000 }
        return asbd.pointee.mSampleRate
    }

    var channelCount: Int {
        let desc = device.activeFormat.formatDescription
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc) else { return 1 }
        return Int(asbd.pointee.mChannelsPerFrame)
    }

    init(device: AVCaptureDevice) {
        self.device = device
        self.id = device.uniqueID
        self.name = device.localizedName

        let stream = AsyncStream.makeStream(of: AudioFrame.self, bufferingPolicy: .bufferingNewest(4))
        self.frames = stream.stream
        self.continuation = stream.continuation

        super.init()

        audioOutput.setSampleBufferDelegate(self, queue: sessionQueue)
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
                    Logger.info("Audio capture started: \(self.name)", category: .audio)
                    cont.resume()
                } catch {
                    Logger.error("Audio capture start failed: \(error)", category: .audio)
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
            self.removeInputs()
            Logger.info("Audio capture stopped: \(self.name)", category: .audio)
        }
    }

    deinit {
        continuation.finish()
    }

    private func configureSession() throws {
        session.beginConfiguration()

        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
        } else {
            session.commitConfiguration()
            throw CaptureError.sessionConfigurationFailed("无法添加音频输出")
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CaptureError.sessionConfigurationFailed("无法添加音频设备输入")
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

extension AVCaptureAudioSource: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        continuation.yield(AudioFrame(sampleBuffer: sampleBuffer))
    }
}
