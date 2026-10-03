#!/bin/zsh
set -euo pipefail

usage() {
  cat <<'USAGE'
用法：
  run-local-gates.sh

執行 CMV 2.0 的本機完整 gate：Rust／Swift 測試、雙平台 Release
build、bundle／AppIcon／privacy preflight、canonical archive qualification、
現行 toolchain contract 與 MissionCenter Doctor。建置輸出預設放在 /tmp，
不會刪除既有產物。

可用環境變數：
  CMV_CARGO_TARGET_DIR   Rust target 路徑
  CMV_SWIFT_SCRATCH_PATH Swift scratch 路徑
  CMV_DERIVED_ROOT       兩個 Xcode DerivedData 子目錄的根路徑
  CMV_ARCHIVE_PATH       要驗證的 macOS archive（預設 canonical archive）
  CMV_MISSION_CENTER_SCRIPTS  MissionCenter scripts 目錄（可選）
USAGE
}

if (( $# > 0 )); then
  case "$1" in
    --help|-h) usage; exit 0 ;;
    *) print -u2 -- "error: 未知參數：$1"; usage >&2; exit 2 ;;
  esac
fi

script_dir="${0:A:h}"
native_root="${script_dir:h}"
workspace="${native_root:h}"
cargo_target="${CMV_CARGO_TARGET_DIR:-/tmp/cmv-cargo-local-gates}"
swift_scratch="${CMV_SWIFT_SCRATCH_PATH:-/tmp/cmv-swift-local-gates}"
derived_root="${CMV_DERIVED_ROOT:-$(mktemp -d /tmp/cmv-derived-local-gates.XXXXXX)}"
mac_derived="$derived_root/mac"
ipad_derived="$derived_root/ipad"
archive_path="${CMV_ARCHIVE_PATH:-/tmp/CMV-macOS-universal.xcarchive}"

for required_tool in cargo rustc swift xcodebuild plutil lipo python3 git; do
  command -v "$required_tool" >/dev/null || {
    print -u2 -- "error: 缺少必要工具：$required_tool"
    exit 1
  }
done

run_step() {
  print -- "[local-gates] $1"
}

cd "$workspace"

run_step "Rust 1.98.1 toolchain contract"
expected="1.98.1"
read_toml_string() {
  local file="$1"
  local key="$2"
  sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([^\"]+)\".*$/\1/p" "$file" | sed -n '1p'
}

actual_channel="$(read_toml_string "rust-toolchain.toml" channel)"
if [[ "$actual_channel" != "$expected" ]]; then
  print -u2 -- "error: rust-toolchain.toml channel mismatch: expected $expected, got ${(actual_channel):-<missing>}"
  exit 1
fi

for relative in \
  Native/CMVCoreRS/Cargo.toml \
  Native/CMVCoreRS/ffi/Cargo.toml; do
  actual="$(read_toml_string "$relative" rust-version)"
  if [[ "$actual" != "$expected" ]]; then
    print -u2 -- "error: $relative rust-version mismatch: expected $expected, got ${(actual):-<missing>}"
    exit 1
  fi
done

rustc_version="$(rustc --version)"
[[ "$rustc_version" == rustc\ 1.98.1\ * ]] || {
  print -u2 -- "error: active rustc must be 1.98.1; got: $rustc_version"
  exit 1
}

run_step "Rust fmt／Clippy／workspace tests"
(
  cd Native/CMVCoreRS
  CARGO_TARGET_DIR="$cargo_target" CARGO_INCREMENTAL=0 cargo fmt --check
  CARGO_TARGET_DIR="$cargo_target" CARGO_INCREMENTAL=0 cargo clippy --workspace --all-targets -- -D warnings
  CARGO_TARGET_DIR="$cargo_target" CARGO_INCREMENTAL=0 cargo test --workspace
)

run_step "Swift package tests"
swift test --package-path Native/CMVCore --scratch-path "$swift_scratch"

run_step "macOS universal Release build"
xcodebuild -quiet \
  -project Native/CMV/CMV.xcodeproj \
  -scheme CMV \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$mac_derived" \
  -jobs 1 \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

run_step "iPad Simulator universal Release build"
xcodebuild -quiet \
  -project Native/CMV/CMV.xcodeproj \
  -scheme CMV \
  -configuration Release \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$ipad_derived" \
  -jobs 1 \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

run_step "App bundle／AppIcon／privacy preflight"
Native/scripts/qualify-app-store.sh \
  --app "$mac_derived/Build/Products/Release/CMV.app" \
  --expected-arches 'x86_64 arm64' \
  --skip-codesign
Native/scripts/qualify-app-store.sh \
  --app "$ipad_derived/Build/Products/Release-iphonesimulator/CMV.app" \
  --expected-arches 'arm64 x86_64' \
  --skip-codesign

run_step "canonical macOS archive strict preflight"
Native/scripts/qualify-app-store.sh \
  --app "$archive_path/Products/Applications/CMV.app" \
  --expected-arches 'x86_64 arm64'

run_step "repository whitespace checks"
git diff --check

run_step "MissionCenter sync／Doctor"
mc_binary="${CMV_MISSION_CENTER_BIN:-}"
if [[ -z "$mc_binary" ]] && command -v mission-center >/dev/null; then
  mc_binary="${commands[mission-center]}"
fi
[[ -n "$mc_binary" && -x "$mc_binary" ]] || {
  print -u2 -- "error: 找不到 MissionCenter Rust CLI；請設定 CMV_MISSION_CENTER_BIN"
  exit 1
}
"$mc_binary" sync --root "$workspace"
"$mc_binary" doctor --root "$workspace"

run_step "external gate inventory (informational; never auto-closes tasks)"
if command -v xcrun >/dev/null; then
  xcrun xctrace list devices 2>&1 | sed -n '1,28p'
fi
if command -v security >/dev/null; then
  if security find-identity -v -p codesigning 2>/dev/null | grep -q 'Apple Distribution'; then
    print -- "Apple Distribution identity: available (still requires archive/export validation)"
  else
    print -- "Apple Distribution identity: pending"
  fi
fi
print -- "physical device／NAS／TestFlight／licensed material: pending external gate"
print -- "LOCAL_GATES_PASS"
print -- "EXTERNAL_GATES_PENDING"
print -- "derived data: $derived_root"
