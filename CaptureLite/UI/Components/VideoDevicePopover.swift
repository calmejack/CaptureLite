import SwiftUI

struct VideoDevicePopover: View {
    let viewModel: MainViewModel
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("视频设备")
                .font(.headline)

            Menu {
                ForEach(state.videoDevices) { device in
                    Button {
                        viewModel.selectVideoDevice(device)
                    } label: {
                        if device.id == state.currentVideoDevice?.id {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Text(device.name)
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "video.fill")
                    Text(state.currentVideoDevice?.name ?? "选择设备")
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption2)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            if !state.availableResolutions.isEmpty {
                Picker("分辨率", selection: $state.selectedResolution) {
                    ForEach(state.availableResolutions) { resolution in
                        Text(resolution.displayName).tag(Optional(resolution))
                    }
                }
                .onChange(of: state.selectedResolution) { _, newValue in
                    if let newValue { viewModel.setResolution(newValue) }
                }

                Picker("帧率", selection: $state.selectedFPS) {
                    ForEach(state.availableFrameRates, id: \.self) { fps in
                        Text(Self.fpsLabel(fps)).tag(Optional(fps))
                    }
                }
                .onChange(of: state.selectedFPS) { _, newValue in
                    if let newValue { viewModel.setFPS(newValue) }
                }
            }

            Divider()

            Picker("画面比例", selection: $state.aspectMode) {
                ForEach(AspectMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .onChange(of: state.aspectMode) { _, newValue in
                viewModel.setAspectMode(newValue)
            }

            Picker("旋转", selection: $state.rotation) {
                ForEach(Rotation.allCases) { rotation in
                    Text("\(rotation.rawValue)°").tag(rotation)
                }
            }
            .onChange(of: state.rotation) { _, newValue in
                viewModel.setRotation(newValue)
            }

            Toggle("镜像", isOn: $state.mirror)
                .onChange(of: state.mirror) { _, newValue in
                    viewModel.setMirror(newValue)
                }
        }
        .padding()
        .frame(width: 280)
    }

    private static func fpsLabel(_ fps: Double) -> String {
        fps == floor(fps) ? "\(Int(fps)) FPS" : String(format: "%.2f FPS", fps)
    }
}
