import XCTest
@testable import CaptureLite

final class CaptureLiteTests: XCTestCase {
    func testRotationRadians() {
        XCTAssertEqual(Rotation.zero.radians, 0)
        XCTAssertEqual(Rotation.ninety.radians, .pi / 2)
        XCTAssertEqual(Rotation.oneEighty.radians, .pi)
        XCTAssertEqual(Rotation.twoSeventy.radians, 3 * .pi / 2)
    }

    func testRecordingConfigDefaults() {
        let url = URL(fileURLWithPath: "/tmp/test.mp4")
        let config = RecordingConfig(codec: .h264, width: 1920, height: 1080, fps: 60, bitrate: nil, outputURL: url)
        XCTAssertEqual(config.width, 1920)
        XCTAssertEqual(config.codec, .h264)
    }
}

final class AspectTransformTests: XCTestCase {
    private func vertices(
        frameW: Int, frameH: Int, viewW: Int, viewH: Int,
        aspect: AspectMode, rotation: Rotation = .zero, mirror: Bool = false
    ) -> [MetalRenderer.Vertex] {
        MetalRenderer.makeVertices(
            frameWidth: frameW, frameHeight: frameH,
            drawableWidth: viewW, drawableHeight: viewH,
            aspect: aspect, rotation: rotation, mirror: mirror
        )
    }

    func testStretchFillsView() {
        let v = vertices(frameW: 1920, frameH: 1080, viewW: 800, viewH: 600, aspect: .stretch)
        XCTAssertEqual(v[0].position.x, -1, accuracy: 0.001)
        XCTAssertEqual(v[0].position.y, 1, accuracy: 0.001)
        XCTAssertEqual(v[2].position.x, -1, accuracy: 0.001)
        XCTAssertEqual(v[2].position.y, -1, accuracy: 0.001)
    }

    func testFitLetterboxesNarrowerView() {
        let v = vertices(frameW: 1920, frameH: 1080, viewW: 720, viewH: 480, aspect: .fit)
        XCTAssertEqual(v[0].position.x, -1, accuracy: 0.001)
        XCTAssertEqual(v[1].position.x, 1, accuracy: 0.001)
        let expectedY = Float(720.0 / 480.0) / Float(1920.0 / 1080.0)
        XCTAssertEqual(v[0].position.y, expectedY, accuracy: 0.001)
        XCTAssertLessThan(v[0].position.y, 1)
    }

    func testFitSameAspectNoCrop() {
        let v = vertices(frameW: 1920, frameH: 1080, viewW: 1600, viewH: 900, aspect: .fit)
        XCTAssertEqual(v[0].position.x, -1, accuracy: 0.001)
        XCTAssertEqual(v[0].position.y, 1, accuracy: 0.001)
    }

    func testFillCenterCrops() {
        let v = vertices(frameW: 1920, frameH: 1080, viewW: 720, viewH: 480, aspect: .fill)
        XCTAssertEqual(v[0].position.y, 1, accuracy: 0.001)
        let expectedX = Float(1920.0 / 1080.0) / Float(720.0 / 480.0)
        XCTAssertEqual(v[1].position.x, expectedX, accuracy: 0.001)
        XCTAssertGreaterThan(v[1].position.x, 1)
    }

    func testMirrorFlipsU() {
        let v = vertices(frameW: 1920, frameH: 1080, viewW: 1920, viewH: 1080, aspect: .stretch, mirror: true)
        XCTAssertEqual(v[0].texCoord.x, 1, accuracy: 0.001)
        XCTAssertEqual(v[1].texCoord.x, 0, accuracy: 0.001)
        XCTAssertEqual(v[0].texCoord.y, 0, accuracy: 0.001)
        XCTAssertEqual(v[2].texCoord.y, 1, accuracy: 0.001)
    }

