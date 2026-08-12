#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_ROOT="$(mktemp -d /tmp/aeromusic-build.XXXXXX)"
OUTPUT_DIR="${AEROMUSIC_OUTPUT_DIR:-$PROJECT_ROOT/dist-app}"

cleanup() {
  case "$BUILD_ROOT" in
    /tmp/aeromusic-build.*) rm -rf -- "$BUILD_ROOT" ;;
  esac
}
trap cleanup EXIT

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

ELECTRON_BUILDER_CACHE=/tmp/electron-builder-cache \
TMPDIR=/tmp \
npx electron-builder --mac --arm64

mkdir -p "$OUTPUT_DIR"
ditto "$BUILD_ROOT/dist-app/mac-arm64/AeroMusic.app" "$OUTPUT_DIR/AeroMusic.app"
for artifact in "$BUILD_ROOT"/dist-app/*.dmg "$BUILD_ROOT"/dist-app/*.dmg.blockmap "$BUILD_ROOT"/dist-app/latest-mac.yml; do
  [[ -e "$artifact" ]] || continue
  cp -p "$artifact" "$OUTPUT_DIR/"
done

print "AeroMusic 已輸出至：$OUTPUT_DIR"
