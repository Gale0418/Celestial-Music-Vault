#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
native_root="${script_dir:h}"
workspace="${native_root:h}"
cargo_target="${CMV_CARGO_TARGET_DIR:-/tmp/cmv-cargo-fast-gates}"
swift_scratch="${CMV_SWIFT_SCRATCH_PATH:-/tmp/cmv-swift-fast-gates}"
derived_root="${CMV_DERIVED_ROOT:-/tmp/cmv-derived-fast-gates}"

for required_tool in rustc cargo swift xcodebuild xcrun git; do
  command -v "$required_tool" >/dev/null || {
    print -u2 -- "error: 缺少必要工具：$required_tool"
    exit 1
  }
done

cd "$workspace"
rust_version="$(rustc --version)"
[[ "$rust_version" == rustc\ 1.98.1\ * ]] || {
  print -u2 -- "error: CMV requires Rust 1.98.1 exactly for this release line; got: $rust_version"
  exit 1
}

print -- "[fast-gates] Rust fmt／Clippy／workspace tests"
(
  cd Native/CMVCoreRS
  CARGO_TARGET_DIR="$cargo_target" cargo fmt --check
  CARGO_TARGET_DIR="$cargo_target" cargo clippy --workspace --all-targets -- -D warnings
  CARGO_TARGET_DIR="$cargo_target" cargo test --workspace
  CMV_CARGO_TARGET_DIR="$cargo_target" ./scripts/test-swift-bridge.sh
)

print -- "[fast-gates] Swift package tests"
swift test --package-path Native/CMVCore --scratch-path "$swift_scratch"

print -- "[fast-gates] macOS arm64 Debug build"
xcodebuild -quiet \
  -project Native/CMV/CMV.xcodeproj \
  -scheme CMV \
  -configuration Debug \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$derived_root/mac" \
  -jobs 1 \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build

print -- "[fast-gates] iPad Simulator arm64 Debug build"
xcodebuild -quiet \
  -project Native/CMV/CMV.xcodeproj \
  -scheme CMV \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$derived_root/ipad" \
  -jobs 1 \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  build

print -- "[fast-gates] whitespace check"
git diff --check

print -- "FAST_GATES_PASS"
