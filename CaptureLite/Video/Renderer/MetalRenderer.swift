import Metal
import MetalKit
import CoreVideo
import CoreMedia
import CoreGraphics
import ImageIO
import Foundation

final class MetalRenderer: NSObject, VideoRenderer, MTKViewDelegate, @unchecked Sendable {
    struct Vertex {
        var position: SIMD2<Float>
        var texCoord: SIMD2<Float>
    }

    struct RendererStats: Sendable {
        var fps: Double
        var resolution: String
        var pixelFormat: String
        var droppedFrames: Int
        var renderTimeMS: Double
        var latencyMS: Double
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var textureCache: CVMetalTextureCache?
    private var pipelineNV12: MTLRenderPipelineState?
    private var pipelineBGRA: MTLRenderPipelineState?
    private let vertexBuffer: MTLBuffer

    private let lock = NSLock()
    private var _latestFrame: VideoFrame?
    private var _aspectMode: AspectMode = .fit
    private var _mirror: Bool = false
    private var _rotation: Rotation = .zero

    private var _frameCount: Int = 0
    private var _sampleStart: CFAbsoluteTime = 0
    private var _fps: Double = 0
    private var _droppedFrames: Int = 0
    private var _pendingDrawn = false
    private var _lastRenderTimeMS: Double = 0
    private var _latestFrameArrival: CFAbsoluteTime = 0

    var aspectMode: AspectMode {
        get { lock.lock(); defer { lock.unlock() }; return _aspectMode }
        set { lock.lock(); _aspectMode = newValue; lock.unlock() }
    }

