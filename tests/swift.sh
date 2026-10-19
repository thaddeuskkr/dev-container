#!/usr/bin/env bash
# Run inside the dev image as ubuntu, including with an empty mounted home.
set -euo pipefail

# SSH and sudo can reset PATH; the global links must still find the toolchain.
export PATH=/usr/local/bin:/usr/bin:/bin
test "$(id -un)" = ubuntu
swift --version
swift package --version
swift_test=$(mktemp -d)
trap 'rm -rf "$swift_test"' EXIT
cd "$swift_test"
swift package init --type executable --name SwiftSmoke
# Use our own source to exercise Foundation, not just the generated hello world.
find Sources -name '*.swift' -delete
mkdir -p Sources/SwiftSmoke
cat > Sources/SwiftSmoke/main.swift <<'SWIFT'
import Foundation

let data = Data("{\"status\":\"swift-ok\"}".utf8)
let result = try JSONSerialization.jsonObject(with: data) as! [String: String]
print(result["status"]!)
SWIFT
swift build --jobs 2
swift_bin=$(swift build --show-bin-path)
test "$("$swift_bin/SwiftSmoke")" = swift-ok
