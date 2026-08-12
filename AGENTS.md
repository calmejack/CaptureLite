# CaptureLite — macOS 轻量视频采集与录制应用 Vibe Coding Prompt

> 目标：使用 Swift + SwiftUI + AVFoundation + Metal + VideoToolbox 构建一个面向 macOS 的轻量视频采集应用。  
> 核心场景是 USB 摄像头、HDMI USB 视频采集卡的实时预览、截图、音频监听与本地录制。  
> 产品体验应明显比 OBS 更简单，但底层架构必须为后续画中画、场景、屏幕采集、虚拟摄像头、直播、滤镜、插件系统等能力预留扩展空间。

---

# 1. AI Agent 工作原则

你正在实现一个真实可维护的 macOS 原生应用，而不是 Demo。

必须遵守以下原则：

1. 不要一次性实现所有未来功能。
2. 优先完成当前阶段 MVP。
3. 每一步都保持项目可编译、可运行。
4. 在修改多个文件之前，先理解现有项目结构。
5. 不要为了“未来扩展”提前引入复杂框架。
6. 不要创建巨大 Manager / Service 类。
7. Capture、Render、Output 必须解耦。
8. UI 不得直接依赖 AVFoundation 底层细节。
9. 任何可扩展能力优先通过 protocol / abstraction 实现。
10. 不要复制 OBS 的复杂交互。
11. 优先使用 Apple 原生框架。
12. MVP 阶段不要引入 FFmpeg。
13. 除非确有必要，不引入第三方依赖。
14. 不使用 Electron、Flutter、React Native。
15. 所有耗时操作不得阻塞 MainActor。
16. 视频帧处理必须避免不必要的内存复制。
17. 不要在 SwiftUI View 内写 Capture / Encoder / Device 业务逻辑。
18. 每完成一个阶段，检查：
    - 是否可以编译
    - 是否可以运行
    - 是否出现明显线程问题
    - 是否有资源泄漏
    - 是否破坏前一阶段功能

---

# 2. 产品定位

产品暂定名称：

`CaptureLite`

这是一个：

> macOS 原生、轻量、低资源占用的视频采集与录制工具。

核心体验：

```text
打开 App
   ↓
自动发现 USB 摄像头 / HDMI 采集卡
   ↓
自动恢复上一次使用设备
   ↓
立即显示画面
   ↓
截图 / 录制 / 全屏
```

用户不需要：

- 创建 Scene
- 创建 Source
- 配置复杂 Output
- 理解 OBS 概念
- 手动搭建音视频链路

MVP 必须做到：

> 插上设备就能看，点一下就能录。

---

# 3. 核心用户场景

重点覆盖：

- HDMI 视频采集卡
- USB 摄像头
- 游戏机采集
- Switch
- PS5
- Xbox
- 相机 HDMI 输出
- 手机 HDMI 输出
- 显微镜 USB 摄像头
- 会议摄像头
- 外部 USB 音频设备
- 摄像头本地录制

---

# 4. 非目标

MVP 阶段明确不做：

- RTMP 推流
- SRT
- WebRTC
- 虚拟摄像头
- Browser Source
- NDI
- 多场景 UI
- Scene Transition
- 插件市场
- AI 抠像
- 绿幕
- LUT
- 大量滤镜
- 多轨录音
- 多路直播
- FFmpeg
- 云同步
- 登录系统
- 用户系统

这些只在架构层预留，不实际实现。

---

# 5. 技术栈

使用：

```text
Language
- Swift 6+

UI
- SwiftUI
- 少量 AppKit bridge（仅必要时）

Capture
- AVFoundation
- CoreMedia
- CoreVideo

Rendering
- Metal
- MetalKit

Encoding
- VideoToolbox

Audio
- AVFoundation
- CoreAudio（仅必要时）

Future
- ScreenCaptureKit
- CoreMediaIO
```

最低目标系统：

```text
macOS 15+
Apple Silicon 优先
Intel 不作为第一阶段重点
```

如项目已有 Deployment Target，则不要擅自降低。

---

# 6. 总体架构

应用必须遵循以下数据流：

```text
Video Source
     │
     ▼
CMSampleBuffer
     │
     ▼
VideoFrame
     │
     ▼
VideoPipeline
     │
     ├──────────────┐
     │              │
     ▼              ▼
Preview          Recorder
     │              │
     ▼              ▼
Metal          VideoToolbox
Renderer         Encoder
```

后续扩展：

```text
                 ┌─ Preview
                 ├─ Recorder
Source → Pipeline├─ Stream
                 └─ Virtual Camera
```

重要：

`Preview` 不是整个系统的中心。

---

# 7. 模块边界

必须拆成：

```text
Capture
Rendering
Video Pipeline
Audio
Output
Device Management
Scene Model
Storage
UI
```

依赖方向：

```text
UI
 ↓
Application Layer
 ↓
Domain Abstractions
 ↓
AVFoundation / Metal / VideoToolbox
```

禁止：

```text
SwiftUI View
  ↓
AVCaptureSession
```

SwiftUI View 不直接控制 AVCaptureSession。

