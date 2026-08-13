import Foundation
import AVFoundation
import CoreMedia

actor Recorder {
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var encoder: (any VideoEncoder)?
    private var consumeTask: Task<Void, Never>?
    private var baseTime: CMTime?
    private var audioBaseTime: CMTime?

    var isRecording: Bool { writer != nil }

    func start(config: RecordingConfig, audioSettings: AudioRecordingSettings?) throws {
        guard writer == nil else { throw RecordingError.alreadyRecording }

        try FileManager.default.createDirectory(
            at: config.outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let writer = try AVAssetWriter(outputURL: config.outputURL, fileType: .mp4)

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: nil)
        videoInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(videoInput) else {
            throw RecordingError.writerCreationFailed("无法添加视频输入")
        }
        writer.add(videoInput)

        var audioInput: AVAssetWriterInput?
        if let audioSettings {
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: audioSettings.sampleRate,
                AVNumberOfChannelsKey: audioSettings.channelCount,
                AVEncoderBitRateKey: 192_000
            ]
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
            input.expectsMediaDataInRealTime = true
            if writer.canAdd(input) {
                writer.add(input)
                audioInput = input
            }
        }

        let encoder: any VideoEncoder = config.codec == .h264 ? VideoToolboxH264Encoder() : VideoToolboxHEVCEncoder()
        try encoder.configure(config)

        guard writer.startWriting() else {
            throw RecordingError.writerCreationFailed(writer.error?.localizedDescription ?? "startWriting 失败")
        }
        writer.startSession(atSourceTime: .zero)

        self.writer = writer
        self.videoInput = videoInput
        self.audioInput = audioInput
        self.encoder = encoder
        self.baseTime = nil
        self.audioBaseTime = nil

        consumeTask = Task { [weak self] in
            await self?.consume()
        }
    }

    func appendVideo(_ frame: VideoFrame) {
        guard let encoder, let input = videoInput, input.isReadyForMoreMediaData else { return }

        let base = baseTime ?? frame.timestamp
        if baseTime == nil { baseTime = base }
        var pts = CMTimeSubtract(frame.timestamp, base)
        if pts < .zero { pts = .zero }

        do {
            try encoder.encode(frame.pixelBuffer, presentationTime: pts)
        } catch {
            Logger.error("Encode failed: \(error)", category: .recording)
        }
    }

    func appendAudio(_ frame: AudioFrame) {
        let sampleBuffer = frame.sampleBuffer
        guard let input = audioInput, input.isReadyForMoreMediaData else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let base = audioBaseTime ?? timestamp
        if audioBaseTime == nil { audioBaseTime = base }
        var pts = CMTimeSubtract(timestamp, base)
        if pts < .zero { pts = .zero }

        guard let adjusted = Self.sampleBuffer(sampleBuffer, withPresentationTime: pts) else { return }
        input.append(adjusted)
    }

    func stop() async {
        encoder?.finish()
        await consumeTask?.value
        consumeTask = nil

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        await completeWriting()
    }

    private func consume() async {
        guard let encoder else { return }
        for await sample in encoder.samples {
            if Task.isCancelled { break }
            if let input = videoInput, input.isReadyForMoreMediaData {
                input.append(sample.sampleBuffer)
            }
        }
    }

    private func completeWriting() async {
        guard let writer else { return }
        await writer.finishWriting()
        if let error = writer.error {
            Logger.error("Recording finished with error: \(error)", category: .recording)
        } else {
            Logger.info("Recording finalized", category: .recording)
        }
        self.writer = nil
        self.videoInput = nil
        self.audioInput = nil
        self.encoder = nil
        self.baseTime = nil
        self.audioBaseTime = nil
    }

    private static func sampleBuffer(_ sampleBuffer: CMSampleBuffer, withPresentationTime pts: CMTime) -> CMSampleBuffer? {
        var timing = CMSampleTimingInfo(
            duration: CMSampleBufferGetDuration(sampleBuffer),
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid
        )
        var newBuffer: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleBufferOut: &newBuffer
        )
        return newBuffer
    }
}
