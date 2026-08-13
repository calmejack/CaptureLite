import Foundation
import os

enum LogCategory: String {
    case app = "App"
    case capture = "Capture"
    case device = "Device"
    case renderer = "Renderer"
    case audio = "Audio"
    case recording = "Recording"
    case pipeline = "Pipeline"
}

enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.capturelite.CaptureLite"

    static func debug(_ message: @autoclosure () -> String, category: LogCategory = .app) {
        os_log(.debug, log: .init(subsystem: subsystem, category: category.rawValue), "%{public}@", message())
    }

    static func info(_ message: @autoclosure () -> String, category: LogCategory = .app) {
        os_log(.info, log: .init(subsystem: subsystem, category: category.rawValue), "%{public}@", message())
    }

    static func error(_ message: @autoclosure () -> String, category: LogCategory = .app) {
        os_log(.error, log: .init(subsystem: subsystem, category: category.rawValue), "%{public}@", message())
    }
}