---

# 8. 项目目录

优先采用：

```text
CaptureLite/
│
├── App/
│   ├── CaptureLiteApp.swift
│   ├── AppState.swift
│   └── AppEnvironment.swift
│
├── UI/
│   ├── Main/
│   │   ├── MainView.swift
│   │   └── MainViewModel.swift
│   │
│   ├── Preview/
│   │   ├── PreviewView.swift
│   │   └── MetalPreviewView.swift
│   │
│   ├── DevicePicker/
│   ├── Audio/
│   ├── Recording/
│   ├── Settings/
│   └── Components/
│
├── Capture/
│   ├── CaptureEngine.swift
│   │
│   ├── Video/
│   │   ├── VideoSource.swift
│   │   ├── VideoFrame.swift
│   │   ├── VideoFormat.swift
│   │   └── AVCaptureVideoSource.swift
│   │
│   └── Audio/
│       ├── AudioSource.swift
│       ├── AudioFrame.swift
│       └── AVCaptureAudioSource.swift
│
├── Video/
│   ├── VideoPipeline.swift
│   │
│   ├── Renderer/
│   │   ├── VideoRenderer.swift
│   │   └── MetalRenderer.swift
│   │
│   └── Effects/
│       ├── VideoEffect.swift
│       ├── EffectChain.swift
│       ├── MirrorEffect.swift
│       ├── RotateEffect.swift
│       └── CropEffect.swift
│
├── Audio/
│   ├── AudioEngine.swift
│   ├── AudioMeter.swift
│   └── AudioMonitor.swift
│
├── Output/
│   ├── Output.swift
│   ├── OutputManager.swift
│   │
│   ├── Recording/
│   │   ├── Recorder.swift
│   │   ├── RecordingConfig.swift
│   │   ├── VideoEncoder.swift
│   │   ├── VideoToolboxH264Encoder.swift
│   │   └── VideoToolboxHEVCEncoder.swift
│   │
│   ├── Streaming/
│   └── VirtualCamera/
│
├── Scene/
│   ├── Scene.swift
│   ├── SceneItem.swift
│   └── Transform.swift
│
├── Devices/
│   ├── DeviceManager.swift
│   ├── DeviceDescriptor.swift
│   ├── DeviceMonitor.swift
│   └── DevicePreferences.swift
│
├── Storage/
│   ├── SettingsStore.swift
│   └── ProjectStore.swift
│
├── Utilities/
│   ├── Logger.swift
│   ├── Extensions/
│   └── Errors/
│
└── Resources/
```

如果当前项目已经存在不同目录结构：

不要为了符合本文档而机械重构。

应尽量保持：

- Capture
- Pipeline
- Renderer
- Output
- UI

这几个职责边界。

---

# 9. 核心数据模型

## 9.1 VideoFrame

定义统一视频帧：

```swift
struct VideoFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let timestamp: CMTime
    let duration: CMTime?
    let width: Int
    let height: Int
    let pixelFormat: OSType
}
```

具体字段可根据编译要求调整。

关键原则：

- 不要到处传 CMSampleBuffer
- Capture 层负责转换
- Pipeline 使用 VideoFrame
- Renderer 使用 VideoFrame
- Recorder 可以同时保留必要时间信息

---

# 10. VideoSource

必须定义抽象：

```swift
protocol VideoSource: AnyObject {
    var id: String { get }
    var name: String { get }

    func start() async throws
    func stop()

    var frames: AsyncStream<VideoFrame> { get }
}
```

可根据 Swift Concurrency 约束进行合理改写。

第一阶段实现：

```text
AVCaptureVideoSource
```

未来：

```text
ScreenCaptureSource
WindowCaptureSource
ImageSource
MediaFileSource
NDISource
RTSPSource
WebRTCSource
```

不要实现未来 Source。

---

# 11. AudioSource

定义：

```swift
protocol AudioSource: AnyObject {
    var id: String { get }
    var name: String { get }

    func start() async throws
    func stop()
}
```

后续可以增加：

```text
AsyncStream<AudioFrame>
```

MVP 至少支持：

- 列出音频输入设备
- 选择设备
- 音量电平
- 静音

---

# 12. DeviceManager

职责：

- 获取视频设备
- 获取音频设备
- 监听设备插拔
- 保存用户上次设备
- 当设备消失时处理 fallback
- 当设备重新连接时尝试恢复

禁止 DeviceManager：

- 处理视频帧
- 录制
- Metal rendering
- SwiftUI navigation

---

# 13. 设备发现

视频设备使用：

```text
AVCaptureDevice.DiscoverySession
```

必须考虑：

- USB 摄像头
- HDMI USB 采集卡
- 内建摄像头
- 外部摄像头
- 连续性摄像头

设备模型建议：

```swift
struct DeviceDescriptor: Identifiable, Hashable {
    let id: String
    let name: String
    let transport: String?
    let isExternal: Bool
}
```

不得依赖设备名称判断“是不是采集卡”。

---

# 14. CaptureEngine

CaptureEngine 是采集协调器。

负责：

