#!/bin/zsh
set -euo pipefail

usage() {
  cat <<'USAGE'
用法：
  qualify-app-store.sh [--app PATH] [--expected-arches "arm64 x86_64"]
    [--expected-version VERSION] [--expected-build NUMBER] [--distribution] [--skip-codesign]

預設檢查 /tmp/CMV-macOS-universal.xcarchive 內的 CMV.app。
--skip-codesign 適用於未簽章的 iOS Simulator bundle；正式 archive 不應使用。
--distribution 額外要求 App Store 配發簽章、有效 profile 與非開發 entitlements。
一般模式通過只代表本機 bundle preflight，不代表可上傳。
USAGE
}

script_dir="${0:A:h}"
native_root="${script_dir:h}"
archive_path="${CMV_ARCHIVE_PATH:-/tmp/CMV-macOS-universal.xcarchive}"
app_path="${CMV_APP_PATH:-$archive_path/Products/Applications/CMV.app}"
expected_arches="${CMV_EXPECTED_ARCHES:-arm64 x86_64}"
skip_codesign="${CMV_SKIP_CODESIGN:-0}"
distribution=0
expected_version="${CMV_EXPECTED_VERSION:-}"
expected_build="${CMV_EXPECTED_BUILD:-}"

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
    --distribution)
      distribution=1
      shift
      ;;
    --expected-version|--expected-build)
      (( $# >= 2 )) || { print -u2 -- "error: $1 需要值"; exit 2; }
      if [[ "$1" == --expected-version ]]; then expected_version="$2"; else expected_build="$2"; fi
      shift 2
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

if [[ "$distribution" == 1 && "$skip_codesign" == 1 ]]; then
  print -u2 -- "error: Distribution qualification 不可跳過 codesign"
  exit 2
fi

for required_tool in plutil lipo; do
  command -v "$required_tool" >/dev/null || {
    print -u2 -- "error: 缺少必要工具：$required_tool"
    exit 1
  }
done

source_info="$native_root/CMV/CMV/Info.plist"
source_privacy="$native_root/CMV/CMV/PrivacyInfo.xcprivacy"
[[ -f "$source_info" ]] || { print -u2 -- "error: 找不到 source Info.plist：$source_info"; exit 1; }
[[ -f "$source_privacy" ]] || { print -u2 -- "error: 找不到 source privacy manifest：$source_privacy"; exit 1; }
plutil -lint "$source_info" "$source_privacy" >/dev/null

[[ -d "$app_path" ]] || {
  print -u2 -- "error: 找不到 App bundle：$app_path"
  print -u2 -- "提示：先建立 archive，或設定 CMV_APP_PATH"
  exit 1
}

if [[ -d "$app_path/Contents" ]]; then
  info_path="$app_path/Contents/Info.plist"
  privacy_path="$app_path/Contents/Resources/PrivacyInfo.xcprivacy"
  binary_path="$app_path/Contents/MacOS/CMV"
  icon_name=$(plutil -extract CFBundleIconName raw "$info_path" 2>/dev/null || true)
else
  info_path="$app_path/Info.plist"
  privacy_path="$app_path/PrivacyInfo.xcprivacy"
  binary_path="$app_path/CMV"
  icon_name=$(plutil -extract 'CFBundleIcons~ipad.CFBundlePrimaryIcon.CFBundleIconName' raw "$info_path" 2>/dev/null || true)
fi
[[ -f "$info_path" ]] || { print -u2 -- "error: bundle 缺少 Info.plist"; exit 1; }
[[ -f "$privacy_path" ]] || { print -u2 -- "error: bundle 缺少 PrivacyInfo.xcprivacy"; exit 1; }
[[ -f "$binary_path" ]] || { print -u2 -- "error: bundle 缺少可執行檔：$binary_path"; exit 1; }
plutil -lint "$info_path" "$privacy_path" >/dev/null
bundle_id=$(plutil -extract CFBundleIdentifier raw "$info_path")
product_id=$(plutil -extract CMVProProductID raw "$info_path" 2>/dev/null || true)
bundle_version=$(plutil -extract CFBundleShortVersionString raw "$info_path")
bundle_build=$(plutil -extract CFBundleVersion raw "$info_path")
[[ "$bundle_id" == com.windsheep.cmv ]] || { print -u2 -- "error: bundle ID 不符"; exit 1; }
[[ "$product_id" == com.windsheep.cmv.pro.v1 ]] || {
  print -u2 -- "error: CMVProProductID 必須為正式商品 ID，不可空白、未展開或為本機 fixture"
  exit 1
}
[[ "$bundle_version" =~ '^[0-9]+(\.[0-9]+){0,2}$' && "$bundle_build" =~ '^[0-9]+(\.[0-9]+){0,2}$' ]] || {
  print -u2 -- "error: 版本／build 格式不符"
  exit 1
}
[[ -z "$expected_version" || "$bundle_version" == "$expected_version" ]] || { print -u2 -- "error: 版本不符"; exit 1; }
[[ -z "$expected_build" || "$bundle_build" == "$expected_build" ]] || { print -u2 -- "error: build 不符"; exit 1; }
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
  cmv_qualification_scratch=$(mktemp -d "${TMPDIR:-/tmp}/cmv-qualification.XXXXXX")
  trap 'rm -r -- "$cmv_qualification_scratch"' EXIT
  codesign -d --entitlements :- "$app_path" > "$cmv_qualification_scratch/entitlements.plist" 2>/dev/null
  plutil -lint "$cmv_qualification_scratch/entitlements.plist" >/dev/null
  if [[ -d "$app_path/Contents" ]]; then
    for key in com.apple.security.app-sandbox com.apple.security.files.user-selected.read-only com.apple.security.files.bookmarks.app-scope; do
      [[ "$(/usr/libexec/PlistBuddy -c "Print :$key" "$cmv_qualification_scratch/entitlements.plist" 2>/dev/null || true)" == true ]] || {
        print -u2 -- "error: macOS bundle 缺少必要 sandbox entitlement：$key"
        exit 1
      }
    done
  fi
  if [[ "$distribution" == 1 ]]; then
    command -v security >/dev/null || { print -u2 -- "error: 缺少 security"; exit 1; }
    command -v python3 >/dev/null || { print -u2 -- "error: 缺少 python3"; exit 1; }
    codesign -dv "$app_path" 2> "$cmv_qualification_scratch/signature.txt"
    cmv_signature_text=$(<"$cmv_qualification_scratch/signature.txt")
    if [[ "$cmv_signature_text" != *'Authority=Apple Distribution:'* && "$cmv_signature_text" != *'Authority=iPhone Distribution:'* && "$cmv_signature_text" != *'Authority=3rd Party Mac Developer Application:'* ]]; then
      print -u2 -- "error: 必須使用 App Store Distribution identity；Development／ad-hoc 不合格"
      exit 1
    fi
    if [[ -d "$app_path/Contents" ]]; then
      cmv_profile="$app_path/Contents/embedded.provisionprofile"
    else
      cmv_profile="$app_path/embedded.mobileprovision"
    fi
    [[ -f "$cmv_profile" ]] || { print -u2 -- "error: 缺少 embedded Distribution profile"; exit 1; }
    security cms -D -i "$cmv_profile" > "$cmv_qualification_scratch/profile.plist" 2>/dev/null
    python3 - "$cmv_qualification_scratch/profile.plist" "$cmv_qualification_scratch/entitlements.plist" "$bundle_id" <<'PY'
import datetime, plistlib, sys
with open(sys.argv[1], 'rb') as stream:
    profile = plistlib.load(stream)
with open(sys.argv[2], 'rb') as stream:
    signed = plistlib.load(stream)
entitlements = profile.get('Entitlements', {})
expiry = profile.get('ExpirationDate')
identifier = entitlements.get('application-identifier') or entitlements.get('com.apple.application-identifier', '')
signed_identifier = signed.get('application-identifier') or signed.get('com.apple.application-identifier', '')
team = entitlements.get('com.apple.developer.team-identifier')
valid = (
    isinstance(expiry, datetime.datetime) and expiry > datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
    and 'ProvisionedDevices' not in profile and not profile.get('ProvisionsAllDevices', False)
    and not entitlements.get('get-task-allow', False) and not entitlements.get('com.apple.security.get-task-allow', False)
    and not signed.get('get-task-allow', False) and not signed.get('com.apple.security.get-task-allow', False)
    and identifier.endswith('.' + sys.argv[3]) and signed_identifier == identifier
    and bool(team) and signed.get('com.apple.developer.team-identifier') == team
)
if not valid:
    sys.exit('error: profile／signed entitlements 的效期、App ID、Team 或 App Store 配發資格不符')
PY
  fi
fi

if [[ "$distribution" == 1 ]]; then
  print -- "CMV App Store Distribution qualification PASS"
else
  print -- "CMV local bundle preflight PASS (Distribution readiness not checked)"
fi
print -- "  app: $app_path"
print -- "  version/build: $bundle_version ($bundle_build)"
print -- "  Pro product: $product_id"
print -- "  architectures: ${(j: :)actual_arches}"
print -- "  app icon: $icon_name"
print -- "  privacy manifest: $bundle_privacy_sha"
if [[ "$skip_codesign" == 1 ]]; then
  print -- "  codesign: skipped (simulator bundle)"
else
  print -- "  codesign: strict verification passed"
fi
