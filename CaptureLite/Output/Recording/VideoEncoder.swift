import Foundation
import CoreVideo
import CoreMedia

struct EncodedSample: @unchecked Sendable {
    let sampleBuffer: CMSampleBuffer
}

protocol VideoEncoder: AnyObject {
    var samples: AsyncStream<EncodedSample> { get }

    func configure(_ config: RecordingConfig) throws
    func encode(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) throws
    func finish()
    func invalidate()
}
