#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
TEST_BINARY="$PROJECT_DIR/.build/renotch-appmodel-tests"

cd "$PROJECT_DIR"
swiftc \
    -swift-version 5 \
    Sources/Renotch/Models/NotchModels.swift \
    Sources/Renotch/Models/BrowserActivityModels.swift \
    Sources/Renotch/Models/DeveloperActivityGlance.swift \
    Sources/Renotch/Services/SettingsStore.swift \
    Sources/Renotch/Services/TimerService.swift \
    Sources/Renotch/Services/ShelfStore.swift \
    Sources/Renotch/Services/TodoStore.swift \
    Sources/Renotch/Services/MusicService.swift \
    Sources/Renotch/Services/QQMusicBridge.swift \
    Sources/Renotch/Services/BrowserActivityService.swift \
    Sources/Renotch/Services/DeveloperActivityService.swift \
    Sources/Renotch/Services/AppleCalendarService.swift \
    Sources/Renotch/Services/LaunchAtLoginService.swift \
    Sources/Renotch/Services/NotificationService.swift \
    Sources/Renotch/Services/FocusBlockerService.swift \
    Sources/Renotch/Window/FocusBlockerOverlayController.swift \
    Sources/Renotch/Models/CodexTaskModels.swift \
    Sources/Renotch/Models/CodexUsageModels.swift \
    Sources/Renotch/Services/CodexUsageClient.swift \
    Sources/Renotch/Services/CodexUsageService.swift \
    Sources/Renotch/Models/CodexStreamProjection.swift \
    Sources/Renotch/Services/CodexIPCClient.swift \
    Sources/Renotch/Services/CodexActivityService.swift \
    Sources/Renotch/State/AppModel.swift \
    Tests/AppModelFileDropTests.swift \
    -framework AppKit \
    -framework EventKit \
    -framework ServiceManagement \
    -framework UserNotifications \
    -framework WebKit \
    -o "$TEST_BINARY"
"$TEST_BINARY"