- 当前 VideoSource
- 当前 AudioSource
- 启停采集
- 切换设备
- 向 VideoPipeline 分发帧
- 处理设备异常

不负责：

- UI
- 编码
- 文件保存
- 场景布局
- Metal shader

---

# 15. AVCaptureVideoSource

职责：

```text
AVCaptureSession
AVCaptureDeviceInput
AVCaptureVideoDataOutput
```

必须：

- 使用独立队列接收帧
- 避免在 MainActor 做视频处理
- 设置适合低延迟预览的输出策略
- 合理处理 alwaysDiscardsLateVideoFrames
- 不对每一帧创建大量临时对象

输出：

```text
CMSampleBuffer
 ↓
CVPixelBuffer
 ↓
VideoFrame
```

---

# 16. 视频格式

支持：

- Resolution
- FPS

MVP UI：

```text
Resolution
[ 1920 × 1080 ▼ ]

Frame Rate
[ 60 FPS ▼ ]
```

必须从：

```text
AVCaptureDevice.formats
```

读取真实支持格式。

不得硬编码“所有设备都支持 1080p60”。

切换格式时：

- lockForConfiguration
- activeFormat
- activeVideoMinFrameDuration
- activeVideoMaxFrameDuration
- unlockForConfiguration

必须做好错误处理。

---

# 17. 视频 Pipeline

定义：

```swift
final class VideoPipeline {
    ...
}
```

或 actor。

负责：

```text
VideoSource
 ↓
EffectChain
 ↓
Output Fan-out
```

第一阶段：

```text
Input
 ↓
Mirror
 ↓
Rotate
 ↓
Renderer
```

保持最小实现。

---

# 18. VideoEffect

预留：

```swift
protocol VideoEffect {
    var id: String { get }

    func process(_ frame: VideoFrame) async throws -> VideoFrame
}
```

第一阶段可实现：

```text
MirrorEffect
RotateEffect
CropEffect
```

如果这些更适合在 Metal Renderer shader 内实现，可调整实现方式。

重点是：

外层仍保留 Effect / Transform 抽象。

未来：

```text
ColorAdjustmentEffect
LUTEffect
SharpenEffect
BackgroundBlurEffect
ChromaKeyEffect
WatermarkEffect
TextOverlayEffect
FaceTrackingEffect
```

不要提前实现。

---

# 19. Metal Renderer

MVP 就使用 Metal。

目标：

```text
CVPixelBuffer
 ↓
CVMetalTextureCache
 ↓
MTLTexture
 ↓
Metal Rendering
 ↓
Preview
```

必须尽量：

- Zero-copy
- 避免 CPU pixel conversion
- 避免 UIImage / NSImage 中转
- 不要每帧创建新的 Metal device
- 不要每帧创建新的 command queue

建议长期持有：

```text
MTLDevice
MTLCommandQueue
CVMetalTextureCache
Render Pipeline State
```

---

# 20. 预览比例

支持：

```text
Fit
Fill
Stretch
```

默认：

```text
Fit
```

行为：

### Fit

完整显示视频：

```text
letterbox / pillarbox
```

### Fill

填满容器：

```text
center crop
```

### Stretch

拉伸到容器大小。

不要修改原始采集分辨率来实现 Fit / Fill。

这是渲染 Transform。

---

# 21. Mirror

支持：

```text
Horizontal Mirror
```

默认：

- 普通摄像头可考虑 UI 默认镜像
- HDMI 采集卡不要默认镜像

不要根据名称自动决定。

可以按设备保存设置。

---

# 22. Rotate

MVP：

```text
0°
90°
180°
270°
```

如果第一阶段工作量过大：

至少完成：

```text
0°
180°
```

---

# 23. Main UI

主界面目标：

```text
┌─────────────────────────────────────────────┐
│ CaptureLite                 1080p60     ⚙   │
├─────────────────────────────────────────────┤
│                                             │
│                                             │
│                 Preview                     │
│                                             │
│                                             │
├─────────────────────────────────────────────┤
│ 🎥 HDMI Capture        🔊 USB Audio         │
│                                             │
│          📷       ● REC       ⛶             │
│        Screenshot Record   Fullscreen       │
└─────────────────────────────────────────────┘
```

设计原则：

- Preview 占据最大区域
- 常用功能永远可见
- 设备切换简单
- 高级设置隐藏
- 不做 OBS 风格多面板

---

# 24. 未连接设备 UI

如果没有设备：

```text
未检测到视频设备

连接 USB 摄像头或 HDMI 视频采集卡
设备连接后将自动显示画面
```

设备插入：

自动刷新设备列表。

如果用户只有一个外部设备：

可以自动选择。

---

# 25. 视频设备 Popover

点击视频设备：

```text
Video Device

✓ Elgato HD60 X
  FaceTime HD Camera
  OBS Virtual Camera

Format

Resolution
[ 1920 × 1080 ▼ ]

Frame Rate
[ 60 FPS ▼ ]

Aspect Ratio
● Fit
○ Fill
○ Stretch

□ Mirror

Rotation
[ 0° ▼ ]
```

---

# 26. Audio Popover

