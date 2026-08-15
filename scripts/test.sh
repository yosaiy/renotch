#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
TEST_BINARY="$PROJECT_DIR/.build/renotch-smoke-tests"

cd "$PROJECT_DIR"
swift build
swiftc \
    -swift-version 5 \
    Sources/Renotch/Models/NotchModels.swift \
    Sources/Renotch/Models/BrowserActivityModels.swift \
    Sources/Renotch/Models/DeveloperActivityGlance.swift \
    Sources/Renotch/Services/SettingsStore.swift \
    Sources/Renotch/Services/NotificationService.swift \
    Sources/Renotch/Services/TimerService.swift \
    Sources/Renotch/Services/ClipboardService.swift \
    Sources/Renotch/Services/ShelfStore.swift \
    Sources/Renotch/Services/TodoStore.swift \
    Sources/Renotch/Services/MusicService.swift \
    Sources/Renotch/Services/BrowserActivityService.swift \
    Sources/Renotch/Services/DeveloperActivityService.swift \
    Tests/SmokeTests.swift \
    -framework AppKit \
    -o "$TEST_BINARY"
"$TEST_BINARY"

"$SCRIPT_DIR/test-appmodel.sh"
