#!/bin/zsh
set -euo pipefail

usage() {
  cat <<'USAGE'
用法：
  run-local-gates.sh

執行 AeroMusic 2.0 的本機完整 gate：Rust／Swift 測試、雙平台 Release
build、bundle／AppIcon／privacy preflight、artifact manifest、MissionCenter
Doctor。建置輸出預設放在 /tmp，不會刪除既有產物。

可用環境變數：
  AEROMUSIC_CARGO_TARGET_DIR   Rust target 路徑
  AEROMUSIC_SWIFT_SCRATCH_PATH Swift scratch 路徑
  AEROMUSIC_DERIVED_ROOT       兩個 Xcode DerivedData 子目錄的根路徑
  AEROMUSIC_ARCHIVE_PATH       要驗證的 macOS archive（預設 canonical archive）
  AEROMUSIC_MISSION_CENTER_SCRIPTS  MissionCenter scripts 目錄（可選）
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
cargo_target="${AEROMUSIC_CARGO_TARGET_DIR:-/tmp/aeromusic-cargo-local-gates}"
swift_scratch="${AEROMUSIC_SWIFT_SCRATCH_PATH:-/tmp/aeromusic-swift-local-gates}"
derived_root="${AEROMUSIC_DERIVED_ROOT:-$(mktemp -d /tmp/aeromusic-derived-local-gates.XXXXXX)}"
mac_derived="$derived_root/mac"
ipad_derived="$derived_root/ipad"
archive_path="${AEROMUSIC_ARCHIVE_PATH:-/tmp/AeroMusic-macOS-universal.xcarchive}"

for required_tool in cargo swift xcodebuild plutil lipo shasum python3; do
  command -v "$required_tool" >/dev/null || {
    print -u2 -- "error: 缺少必要工具：$required_tool"
    exit 1
  }
done

run_step() {
  print -- "[local-gates] $1"
}

cd "$workspace"
run_step "Rust fmt／Clippy／workspace tests"
(
  cd Native/AeroCoreRS
  CARGO_TARGET_DIR="$cargo_target" CARGO_INCREMENTAL=0 cargo fmt --check
  CARGO_TARGET_DIR="$cargo_target" CARGO_INCREMENTAL=0 cargo clippy --workspace --all-targets -- -D warnings
  CARGO_TARGET_DIR="$cargo_target" CARGO_INCREMENTAL=0 cargo test --workspace
)

run_step "Swift package tests"
swift test --package-path Native/AeroCore --scratch-path "$swift_scratch"

run_step "macOS universal Release build"
xcodebuild -quiet \
  -project Native/AeroMusic/AeroMusic.xcodeproj \
  -scheme AeroMusic \
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
  -project Native/AeroMusic/AeroMusic.xcodeproj \
  -scheme AeroMusic \
  -configuration Release \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4),OS=26.5' \
  -derivedDataPath "$ipad_derived" \
  -jobs 1 \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

run_step "App bundle／AppIcon／privacy preflight"
Native/scripts/qualify-app-store.sh \
  --app "$mac_derived/Build/Products/Release/AeroMusic.app" \
  --expected-arches 'x86_64 arm64' \
  --skip-codesign
Native/scripts/qualify-app-store.sh \
  --app "$ipad_derived/Build/Products/Release-iphonesimulator/AeroMusic.app" \
  --expected-arches 'arm64 x86_64' \
  --skip-codesign

run_step "canonical macOS archive strict preflight"
Native/scripts/qualify-app-store.sh \
  --app "$archive_path/Products/Applications/AeroMusic.app" \
  --expected-arches 'x86_64 arm64'

run_step "artifact manifest and whitespace checks"
bad=0
manifest_entries=0
while IFS=$'\t' read -r file_path expected; do
  [[ -n "$file_path" ]] || continue
  manifest_entries=$((manifest_entries + 1))
  actual=$(shasum -a 256 "$file_path" | awk '{print $1}')
  if [[ "$actual" != "$expected" ]]; then
    print -u2 -- "DRIFT $file_path expected=$expected actual=$actual"
    bad=1
  fi
done < <(sed -n 's/^| `\([^`]*\)` | `\([0-9a-f]*\)` |$/\1\t\2/p' Native/ARTIFACT_MANIFEST.md)
(( manifest_entries > 0 )) || { print -u2 -- "error: artifact manifest is empty or malformed"; exit 1; }
(( bad == 0 )) || exit 1
git diff --check

run_step "MissionCenter sync／Doctor"
mc_scripts="${AEROMUSIC_MISSION_CENTER_SCRIPTS:-}"
if [[ -z "$mc_scripts" && -d "$workspace/MissionCenter/scripts" ]]; then
  mc_scripts="$workspace/MissionCenter/scripts"
fi
if [[ -z "$mc_scripts" ]] && command -v mission_maintenance.py >/dev/null; then
  mc_scripts="${commands[mission_maintenance.py]:h}"
fi
[[ -n "$mc_scripts" && -f "$mc_scripts/mission_maintenance.py" && -f "$mc_scripts/doctor_mission_center.py" ]] || {
  print -u2 -- "error: 找不到 MissionCenter scripts；請設定 AEROMUSIC_MISSION_CENTER_SCRIPTS"
  exit 1
}
python3 "$mc_scripts/mission_maintenance.py" "$workspace" sync
python3 "$mc_scripts/doctor_mission_center.py" "$workspace"

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