```text
Audio Device

✓ HDMI Capture Audio
  Mac Microphone
  USB Audio

████████░░

Volume   80%

Mute ○
```

MVP 第一阶段：

只需要实现：

- 设备选择
- 音量电平
- Mute

本地监听可以作为次阶段。

---

# 27. 音频电平

实现简单 RMS / Peak Meter。

刷新 UI 频率：

```text
约 20 ~ 30 FPS
```

不要让 SwiftUI 对每个 Audio Sample 重绘。

对原始采样进行降频后更新 UI。

---

# 28. Screenshot

截图按钮：

```text
📷
```

行为：

```text
当前最终预览帧
 ↓
保存 PNG / HEIC / JPEG
```

默认：

```text
PNG
```

如果当前 Pipeline 已经包含：

- Mirror
- Rotate
- Crop

截图必须与用户看到的预览一致。

截图保存位置：

默认：

```text
~/Pictures/CaptureLite/
```

允许后续设置修改。

---

# 29. Recording

MVP 支持：

```text
Container
- MP4

Codec
- H.264
- HEVC
```

默认：

```text
H.264
```

分辨率：

默认跟随采集源。

FPS：

默认跟随采集源。

编码：

优先 VideoToolbox Hardware Encoder。

---

# 30. VideoEncoder

定义：

```swift
protocol VideoEncoder {
    func configure(_ config: RecordingConfig) throws

    func encode(_ frame: VideoFrame) async throws

    func finish() async throws
}
```

实现：

```text
VideoToolboxH264Encoder
VideoToolboxHEVCEncoder
```

---

# 31. RecordingConfig

至少：

```swift
struct RecordingConfig {
    var codec: VideoCodec
    var width: Int
    var height: Int
    var fps: Double
    var bitrate: Int?
    var outputURL: URL
}
```

---

# 32. Recorder

Recorder 负责：

```text
Start
Stop
Timestamp
Mux
File Lifecycle
```

不要让 VideoEncoder 负责所有逻辑。

建议：

```text
Recorder
 ↓
VideoEncoder
 ↓
Mux / File Writer
```

如果 MVP 使用 AVAssetWriter 简化 mux：

允许。

架构仍保留 Encoder 抽象。

---

# 33. 录制状态

UI：

未录制：

```text
● REC
```

录制中：

```text
● 00:03:18
```

录制中按钮状态明显。

必须避免用户：

- 连续重复 start
- stop 未完成又 start
- App 退出导致损坏文件

---

# 34. 录制文件命名

默认：

```text
CaptureLite_2026-08-13_14-30-22.mp4
```

保存：

```text
~/Movies/CaptureLite/
```

---

# 35. Fullscreen

支持：

```text
⌘F
```

或系统标准全屏。

全屏后：

- Preview 占满窗口
- 鼠标移动显示控制条
- 若实现复杂，可第一阶段只使用原生 window fullscreen

---

# 36. 快捷键

支持：

```text
⌘R
开始 / 停止录制

⌘⇧S
截图

⌘F
全屏

M
静音
```

不要使用 Space 控制录制，避免与未来 UI 焦点冲突。

---

# 37. Settings

设置窗口第一阶段：

```text
General
Recording
```

General：

```text
Remember last device
Auto open last device
Screenshot folder
Recording folder
```

Recording：

```text
Codec
Quality
```

不要做几十个配置项。

---

# 38. SettingsStore

使用：

```text
UserDefaults
```

保存：

- lastVideoDeviceID
- lastAudioDeviceID
- aspectMode
- mirror
- rotation
- screenshotDirectory
- recordingDirectory
- recordingCodec
- preferredResolution
- preferredFPS

如权限原因无法直接持久保存 arbitrary folder URL：

正确处理 security-scoped bookmark。

第一阶段也可仅使用系统默认目录。

---

# 39. Scene 模型

MVP 不显示 Scene UI。

但内部保留：

```swift
struct Scene {
    let id: UUID
    var name: String
    var items: [SceneItem]
}
```

```swift
struct SceneItem {
    let id: UUID
    var sourceID: String
    var transform: Transform
    var isVisible: Bool
}
```

MVP：

```text
Default Scene
 └── Current VideoSource
```

重要：

不要为了这个内部 Scene 模型实现复杂 Scene Engine。

---

# 40. Transform

建议：

```swift
struct Transform {
    var position: CGPoint
    var scale: CGSize
    var rotation: Double
    var mirrorX: Bool
    var crop: EdgeInsets?
}
```

可根据实际实现调整。

---

# 41. Output 抽象

定义：

```swift
protocol Output {
    func start() async throws
    func stop() async
}
```

未来：

```text
PreviewOutput
RecordingOutput
StreamingOutput
VirtualCameraOutput
```

当前阶段可以只实现：

```text
RecordingOutput
```

Preview 可先由 Renderer 负责。

---

# 42. 错误处理

定义明确错误：

```text
CaptureError
DeviceError
FormatError
RendererError
RecordingError
PermissionError
```

UI 错误提示必须用户可理解。

例如不要直接显示：

