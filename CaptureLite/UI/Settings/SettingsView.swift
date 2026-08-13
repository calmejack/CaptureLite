import SwiftUI
import AppKit

struct SettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        TabView {
            Form {
                Toggle("记住上次使用的设备", isOn: $settings.rememberLastDevice)
                folderPicker(label: "截图文件夹", path: $settings.screenshotDirectory)
                folderPicker(label: "录制文件夹", path: $settings.recordingDirectory)
            }
            .formStyle(.grouped)
            .tabItem { Text("通用") }
            .padding()

            Form {
                Picker("编码格式", selection: $settings.recordingCodec) {
                    ForEach(VideoCodec.allCases) { codec in
                        Text(codec.displayName).tag(codec)
                    }
                }
                Picker("录制质量", selection: $settings.recordingQuality) {
                    ForEach(RecordingQuality.allCases) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Text("录制") }
            .padding()
        }
        .frame(width: 460, height: 300)
    }

    @ViewBuilder
    private func folderPicker(label: String, path: Binding<URL>) -> some View {
        HStack {
            Text(label)
            Text(path.wrappedValue.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button("选择…") {
                pickFolder(current: path.wrappedValue) { url in
                    path.wrappedValue = url
                }
            }
        }
    }

    private func pickFolder(current: URL, completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = current
        if panel.runModal() == .OK, let url = panel.url {
            completion(url)
        }
    }
}
