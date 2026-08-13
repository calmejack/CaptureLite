import SwiftUI

struct DebugOverlayView: View {
    let renderer: MetalRenderer

    @State private var stats: MetalRenderer.RendererStats?
    @State private var timer: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let stats {
                Text(String(format: "FPS %.1f", stats.fps))
                Text(stats.resolution + " · " + stats.pixelFormat)
                Text("dropped \(stats.droppedFrames)")
                Text(String(format: "render %.2f ms", stats.renderTimeMS))
            }
        }
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.green)
        .padding(6)
        .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
        .onAppear {
            stats = renderer.stats()
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                stats = renderer.stats()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}
