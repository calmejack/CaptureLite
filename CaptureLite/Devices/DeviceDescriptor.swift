import Foundation

struct DeviceDescriptor: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let transport: String?
    let isExternal: Bool
    let deviceType: DeviceType

    enum DeviceType: String, Sendable {
        case builtIn
        case usbCamera
        case captureCard
        case continuityCamera
        case unknown
    }
}
