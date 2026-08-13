import Foundation

enum CaptureError: LocalizedError {
    case noDevice
    case deviceInUse
    case sessionConfigurationFailed(String)
    case notRunning

    var errorDescription: String? {
        switch self {
        case .noDevice:
            return "未检测到视频设备。"
        case .deviceInUse:
            return "无法打开该视频设备。\n请确认设备没有被其他应用占用，然后重试。"
        case let .sessionConfigurationFailed(reason):
            return "无法配置采集会话：\(reason)"
        case .notRunning:
            return "采集尚未开始。"
        }
    }
}

enum DeviceError: LocalizedError {
    case permissionDenied
    case deviceUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "未获得摄像头或麦克风权限。"
        case let .deviceUnavailable(name):
            return "设备「\(name)」不可用。"
        }
    }
}

enum FormatError: LocalizedError {
    case unsupportedFormat

    var errorDescription: String? {
        "设备不支持该格式。"
    }
}

enum RendererError: LocalizedError {
    case deviceCreationFailed

    var errorDescription: String? {
        "无法创建 Metal 渲染设备。"
    }
}

enum RecordingError: LocalizedError {
    case alreadyRecording
    case notRecording
    case encoderCreationFailed(String)
    case writerCreationFailed(String)
    case encodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "已经在录制中。"
        case .notRecording:
            return "当前未在录制。"
        case let .encoderCreationFailed(reason):
            return "无法创建视频编码器：\(reason)"
        case let .writerCreationFailed(reason):
            return "无法创建录制文件：\(reason)"
        case let .encodeFailed(reason):
            return "视频编码失败：\(reason)"
        }
    }
}

enum PermissionError: LocalizedError {
    case cameraDenied
    case microphoneDenied

    var errorDescription: String? {
        switch self {
        case .cameraDenied:
            return "未获得摄像头权限。\n请在「系统设置 › 隐私与安全性 › 摄像头」中允许 CaptureLite 访问。"
        case .microphoneDenied:
            return "未获得麦克风权限。\n请在「系统设置 › 隐私与安全性 › 麦克风」中允许 CaptureLite 访问。"
        }
    }
}
