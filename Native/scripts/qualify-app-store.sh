#!/bin/zsh
set -euo pipefail

usage() {
  cat <<'USAGE'
用法：
  qualify-app-store.sh [--app PATH] [--expected-arches "arm64 x86_64"] [--skip-codesign]

預設檢查 /tmp/AeroMusic-macOS-universal.xcarchive 內的 AeroMusic.app。
--skip-codesign 適用於未簽章的 iOS Simulator bundle；正式 archive 不應使用。
USAGE
}

script_dir="${0:A:h}"
native_root="${script_dir:h}"
archive_path="${AEROMUSIC_ARCHIVE_PATH:-/tmp/AeroMusic-macOS-universal.xcarchive}"
app_path="${AEROMUSIC_APP_PATH:-$archive_path/Products/Applications/AeroMusic.app}"
expected_arches="${AEROMUSIC_EXPECTED_ARCHES:-arm64 x86_64}"
skip_codesign="${AEROMUSIC_SKIP_CODESIGN:-0}"

while (( $# > 0 )); do
  case "$1" in
    --app)
      (( $# >= 2 )) || { print -u2 -- "error: --app 需要路徑"; exit 2; }
      app_path="$2"
      shift 2
      ;;
    --expected-arches)
      (( $# >= 2 )) || { print -u2 -- "error: --expected-arches 需要值"; exit 2; }
      expected_arches="$2"
      shift 2
      ;;
    --skip-codesign)
      skip_codesign=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      print -u2 -- "error: 未知參數：$1"
      usage >&2
      exit 2
      ;;
  esac
done

for required_tool in plutil lipo; do
  command -v "$required_tool" >/dev/null || {
    print -u2 -- "error: 缺少必要工具：$required_tool"
    exit 1
  }
done

source_info="$native_root/AeroMusic/AeroMusic/Info.plist"
source_privacy="$native_root/AeroMusic/AeroMusic/PrivacyInfo.xcprivacy"
[[ -f "$source_info" ]] || { print -u2 -- "error: 找不到 source Info.plist：$source_info"; exit 1; }
[[ -f "$source_privacy" ]] || { print -u2 -- "error: 找不到 source privacy manifest：$source_privacy"; exit 1; }
plutil -lint "$source_info" "$source_privacy" >/dev/null

[[ -d "$app_path" ]] || {
  print -u2 -- "error: 找不到 App bundle：$app_path"
  print -u2 -- "提示：先建立 archive，或設定 AEROMUSIC_APP_PATH"
  exit 1
}

if [[ -d "$app_path/Contents" ]]; then
  info_path="$app_path/Contents/Info.plist"
  privacy_path="$app_path/Contents/Resources/PrivacyInfo.xcprivacy"
  binary_path="$app_path/Contents/MacOS/AeroMusic"
  icon_name=$(plutil -extract CFBundleIconName raw "$info_path" 2>/dev/null || true)
else
  info_path="$app_path/Info.plist"
  privacy_path="$app_path/PrivacyInfo.xcprivacy"
  binary_path="$app_path/AeroMusic"
  icon_name=$(plutil -extract 'CFBundleIcons~ipad.CFBundlePrimaryIcon.CFBundleIconName' raw "$info_path" 2>/dev/null || true)
fi
[[ -f "$info_path" ]] || { print -u2 -- "error: bundle 缺少 Info.plist"; exit 1; }
[[ -f "$privacy_path" ]] || { print -u2 -- "error: bundle 缺少 PrivacyInfo.xcprivacy"; exit 1; }
[[ -f "$binary_path" ]] || { print -u2 -- "error: bundle 缺少可執行檔：$binary_path"; exit 1; }
plutil -lint "$info_path" "$privacy_path" >/dev/null
[[ "$icon_name" == "AppIcon" ]] || {
  print -u2 -- "error: bundle 缺少 AppIcon（實際：${icon_name:-<none>}）"
  exit 1
}

source_privacy_sha=$(shasum -a 256 "$source_privacy" | awk '{print $1}')
bundle_privacy_sha=$(shasum -a 256 "$privacy_path" | awk '{print $1}')
[[ "$source_privacy_sha" == "$bundle_privacy_sha" ]] || {
  print -u2 -- "error: bundle privacy manifest 與 source 不一致（source=$source_privacy_sha bundle=$bundle_privacy_sha）"
  exit 1
}

typeset -a actual_arches expected_list
actual_arches=("${(@s: :)$(lipo -archs "$binary_path")}")
expected_list=("${(@s: :)expected_arches}")
actual_sorted=("${(@o)actual_arches}")
expected_sorted=("${(@o)expected_list}")
[[ "${(j: :)actual_sorted}" == "${(j: :)expected_sorted}" ]] || {
  print -u2 -- "error: 架構集合不符（期待：${(j: :)expected_sorted}；實際：${(j: :)actual_sorted}）"
  exit 1
}
for expected in "${expected_list[@]}"; do
  (( ${actual_arches[(I)$expected]} )) || {
    print -u2 -- "error: binary 缺少架構 $expected（實際：${(j: :)actual_arches}）"
    exit 1
  }
done

if [[ "$skip_codesign" != 1 ]]; then
  command -v codesign >/dev/null || { print -u2 -- "error: 缺少必要工具：codesign"; exit 1; }
  codesign --verify --deep --strict "$app_path"
fi

print -- "AeroMusic App Store preflight PASS"
print -- "  app: $app_path"
print -- "  architectures: ${(j: :)actual_arches}"
print -- "  app icon: $icon_name"
print -- "  privacy manifest: $bundle_privacy_sha"
if [[ "$skip_codesign" == 1 ]]; then
  print -- "  codesign: skipped (simulator bundle)"
else
  print -- "  codesign: strict verification passed"
fi
