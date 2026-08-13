import Foundation

struct SceneItem: Identifiable, Sendable {
    let id: UUID
    var sourceID: String
    var transform: Transform
    var isVisible: Bool

    init(id: UUID = UUID(), sourceID: String, transform: Transform = .identity, isVisible: Bool = true) {
        self.id = id
        self.sourceID = sourceID
        self.transform = transform
        self.isVisible = isVisible
    }
}
