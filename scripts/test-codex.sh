#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
cd "$PROJECT_DIR"
mkdir -p .build
swiftc -swift-version 5 \
    Sources/Renotch/Models/CodexTaskModels.swift \
    Sources/Renotch/Models/CodexStreamProjection.swift \
    Sources/Renotch/Services/CodexIPCClient.swift \
    Tests/CodexStatusTests.swift \
    -o .build/renotch-codex-tests
.build/renotch-codex-tests "$@"
