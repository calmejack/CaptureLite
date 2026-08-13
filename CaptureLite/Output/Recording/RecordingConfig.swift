import Foundation

enum VideoCodec: String, CaseIterable, Sendable, Identifiable {
    case h264
    case hevc

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .h264: return "H.264"
        case .hevc: return "HEVC"
        }
    }
}

struct RecordingConfig: Sendable {
    var codec: VideoCodec
    var width: Int
    var height: Int
    var fps: Double
    var bitrate: Int?
    var outputURL: URL
}

struct AudioRecordingSettings: Sendable {
    let sampleRate: Double
    let channelCount: Int
}

enum RecordingFilename {
    static func make(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "CaptureLite_\(formatter.string(from: date)).mp4"
    }
}
