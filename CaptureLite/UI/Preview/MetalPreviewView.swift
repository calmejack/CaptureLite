import SwiftUI
import MetalKit

struct MetalPreviewView: NSViewRepresentable {
    let renderer: MetalRenderer

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: renderer.metalDevice)
        view.delegate = renderer
        view.framebufferOnly = false
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.autoResizeDrawable = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {}
}
