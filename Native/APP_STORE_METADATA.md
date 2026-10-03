# 星穹私藏音樂庫 Celestial Music Vault（CMV）2.0｜App Store Connect metadata gate

更新：2026-10-03

這份文件是送審前的 metadata 與授權資料單一清單。它不把本機建置或
模擬器測試當成 Apple 審核資料，也不在工作區保存 Apple ID、憑證或 NAS 帳密。

## 已可由專案固定的內容

- App 名稱：`星穹私藏音樂庫 Celestial Music Vault`
- 版本：`2.0`（build `1`）
- Bundle ID：`com.windsheep.cmv`
- 類別：Music
- 支援平台：macOS 15+、iPadOS 18+
- 產品定位：夢幻星空風格的本機／NAS 私人音樂庫播放器；不含帳號、雲端 AI、
  廣告或第三方追蹤。
- App icon：`Assets.xcassets/AppIcon.appiconset`，1024px 與 512px、RGB、無 Alpha；
  由 `Native/scripts/qualify-app-store.sh` 與兩平台 Release build 驗證。
- 開源依賴：Apple 第一方框架；Rust 核心只使用標準函式庫。送審前仍須由發布者
  重新確認產物中的第三方 notices。

## 必須由發布者補入 App Store Connect 的資料

以下資料涉及帳號、網址或法律責任，不能由本機程式碼推定；在填妥並核准前保持
`AERO-V3`／`AERO-R3` 未完成：

1. Privacy Policy URL：`https://github.com/Gale0418/Celestial-Music-Vault/blob/main/PRIVACY.md`。
2. Support URL：`https://github.com/Gale0418/Celestial-Music-Vault/blob/main/SUPPORT.md`；公開客服 `coderb0418@gmail.com`，沿用使用者指定的 G.A.I／MediBuddy 公開支援資料。這兩個 URL 必須在 repository 公開後以未登入連線回讀 HTTP 200，才能填入商店。
3. 繁中／英文／日文 App subtitle、description、keywords、promotional text 與 screenshots。
4. 年齡分級、版權聲明、出口合規與 App Review notes。
5. 內建或測試節目級音訊、字體、插圖與產生式圖示的授權／來源紀錄，以及完整
   `LICENSE`／`NOTICE` 清單。

## 本次發行語言與素材規則

- 收費方向為免費下載＋一次性 Pro；方案與待審文案統一見
  [MONETIZATION_DRAFT.md](MONETIZATION_DRAFT.md)，由 AERO-MON29／AERO-MON30 追蹤。
- 文案以既定功能全部完成為上市情境，並非目前 build 的功能證據。正式上傳時
  須逐項對照凍結 RC、實際 Pro 商品與權益；不因草案使用現在式就跳過 AERO-SD4
  等驗收，亦不把只有「評估」任務的功能視為確定上市內容。
- 價格、跨平台購買權益、家庭共享與未來版本涵蓋範圍未定案前，不寫入確定承諾；
  素材不得將本機播放器描述成包含音樂內容的串流訂閱服務。

- App 介面已有 `en`／`zh-Hant`／`ja` 三語；裝置偏好為簡中時顯示繁中，其他未支援
  語言回退英文。三語 string catalog、Mac／iPad Simulator Debug 建置與模擬器主畫面
  已驗，但設定頁點選、實機與完整語言 QA 仍待驗。不得把 App 內翻譯完成當成商店
  頁已建立或送審通過；各語商店文案、截圖、權利素材與 Review Notes 由 AERO-MD4
  分別補齊並核對凍結 RC。
- Mac 與 iPad 截圖必須來自同一個已凍結 RC，不得混用歷史 `com.aeromusic.native`
  build、`/tmp` 臨時截圖或不同主題狀態。
- 截圖／預覽影片只能使用自有或明確授權的音訊、影片與封面；不得出現商業專輯
  封面、YouTube／串流服務畫面或權利不明的 VTuber 影片。
- Review Notes、無剪輯實機影片與測試矩陣集中在
  `Native/APP_STORE_REVIEW_KIT.md`；權利證據集中在
  `Native/ASSET_RIGHTS_LEDGER.md`。

## App Privacy 對照

程式會在裝置本機保存使用者授權資料夾的 security-scoped bookmark、相對路徑／
檔案識別、媒體 metadata／封面、歌單、最愛、評分、播放／跳歌紀錄、BPM／調性／
響度分析、主題偏好與離線快取。這些資料不傳給開發者或第三方，因此 App Store
問卷可選「不收集」，但公開隱私政策仍須清楚說明本機處理、刪除方式與 NAS 連線
模型。CMV 不做 SMB 登入、LAN 掃描、雲端同步、廣告、追蹤或第三方分析。

## 驗收方式

- 由發布者在 App Store Connect 填入資料後，將實際 URL、問卷截圖或匯出紀錄存入
  受控的發布檔案庫；本工作區只記錄 gate 結果，不保存敏感憑證。
- 用正式 Apple Distribution archive 執行 upload validation，再以 TestFlight
  測試同一版 metadata 與隱私問卷；完成後才可關閉 `AERO-V3` 並啟動 `AERO-R3`。
