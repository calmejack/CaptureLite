import Foundation
import Observation
import AppKit
import AVFoundation

@MainActor
@Observable
final class MainViewModel {
    let state: AppState
    private let environment: AppEnvironment

    var renderer: MetalRenderer? { environment.renderer }

    init(environment: AppEnvironment, state: AppState) {
        self.environment = environment
        self.state = state
    }

    func start() async {
        refreshDevices()
        restoreSettings()
        await environment.pipeline.setRenderer(environment.renderer)
        syncRendererTransform()
        environment.audioEngine.onLevelUpdate = { [weak self] level in
            self?.state.audioLevel = level
        }
        environment.deviceManager.onDeviceConnected = { [weak self] id in
            self?.handleDeviceConnected(id)
        }
        environment.deviceManager.onDeviceDisconnected = { [weak self] id in
            self?.handleDeviceDisconnected(id)
        }
        restoreLastDevice()
    }

    private func handleDeviceConnected(_ id: String) {
        guard state.currentVideoDevice == nil,
              environment.settings.rememberLastDevice,
              environment.settings.lastVideoDeviceID == id,
              let device = environment.deviceManager.device(withID: id, mediaType: .video)
        else { return }
        state.currentVideoDevice = device
        Task { await startCapture(for: device) }
    }

    private func handleDeviceDisconnected(_ id: String) {
        guard state.currentVideoDevice?.id == id else { return }
        state.errorMessage = "视频设备已断开连接。"
        state.activeFormat = nil
        state.availableResolutions = []
        state.availableFrameRates = []
        state.selectedResolution = nil
        state.selectedFPS = nil
        state.currentVideoDevice = nil
        state.captureState = .idle
        Task {
            await environment.captureEngine.stop()
        }
    }

    func refreshDevices() {
        state.videoDevices = environment.deviceManager.videoDevices
        state.audioDevices = environment.deviceManager.audioDevices
    }

    func selectVideoDevice(_ device: DeviceDescriptor) {
        state.currentVideoDevice = device
        if environment.settings.rememberLastDevice {
            environment.settings.lastVideoDeviceID = device.id
        }
        Task { await startCapture(for: device) }
    }

    func selectAudioDevice(_ device: DeviceDescriptor) {
        state.currentAudioDevice = device
        if environment.settings.rememberLastDevice {
            environment.settings.lastAudioDeviceID = device.id
        }
        Task { await startAudioCapture(for: device) }
    }

    func setAspectMode(_ mode: AspectMode) {
        state.aspectMode = mode
        environment.settings.aspectMode = mode
        environment.renderer?.aspectMode = mode
    }

    func toggleMirror() {
        state.mirror.toggle()
        environment.settings.mirror = state.mirror
        environment.renderer?.mirror = state.mirror
    }

    func setRotation(_ rotation: Rotation) {
        state.rotation = rotation
        environment.settings.rotation = rotation
        environment.renderer?.rotation = rotation
    }

    func toggleMute() {
        state.isMuted.toggle()
        environment.audioEngine.setMuted(state.isMuted)
    }

    func setResolution(_ resolution: Resolution) {
        state.selectedResolution = resolution
        environment.settings.preferredResolution = "\(resolution.width)x\(resolution.height)"
        guard let device = state.currentVideoDevice,
              let captureDevice = environment.deviceManager.captureDevice(withID: device.id, mediaType: .video)
        else { return }

        let rates = FormatEnumerator.supportedFrameRates(for: captureDevice, resolution: resolution)
        state.availableFrameRates = rates
        if let fps = state.selectedFPS, rates.contains(fps) {
            applyFormat(resolution: resolution, fps: fps)
        } else if let max = rates.first {
            state.selectedFPS = max
            applyFormat(resolution: resolution, fps: max)
        }
    }

    func setFPS(_ fps: Double) {
        state.selectedFPS = fps
        environment.settings.preferredFPS = fps
        guard let resolution = state.selectedResolution else { return }
        applyFormat(resolution: resolution, fps: fps)
    }

