import Foundation
import Observation

enum CaptureState: Equatable {
    case idle
    case starting
    case running
    case switching
    case stopping
    case failed(String)
}

enum RecordingState: Equatable {
    case idle
    case starting
    case recording
    case stopping
    case failed(String)
}

enum PermissionState: Equatable {
    case unknown
    case authorized
    case denied
    case restricted
}

@MainActor
@Observable
final class AppState {
    var captureState: CaptureState = .idle
    var recordingState: RecordingState = .idle
    var permissionState: PermissionState = .unknown

    var currentVideoDevice: DeviceDescriptor?
    var currentAudioDevice: DeviceDescriptor?
    var videoDevices: [DeviceDescriptor] = []
    var audioDevices: [DeviceDescriptor] = []

    var activeFormat: VideoFormat?
    var availableResolutions: [Resolution] = []
    var availableFrameRates: [Double] = []
    var selectedResolution: Resolution?
    var selectedFPS: Double?

    var aspectMode: AspectMode = .fit
    var mirror: Bool = false
    var rotation: Rotation = .zero

    var audioLevel: Float = 0
    var isMuted: Bool = false

    var recordingElapsed: TimeInterval = 0

    var isDebugOverlayExpanded: Bool = true
    var debugOverlayPosition: CGPoint?

    var errorMessage: String?
}
