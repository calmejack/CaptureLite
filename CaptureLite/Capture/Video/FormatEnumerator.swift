import Foundation
import AVFoundation
import CoreMedia

struct Resolution: Hashable, Identifiable, Sendable {
    let width: Int
    let height: Int

    var id: String { "\(width)x\(height)" }

    var displayName: String { "\(width) × \(height)" }
}

enum FormatEnumerator {
    static func supportedResolutions(for device: AVCaptureDevice) -> [Resolution] {
        var seen = Set<String>()
        var resolutions: [Resolution] = []

        for format in device.formats {
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let resolution = Resolution(width: Int(dims.width), height: Int(dims.height))
            guard !seen.contains(resolution.id) else { continue }
            seen.insert(resolution.id)
            resolutions.append(resolution)
        }

        return resolutions.sorted {
            $0.width * $0.height > $1.width * $1.height
        }
    }

    static func supportedFrameRates(for device: AVCaptureDevice, resolution: Resolution) -> [Double] {
        var rates = Set<Double>()

        for format in device.formats {
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            guard Int(dims.width) == resolution.width, Int(dims.height) == resolution.height else { continue }

            for range in format.videoSupportedFrameRateRanges {
                var fps = range.minFrameRate
                let step = 10.0
                while fps <= range.maxFrameRate {
                    rates.insert(round(fps * 100) / 100)
                    fps += step
                }
                rates.insert(range.maxFrameRate)
            }
        }

        return rates.filter { $0 >= 1 }.sorted(by: >)
    }

    static func currentFormat(for device: AVCaptureDevice) -> VideoFormat? {
        let format = device.activeFormat
        let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let fps = format.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 30
        let pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription)
        return VideoFormat(width: Int(dims.width), height: Int(dims.height), fps: fps, pixelFormat: pixelFormat)
    }
}