    func testRotationNinetyMapsUV() {
        let v = vertices(frameW: 1920, frameH: 1080, viewW: 1080, viewH: 1920, aspect: .stretch, rotation: .ninety)
        XCTAssertEqual(v[0].texCoord.x, 1, accuracy: 0.001)
        XCTAssertEqual(v[0].texCoord.y, 0, accuracy: 0.001)
        XCTAssertEqual(v[1].texCoord.x, 1, accuracy: 0.001)
        XCTAssertEqual(v[1].texCoord.y, 1, accuracy: 0.001)
        XCTAssertEqual(v[2].texCoord.x, 0, accuracy: 0.001)
        XCTAssertEqual(v[2].texCoord.y, 0, accuracy: 0.001)
    }
}

final class RecordingFilenameTests: XCTestCase {
    func testMakeProducesExpectedName() {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 13
        components.hour = 14
        components.minute = 30
        components.second = 22
        let date = Calendar(identifier: .gregorian).date(from: components)!
        XCTAssertEqual(RecordingFilename.make(date: date), "CaptureLite_2026-08-13_14-30-22.mp4")
    }

    func testMakeMatchesExpectedPattern() {
        let name = RecordingFilename.make()
        XCTAssertTrue(name.hasPrefix("CaptureLite_"))
        XCTAssertTrue(name.hasSuffix(".mp4"))
        let middle = name.replacingOccurrences(of: "CaptureLite_", with: "").replacingOccurrences(of: ".mp4", with: "")
        let digits = middle.filter(\.isNumber)
        XCTAssertFalse(digits.isEmpty)
        XCTAssertNotNil(Int(digits))
    }
}

@MainActor
final class SettingsStoreTests: XCTestCase {
    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "CaptureLiteTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    func testRoundTrip() throws {
        let (defaults, suiteName) = try makeDefaults()

        let store = SettingsStore(defaults: defaults)
        store.lastVideoDeviceID = "ABC-123"
        store.lastAudioDeviceID = "AUD-456"
        store.rememberLastDevice = false
        store.aspectMode = .fill
        store.mirror = true
        store.rotation = .ninety
        store.preferredResolution = "1920x1080"
        store.preferredFPS = 60
        store.recordingCodec = .hevc

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.lastVideoDeviceID, "ABC-123")
        XCTAssertEqual(reloaded.lastAudioDeviceID, "AUD-456")
        XCTAssertFalse(reloaded.rememberLastDevice)
        XCTAssertEqual(reloaded.aspectMode, .fill)
        XCTAssertTrue(reloaded.mirror)
        XCTAssertEqual(reloaded.rotation, .ninety)
        XCTAssertEqual(reloaded.preferredResolution, "1920x1080")
        XCTAssertEqual(reloaded.preferredFPS, 60)
        XCTAssertEqual(reloaded.recordingCodec, .hevc)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDefaults() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults)

        XCTAssertTrue(store.rememberLastDevice)
        XCTAssertEqual(store.aspectMode, .fit)
        XCTAssertEqual(store.rotation, .zero)
        XCTAssertFalse(store.mirror)
        XCTAssertNil(store.preferredResolution)
        XCTAssertEqual(store.recordingCodec, .h264)
        XCTAssertEqual(store.recordingDirectory.lastPathComponent, "CaptureLite")
        XCTAssertEqual(store.screenshotDirectory.lastPathComponent, "CaptureLite")
    }
}

final class MockVideoSourceTests: XCTestCase {
    func testProducesFrames() async throws {
        let source = MockVideoSource(width: 640, height: 480, fps: 60)
        try await source.start()
        defer { source.stop() }

        let deadline = Date().addingTimeInterval(2)
        var latest: VideoFrame?
        while Date() < deadline, latest == nil {
            latest = source.latestFrame
            if latest == nil {
                try await Task.sleep(for: .milliseconds(50))
            }
        }

        let frame = try XCTUnwrap(latest)
        XCTAssertEqual(frame.width, 640)
        XCTAssertEqual(frame.height, 480)
        XCTAssertNotEqual(frame.timestamp.seconds, 0)
    }

    func testStartStopIdempotent() async throws {
        let source = MockVideoSource(fps: 30)
        try await source.start()
        try await source.start()
        source.stop()
        source.stop()
    }
}
