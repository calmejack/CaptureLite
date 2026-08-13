import Foundation

struct CaptureScene: Identifiable, Sendable {
    let id: UUID
    var name: String
    var items: [SceneItem]

    init(id: UUID = UUID(), name: String = "Default Scene", items: [SceneItem] = []) {
        self.id = id
        self.name = name
        self.items = items
    }
}
