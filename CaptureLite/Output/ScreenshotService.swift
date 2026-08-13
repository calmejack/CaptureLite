import Foundation

struct ScreenshotService {
    let renderer: MetalRenderer

    func capture(to directory: URL) throws -> URL {
        guard let data = renderer.snapshotPNGData() else {
            throw CaptureError.notRunning
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "CaptureLite_\(formatter.string(from: Date())).png"
        let url = directory.appendingPathComponent(filename)

        try data.write(to: url)
        return url
    }
}
