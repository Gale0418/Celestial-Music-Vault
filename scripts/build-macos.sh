#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_ROOT="$(mktemp -d /tmp/aeromusic-build.XXXXXX)"
OUTPUT_DIR="${AEROMUSIC_OUTPUT_DIR:-$PROJECT_ROOT/dist-app}"
SIGNING_IDENTITY="${AEROMUSIC_SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${AEROMUSIC_NOTARY_KEYCHAIN_PROFILE:-}"

cleanup() {
  case "$BUILD_ROOT" in
    /tmp/aeromusic-build.*) rm -rf -- "$BUILD_ROOT" ;;
  esac
}
trap cleanup EXIT

# Resolve and validate the output before any destructive cleanup. Never allow a
# dangerous broad target such as /, /tmp, the project, or the temporary build root.
if [[ "$OUTPUT_DIR" != /* ]]; then
  OUTPUT_DIR="$PROJECT_ROOT/$OUTPUT_DIR"
fi
OUTPUT_PARENT="$(dirname "$OUTPUT_DIR")"
OUTPUT_NAME="$(basename "$OUTPUT_DIR")"
if [[ -z "$OUTPUT_NAME" || "$OUTPUT_NAME" == '.' || "$OUTPUT_NAME" == '..' || ! -d "$OUTPUT_PARENT" ]]; then
  print -u2 'AEROMUSIC_OUTPUT_DIR 必須是既有父目錄下的具名輸出目錄。'
  exit 1
fi
OUTPUT_PARENT="$(cd "$OUTPUT_PARENT" && pwd -P)"
OUTPUT_DIR="$OUTPUT_PARENT/$OUTPUT_NAME"
if [[ -L "$OUTPUT_DIR" || ( -e "$OUTPUT_DIR" && ! -d "$OUTPUT_DIR" ) ]]; then
  print -u2 'AEROMUSIC_OUTPUT_DIR 不得是符號連結或非目錄。'
  exit 1
fi
if [[ -d "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd -P)"
fi
case "$OUTPUT_DIR" in
  /|/tmp|"$PROJECT_ROOT"|"$BUILD_ROOT")
    print -u2 '拒絕危險的 AEROMUSIC_OUTPUT_DIR。'
    exit 1
    ;;
esac

rsync -a \
  --exclude '.git/' \
  --exclude 'node_modules/' \
  --exclude 'dist/' \
  --exclude 'dist-app/' \
  --exclude 'MissionCenter/' \
  --exclude 'output/' \
  "$PROJECT_ROOT/" "$BUILD_ROOT/"

cd "$BUILD_ROOT"
NPM_CONFIG_CACHE=/tmp/aeromusic-npm-cache npm ci --prefer-offline --no-audit --no-fund
npm test
npm run lint
npm run build

export CSC_IDENTITY_AUTO_DISCOVERY=false

ELECTRON_BUILDER_CACHE=/tmp/electron-builder-cache \
TMPDIR=/tmp \
npx electron-builder --mac --arm64 --dir

APP_PATH="$BUILD_ROOT/dist-app/mac-arm64/AeroMusic.app"
DMG_PATH="${BUILD_ROOT}/dist-app/AeroMusic-$(node -p "require('./package.json').version")-arm64.dmg"
DMG_ROOT="$BUILD_ROOT/dmg-root"
ENTITLEMENTS_PATH="$BUILD_ROOT/build/entitlements.mac.plist"

# electron-builder/Electron may inject a permissive ATS default. AeroMusic only
# uses HTTPS and its own secure custom protocol, so fail closed before signing.
plutil -replace NSAppTransportSecurity.NSAllowsArbitraryLoads -bool NO "$APP_PATH/Contents/Info.plist"
if [[ "$(plutil -extract NSAppTransportSecurity.NSAllowsArbitraryLoads raw "$APP_PATH/Contents/Info.plist")" != 'false' ]]; then
  print -u2 '無法關閉 NSAllowsArbitraryLoads；停止產生不安全的候選版。'
  exit 1
fi

if [[ -n "$SIGNING_IDENTITY" ]]; then
  if [[ "$SIGNING_IDENTITY" == 'Developer ID Application:'* ]]; then
    TIMESTAMP_ARG='--timestamp'
    LEAF_SIGN_ARGS=(--options runtime)
    APP_SIGN_ARGS=(--options runtime --entitlements "$ENTITLEMENTS_PATH")
  else
    print '注意：目前使用 Apple Development 憑證，只適用於本機開發與測試。'
    TIMESTAMP_ARG='--timestamp=none'
    LEAF_SIGN_ARGS=()
    APP_SIGN_ARGS=()
  fi

  # Electron ships its media/GPU libraries with ad-hoc signatures. A later
  # `codesign --deep` validates but does not reliably replace every nested
  # signature, which makes Hardened Runtime reject them when the outer app has
  # a Team ID. Re-sign leaf binaries first so the complete graph has one team.
  while IFS= read -r nested_binary; do
    codesign --force "${LEAF_SIGN_ARGS[@]}" "$TIMESTAMP_ARG" \
      --sign "$SIGNING_IDENTITY" "$nested_binary"
  done < <(find "$APP_PATH/Contents/Frameworks" -type f \
    \( -name '*.dylib' -o -name 'chrome_crashpad_handler' \) -print)

  while IFS= read -r helper_app; do
    codesign --force --deep "${APP_SIGN_ARGS[@]}" "$TIMESTAMP_ARG" \
      --sign "$SIGNING_IDENTITY" "$helper_app"
  done < <(find "$APP_PATH/Contents/Frameworks" -type d -name '*.app' -print)

  codesign --force --deep "${APP_SIGN_ARGS[@]}" "$TIMESTAMP_ARG" \
    --sign "$SIGNING_IDENTITY" "$APP_PATH"
else
  print '注意：未指定簽章憑證，產物只使用 ad-hoc 本機簽章。'
  codesign --force --deep --sign - "$APP_PATH"
fi
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

mkdir -p "$DMG_ROOT"
ditto "$APP_PATH" "$DMG_ROOT/AeroMusic.app"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create -volname AeroMusic -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH"

if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force "$TIMESTAMP_ARG" --sign "$SIGNING_IDENTITY" "$DMG_PATH"
else
  codesign --force --sign - "$DMG_PATH"
fi
codesign --verify --verbose=2 "$DMG_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
  if [[ "$SIGNING_IDENTITY" != 'Developer ID Application:'* ]]; then
    print -u2 "公證需要 Developer ID Application 簽章；請同時設定 AEROMUSIC_SIGNING_IDENTITY。"
    exit 1
  fi
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_PATH"
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$APP_PATH"
  xcrun stapler validate "$DMG_PATH"
fi

mkdir -p "$OUTPUT_DIR"
APP_OUTPUT_PATH="$OUTPUT_DIR/AeroMusic.app"
if [[ -L "$APP_OUTPUT_PATH" ]]; then
  print -u2 '拒絕覆寫符號連結形式的舊 AeroMusic.app。'
  exit 1
fi
if [[ -e "$APP_OUTPUT_PATH" ]]; then
  rm -rf -- "$APP_OUTPUT_PATH"
fi
ditto "$APP_PATH" "$APP_OUTPUT_PATH"
for artifact in "$BUILD_ROOT"/dist-app/*.dmg; do
  [[ -e "$artifact" ]] || continue
  cp -p "$artifact" "$OUTPUT_DIR/"
done

print "AeroMusic 已輸出至：$OUTPUT_DIR"
