import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let settings: SettingsStore
    let deviceManager: DeviceManager
    let pipeline: VideoPipeline
    let captureEngine: CaptureEngine
    let audioEngine: AudioEngine
    let recorder: Recorder
    let renderer: MetalRenderer?

    init(settings: SettingsStore = SettingsStore(), deviceManager: DeviceManager = DeviceManager()) {
        self.settings = settings
        self.deviceManager = deviceManager
        let pipeline = VideoPipeline()
        self.pipeline = pipeline
        self.captureEngine = CaptureEngine(pipeline: pipeline)
        self.audioEngine = AudioEngine()
        self.recorder = Recorder()
        self.renderer = MetalRenderer.make()
    }
}
