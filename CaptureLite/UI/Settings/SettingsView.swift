import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        TabView {
            Form {
                Toggle("记住上次使用的设备", isOn: $settings.rememberLastDevice)
            }
            .tabItem { Text("通用") }
            .padding()

            Form {
                Picker("编码格式", selection: $settings.recordingCodec) {
                    ForEach(VideoCodec.allCases) { codec in
                        Text(codec.displayName).tag(codec)
                    }
                }
            }
            .tabItem { Text("录制") }
            .padding()
        }
        .frame(width: 420, height: 260)
    }
}
