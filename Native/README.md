# 星穹私藏音樂庫 Celestial Music Vault（CMV）Native

This directory contains the Swift 6 / SwiftUI rebuild for macOS 15+ and iPadOS
18+. It is the only current application implementation. The legacy
Electron/React/Node source and packaging were retired from this checkout under
AERO-RT4; native acceptance and release gates remain separate work.

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
signing, TestFlight, and App Store submission remain explicit qualification gates
rather than being implied complete by the scaffold.

The retired legacy source can be recovered from the repository baseline
`7e033ae3b776f116695b3f2df0f0293bd76322f9` with `git show <sha>:path` or
`git restore --source <sha> -- paths` when a historical comparison is required.

## 本輪音效與品質驗收

原生音效的模式、處理管線與限制見 [AUDIO_EFFECTS.md](AUDIO_EFFECTS.md)；音色探索與原音對照見 [PLAYFUL_LISTENING.md](PLAYFUL_LISTENING.md)。
目前可販售品質的修正、實際測試範圍、成品資料保留及未通過門檻見
[SELLABLE_QUALITY.md](SELLABLE_QUALITY.md)；局部通過不代表已可正式上架。

推薦定位、首次使用與三語介紹稿見 [RECOMMENDATION_KIT.md](RECOMMENDATION_KIT.md)；上市驗收限制仍如實保留。
