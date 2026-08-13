import Foundation
import AVFoundation

@MainActor
final class CaptureEngine {
    private let pipeline: VideoPipeline
    private(set) var currentSource: AVCaptureVideoSource?
    private(set) var currentDeviceID: String?

    init(pipeline: VideoPipeline) {
        self.pipeline = pipeline
    }

    func start(device: AVCaptureDevice) async throws {
        let source = AVCaptureVideoSource(device: device)
        try await source.start()
        currentSource = source
        currentDeviceID = device.uniqueID
        await pipeline.run(source: source)
    }

    func stop() async {
        await pipeline.stop()
        currentSource?.stop()
        currentSource = nil
        currentDeviceID = nil
    }

    func switchDevice(to device: AVCaptureDevice) async throws {
        await pipeline.stop()
        currentSource?.stop()
        currentSource = nil

        let source = AVCaptureVideoSource(device: device)
        try await source.start()
        currentSource = source
        currentDeviceID = device.uniqueID
        await pipeline.run(source: source)
    }

    func setFormat(width: Int, height: Int, fps: Double) async throws {
        try await currentSource?.setFormat(width: width, height: height, fps: fps)
    }
}
