# Adaptive Notch System PRD

## Overview

This document describes the architecture for an adaptive Notch window on macOS, inspired by Dynamic Island while remaining native to macOS.

The Notch should:

- Adapt its size depending on current activity.
- Remain centered regardless of display resolution.
- Animate smoothly between states.
- Support physical notch MacBooks and regular monitors.
- Be scalable for future features.

---

# Design Goals

✅ Smooth animations

✅ Modular architecture

✅ Multiple activities

✅ Multiple display support

✅ Future-proof

---

# Architecture

```
App

├── ScreenManager
│
├── NotchPositionManager
│
├── NotchStateManager
│
├── NotchWindowController
│
└── SwiftUI Root View
```

Each component has a single responsibility.

---

# ScreenManager

Responsible for:

- Detect current screen
- Detect safe area
- Detect display changes
- Handle multiple monitors

Provides:

```swift
currentScreen: NSScreen?
safeAreaInsets: NSEdgeInsets
visibleFrame: CGRect
```

Never use hardcoded screen values.

---

# NotchPositionManager

Responsible for calculating window position.

Responsibilities:

- Horizontal centering
- Vertical placement
- Recalculate after resize
- Animate movement

Public API

```swift
func updatePosition(animated: Bool)
```

---

# NotchStateManager

This is the brain of the application.

It decides:

- Which content is visible
- Window size
- Animation state

---

## Activities

Activities describe **what is happening**.

```swift
enum NotchActivity {

    case idle

    case music

    case timer

    case notification

    case fileDrop

    case clipboard

    case recording

}
```

Examples

```
Spotify playing
↓

activity = .music
```

```
Countdown started
↓

activity = .timer
```

```
User drags a file
↓

activity = .fileDrop
```

---

## Presentation

Presentation describes **how much space the UI occupies**.

```swift
enum NotchPresentation {

    case compact

    case preview

    case expanded

}
```

Examples

```
Music running

↓

Compact
```

```
Hover mouse

↓

Expanded
```

```
Mouse leaves

↓

Compact
```

---

# Why Separate Activity and Presentation?

Avoid creating combinations like

```
musicCompact

musicExpanded

timerCompact

timerExpanded

clipboardExpanded

clipboardCompact
```

Instead

```
Activity

+

Presentation

↓

Mode
```

This scales infinitely better.

---

# Final Mode

Mode is generated automatically.

```swift
enum NotchMode {

    case compact

    case music

    case timer

    case notification

    case fileShelf

    case expandedMenu

}
```

The UI never changes modes directly.

Instead

```
Activity

+

Presentation

↓

Mode
```

---

# State Flow

Example

```
Spotify starts

↓

Activity = Music

↓

Presentation = Compact

↓

Mode = Music
```

Hover

↓

```
Presentation = Expanded

↓

Mode = Music
```

Spotify stops

↓

```
Activity = Idle

↓

Presentation = Compact

↓

Mode = Compact
```

---

# Size Tokens

Never hardcode frame sizes throughout the project.

Create one source of truth.

```swift
struct NotchSize {

    static let compact =
        CGSize(width:220,height:34)

    static let hover =
        CGSize(width:300,height:70)

    static let music =
        CGSize(width:380,height:110)

    static let timer =
        CGSize(width:320,height:90)

    static let notification =
        CGSize(width:360,height:80)

    static let fileShelf =
        CGSize(width:420,height:160)

    static let expanded =
        CGSize(width:440,height:220)

}
```

---

# Window Resize Flow

```
Activity changes

↓

Mode changes

↓

Target size changes

↓

Window resizes

↓

Window re-centers

↓

Animation
```

---

# Adaptive Position

The window must always stay centered.

Algorithm

```
Read screen

↓

Read safe area

↓

Calculate usable width

↓

Center inside usable width

↓

Pin below menu bar
```

Never use fixed coordinates.

---

# SwiftUI Root

The Root View only displays content.

```
NotchRootView

↓

Background

↓

Current Content

↓

Animation
```

The Root View must never calculate screen positions.

---

# Content Modules

Each feature is its own view.

```
CompactView

MusicView

TimerView

NotificationView

FileShelfView

ClipboardView

RecordingView
```

Each module owns only its own UI.

---

# Activity Priority

Multiple activities may happen simultaneously.

Example

Spotify playing

+

File drag

+

Notification

Need priority.

```
File Drop

>

Notification

>

Timer

>

Music

>

Idle
```

Example

```
Dragging file

↓

FileShelf
```

Even if music is playing.

After drop

↓

Music returns automatically.

---

# Animation Rules

All transitions should feel fluid.

Recommended

```
Spring animation
```

Approximately

```
Response

0.35

Damping

0.82
```

Animations

- Resize

- Position

- Corner Radius

- Blur

- Shadow

- Content Fade

- Icon Transition

---

# Music Module

Contents

- Artwork

- Song Title

- Artist

- Previous

- Play/Pause

- Next

Future

- Progress Bar

- AirPlay

- Volume

---

# Timer Module

Contents

- Countdown

- Progress Ring

- Pause

- Resume

- Cancel

Use monospaced digits.

Animate number changes smoothly.

---

# Notification Module

Contents

- App Icon

- Title

- Subtitle

- Action Button

Disappear automatically.

---

# File Shelf

Contents

- Dropped Files

- File Preview

- Drag Indicator

- Remove Button

Future

- Pin files

- Copy paths

- Quick Share

---

# Clipboard Module

Future feature.

Shows

- Copied Image

- Copied Text

- QR Code

- Copy History

---

# Recording Module

Future feature.

Shows

- Recording Time

- Microphone Status

- Camera Status

---

# Multiple Monitor Support

When

- monitor added

- monitor removed

- display resolution changes

- display scale changes

- window moves

Recalculate

- screen

- safe area

- size

- position

Automatically.

---

# Debug Mode

Development only.

Display

```
Current Screen

Resolution

Scale

Safe Area

Visible Frame

Activity

Presentation

Mode

Target Size

Calculated Position

Animation State
```

Toggle using

```swift
DebugSettings.shared.enabled
```

---

# Future Features

- Live Activities

- Calendar

- Pomodoro

- Clipboard History

- AirPods Battery

- CPU Usage

- Memory Usage

- Network Speed

- Weather

- Downloads

- Screen Recording

- Voice Recorder

- Quick Notes

- Calculator

- File Shelf

- AI Assistant

---

# Final Principles

The application should never think in terms of:

> "Make the notch 380px."

Instead, it should think:

```
Current Activity

↓

Current Presentation

↓

Target Mode

↓

Target Size

↓

Animated Window

↓

Animated Content
```

This keeps the architecture clean, scalable, maintainable, and ready for future features without requiring large refactors.