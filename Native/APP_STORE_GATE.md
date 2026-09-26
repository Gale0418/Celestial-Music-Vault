# 星穹私藏音樂庫 Celestial Music Vault（CMV）2.0｜送審前 gate

更新：2026-09-26

這份清單是送 TestFlight 前的可重跑 gate，不把模擬器編譯誤當成實機核准。

## 已完成的靜態 gate

- deployment target：macOS 15.0、iPadOS 18.0；只啟用 `iphoneos`、`iphonesimulator`、`macosx`。
- macOS App Sandbox、user-selected read-only、app-scope bookmark 與 network client entitlement 已列在 `CMV.entitlements`。
- App 不保存 NAS 帳密、不建立帳號、不送出音樂、PCM、Metadata 或 Smart DJ 結果。
- `PrivacyInfo.xcprivacy` 宣告不追蹤、不收集資料；檔案修改時間只用於使用者明確授權的資料夾差異掃描（`3B52.1`），`UserDefaults` 只保存 App 自身偏好（`CA92.1`），system boot time 只用於 App 內能量表 elapsed-time 節流（`35F9.1`）與 AVAudioTime 絕對 host timestamp 排程（`8FFB.1`）。
- `Info.plist` 僅宣告音訊背景模式與 Music 類別；沒有任意網路載入或第三方追蹤 SDK。
- 靜態搜尋未找到 CMV 自行建立 URLSession／Network／Bonjour／SMB 連線；目前
  `network.client` entitlement 僅暫留至實機 NAS 掛載測試。若 Finder／Files 掛載後的
  security-scoped 檔案存取不需要它，正式 RC 應移除以維持最小權限。
- 歷史上曾完成 Development 簽章的 universal archive 驗證；目前 canonical
  `/tmp/CMV-macOS-universal.xcarchive` 已不存在，且工作樹與 artifact manifest 已變更，
  因此該歷史證據不可作為本次 RC。正式 RC 必須重建並重新記錄 binary／dSYM UUID。
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

## 2026-09-26 唯讀發行盤點

- App Store Connect 已成功唯讀回讀 App Record：App ID `6815468050`、Bundle ID
  `com.windsheep.cmv`，iOS 與 macOS 共用同一紀錄，主要語言為繁體中文；不再以「尚未
  確認 App Record」作為目前狀態。版本／build 仍為 `2.0`／`1`。
- 正式 Pro non-consumable 已建立：商品 ID `com.windsheep.cmv.pro.v1`、商品資源 ID
  `6815468483`；台灣價格唯讀回讀為 NT$150，繁中與英文名稱／描述已回讀。商品截圖
  資源 `3d8c1597-c3fd-46e1-8411-9264d81e913e` 已完成傳遞，商品狀態為
  `READY_TO_SUBMIT`。
- App Store Connect 商務頁已唯讀確認免費／付費協議、收款與稅務狀態完成；Pro 商品仍
  未送審，App 尚未發佈。這些商店設定證據不等於 Sandbox 購買、實機驗收或可上架。
- 正式 Distribution archive、embedded entitlements／privacy manifest、實機與上傳
  validation 仍待重新驗證；9/26 紀錄只有 Mac／iPad Simulator Debug 編譯與隔離 App
  strict ad-hoc 簽章證據，不能宣稱 TestFlight 或 App Store ready。
- 實體 iPad、背景音訊、PiP、Files provider、bookmark 重啟恢復、NAS 故障矩陣，以及
  Apple Sandbox 購買／恢復／退款／撤銷仍無足夠證據；`Native/APP_STORE_REVIEW_KIT.md`
  與 `Native/ASSET_RIGHTS_LEDGER.md` 的方括號欄位仍是人工 gate。

## 可重跑命令

先用統一 preflight 檢查既有產物；它會驗證 bundle、Info.plist、privacy manifest、架構，
以及（除非指定 `--skip-codesign`）strict codesign：

```sh
Native/scripts/qualify-app-store.sh

# 未簽章的 Simulator／generic device 編譯輸出
CMV_APP_PATH=/tmp/cmv-derived-ios-universal-t4/Build/Products/Release-iphonesimulator/CMV.app \
  CMV_EXPECTED_ARCHES='arm64 x86_64' \
  Native/scripts/qualify-app-store.sh --skip-codesign
```

```sh
xcodebuild -project Native/CMV/CMV.xcodeproj -scheme CMV \
  -configuration Release -sdk macosx \
  -destination 'platform=macOS,arch=arm64' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build

xcodebuild -project Native/CMV/CMV.xcodeproj -scheme CMV \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath /tmp/CMV-macOS-universal.xcarchive \
  DEVELOPMENT_TEAM=<TEAM_ID> CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=<DISTRIBUTION_IDENTITY> archive

xcodebuild -project Native/CMV/CMV.xcodeproj -scheme CMV \
  -configuration Release -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4),OS=26.5' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build
```

完成上述實機項目並取得可驗證 arbiter 回覆後，才可將 AERO-V3 轉 Done，
再由 AERO-R3 執行 TestFlight、送審與 Electron 退場審批。

## 一次性 Pro 發行 gate（AERO-MON30）

- 核對正式 non-consumable 商品與封裝後 Info.plist 的 `CMVProProductID`；空值、未展開 build variable 或 `local.cmv.pro.test` 不能作為發行候選。
- 核定價格、平台購買權益與商品說明；恢復、退款／撤銷、pending、失敗、已購離線冷啟動須有兩平台證據。
- [Pro 實作紀錄](PRO_IMPLEMENTATION.md) 的 48 項純邏輯／package 測試和 Debug 編譯不能取代 Apple Sandbox、實機或正式簽章驗收。
