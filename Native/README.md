# 星穹私藏音樂庫 Celestial Music Vault（CMV）Native

This directory contains the Swift 6 / SwiftUI rebuild for macOS 15+ and iPadOS
18+. The legacy Electron application remains untouched until native acceptance is
complete.

## Structure

- `CMVCore/`: first-party Swift package containing domain, library, playback,
  analysis, cache, and theme modules.
- `CMV/`: shared multi-platform Xcode application target.

## Verify

土星雲層使用隨 App 編譯的 Metal shader。若 Xcode 回報缺少 Metal Toolchain，先執行
`xcodebuild -downloadComponent MetalToolchain` 安裝 Apple 官方元件，再執行建置。

Keep build products on the workspace volume when the system disk is constrained:

```sh
cd Native/CMVCore
swift test --scratch-path .swiftpm-build --disable-index-store -j 1

cd ../CMV
xcodebuild -project CMV.xcodeproj -scheme CMV \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath ../.DerivedData-mac CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO -jobs 1 build

xcodebuild -project CMV.xcodeproj -scheme CMV \
  -configuration Debug -sdk iphonesimulator \
  -derivedDataPath ../.DerivedData-ios CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  -jobs 1 build
```

## Current milestone

The shared shell, SwiftData records, folder authorization/bookmark persistence,
differential scanner, paged library query, embedded artwork persistence, playlist
queue loading, dual-node audio foundation, ReplayGain gain stage, limiter/EQ,
offline cache playback, local analyzer contract, and explainable Smart DJ
foundation are present. The 50,000-track fixture, Rust/Swift gapless planning,
Mac folder drop, paged library/catalog UI, simulator PiP/UI checks, and static
App Store preflight are green. Physical-device background audio, NAS/file-provider
reauthorization, licensed program loudness reference material, Distribution
signing, TestFlight, and final Electron retirement remain explicit qualification
gates rather than being implied complete by the scaffold.
