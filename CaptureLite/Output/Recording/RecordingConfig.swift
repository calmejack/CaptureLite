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

enum RecordingQuality: String, CaseIterable, Sendable, Identifiable {
    case high
    case medium
    case low

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high: return "高"
        case .medium: return "中"
        case .low: return "低"
        }
    }

    var bitrateMultiplier: Double {
        switch self {
        case .high: return 0.14
        case .medium: return 0.10
        case .low: return 0.06
        }
    }

    func bitrate(width: Int, height: Int, fps: Double) -> Int {
        let raw = Double(width) * Double(height) * fps * bitrateMultiplier
        return max(500_000, Int(raw))
    }
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
