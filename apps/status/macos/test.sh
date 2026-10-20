#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Sources/DXStatus/Models.swift Tests/DXStatusTests/ModelsTests.swift -o "$TEST_DIR/models-test"
"$TEST_DIR/models-test"
