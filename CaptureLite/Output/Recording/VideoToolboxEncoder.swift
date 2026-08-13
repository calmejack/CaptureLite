import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo

class VideoToolboxEncoder: VideoEncoder, @unchecked Sendable {
    let samples: AsyncStream<EncodedSample>
    private let continuation: AsyncStream<EncodedSample>.Continuation

    private let codecType: CMVideoCodecType
    private let profileLevel: CFString
    private var session: VTCompressionSession?
    private let group = DispatchGroup()

    init(codecType: CMVideoCodecType, profileLevel: CFString) {
        self.codecType = codecType
        self.profileLevel = profileLevel
        let stream = AsyncStream.makeStream(of: EncodedSample.self, bufferingPolicy: .unbounded)
        self.samples = stream.stream
        self.continuation = stream.continuation
    }

    func configure(_ config: RecordingConfig) throws {
        var session: VTCompressionSession?
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey as String: config.width,
            kCVPixelBufferHeightKey as String: config.height
        ]

        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(config.width),
            height: Int32(config.height),
            codecType: codecType,
            encoderSpecification: nil,
            imageBufferAttributes: attributes as CFDictionary,
            compressedDataAllocator: nil,
            outputCallback: Self.compressionCallback,
            refcon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            compressionSessionOut: &session
        )

        guard status == noErr, let session else {
            throw RecordingError.encoderCreationFailed("VTCompressionSessionCreate failed: \(status)")
        }

        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: profileLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)

        let bitrate = config.bitrate ?? Self.defaultBitrate(width: config.width, height: config.height, fps: config.fps)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: NSNumber(value: bitrate))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: NSNumber(value: config.fps))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: NSNumber(value: Int(config.fps * 2)))

        VTCompressionSessionPrepareToEncodeFrames(session)
        self.session = session
    }

    func encode(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) throws {
        guard let session else {
            throw RecordingError.encodeFailed("encoder not configured")
        }
        group.enter()
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: .invalid,
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )
        if status != noErr {
            group.leave()
            throw RecordingError.encodeFailed("VTCompressionSessionEncodeFrame failed: \(status)")
        }
    }

    func finish() {
        guard let session else {
            continuation.finish()
            return
        }
        VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
        _ = group.wait(timeout: .now() + 3)
        VTCompressionSessionInvalidate(session)
        self.session = nil
        continuation.finish()
    }

    func invalidate() {
        if let session {
            VTCompressionSessionInvalidate(session)
            self.session = nil
        }
        continuation.finish()
    }

    private static let compressionCallback: VTCompressionOutputCallback = { refcon, _, status, _, sampleBuffer in
        guard let refcon else { return }
        let encoder = Unmanaged<VideoToolboxEncoder>.fromOpaque(refcon).takeUnretainedValue()
        defer { encoder.group.leave() }
        guard status == noErr, let sampleBuffer else { return }
        encoder.continuation.yield(EncodedSample(sampleBuffer: sampleBuffer))
    }

    private static func defaultBitrate(width: Int, height: Int, fps: Double) -> Int {
        let raw = Double(width) * Double(height) * fps * 0.1
        return max(1_000_000, Int(raw))
    }
}

final class VideoToolboxH264Encoder: VideoToolboxEncoder, @unchecked Sendable {
    init() {
        super.init(codecType: kCMVideoCodecType_H264, profileLevel: kVTProfileLevel_H264_High_AutoLevel)
    }
}

final class VideoToolboxHEVCEncoder: VideoToolboxEncoder, @unchecked Sendable {
    init() {
        super.init(codecType: kCMVideoCodecType_HEVC, profileLevel: kVTProfileLevel_HEVC_Main_AutoLevel)
    }
}
