import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var lastVideoDeviceID: String? {
        didSet { defaults.set(lastVideoDeviceID, forKey: Keys.lastVideoDeviceID) }
    }

    var lastAudioDeviceID: String? {
        didSet { defaults.set(lastAudioDeviceID, forKey: Keys.lastAudioDeviceID) }
    }

    var rememberLastDevice: Bool = true {
        didSet { defaults.set(rememberLastDevice, forKey: Keys.rememberLastDevice) }
    }

    var aspectMode: AspectMode = .fit {
        didSet { defaults.set(aspectMode.rawValue, forKey: Keys.aspectMode) }
    }

    var mirror: Bool = false {
        didSet { defaults.set(mirror, forKey: Keys.mirror) }
    }

    var rotation: Rotation = .zero {
        didSet { defaults.set(rotation.rawValue, forKey: Keys.rotation) }
    }

    var preferredResolution: String? {
        didSet { defaults.set(preferredResolution, forKey: Keys.preferredResolution) }
    }

    var preferredFPS: Double? {
        didSet { defaults.set(preferredFPS, forKey: Keys.preferredFPS) }
    }

    var recordingCodec: VideoCodec = .h264 {
        didSet { defaults.set(recordingCodec.rawValue, forKey: Keys.recordingCodec) }
    }

    var recordingDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Movies/CaptureLite", isDirectory: true) {
        didSet { defaults.set(recordingDirectory.path, forKey: Keys.recordingDirectory) }
    }

    var screenshotDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures/CaptureLite", isDirectory: true) {
        didSet { defaults.set(screenshotDirectory.path, forKey: Keys.screenshotDirectory) }
    }

    private func load() {
        lastVideoDeviceID = defaults.string(forKey: Keys.lastVideoDeviceID)
        lastAudioDeviceID = defaults.string(forKey: Keys.lastAudioDeviceID)
        rememberLastDevice = defaults.object(forKey: Keys.rememberLastDevice) as? Bool ?? true
        aspectMode = AspectMode(rawValue: defaults.string(forKey: Keys.aspectMode) ?? "") ?? .fit
        mirror = defaults.object(forKey: Keys.mirror) as? Bool ?? false
        rotation = Rotation(rawValue: defaults.integer(forKey: Keys.rotation)) ?? .zero
        preferredResolution = defaults.string(forKey: Keys.preferredResolution)
        preferredFPS = defaults.object(forKey: Keys.preferredFPS) as? Double
        recordingCodec = VideoCodec(rawValue: defaults.string(forKey: Keys.recordingCodec) ?? "") ?? .h264
        if let path = defaults.string(forKey: Keys.recordingDirectory) {
            recordingDirectory = URL(fileURLWithPath: path, isDirectory: true)
        }
        if let path = defaults.string(forKey: Keys.screenshotDirectory) {
            screenshotDirectory = URL(fileURLWithPath: path, isDirectory: true)
        }
    }

    private enum Keys {
        static let lastVideoDeviceID = "lastVideoDeviceID"
        static let lastAudioDeviceID = "lastAudioDeviceID"
        static let rememberLastDevice = "rememberLastDevice"
        static let aspectMode = "aspectMode"
        static let mirror = "mirror"
        static let rotation = "rotation"
        static let preferredResolution = "preferredResolution"
        static let preferredFPS = "preferredFPS"
        static let recordingCodec = "recordingCodec"
        static let recordingDirectory = "recordingDirectory"
        static let screenshotDirectory = "screenshotDirectory"
    }
}