```text
AVFoundationErrorDomain -11800
```

而显示：

```text
无法打开该视频设备。

请确认设备没有被其他应用占用，然后重试。
```

日志中保留原始 NSError。

---

# 43. Permission

需要处理：

```text
Camera Permission
Microphone Permission
```

必须：

- 首次使用时正确请求
- 用户拒绝后显示解释
- 提供跳转 System Settings 的能力

Info.plist：

```text
NSCameraUsageDescription
NSMicrophoneUsageDescription
```

---

# 44. 日志

使用：

```text
OSLog
```

不要到处 print。

建议分类：

```text
Capture
Device
Renderer
Audio
Recording
App
```

Debug：

记录：

- Device connected
- Device disconnected
- Capture start
- Capture stop
- Format changed
- Recording start
- Recording stop
- Encoder error

不要每帧打印日志。

---

# 45. Swift Concurrency

必须注意：

UI：

```text
@MainActor
```

Capture：

后台队列 / actor。

Renderer：

Metal queue。

Recording：

独立处理。

禁止：

```text
Task {
    await MainActor.run {
        processEveryVideoFrame()
    }
}
```

视频帧绝不能丢到 MainActor 处理。

---

# 46. Backpressure

实时视频必须允许丢帧。

优先保证：

```text
最新帧
```

而不是：

```text
所有帧排队处理
```

Preview：

如果 Renderer 来不及：

丢旧帧。

Recording：

尽可能保持 timestamp 正确。

两条数据通道不要互相阻塞。

---

# 47. 性能目标

MVP 目标：

1080p60 视频：

- UI 保持流畅
- Preview 无明显卡顿
- CPU 占用尽可能低
- 优先 GPU render
- 优先 Hardware Encoder
- 不重复复制 CVPixelBuffer
- 不使用 CIImage → NSImage → SwiftUI Image 的低效链路

禁止：

```text
CMSampleBuffer
 ↓
CGImage
 ↓
NSImage
 ↓
SwiftUI Image
```

作为持续实时预览方案。

---

# 48. 内存管理

重点检查：

- CVPixelBuffer 生命周期
- CMSampleBuffer 生命周期
- CVMetalTexture
- command buffer
- texture cache
- AVCaptureSession
- Notification observer
- async stream continuation

设备切换后：

旧 Session 必须释放。

---

# 49. 热插拔

必须处理：

```text
USB Device Connected
USB Device Disconnected
```

设备拔出：

```text
Preview → Device disconnected placeholder
```

不要：

- Crash
- Freeze
- 无限 retry

重新连接：

如果 Device ID 能匹配：

自动恢复。

---

# 50. App 生命周期

处理：

- Window close
- App terminate
- Device disconnect
- Sleep
- Wake

录制中退出：

至少弹窗：

```text
正在录制视频。

停止录制并退出？
```

---

# 51. Phase 1 — 创建项目骨架

实现：

- SwiftUI macOS App
- AppState
- AppEnvironment
- 基础目录
- MainView
- Preview placeholder
- Device toolbar placeholder

验收：

- 项目可以编译
- App 可以启动
- 主窗口正常显示

---

# 52. Phase 2 — 视频设备发现

实现：

```text
DeviceManager
DeviceDescriptor
AVCaptureDevice discovery
```

UI：

设备下拉列表。

验收：

- 可列出内建摄像头
- 可列出 USB 摄像头
- 可列出 USB HDMI Capture
- 插拔设备列表更新

---

# 53. Phase 3 — AVCaptureVideoSource

实现：

- AVCaptureSession
- AVCaptureDeviceInput
- AVCaptureVideoDataOutput
- VideoFrame
- start / stop
- 设备切换

验收：

- 选设备后开始采集
- 切设备不会崩溃
- 拔设备不会崩溃

---

# 54. Phase 4 — Metal Preview

实现：

- MTKView bridge
- MetalRenderer
- CVMetalTextureCache
- CVPixelBuffer → Texture
- 实时显示

验收：

1080p60：

- Preview 流畅
- 不出现明显 CPU 转换
- Window resize 正常

---

# 55. Phase 5 — Format

实现：

- Resolution 列表
- FPS 列表
- activeFormat
- Frame Duration

UI：

```text
Resolution
Frame Rate
```

验收：

可在设备真实支持格式之间切换。

---

# 56. Phase 6 — Transform

实现：

```text
Fit
Fill
Stretch
Mirror
Rotate
```

优先 Metal shader / rendering transform。

验收：

截图与 Preview Transform 一致。

---

# 57. Phase 7 — Screenshot

实现：

```text
ScreenshotService
```

支持：

```text
PNG
```

保存到默认目录。

验收：

- 连续截图
- 文件可打开
- 方向正确
- Mirror 正确
- 比例正确

---

# 58. Phase 8 — Audio

实现：

- Audio device discovery
- audio capture
- mute
- RMS / peak meter

验收：

- 可切设备
- Meter 动态变化
- UI 不因 audio sample 高频刷新卡顿

---

# 59. Phase 9 — Recording

实现：

