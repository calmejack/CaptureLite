import Foundation
import CoreVideo
import CoreMedia

/// Debug / test source that generates solid-color NV12 frames without hardware.
/// Not exposed anywhere in the product UI.
final class MockVideoSource: VideoSource, @unchecked Sendable {
    let id: String
    let name: String
    let frames: AsyncStream<VideoFrame>

    let width: Int
    let height: Int
    let fps: Double

    private let continuation: AsyncStream<VideoFrame>.Continuation
    private let lock = NSLock()
    private var _latestFrame: VideoFrame?
    private var task: Task<Void, Never>?
    private var frameIndex: UInt64 = 0

    var latestFrame: VideoFrame? {
        lock.lock()
        defer { lock.unlock() }
        return _latestFrame
    }

    init(id: String = "mock-video-source", name: String = "Mock Video", width: Int = 1920, height: Int = 1080, fps: Double = 30) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.fps = fps

        let stream = AsyncStream.makeStream(of: VideoFrame.self, bufferingPolicy: .bufferingNewest(1))
        self.frames = stream.stream
        self.continuation = stream.continuation
    }

    func start() async throws {
        guard task == nil else { return }
        let interval = 1.0 / fps
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                let index = self.nextIndex()
                let timestamp = CMTime(seconds: Double(index) * interval, preferredTimescale: 600)
                guard let frame = Self.makeTestFrame(width: self.width, height: self.height, frameIndex: index, timestamp: timestamp) else { break }
                self.lock.withLock {
                    self._latestFrame = frame
                }
                self.continuation.yield(frame)
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func nextIndex() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        frameIndex += 1
        return frameIndex
    }

    private static func makeTestFrame(width: Int, height: Int, frameIndex: UInt64, timestamp: CMTime) -> VideoFrame? {
        var pixelBufferOut: CVPixelBuffer?
        let attrs: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            attrs as CFDictionary, &pixelBufferOut
        )
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBufferOut else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let yBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
           let uvBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) {
            let yValue = UInt8(16 + (frameIndex % 220))
            memset(yBase, Int32(yValue), CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) * height)
            memset(uvBase, 128, CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1) * CVPixelBufferGetHeightOfPlane(pixelBuffer, 1))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        return VideoFrame(pixelBuffer: pixelBuffer, timestamp: timestamp)
    }

    deinit {
        continuation.finish()
    }
}
