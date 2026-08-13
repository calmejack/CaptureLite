import Foundation
import CoreGraphics

enum Rotation: Int, CaseIterable, Sendable, Identifiable {
    case zero = 0
    case ninety = 90
    case oneEighty = 180
    case twoSeventy = 270

    var id: Int { rawValue }

    var radians: Double {
        Double(rawValue) * .pi / 180.0
    }
}

struct Transform: Sendable {
    var position: CGPoint
    var scale: CGSize
    var rotation: Rotation
    var mirrorX: Bool
    var crop: NSEdgeInsets?

    static let identity = Transform(
        position: .zero,
        scale: CGSize(width: 1, height: 1),
        rotation: .zero,
        mirrorX: false,
        crop: nil
    )
}
