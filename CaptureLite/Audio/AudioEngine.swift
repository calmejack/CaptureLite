import Foundation
import AVFoundation

@MainActor
final class AudioEngine {
    private(set) var currentSource: AVCaptureAudioSource?
    private var consumerTask: Task<Void, Never>?
    private(set) var isMuted = false

    var onLevelUpdate: ((Float) -> Void)?
    var onAudioFrame: ((AudioFrame) -> Void)?

    var currentAudioFormat: (sampleRate: Double, channelCount: Int)? {
        guard let source = currentSource else { return nil }
        return (source.sampleRate, source.channelCount)
    }

    func start(device: AVCaptureDevice) async throws {
        let source = AVCaptureAudioSource(device: device)
        try await source.start()
        currentSource = source
        consume(source)
    }

    func stop() {
        consumerTask?.cancel()
        consumerTask = nil
        currentSource?.stop()
        currentSource = nil
    }

    func switchDevice(to device: AVCaptureDevice) async throws {
        consumerTask?.cancel()
        consumerTask = nil
        currentSource?.stop()
        currentSource = nil

        let source = AVCaptureAudioSource(device: device)
        try await source.start()
        currentSource = source
        consume(source)
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        if muted {
            onLevelUpdate?(0)
        }
    }

    private func consume(_ source: AVCaptureAudioSource) {
        consumerTask = Task { [weak self] in
            var lastUpdate = Date.distantPast
            for await frame in source.frames {
                if Task.isCancelled { break }
                guard let self else { break }
                if self.isMuted {
                    let now = Date()
                    if now.timeIntervalSince(lastUpdate) >= 0.033 {
                        lastUpdate = now
                        self.onLevelUpdate?(0)
                    }
                    continue
                }
                let level = AudioMeter.level(from: frame.sampleBuffer)
                let now = Date()
                if now.timeIntervalSince(lastUpdate) >= 0.033 {
                    lastUpdate = now
                    self.onLevelUpdate?(level)
                }
                self.onAudioFrame?(frame)
            }
        }
    }
}
