import Foundation

protocol AudioSource: AnyObject {
    var id: String { get }
    var name: String { get }

    func start() async throws
    func stop()

    var frames: AsyncStream<AudioFrame> { get }
}