```text
Recorder
RecordingConfig
VideoEncoder
H264
HEVC
AVAssetWriter or appropriate mux
```

第一目标：

```text
H264 MP4
```

HEVC 可随后增加。

验收：

录制：

```text
1080p60
30 秒
```

生成 MP4：

- QuickTime 可正常播放
- 时长正确
- FPS 正常
- 无明显音画问题

---

# 60. Phase 10 — Audio Recording

将音频写入录制文件。

验收：

- USB capture audio + video 同步
- 文件 QuickTime 可播放
- 不明显漂移

如果同步实现过于复杂：

优先保证时间戳模型正确。

不要用不可靠 sleep 拼同步。

---

# 61. Phase 11 — Settings

保存：

```text
Last Video Device
Last Audio Device
Format
FPS
Aspect
Mirror
Rotation
Codec
Output Folder
```

App 重启：

恢复。

如果设备不存在：

自动 fallback。

---

# 62. Phase 12 — Polish

处理：

- Empty state
- Permission state
- Recording state
- Device disconnect state
- Error alert
- Keyboard shortcuts
- Dark / Light mode
- Window minimum size
- UI spacing

---

# 63. MVP 完成标准

只有全部满足才算 MVP 完成：

## Device

- [ ] USB camera 可以发现
- [ ] HDMI capture card 可以发现
- [ ] 支持热插拔
- [ ] 自动恢复上一次设备

## Preview

- [ ] Preview 正常
- [ ] 1080p60 可运行
- [ ] Fit
- [ ] Fill
- [ ] Mirror
- [ ] Rotate

## Format

- [ ] Resolution
- [ ] FPS
- [ ] 读取真实 Device Formats

## Audio

- [ ] Audio Device
- [ ] Meter
- [ ] Mute

## Capture

- [ ] Screenshot
- [ ] H264 MP4 Recording
- [ ] Audio Recording

## UX

- [ ] Fullscreen
- [ ] Keyboard shortcut
- [ ] Empty device state
- [ ] Permission error
- [ ] Device disconnect

## Performance

- [ ] 不使用 NSImage 实时转换链路
- [ ] Metal Preview
- [ ] VideoToolbox Hardware Encoding
- [ ] MainActor 不处理视频帧

---

# 64. UI 设计原则

整体风格：

```text
Native macOS
Minimal
Clean
Professional
Dark-mode friendly
```

参考：

- QuickTime Player
- Final Cut Preview
- Apple Camera UI
- CleanShot
- IINA

不要模仿：

```text
OBS 多面板布局
```

---

# 65. UX 原则

所有常用操作最多：

```text
1 click
```

例如：

设备：

```text
Device button
 ↓
Select device
```

录制：

```text
REC
```

截图：

```text
Screenshot
```

不要：

```text
Settings
 ↓
Output
 ↓
Recording
 ↓
Start
```

---

# 66. 后续路线

MVP 完成后，再逐阶段扩展。

---

# 67. V0.5 — 第二视频源

增加：

```text
2 Video Sources
```

例如：

```text
Game Capture
+
Camera
```

启用：

```text
Scene Engine
```

UI：

允许拖动 PIP。

---

# 68. V0.6 — Scene

加入：

```text
Scene
SceneItem
Layer
Transform
```

Sources：

```text
Camera
Capture Card
```

仍保持 UI 简洁。

---

# 69. V0.7 — ScreenCaptureKit

增加：

```text
Screen Source
Window Source
App Source
```

使用：

```text
ScreenCaptureKit
```

Source：

```text
ScreenCaptureSource
WindowCaptureSource
```

继续输出：

```text
VideoFrame
```

不得让下游知道来自 ScreenCaptureKit。

---

# 70. V0.8 — Overlay

支持：

```text
Image
Logo
Text
```

SceneItem：

```text
Video
Image
Text
```

---

# 71. V0.9 — Effects

增加：

```text
Brightness
Contrast
Saturation
Temperature
Sharpen
LUT
```

使用：

```text
Metal Shader
```

---

# 72. V1.0 — Virtual Camera

使用：

```text
CoreMediaIO
Camera Extension
```

数据：

```text
Final Rendered Frame
 ↓
Virtual Camera Output
```

Zoom / Chrome / Discord 可识别：

```text
CaptureLite Camera
```

---

# 73. V1.1 — Streaming

增加：

```text
StreamingOutput
```

支持：

```text
RTMP
```

Pipeline：

```text
VideoFrame
 ↓
VideoToolbox H264
 ↓
RTMP
```

后续：

```text
SRT
WebRTC
```

---

# 74. V1.2 — Plugin

只有核心能力稳定后再做。

预留：

```text
SourcePlugin
EffectPlugin
OutputPlugin
```

不要 MVP 期间实现插件系统。

---

# 75. 架构约束

长期必须保持：

```text
Source
 ↓
Frame
 ↓
Pipeline
 ↓
Output
```

禁止变成：

```text
AVCaptureSession
 ↓
UI
 ↓
Recorder
 ↓
Streamer
```

---

# 76. 禁止出现的反模式

不要创建：

```text
CaptureManager.swift
```

里面同时包含：

