import SwiftUI

struct DebugOverlayView: View {
    let state: AppState
    let renderer: MetalRenderer

    @State private var stats: MetalRenderer.RendererStats?
    @State private var timer: Timer?
    @State private var offset: CGSize = .zero
    @State private var position: CGPoint = .zero
    @State private var contentSize: CGSize = .zero
    @State private var containerSize: CGSize = .zero

    private let snapMargin: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            let container = proxy.size
            content
                .fixedSize()
                .onGeometryChange(for: CGSize.self) { contentProxy in
                    contentProxy.size
                } action: { newSize in
                    if contentSize != newSize {
                        contentSize = newSize
                        clampToContainer(container)
                    }
                }
                .onAppear {
                    containerSize = container
                    position = state.debugOverlayPosition ?? CGPoint(x: snapMargin, y: snapMargin)
                }
                .onChange(of: container) { _, newSize in
                    containerSize = newSize
                    clampToContainer(newSize)
                    savePosition()
                }
                .position(x: position.x + offset.width, y: position.y + offset.height)
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            offset = value.translation
                        }
                        .onEnded { value in
                            position.x += value.translation.width
                            position.y += value.translation.height
                            offset = .zero
                            snap()
                        }
                )
                .onDisappear {
                    savePosition()
                }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let stats {
                Text(String(format: "FPS %.1f", stats.fps))
                Text(stats.resolution + " · " + stats.pixelFormat)
                Text("render \(String(format: "%.1f", stats.latencyMS)) ms")
                Text("dropped \(stats.droppedFrames)")
            }
        }
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.green)
        .padding(6)
        .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
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

    private func clampToContainer(_ container: CGSize) {
        let halfW = contentSize.width / 2
        let halfH = contentSize.height / 2
        position.x = min(max(position.x, halfW + snapMargin), max(halfW + snapMargin, container.width - halfW - snapMargin))
        position.y = min(max(position.y, halfH + snapMargin), max(halfH + snapMargin, container.height - halfH - snapMargin))
    }

    private func savePosition() {
        state.debugOverlayPosition = position
    }

    private func snap() {
        let halfW = contentSize.width / 2
        let halfH = contentSize.height / 2
        let minX = halfW + snapMargin
        let minY = halfH + snapMargin
        let maxX = max(minX, containerSize.width - halfW - snapMargin)
        let maxY = max(minY, containerSize.height - halfH - snapMargin)

        let currentX = position.x
        let currentY = position.y

        let anchors: [CGPoint] = [
            CGPoint(x: minX, y: minY),                     // top-left
            CGPoint(x: maxX, y: minY),                     // top-right
            CGPoint(x: minX, y: maxY),                     // bottom-left
            CGPoint(x: maxX, y: maxY),                     // bottom-right
            CGPoint(x: containerSize.width / 2, y: minY),  // top-center
            CGPoint(x: containerSize.width / 2, y: maxY),  // bottom-center
            CGPoint(x: minX, y: containerSize.height / 2), // left-center
            CGPoint(x: maxX, y: containerSize.height / 2), // right-center
        ]

        let nearest = anchors.min { a, b in
            distSq(a, to: currentX, y: currentY) < distSq(b, to: currentX, y: currentY)
        } ?? anchors[0]

        withAnimation(.easeOut(duration: 0.18)) {
            position = nearest
        }
        savePosition()
    }

    private func distSq(_ p: CGPoint, to x: CGFloat, y: CGFloat) -> CGFloat {
        let dx = p.x - x
        let dy = p.y - y
        return dx * dx + dy * dy
    }
}
