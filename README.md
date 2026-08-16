# Re:notch

> Your development activity, always one hover away.

<div align="center">

[![macOS](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://developer.apple.com/macos/)
[![Release](https://img.shields.io/github/v/release/yosaiy/renotch?label=release)](https://github.com/yosaiy/renotch/releases)

**[Download](https://github.com/yosaiy/renotch/releases/latest)** · **[Report an Issue](https://github.com/yosaiy/renotch/issues)**

</div>

<br>

<div align="center">
  <img src="./assets/hero.png" width="850" alt="Re:notch">
</div>

<br>

Re:notch is a native macOS utility that turns your notch into a lightweight command center for your development workflow.

It surfaces what you're doing **without interrupting what you're doing.**

---

## Features

**Development**

* Server & build activity
* Git status and quick actions
* Docker containers & logs
* Deployment status
* One-click access to terminals, folders, URLs and repositories

**Everyday**

* Apple Music & Spotify
* Timer & focus sessions
* Clipboard history
* File shelf
* Quick actions

**Built for macOS**

* Native Swift application
* Lightweight and fully local
* No accounts
* No analytics
* No cloud sync

---

## Installation

### Download

Download the latest release, extract the zip (or let Safari do it automatically), and double-click `Re:notch.app` to run.

**[Download the latest release →](https://github.com/yosaiy/renotch/releases/latest)**

### Build from source

```bash
git clone https://github.com/yosaiy/renotch.git
cd renotch
swift run VirtualNotch
```

For a complete app bundle:

```bash
./scripts/build-app.sh
```

---

## Browser Activity

Re:notch can detect YouTube playback and Chromium downloads through a local browser extension.

1. Launch Re:notch
2. Open **Set Up Browser Activity…**
3. Open `chrome://extensions`
4. Enable **Developer mode**
5. Select **Load unpacked**
6. Choose the `BrowserExtension` directory

See [`BrowserExtension/README.md`](BrowserExtension/README.md) for details.

---

## Settings

Re:notch can be customized from **Settings…** or `⌘,`.

* Appearance & notch style
* Hover and click behavior
* Fullscreen behavior
* Clipboard privacy
* Notifications
* Launch at login
* Keyboard shortcuts

---

## Privacy

Re:notch is **100% local**.

* No accounts
* No analytics or telemetry
* No cloud sync
* No uploaded files
* Activity is detected locally from running processes
* Clipboard history stays on your Mac

---

## Requirements

* macOS 13+
* Apple Silicon or Intel
* Accessibility permission
* Automation permission for music controls
* Developer Mode for browser activity

---

## Development

```bash
# Build
swift build

# Release build
swift build -c release

# Build app
./scripts/build-app.sh

# Build release zip (for GitHub Releases)
./scripts/build-zip.sh

# Run tests
./scripts/test.sh
```

---

## Contributing

Issues, ideas and pull requests are welcome.

If you have an idea that would make Re:notch better, feel free to open an issue.

---

<div align="center">

**Re:notch**

Made with ❤️ by [yosaiy](https://github.com/yosaiy)

</div>