- Device discovery
- Capture
- Rendering
- Audio
- Recording
- Settings
- SwiftUI state

如果某个类超过约：

```text
500 ~ 700 lines
```

需要检查职责是否过多。

不是绝对限制，但必须审视。

---

# 77. 禁止过早优化

不要第一阶段实现：

- lock-free queue
- custom memory pool
- Metal compute graph
- custom muxer
- plugin ABI
- dependency injection framework

先用简单可靠实现。

只有 profiler 证明瓶颈后再优化。

---

# 78. 禁止过早第三方依赖

第一阶段不添加：

```text
FFmpeg
OpenCV
RxSwift
CombineExt
大型 DI Framework
网络 SDK
```

优先：

```text
Swift
SwiftUI
AVFoundation
Metal
VideoToolbox
```

---

# 79. 测试

至少建立：

```text
CaptureLiteTests
```

可单测：

- Device preference
- Format selection
- Aspect transform
- Recording config
- File naming
- Settings store

硬件 Capture 不强求完整 unit test。

可以通过 protocol mock。

---

# 80. Mock Source

建议实现 Debug 用：

```text
MockVideoSource
```

输出：

- 固定色
- Test Pattern
- Timestamp

便于：

- 没有采集卡时开发 Renderer
- 测试 Recording
- 测试 Pipeline

不要让 Mock 进入正式 UI。

---

# 81. Debug Overlay

Debug build 可支持：

```text
FPS
Resolution
Pixel Format
Dropped Frames
Render Time
```

Release 默认隐藏。

---

# 82. 性能诊断

开发期间使用：

```text
Instruments
Metal System Trace
Time Profiler
Allocations
```

重点检查：

- 每帧 allocation
- Main Thread blocking
- Pixel Buffer copy
- GPU utilization
- Encoder latency

---

# 83. Pixel Format

优先保持设备原始可高效处理格式。

常见：

```text
NV12
BGRA
```

不要无理由：

```text
NV12 → BGRA → RGB → BGRA
```

VideoToolbox 常用：

```text
NV12
```

Renderer 应尽量支持 NV12。

---

# 84. 时间戳

必须正确保留：

```text
presentation timestamp
```

不要使用：

```text
Date()
```

作为每一帧视频时间戳。

录制同步依赖：

```text
CMTime
```

---

# 85. Audio / Video Sync

Video 和 Audio：

使用 capture timestamp。

Recorder 建立：

```text
session start time
```

之后按各自 PTS 写入。

不要人为：

```text
sleep
delay
timer
```

做同步。

---

# 86. 文件安全

录制开始：

创建临时文件。

录制正常结束：

Finalize。

异常：

保留可恢复信息。

至少避免：

直接覆盖已有文件。

---

# 87. 设备切换状态机

建议状态：

```text
idle
starting
running
switching
stopping
failed
```

防止：

快速点击设备导致多个 session 同时运行。

---

# 88. Recording 状态机

```text
idle
starting
recording
stopping
failed
```

禁止 boolean 堆叠：

```text
isRecording
isStartingRecording
isStoppingRecording
hasRecordingError
```

优先明确 enum。

---

# 89. Permission 状态机

```text
unknown
authorized
denied
restricted
```

UI 根据状态显示。

---

# 90. AppState

AppState 只存高层 UI / 应用状态。

不要放：

```text
CMSampleBuffer
CVPixelBuffer
AVCaptureSession
MetalTexture
```

这些对象不属于 SwiftUI State。

---

# 91. MainViewModel

职责：

- 当前设备显示信息
- 用户 UI action
- Recording UI 状态
- Error presentation

它调用：

```text
CaptureEngine
OutputManager
DeviceManager
```

不要直接调用：

```text
AVCaptureDeviceInput(...)
```

---

# 92. 代码风格

要求：

- 类型名称明确
- 小函数
- 不滥用 singleton
- 不滥用 static mutable state
- async / await 优先
- 尽量符合 Swift API Design Guidelines
- error message 可读
- public/internal/private 合理
- 添加必要注释，不写废话注释

---

# 93. AI Agent 每一步输出格式

每完成一个阶段，必须说明：

```text
Completed

Files changed

Key implementation

Known limitations

Manual test steps
```

不要只说：

```text
Done
```

---

# 94. AI Agent 修改前检查

修改代码前：

1. 查现有目录
2. 查相关类型
3. 查现有 capture 实现
4. 查是否已有相同 abstraction
5. 不重复创建功能
6. 保持 naming 一致

---

# 95. AI Agent 编译要求

每一个主要阶段：

必须运行编译。

优先：

```bash
xcodebuild \
  -project CaptureLite.xcodeproj \
  -scheme CaptureLite \
  -configuration Debug \
  build
```

如果项目使用 workspace：

改用：

```bash
xcodebuild \
  -workspace CaptureLite.xcworkspace \
  -scheme CaptureLite \
  -configuration Debug \
  build
```

根据实际项目调整。

不要编造成功。

如果失败：

必须读取完整错误并修复。

---

# 96. Hardware 测试

测试优先设备：

