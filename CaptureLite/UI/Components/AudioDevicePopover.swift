import SwiftUI

struct AudioDevicePopover: View {
    let viewModel: MainViewModel
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("音频设备")
                .font(.headline)

            Menu {
                ForEach(state.audioDevices) { device in
                    Button {
                        viewModel.selectAudioDevice(device)
                    } label: {
                        if device.id == state.currentAudioDevice?.id {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Text(device.name)
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                    Text(state.currentAudioDevice?.name ?? "选择设备")
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption2)
                }
            }
            .frame(maxWidth: .infinity)

            MeterBar(level: state.audioLevel)

            Toggle("静音", isOn: $state.isMuted)
                .onChange(of: state.isMuted) { _, newValue in
                    viewModel.setMuted(newValue)
                }
        }
        .padding()
        .frame(width: 260)
    }
}

struct MeterBar: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                Capsule()
                    .fill(level > 0.85 ? Color.red : Color.accentColor)
                    .frame(width: max(4, geo.size.width * CGFloat(level)))
                    .animation(.linear(duration: 0.05), value: level)
            }
        }
        .frame(height: 8)
    }
}