    private func applyFormat(resolution: Resolution, fps: Double) {
        Task {
            do {
                try await environment.captureEngine.setFormat(width: resolution.width, height: resolution.height, fps: fps)
                state.activeFormat = VideoFormat(width: resolution.width, height: resolution.height, fps: fps, pixelFormat: state.activeFormat?.pixelFormat ?? 0)
            } catch {
                state.errorMessage = error.localizedDescription
                Logger.error("Format change failed: \(error)", category: .capture)
            }
        }
    }

    func screenshot() {
        guard let renderer = environment.renderer else { return }
        let service = ScreenshotService(renderer: renderer)
        do {
            let url = try service.capture(to: environment.settings.screenshotDirectory)
            Logger.info("Screenshot saved: \(url.path)", category: .app)
        } catch {
            state.errorMessage = error.localizedDescription
            Logger.error("Screenshot failed: \(error)", category: .app)
        }
    }

    func toggleRecording() {
        switch state.recordingState {
        case .idle, .failed:
            Task { await startRecording() }
        case .recording:
            Task { await stopRecording() }
        case .starting, .stopping:
            break
        }
    }

    private func startRecording() async {
        guard state.captureState == .running, let format = state.activeFormat else {
            state.errorMessage = "请先连接并启动视频设备后再录制。"
            return
        }

        state.recordingState = .starting
        let config = RecordingConfig(
            codec: environment.settings.recordingCodec,
            width: format.width,
            height: format.height,
            fps: format.fps,
            bitrate: nil,
            outputURL: recordingURL()
        )

        let audioSettings = makeAudioSettings()

        do {
            await environment.pipeline.setRecorder(environment.recorder)
            try await environment.recorder.start(config: config, audioSettings: audioSettings)
            wireAudioToRecorder()
            state.recordingState = .recording
            state.recordingElapsed = 0
            startElapsedTimer()
            Logger.info("Recording started: \(config.outputURL.path)", category: .recording)
        } catch {
            state.recordingState = .failed(error.localizedDescription)
            state.errorMessage = error.localizedDescription
            await environment.pipeline.setRecorder(nil)
            Logger.error("Recording start failed: \(error)", category: .recording)
        }
    }

    private func makeAudioSettings() -> AudioRecordingSettings? {
        guard let format = environment.audioEngine.currentAudioFormat else { return nil }
        return AudioRecordingSettings(sampleRate: format.sampleRate, channelCount: format.channelCount)
    }

    private func wireAudioToRecorder() {
        let recorder = environment.recorder
        environment.audioEngine.onAudioFrame = { audioFrame in
            Task { await recorder.appendAudio(audioFrame) }
        }
    }

    private func stopRecording() async {
        state.recordingState = .stopping
        stopElapsedTimer()
        environment.audioEngine.onAudioFrame = nil
        await environment.recorder.stop()
        await environment.pipeline.setRecorder(nil)
        state.recordingState = .idle
        state.recordingElapsed = 0
        Logger.info("Recording stopped", category: .recording)
    }

    private func recordingURL() -> URL {
        let directory = environment.settings.recordingDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "CaptureLite_\(formatter.string(from: Date())).mp4"
        return directory.appendingPathComponent(filename)
    }

    private var elapsedTask: Task<Void, Never>?

    private func startElapsedTimer() {
        stopElapsedTimer()
        elapsedTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.state.recordingElapsed += 1
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTask?.cancel()
        elapsedTask = nil
    }

    private func syncRendererTransform() {
        environment.renderer?.aspectMode = state.aspectMode
        environment.renderer?.mirror = state.mirror
        environment.renderer?.rotation = state.rotation
    }

