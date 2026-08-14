# CaptureLite

macOS 原生、轻量、低资源占用的视频采集与录制工具。

> 插上设备就能看，点一下就能录。

## 核心功能

- 自动发现 USB 摄像头 / HDMI 视频采集卡，支持热插拔
- Metal 实时预览（1080p60 低延迟，零拷贝纹理渲染）
- 截图（PNG）
- H.264 / HEVC MP4 录制（VideoToolbox 硬件编码）
- 音频设备选择、音量电平表、静音
- 画面比例（Fit / Fill / Stretch）、镜像、旋转
- 设备真实格式分辨率 / 帧率切换
- 自动恢复上次设备与设置
- 全屏（⌘F）
- 快捷键：⌘R 录制、⇧⌘S 截图、M 静音

## 系统要求

- macOS 15+
- Apple Silicon

## 技术栈

Swift · SwiftUI · AVFoundation · Metal · VideoToolbox

## 构建

```bash
xcodegen generate
xcodebuild -project CaptureLite.xcodeproj -scheme CaptureLite -configuration Release -destination 'platform=macOS' build
```

## 架构

```text
VideoSource → VideoFrame → VideoPipeline
                              ├── Preview (Metal Renderer)
                              └── Recorder (VideoToolbox Encoder)
```

Capture / Render / Output 解耦，为后续画中画、场景、屏幕采集、虚拟摄像头、推流等能力预留扩展空间。
