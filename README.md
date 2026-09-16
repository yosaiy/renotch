<div align="center">

<img src="public/renotch_logo.png" alt="Re:notch" width="120">

# Re:notch

Turn your Mac's notch into a lightweight, native developer command center.

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://developer.apple.com/macos/)
[![Release](https://img.shields.io/github/v/release/yosaiy/renotch?label=release)](https://github.com/yosaiy/renotch/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE.md)

[**Download Latest**](https://github.com/yosaiy/renotch/releases/latest) • [**Report Bug**](https://github.com/yosaiy/renotch/issues)

</div>

[简体中文使用、构建与兼容性说明](README.zh-CN.md)

本分支增加 Codex 多任务状态与账号剩余用量、前台窗口跨屏跟随、QQ 音乐联动，并将界面设为简体中文。功能说明、配置默认值和内部接口限制见中文文档。上游 v1.7.0 发布包尚未包含这些改动。

---

## Features

- **Dev Activity**: Track local servers, ports, Git status, Docker containers, and build jobs.

![Dev Activity](public/Dev-Activity.gif)

- **Media Control**: Apple Music & Spotify playback with album art and controls.

![Media Control](public/Music-Demo.gif)

- **Pomodoro + Website Blocker**: Stop doomscrolling mid-task. Renotch now lets you block specific websites during Pomodoro sessions so you actually get things done.

![Pomodoro + Website Blocker](public/Pomodoro.gif)

- **Browser Bridge**: YouTube playback and Chromium download monitor.
- **Native & Private**: Swift/SwiftUI, fluid animations, zero telemetry. See the privacy notes below for optional Codex account usage queries.

---

## Install

### Download
Grab the latest `Re:notch.app` from **[Releases](https://github.com/yosaiy/renotch/releases/latest)** and move it to `/Applications`.

### Build from Source
```bash
git clone https://github.com/yosaiy/renotch.git
cd renotch
./scripts/build-music-bridge.sh
swift run Renotch
```

To build a standalone `.app` bundle:
```bash
./scripts/build-app.sh
```

---

## Browser Extension (Optional)

Enables YouTube and download tracking:
1. Open `chrome://extensions` in Chrome/Arc/Brave/Edge.
2. Enable **Developer mode**.
3. Click **Load unpacked** and select the `BrowserExtension` directory.

---

## Privacy

任务状态、问题摘要和 QQ 音乐元数据在本机处理，不上传任务正文，不发送统计数据。Codex 剩余用量通过已安装的 CLI 和已有登录状态进行只读账号查询，可在设置中关闭；Re:notch 不读取凭据、不自动回答或批准任务。详情见 [接入方式与边界](README.zh-CN.md#接入方式与边界)。

---

## License

MIT © [yosaiy](https://github.com/yosaiy)
