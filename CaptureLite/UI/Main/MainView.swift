import SwiftUI

struct MainView: View {
    @State private var viewModel: MainViewModel
    @State private var showVideoPopover = false
    @State private var showAudioPopover = false

    init(viewModel: MainViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            PreviewView(state: viewModel.state, renderer: viewModel.renderer)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            controlBar
        }
        .frame(minWidth: 720, minHeight: 480)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            Task { await viewModel.start() }
        }
        .alert("提示", isPresented: errorAlertBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.state.errorMessage ?? "")
        }
        .background {
            Button("") { viewModel.toggleMute() }
                .keyboardShortcut("m", modifiers: [])
                .opacity(0)
                .frame(width: 0, height: 0)
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.errorMessage != nil },
            set: { if !$0 { viewModel.state.errorMessage = nil } }
        )
    }

    private var controlBar: some View {
        HStack(spacing: 16) {
            Button {
                showVideoPopover.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "video.fill")
                    Text(viewModel.state.currentVideoDevice?.name ?? "视频设备")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .frame(maxWidth: 240)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showVideoPopover) {
                VideoDevicePopover(viewModel: viewModel, state: viewModel.state)
            }

            Button {
                showAudioPopover.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                    Text(viewModel.state.currentAudioDevice?.name ?? "音频设备")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .frame(maxWidth: 220)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showAudioPopover) {
                AudioDevicePopover(viewModel: viewModel, state: viewModel.state)
            }

            Spacer()

            #if DEBUG
            Button {
                viewModel.state.isDebugOverlayExpanded.toggle()
            } label: {
                Image(systemName: viewModel.state.isDebugOverlayExpanded ? "info.circle.fill" : "info.circle")
                    .font(.system(size: 16))
            }
            .buttonStyle(.borderless)
            .help("显示/隐藏调试信息")
            #endif

            Button {
                viewModel.screenshot()
            } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18))
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .help("截图 (⇧⌘S)")

            Button {
                viewModel.toggleRecording()
            } label: {
                recordingLabel
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("r", modifiers: .command)
            .help("录制 (⌘R)")

            Button {
                toggleFullscreen()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 16))
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("f", modifiers: .command)
            .help("全屏 (⌘F)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var recordingLabel: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.state.recordingState == .recording ? Color.red : Color.secondary)
                .frame(width: 10, height: 10)
            if case .recording = viewModel.state.recordingState {
                Text(formattedElapsed)
                    .font(.system(.body, design: .monospaced))
            } else {
                Text("REC")
                    .font(.body.weight(.medium))
            }
        }
    }

    private var formattedElapsed: String {
        let seconds = Int(viewModel.state.recordingElapsed)
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }

    private func toggleFullscreen() {
        if let window = NSApp.keyWindow {
            window.toggleFullScreen(nil)
        }
    }
}
