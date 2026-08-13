import Foundation

protocol VideoRenderer: AnyObject {
    var aspectMode: AspectMode { get set }
    var mirror: Bool { get set }
    var rotation: Rotation { get set }

    func enqueue(_ frame: VideoFrame)
    func currentFrame() -> VideoFrame?
}