    var mirror: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _mirror }
        set { lock.lock(); _mirror = newValue; lock.unlock() }
    }

    var rotation: Rotation {
        get { lock.lock(); defer { lock.unlock() }; return _rotation }
        set { lock.lock(); _rotation = newValue; lock.unlock() }
    }

    var metalDevice: MTLDevice { device }

    static func make() -> MetalRenderer? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        return MetalRenderer(device: device)
    }

    init?(device: MTLDevice) {
        guard let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.commandQueue = queue

        guard let buffer = device.makeBuffer(length: MemoryLayout<Vertex>.stride * 4, options: []) else {
            return nil
        }
        self.vertexBuffer = buffer

        super.init()

        var cache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache) == kCVReturnSuccess else {
            return nil
        }
        self.textureCache = cache

        guard let library = try? device.makeDefaultLibrary(bundle: .main) else { return nil }
        buildPipelines(library: library)
    }

    private func buildPipelines(library: MTLLibrary) {
        let vertexFn = library.makeFunction(name: "vertex_main")

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertexFn
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm

        desc.fragmentFunction = library.makeFunction(name: "fragment_nv12")
        pipelineNV12 = try? device.makeRenderPipelineState(descriptor: desc)

        desc.fragmentFunction = library.makeFunction(name: "fragment_bgra")
        pipelineBGRA = try? device.makeRenderPipelineState(descriptor: desc)
    }

    func enqueue(_ frame: VideoFrame) {
        lock.lock()
        if _pendingDrawn {
            _droppedFrames += 1
        }
        _pendingDrawn = true
        _latestFrame = frame
        _latestFrameArrival = CFAbsoluteTimeGetCurrent()
        _frameCount += 1
        lock.unlock()
    }

    func currentFrame() -> VideoFrame? {
        lock.lock()
        defer { lock.unlock() }
        return _latestFrame
    }

    func stats() -> RendererStats {
        lock.lock()
        defer { lock.unlock() }
        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = now - _sampleStart
        if elapsed >= 1 {
            _fps = Double(_frameCount) / elapsed
            _frameCount = 0
            _sampleStart = now
        }
        let frame = _latestFrame
        let pixelFormat = Self.pixelFormatName(frame?.pixelFormat)
        let latencyMS = _latestFrameArrival > 0 ? (now - _latestFrameArrival) * 1000 : 0
        return RendererStats(
            fps: _fps,
            resolution: frame.map { "\($0.width) × \($0.height)" } ?? "—",
            pixelFormat: pixelFormat,
            droppedFrames: _droppedFrames,
            renderTimeMS: _lastRenderTimeMS,
            latencyMS: latencyMS
        )
    }

    private static func pixelFormatName(_ format: OSType?) -> String {
        guard let format else { return "—" }
        switch format {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: return "NV12"
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: return "NV12 (video)"
        case kCVPixelFormatType_32BGRA: return "BGRA"
        case kCVPixelFormatType_32ARGB: return "ARGB"
        default: return String(format: "%08X", format)
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        let start = CFAbsoluteTimeGetCurrent()
        lock.lock()
        let frame = _latestFrame
        let aspect = _aspectMode
        let mirror = _mirror
        let rotation = _rotation
        lock.unlock()

        guard let frame,
              let drawable = view.currentDrawable,
              let passDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
        else { return }

        lock.lock()
        _pendingDrawn = false
        lock.unlock()

        let drawableSize = view.drawableSize

        guard let textures = makeTextures(for: frame),
              let pipeline = textures.isNV12 ? pipelineNV12 : pipelineBGRA
        else {
            encoder.endEncoding()
            commandBuffer.commit()
            return
        }

        let vertices = Self.makeVertices(
            frameWidth: frame.width,
            frameHeight: frame.height,
            drawableWidth: Int(drawableSize.width),
            drawableHeight: Int(drawableSize.height),
            aspect: aspect,
            rotation: rotation,
            mirror: mirror
        )
        vertices.withUnsafeBytes { raw in
            vertexBuffer.contents().copyMemory(from: raw.baseAddress!, byteCount: raw.count)
        }

        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(textures.y, index: 0)
        if textures.isNV12, let cbcrTexture = textures.cbcr {
            encoder.setFragmentTexture(cbcrTexture, index: 1)
        }
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()

        let renderTime = (CFAbsoluteTimeGetCurrent() - start) * 1000
        lock.lock()
        _lastRenderTimeMS = renderTime
        lock.unlock()
    }

    func snapshotPNGData() -> Data? {
        lock.lock()
        let frame = _latestFrame
        let mirror = _mirror
        let rotation = _rotation
        lock.unlock()

        guard let frame else { return nil }

        var outWidth = frame.width
        var outHeight = frame.height
        if rotation == .ninety || rotation == .twoSeventy {
            swap(&outWidth, &outHeight)
        }

        guard let textures = makeTextures(for: frame),
              let pipeline = textures.isNV12 ? pipelineNV12 : pipelineBGRA
        else { return nil }

        let textureDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: outWidth, height: outHeight, mipmapped: false
        )
        textureDesc.usage = [.renderTarget, .shaderRead]
        guard let outTexture = device.makeTexture(descriptor: textureDesc) else { return nil }

        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].texture = outTexture
        passDesc.colorAttachments[0].loadAction = .clear
        passDesc.colorAttachments[0].storeAction = .store
        passDesc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        let vertices = Self.makeVertices(
            frameWidth: frame.width,
            frameHeight: frame.height,
            drawableWidth: outWidth,
            drawableHeight: outHeight,
            aspect: .stretch,
            rotation: rotation,
            mirror: mirror
        )
        vertices.withUnsafeBytes { raw in
            vertexBuffer.contents().copyMemory(from: raw.baseAddress!, byteCount: raw.count)
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDesc)
        else { return nil }

        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentTexture(textures.y, index: 0)
        if textures.isNV12, let cbcrTexture = textures.cbcr {
            encoder.setFragmentTexture(cbcrTexture, index: 1)
        }
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        let bytesPerRow = outWidth * 4
        guard let readback = device.makeBuffer(length: bytesPerRow * outHeight, options: .storageModeShared),
              let blit = commandBuffer.makeBlitCommandEncoder()
        else { return nil }

        blit.copy(
            from: outTexture, sourceSlice: 0, sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: outWidth, height: outHeight, depth: 1),
            to: readback, destinationOffset: 0,
            destinationBytesPerRow: bytesPerRow, destinationBytesPerImage: bytesPerRow * outHeight
        )
        blit.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return encodePNG(bytes: readback.contents(), width: outWidth, height: outHeight, bytesPerRow: bytesPerRow)
    }

    private func encodePNG(bytes: UnsafeRawPointer, width: Int, height: Int, bytesPerRow: Int) -> Data? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        bitmapInfo.insert(.byteOrder32Little)

        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: colorSpace, bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }

        guard let data = context.data else { return nil }
        data.copyMemory(from: bytes, byteCount: bytesPerRow * height)

        guard let image = context.makeImage() else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    private func makeTextures(for frame: VideoFrame) -> (y: MTLTexture, cbcr: MTLTexture?, isNV12: Bool)? {
        guard let cache = textureCache else { return nil }
        let isNV12 = frame.pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            || frame.pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange

        if isNV12 {
            var yOut: CVMetalTexture?
            CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault, cache, frame.pixelBuffer, nil,
                .r8Unorm, frame.width, frame.height, 0, &yOut
            )
            var cbcrOut: CVMetalTexture?
            CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault, cache, frame.pixelBuffer, nil,
                .rg8Unorm, frame.width / 2, frame.height / 2, 1, &cbcrOut
            )
            guard let yOut else { return nil }
            guard let yTexture = CVMetalTextureGetTexture(yOut) else { return nil }
            var cbcrTexture: MTLTexture?
            if let cbcrOut {
                cbcrTexture = CVMetalTextureGetTexture(cbcrOut)
            }
            return (yTexture, cbcrTexture, true)
        } else {
            var out: CVMetalTexture?
            CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault, cache, frame.pixelBuffer, nil,
                .bgra8Unorm, frame.width, frame.height, 0, &out
            )
            guard let out else { return nil }
            guard let texture = CVMetalTextureGetTexture(out) else { return nil }
            return (texture, nil, false)
        }
    }

    static func makeVertices(
        frameWidth: Int,
        frameHeight: Int,
        drawableWidth: Int,
        drawableHeight: Int,
        aspect: AspectMode,
        rotation: Rotation,
        mirror: Bool
    ) -> [Vertex] {
        var videoWidth = Float(frameWidth)
        var videoHeight = Float(frameHeight)
        if rotation == .ninety || rotation == .twoSeventy {
            swap(&videoWidth, &videoHeight)
        }

        let viewWidth = Float(max(drawableWidth, 1))
        let viewHeight = Float(max(drawableHeight, 1))
        let videoAspect = videoWidth / videoHeight
        let viewAspect = viewWidth / viewHeight

        var scaleX: Float = 1
        var scaleY: Float = 1

        switch aspect {
        case .stretch:
            scaleX = 1
            scaleY = 1
        case .fit:
            if videoAspect > viewAspect {
                scaleY = viewAspect / videoAspect
            } else {
                scaleX = videoAspect / viewAspect
            }
        case .fill:
            if videoAspect > viewAspect {
                scaleX = videoAspect / viewAspect
            } else {
                scaleY = viewAspect / videoAspect
            }
        }

        func uv(_ u: Float, _ v: Float) -> SIMD2<Float> {
            var u = u
            var v = v
            switch rotation {
            case .zero:
                break
            case .ninety:
                (u, v) = (1 - v, u)
            case .oneEighty:
                (u, v) = (1 - u, 1 - v)
            case .twoSeventy:
                (u, v) = (v, 1 - u)
            }
            if mirror {
                u = 1 - u
            }
            return SIMD2(u, v)
        }

        return [
            Vertex(position: SIMD2(-scaleX, scaleY), texCoord: uv(0, 0)),
            Vertex(position: SIMD2(scaleX, scaleY), texCoord: uv(1, 0)),
            Vertex(position: SIMD2(-scaleX, -scaleY), texCoord: uv(0, 1)),
            Vertex(position: SIMD2(scaleX, -scaleY), texCoord: uv(1, 1)),
        ]
    }
}
