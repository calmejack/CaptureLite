import Foundation
import CoreMedia

struct VideoFormat: Hashable, Sendable {
    let width: Int
    let height: Int
    let fps: Double
    let pixelFormat: OSType

    var resolutionDescription: String {
        "\(width) × \(height)"
    }

    var fpsDescription: String {
        fps == floor(fps) ? "\(Int(fps)) FPS" : String(format: "%.2f FPS", fps)
    }
}