    private func startCapture(for device: DeviceDescriptor) async {
        state.captureState = .starting
        state.errorMessage = nil

        guard let captureDevice = environment.deviceManager.captureDevice(withID: device.id, mediaType: .video) else {
            state.captureState = .failed(DeviceError.deviceUnavailable(device.name).localizedDescription)
            state.errorMessage = DeviceError.deviceUnavailable(device.name).localizedDescription
            return
        }

        do {
            let authorized = try await requestCameraPermission()
            guard authorized else {
                state.captureState = .failed(PermissionError.cameraDenied.localizedDescription)
                state.errorMessage = PermissionError.cameraDenied.localizedDescription
                return
            }

            if environment.captureEngine.currentDeviceID == device.id {
                state.captureState = .running
                return
            }

            if environment.captureEngine.currentSource != nil {
                state.captureState = .switching
                try await environment.captureEngine.switchDevice(to: captureDevice)
            } else {
                try await environment.captureEngine.start(device: captureDevice)
            }

            state.captureState = .running
            loadFormats(for: captureDevice)
            applyPreferredFormat(for: captureDevice)
            Logger.info("Capture running for \(device.name)", category: .capture)
        } catch {
            state.captureState = .failed(error.localizedDescription)
            state.errorMessage = error.localizedDescription
            Logger.error("Capture failed: \(error)", category: .capture)
        }
    }

    private func loadFormats(for device: AVCaptureDevice) {
        let resolutions = FormatEnumerator.supportedResolutions(for: device)
        state.availableResolutions = resolutions

        guard let current = FormatEnumerator.currentFormat(for: device) else { return }
        state.activeFormat = current

        let resolution = Resolution(width: current.width, height: current.height)
        state.selectedResolution = resolution
        state.selectedFPS = current.fps
        state.availableFrameRates = FormatEnumerator.supportedFrameRates(for: device, resolution: resolution)
    }

    private func applyPreferredFormat(for device: AVCaptureDevice) {
        guard let pref = environment.settings.preferredResolution else { return }
        let parts = pref.split(separator: "x").map(String.init)
        guard parts.count == 2, let width = Int(parts[0]), let height = Int(parts[1]) else { return }

        let resolution = Resolution(width: width, height: height)
        guard state.availableResolutions.contains(resolution) else { return }

        let rates = FormatEnumerator.supportedFrameRates(for: device, resolution: resolution)
        state.selectedResolution = resolution
        state.availableFrameRates = rates

        if let fps = environment.settings.preferredFPS, rates.contains(where: { abs($0 - fps) < 0.01 }) {
            state.selectedFPS = fps
        } else {
            state.selectedFPS = rates.first
        }

        guard let fps = state.selectedFPS else { return }
        applyFormat(resolution: resolution, fps: fps)
    }

    private func requestCameraPermission() async throws -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func startAudioCapture(for device: DeviceDescriptor) async {
        guard let captureDevice = environment.deviceManager.captureDevice(withID: device.id, mediaType: .audio) else {
            state.errorMessage = DeviceError.deviceUnavailable(device.name).localizedDescription
            return
        }

        do {
            let authorized = try await requestMicrophonePermission()
            guard authorized else {
                state.errorMessage = PermissionError.microphoneDenied.localizedDescription
                return
            }

            if environment.audioEngine.currentSource != nil {
                try await environment.audioEngine.switchDevice(to: captureDevice)
            } else {
                try await environment.audioEngine.start(device: captureDevice)
            }
        } catch {
            state.errorMessage = error.localizedDescription
            Logger.error("Audio capture failed: \(error)", category: .audio)
        }
    }

    private func requestMicrophonePermission() async throws -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func restoreSettings() {
        state.aspectMode = environment.settings.aspectMode
        state.mirror = environment.settings.mirror
        state.rotation = environment.settings.rotation
    }

    private func restoreLastDevice() {
        guard environment.settings.rememberLastDevice else { return }
        if let id = environment.settings.lastVideoDeviceID,
           let device = environment.deviceManager.device(withID: id, mediaType: .video) {
            state.currentVideoDevice = device
            Task { await startCapture(for: device) }
        }
        if let id = environment.settings.lastAudioDeviceID,
           let device = environment.deviceManager.device(withID: id, mediaType: .audio) {
            state.currentAudioDevice = device
            Task { await startAudioCapture(for: device) }
        }
    }
}
