import CoreVideo
import CoreMedia

struct VideoFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let timestamp: CMTime
    let duration: CMTime?
    let width: Int
    let height: Int
    let pixelFormat: OSType

    init(pixelBuffer: CVPixelBuffer, timestamp: CMTime, duration: CMTime? = nil) {
        self.pixelBuffer = pixelBuffer
        self.timestamp = timestamp
        self.duration = duration
        self.width = CVPixelBufferGetWidth(pixelBuffer)
        self.height = CVPixelBufferGetHeight(pixelBuffer)
        self.pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
    }
}
