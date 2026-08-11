# Re:notch

> Your development activity, always one hover away.

<div align="center">

[![macOS 14+](https://img.shields.io/badge/macOS-14.0+-silver?logo=apple)](https://developer.apple.com/macos/)
[![Release](https://img.shields.io/github/v/release/yosaiy/renotch?label=Version)](https://github.com/yosaiy/renotch/releases)

[Download v1.0.0](https://github.com/yosaiy/renotch/releases/tag/v1.0.0) • [Features](#features) • [Install](#installation) • [Settings](#settings)

</div>

---

## Features

| Category | Features |
|----------|----------|
| **Servers** | Next.js, Vite, React, Astro, Nuxt, Express, Fastify, Bun, Deno — open, copy URL, reveal folder, terminal, stop |
| **Builds** | Swift, Xcode, npm, pnpm, yarn, Vite, Next.js, Docker — completion feedback with animated progress |
| **Docker** | Container overview, logs, and stop controls (when Docker available) |
| **Git** | Branch, changed files, commit SHA — pull, push, copy SHA, remote repo |
| **Deployments** | Vercel, Netlify, Fly, Wrangler, Firebase, Railway — real-time deployment status |
| **Music** | Apple Music & Spotify integration with album art, waveform, play/pause, seek, volume |
| **Timer** | Presets, custom duration, pause/resume, notifications, recovery after restart |
| **Clipboard** | Up to 20 text items — copy, delete, clear, duplicate filtering |
| **File Shelf** | Drag & drop up to 12 files — reveal in Finder, drag to apps, safe missing-file handling |
| **Quick Actions** | Finder, Downloads, Screenshots, focus timer, clipboard, Settings |
| **Privacy** | No accounts, analytics, or cloud sync — 100% local processing |

---

## Installation

### From GitHub Releases

1. [Download `Re:notch-v1.0.0.zip`](https://github.com/yosaiy/renotch/releases/tag/v1.0.0)
2. Extract the ZIP file
3. Move `Re:notch.app` to your `Applications` folder
4. Launch the app and grant necessary permissions when prompted

### From Source

```bash
git clone https://github.com/yosaiy/renotch.git
cd renotch
swift run VirtualNotch
```

The first run opens a compact onboarding view. Re:notch then lives in the menu bar.

> **Note**: The first time you use Apple Music or Spotify, macOS asks for permission to control playback. You can change this later in **System Settings → Privacy & Security → Automation**.

---

## Browser Activity Setup

Browser activity supports Chromium browsers (Chrome, Edge, Brave, Chromium).

1. Build and launch the app:
   ```bash
   ./scripts/build-app.sh
   ```

2. From the Re:notch menu-bar menu, choose **Set Up Browser Activity…**

3. Open the browser's extensions page (`chrome://extensions`), enable **Developer mode**, and choose **Load unpacked**

4. Select the `BrowserExtension` directory revealed by Re:notch

The bundled extension sends YouTube playback metadata and active-download progress to the app through a local native messaging helper. See [`BrowserExtension/README.md`](BrowserExtension/README.md) for details.

---

## Settings

Re:notch stores preferences in `UserDefaults`. Access settings by clicking the menu bar icon → **Settings…** or pressing `⌘,`.

| Section | Settings |
|---------|----------|
| **Appearance** | Theme (Light/Dark/Black), notch width, corner radius, blur radius |
| **Behavior** | Hover expand, click expand, show on fullscreen, always on top |
| **Privacy** | Disable clipboard capture, clear clipboard history |
| **Notifications** | Enable timer notifications |
| **Startup** | Launch at login, show notch on startup |

---

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Show Notch | `⌘ Shift N` (customizable) |
| Hide Notch | `⌘ Shift H` (customizable) |
| Settings | `⌘,` |
| Check Updates | `⌘ Shift U` |

---

## Building

```bash
# Debug build
swift build

# Release build
swift build -c release

# Build app bundle
./scripts/build-app.sh

# Build DMG installer
./scripts/build-dmg.sh
```

For Developer ID signing:
```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-dmg.sh
```

---

## Testing

```bash
./scripts/test.sh
```

The lightweight test runner requires no external frameworks — it works with standard Apple Command Line Tools.

---

## Privacy

Re:notch is 100% local:

- **No accounts** — never creates or stores user accounts
- **No analytics** — no telemetry, crash reports, or usage tracking
- **No cloud sync** — all data stays on your Mac
- **Local activity detection** — servers, builds, Docker, and Git activity derived from running processes
- **Browser extension** — reads only YouTube playback metadata and Chromium download status via native messaging
- **File Shelf** — URL references kept in memory only; files never uploaded or copied
- **Settings & clipboard** — stored in local `UserDefaults`

---

## Requirements

- **macOS 13.0+** (arm64 / x86_64)
- **Apple Silicon or Intel Mac**
- Accessibility permission (for notch window)
- Automation permission (for music player control)
- Developer mode enabled (for browser extension)

---

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add some amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

---

<div align="center">

Made with ❤️ by [yosaiy](https://github.com/yosaiy)

</div>
