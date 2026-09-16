#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
cd "$PROJECT_DIR"
mkdir -p .build
swiftc -swift-version 5 \
    Sources/Renotch/Models/CodexUsageModels.swift \
    Sources/Renotch/Services/CodexUsageClient.swift \
    Sources/Renotch/Window/ScreenManager.swift \
    Tests/CodexUsageAndDisplayTests.swift \
    -framework AppKit -o .build/renotch-usage-display-tests
.build/renotch-usage-display-tests "$@"
