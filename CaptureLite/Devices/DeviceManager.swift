import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
final class DeviceManager {
    private(set) var videoDevices: [DeviceDescriptor] = []
    private(set) var audioDevices: [DeviceDescriptor] = []

    var onDeviceConnected: ((String) -> Void)?
    var onDeviceDisconnected: ((String) -> Void)?

    private let videoDiscovery = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
        mediaType: .video,
        position: .unspecified
    )

    private let audioDiscovery = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.microphone],
        mediaType: .audio,
        position: .unspecified
    )

    init() {
        refresh()
        startObserving()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func refresh() {
        videoDevices = videoDiscovery.devices.map(Self.descriptor(for:))
        audioDevices = audioDiscovery.devices.map(Self.descriptor(for:))
        Logger.debug("Devices refreshed. video=\(videoDevices.count) audio=\(audioDevices.count)", category: .device)
    }

    func device(withID id: String, mediaType: AVMediaType) -> DeviceDescriptor? {
        switch mediaType {
        case .video: return videoDevices.first { $0.id == id }
        case .audio: return audioDevices.first { $0.id == id }
        default: return nil
        }
    }

    func captureDevice(withID id: String, mediaType: AVMediaType) -> AVCaptureDevice? {
        switch mediaType {
        case .video: return videoDiscovery.devices.first { $0.uniqueID == id }
        case .audio: return audioDiscovery.devices.first { $0.uniqueID == id }
        default: return nil
        }
    }

    private func startObserving() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(deviceChanged),
            name: AVCaptureDevice.wasConnectedNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(deviceChanged),
            name: AVCaptureDevice.wasDisconnectedNotification,
            object: nil
        )
    }

    @objc private func deviceChanged(_ notification: Notification) {
        guard let device = notification.object as? AVCaptureDevice else { return }
        refresh()
        if notification.name == AVCaptureDevice.wasConnectedNotification {
            Logger.info("Device connected: \(device.localizedName)", category: .device)
            onDeviceConnected?(device.uniqueID)
        } else {
            Logger.info("Device disconnected: \(device.localizedName)", category: .device)
            onDeviceDisconnected?(device.uniqueID)
        }
    }

    private static func descriptor(for device: AVCaptureDevice) -> DeviceDescriptor {
        return DeviceDescriptor(
            id: device.uniqueID,
            name: device.localizedName,
            transport: nil,
            isExternal: device.position == .unspecified,
            deviceType: classify(device)
        )
    }

    private static func classify(_ device: AVCaptureDevice) -> DeviceDescriptor.DeviceType {
        switch device.position {
        case .front, .back: return .builtIn
        case .unspecified: return .captureCard
        default: return .unknown
        }
    }
}
