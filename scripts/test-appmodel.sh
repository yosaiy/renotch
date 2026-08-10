#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
TEST_BINARY="$PROJECT_DIR/.build/virtual-notch-appmodel-tests"

cd "$PROJECT_DIR"
swiftc \
    -swift-version 5 \
    Sources/VirtualNotch/Models/NotchModels.swift \
    Sources/VirtualNotch/Models/BrowserActivityModels.swift \
    Sources/VirtualNotch/Models/DeveloperActivityGlance.swift \
    Sources/VirtualNotch/Services/SettingsStore.swift \
    Sources/VirtualNotch/Services/TimerService.swift \
    Sources/VirtualNotch/Services/ClipboardService.swift \
    Sources/VirtualNotch/Services/ShelfStore.swift \
    Sources/VirtualNotch/Services/TodoStore.swift \
    Sources/VirtualNotch/Services/MusicService.swift \
    Sources/VirtualNotch/Services/BrowserActivityService.swift \
    Sources/VirtualNotch/Services/DeveloperActivityService.swift \
    Sources/VirtualNotch/Services/AppleCalendarService.swift \
    Sources/VirtualNotch/Services/LaunchAtLoginService.swift \
    Sources/VirtualNotch/Services/NotificationService.swift \
    Sources/VirtualNotch/State/AppModel.swift \
    Tests/AppModelFileDropTests.swift \
    -framework AppKit \
    -framework EventKit \
    -framework ServiceManagement \
    -framework UserNotifications \
    -o "$TEST_BINARY"
"$TEST_BINARY"
