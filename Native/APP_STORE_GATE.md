# AeroMusic 2.0｜送審前 gate

更新：2026-08-27

這份清單是送 TestFlight 前的可重跑 gate，不把模擬器編譯誤當成實機核准。

## 已完成的靜態 gate

- deployment target：macOS 15.0、iPadOS 18.0；只啟用 `iphoneos`、`iphonesimulator`、`macosx`。
- macOS App Sandbox、user-selected read-only、app-scope bookmark 與 network client entitlement 已列在 `AeroMusic.entitlements`。
- App 不保存 NAS 帳密、不建立帳號、不送出音樂、PCM、Metadata 或 Smart DJ 結果。
- `PrivacyInfo.xcprivacy` 宣告不追蹤、不收集資料；檔案修改時間只用於使用者明確授權的資料夾差異掃描（`3B52.1`）。
- `Info.plist` 僅宣告音訊背景模式與 Music 類別；沒有任意網路載入或第三方追蹤 SDK。
- 已完成本機 universal Release archive：`/tmp/AeroMusic-macOS-universal.xcarchive`；
  App binary 同時含 `arm64`／`x86_64`，`codesign --verify --deep --strict` 通過，
  embedded entitlements 與 `PrivacyInfo.xcprivacy` 均可解析。此 archive 使用
  Apple Development 憑證，僅代表本機封裝與沙盒驗證，不等同 App Store
  Distribution／TestFlight 簽署。
- App icon 已加入 `Assets.xcassets/AppIcon.appiconset`，1024px／512px RGB 無 Alpha，
  並由 macOS／iPadOS Release bundle 產出；metadata、隱私政策／支援 URL 與授權
  清單集中記錄於 `Native/APP_STORE_METADATA.md`。

## 必須在 Apple 實機／沙盒環境完成

1. macOS 沙盒：Finder 選取資料夾、重開 App、bookmark stale／撤銷權限後使用「重新授權」選擇器、NAS 睡眠與重新連線。
2. iPadOS：檔案 App／NAS provider 選取資料夾，強制終止後重新開啟，驗證「重新授權」流程、`.minimalBookmark` 與 lease、Split View、背景播放、PiP。
3. 以實際簽署 archive 執行 `codesign --verify --deep --strict`，檢查 embedded entitlements 與 privacy manifest 已進入 app bundle。
4. TestFlight 隱私問卷逐項核對：只選「不收集」；若未來新增分析／診斷資料，先更新 manifest 與問卷再送審。
5. 使用授權的完整節目級 loudness reference material 驗證，不以 1 kHz tone fixture 取代節目認證。
6. 依 `Native/APP_STORE_METADATA.md` 補齊 Privacy Policy／Support URL、商店文案、
   年齡分級、App Review notes 與完整素材／第三方授權紀錄。

## 可重跑命令

先用統一 preflight 檢查既有產物；它會驗證 bundle、Info.plist、privacy manifest、架構，
以及（除非指定 `--skip-codesign`）strict codesign：

```sh
Native/scripts/qualify-app-store.sh

# 未簽章的 Simulator／generic device 編譯輸出
AEROMUSIC_APP_PATH=/tmp/aeromusic-derived-ios-universal-t4/Build/Products/Release-iphonesimulator/AeroMusic.app \
  AEROMUSIC_EXPECTED_ARCHES='arm64 x86_64' \
  Native/scripts/qualify-app-store.sh --skip-codesign
```

```sh
xcodebuild -project Native/AeroMusic/AeroMusic.xcodeproj -scheme AeroMusic \
  -configuration Release -sdk macosx \
  -destination 'platform=macOS,arch=arm64' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build

xcodebuild -project Native/AeroMusic/AeroMusic.xcodeproj -scheme AeroMusic \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath /tmp/AeroMusic-macOS-universal.xcarchive \
  DEVELOPMENT_TEAM=<TEAM_ID> CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=<DISTRIBUTION_IDENTITY> archive

xcodebuild -project Native/AeroMusic/AeroMusic.xcodeproj -scheme AeroMusic \
  -configuration Release -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4),OS=26.5' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build
```

完成上述實機項目並取得可驗證 arbiter 回覆後，才可將 AERO-V3 轉 Done，
再由 AERO-R3 執行 TestFlight、送審與 Electron 退場審批。
