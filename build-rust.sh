#!/bin/bash
# Builds the Rust FFI shim for iOS (device + Apple-Silicon simulator) and
# repackages DionysosFFI.xcframework. Run this whenever rust/ changes.
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT/rust"

echo "==> Building Rust static libs (release)"
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim

echo "==> Repackaging DionysosFFI.xcframework"
rm -rf "$ROOT/DionysosFFI.xcframework"
xcodebuild -create-xcframework \
  -library target/aarch64-apple-ios/release/libdionysos_ffi.a -headers include \
  -library target/aarch64-apple-ios-sim/release/libdionysos_ffi.a -headers include \
  -output "$ROOT/DionysosFFI.xcframework"

echo "==> Done. (Re)generate the project with: xcodegen generate"
