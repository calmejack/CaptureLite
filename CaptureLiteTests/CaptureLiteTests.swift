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
