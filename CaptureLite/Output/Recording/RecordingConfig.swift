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
