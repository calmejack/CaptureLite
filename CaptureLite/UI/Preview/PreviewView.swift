import SwiftUI

struct PreviewView: View {
    let state: AppState
    let renderer: MetalRenderer?

    var body: some View {
        ZStack {
            Color.black
            if let renderer {
                MetalPreviewView(renderer: renderer)
            }
            if state.currentVideoDevice == nil {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("未检测到视频设备")
                .font(.title3.weight(.medium))
            Text("连接 USB 摄像头或 HDMI 视频采集卡\n设备连接后将自动显示画面")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
