#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

# Builds Tools/SMCDump.swift for the host architecture and runs it. Read-only.
# Usage: Tools/smc-dump.sh [output-file]   (prints to stdout without an argument)
set -euo pipefail
cd "$(dirname "$0")/.."

ARCH="${VORSSAINT_ARCH:-$(uname -m)}"
OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT

swiftc -O -parse-as-library -target "$ARCH-apple-macosx14.0" -sdk "$(xcrun --show-sdk-path)" \
    Tools/SMCDump.swift \
    Sources/Vorssaint/Services/SystemMonitor/SMCClient.swift \
    Sources/Vorssaint/Services/FanControl/FanControlSupport.swift \
    Sources/Vorssaint/Services/Metrics/TemperatureSensorSelector.swift \
    Sources/Vorssaint/Services/Metrics/IntelSMCSensorMap.swift \
    -o "$OUT_DIR/smc-dump"

if [[ $# -gt 0 ]]; then
    "$OUT_DIR/smc-dump" | tee "$1"
else
    "$OUT_DIR/smc-dump"
fi
