#!/bin/zsh
set -euo pipefail

cmv_script_dir="${0:A:h}"
cmv_repo_root="${cmv_script_dir:h:h}"
cmv_scratch="$(mktemp -d "${CMV_STOREKIT_SCRATCH_ROOT:-/private/tmp}/cmv-pro-storekit-run.XXXXXX")"
trap 'rm -r -- "$cmv_scratch"' EXIT
cmv_app="$cmv_scratch/CMVProStoreKitHost.app"
mkdir -p "$cmv_app/Contents/MacOS" "$cmv_app/Contents/Resources"
cp "$cmv_script_dir/CMVProLocal.storekit" "$cmv_app/Contents/Resources/CMVProLocal.storekit"
cat > "$cmv_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CMVProStoreKitHost</string>
<key>CFBundleIdentifier</key><string>local.cmv.pro.storekit.runner</string>
<key>CFBundleName</key><string>CMVProStoreKitHost</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
</dict></plist>
PLIST
cmv_sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
cmv_frameworks="$(xcrun --show-sdk-platform-path)/Developer/Library/Frameworks"
cmv_target="$(uname -m)-apple-macosx15.0"
# Compile the exact production policy used by ProStore, without unrelated media modules.
swiftc -parse-as-library -swift-version 6 -emit-module -emit-object -module-name CMVDomain \
  -target "$cmv_target" -sdk "$cmv_sdk_path" \
  "$cmv_repo_root/Native/CMVCore/Sources/CMVDomain/ProAccess.swift" \
  -emit-module-path "$cmv_scratch/CMVDomain.swiftmodule" -o "$cmv_scratch/CMVDomain.o"
swiftc "$cmv_script_dir/CMVProStoreKitRunner.swift" "$cmv_repo_root/Native/CMV/CMV/ProStore.swift" \
  "$cmv_scratch/CMVDomain.o" -parse-as-library -swift-version 6 \
  -module-name CMVProStoreKitRunner -target "$cmv_target" -sdk "$cmv_sdk_path" -I "$cmv_scratch" \
  -F "$cmv_frameworks" -framework StoreKit -framework StoreKitTest \
  -Xlinker -rpath -Xlinker "$cmv_frameworks" \
  -o "$cmv_app/Contents/MacOS/CMVProStoreKitHost"
codesign --force --deep --sign - "$cmv_app" >/dev/null
"$cmv_app/Contents/MacOS/CMVProStoreKitHost"
