import Foundation

enum AspectMode: String, CaseIterable, Sendable, Identifiable {
    case fit
    case fill
    case stretch

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fit: return "适应"
        case .fill: return "填充"
        case .stretch: return "拉伸"
        }
    }
}