```text
USB Webcam
HDMI USB Capture Card
```

测试：

```text
Connect
Disconnect
Reconnect
Switch
Change Resolution
Change FPS
Record
Screenshot
Fullscreen
```

---

# 97. MVP 手动验收流程

完整走：

```text
Launch App
 ↓
Permission
 ↓
Detect Device
 ↓
Preview
 ↓
Change 1080p60
 ↓
Mirror
 ↓
Screenshot
 ↓
Select Audio
 ↓
Record 30 sec
 ↓
Stop
 ↓
Open MP4
 ↓
Disconnect Device
 ↓
Reconnect Device
 ↓
Restore Preview
 ↓
Restart App
 ↓
Restore Last Device
```

全部通过后 MVP 才算完成。

---

# 98. 最终产品原则

CaptureLite 不是：

> 一个功能较少的 OBS。

而应该是：

> 一个专注视频输入的 macOS 原生工具。

产品体验应该是：

```text
连接
 ↓
看到
 ↓
录制
```

而不是：

```text
Scene
 ↓
Source
 ↓
Properties
 ↓
Output
 ↓
Encoder
 ↓
Start
```

---

# 99. 最重要的四个原则

## Principle 1

使用原生：

```text
Swift
SwiftUI
AVFoundation
Metal
VideoToolbox
```

## Principle 2

始终保持：

```text
Capture
Render
Output
```

解耦。

## Principle 3

MVP 内部保留 Scene Model：

但 UI 不暴露 Scene。

## Principle 4

不要过早加入 FFmpeg。

只有未来：

```text
RTMP
SRT
特殊 Codec
复杂 Container
```

确实需要时再加入。

---

# 100. 第一条执行指令

从现在开始：

首先检查当前项目。

如果项目为空：

执行：

```text
Phase 1
```

建立：

```text
App
UI
Capture
Video
Devices
Output
Storage
Utilities
```

基础骨架。

然后创建：

```text
MainView
Preview Placeholder
DeviceManager abstraction
VideoSource abstraction
VideoFrame model
```

本阶段不要：

```text
录制
音频
场景编辑
FFmpeg
ScreenCaptureKit
Virtual Camera
Streaming
```

完成后：

1. 编译
2. 修复错误
3. 启动 App
4. 汇报修改文件
5. 给出下一阶段建议

之后按照本文档 Phase 顺序逐步推进。

---

# 101. Codex / Claude Code 实施策略

每次只接受一个阶段任务。

推荐逐步执行：

```text
Step 1
Project Skeleton

Step 2
Device Discovery

Step 3
Video Capture

Step 4
Metal Preview

Step 5
Resolution + FPS

Step 6
Transform

Step 7
Screenshot

Step 8
Audio

Step 9
H264 Recording

Step 10
Audio Recording

Step 11
Settings

Step 12
UX Polish
```

不要使用：

```text
"Implement everything in this document"
```

一次完成整个项目。

应该：

```text
Read this architecture document.

Only implement Phase 2.

Do not start Phase 3.

Run build after implementation.
```

这样可以显著降低 Vibe Coding 出现：

- 大量不可编译代码
- 重复架构
- 超大 Manager
- 未实现 placeholder
- 错误 API
- 线程问题

的概率。

---

# 102. 单阶段 Prompt 模板

后续每个阶段可以使用：

```text
Read the project architecture document first.

Current task:
Implement Phase {N}: {PHASE_NAME}.

Requirements:

1. Inspect the existing implementation before editing.
2. Reuse existing abstractions.
3. Do not implement future phases.
4. Keep Capture / Render / Output decoupled.
5. Do not introduce FFmpeg or unnecessary dependencies.
6. Keep video processing off MainActor.
7. Preserve all existing working functionality.
8. Build the macOS app after changes.
9. Fix all compile errors introduced by this task.

After implementation report:

- Files changed
- Architecture decisions
- Known limitations
- Manual test steps
- Build result

Do not begin the next phase.
```

---

# 103. 最终架构目标

未来完整版本：

```text
                    ┌────────────────┐
                    │   VideoSource  │
                    └───────┬────────┘
                            │
                            ▼
                    ┌────────────────┐
                    │   VideoFrame   │
                    └───────┬────────┘
                            │
                            ▼
                    ┌────────────────┐
                    │ Video Pipeline │
                    └───────┬────────┘
                            │
                ┌───────────┼────────────┐
                │           │            │
                ▼           ▼            ▼
            Preview      Recorder      Stream
                │                         │
                ▼                         ▼
             Metal                     RTMP
                │
                └──────────────┐
                               ▼
                         Virtual Camera
```

Source 可扩展：

```text
AVCapture
ScreenCapture
WindowCapture
MediaFile
Network
```

Output 可扩展：

```text
Preview
Record
Stream
Virtual Camera
```

Effect 可扩展：

```text
Crop
Transform
Color
LUT
ChromaKey
AI
Overlay
```

而 MVP 仍然保持：

```text
打开
 ↓
选择设备
 ↓
看到画面
 ↓
截图 / 录制
```

这就是整个项目最重要的设计方向。
