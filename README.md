# Virtual Notch — developer activity for macOS

A native macOS 13+ productivity notch for developers. Local servers, builds, containers, Git changes, deployments, and terminal tasks stay one hover away.

> Your development activity, always one hover away.

## Included MVP

- Localhost discovery for Next.js, Vite, React, Astro, Nuxt, Express, Fastify, Bun, Deno, Node.js, and common development runtimes, with open, copy URL, reveal folder, terminal, and stop actions.
- Live server, build, deployment, and package-install process detection with completion feedback.
- Docker container summary and per-container status, logs, and stop controls when Docker is available.
- Git branch, changed-file count, commit SHA, pull, push, and remote actions for the active project.
- A focused compact state that prioritizes the most relevant developer activity, with category navigation on hover expansion.
- Borderless, non-activating `NSPanel` above regular apps and across Spaces/full-screen apps.
- Smooth hover expansion, click pinning, delayed collapse, and outside-click dismissal.
- Apple Music now-playing view with album artwork, an animated compact waveform, seek, previous/next, play/pause, and volume controls.
- Recoverable timer with presets, custom duration, pause/resume/cancel, and notifications.
- Local clipboard history for up to 20 text items with copy, delete, clear-all, duplicate filtering, and concealed/transient type filtering.
- Adaptive in-memory File Shelf for dropping up to 12 files into the notch, dragging them into other apps, revealing them in Finder, and removing missing references safely.
- Finder, Downloads, Screenshots, focus timer, clipboard, and Settings quick actions.
- Persisted display, sizing, interaction, privacy, and notification preferences.
- Multi-monitor selection and automatic repositioning when displays change.
- Menu-bar controls, no Dock icon, and macOS 13 launch-at-login support.
- Local `.app` and `.dmg` packaging scripts with generated app icon.

## Run from source

```sh
swift run VirtualNotch
```

The first run opens a compact onboarding view. Virtual Notch then lives in the menu bar.

The first time the music player is used, macOS asks for permission to control Apple Music. You can change this later in System Settings → Privacy & Security → Automation.

## Test

```sh
./scripts/test.sh
```

The lightweight test runner is framework-free so it also works with standalone Apple Command Line Tools installations that do not include XCTest.

## Build an app or DMG

```sh
./scripts/build-app.sh
./scripts/build-dmg.sh
```

The default build is ad-hoc signed and appears in `dist/`. For Developer ID signing:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-dmg.sh
```

Notarization requires Xcode command-line tooling plus Apple Developer credentials. After building a Developer ID-signed DMG, submit it with `xcrun notarytool submit ... --wait`, then staple with `xcrun stapler staple dist/VirtualNotch-1.0.0.dmg`.

## Privacy

There is no account, analytics, network request, or cloud sync. Developer activity is derived locally from running processes, listening TCP ports, Docker CLI output, and Git metadata. Settings, timer state, and clipboard history stay in local `UserDefaults`. File Shelf entries are URL references kept in memory only: files are never uploaded or copied, and the shelf clears when the app quits. Clipboard capture can be disabled or cleared at any time.
