# AeroMusic 2.0｜App Store Connect metadata gate

更新：2026-08-27

這份文件是送審前的 metadata 與授權資料單一清單。它不把本機建置或
模擬器測試當成 Apple 審核資料，也不在工作區保存 Apple ID、憑證或 NAS 帳密。

## 已可由專案固定的內容

- App 名稱：`AeroMusic`
- 版本：`2.0`（build `1`）
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

1. Privacy Policy URL（公開可存取的隱私權政策）。
2. Support URL（公開可存取的支援頁面與聯絡方式）。
3. 繁中／英文 App subtitle、description、keywords、promotional text 與 screenshots。
4. 年齡分級、版權聲明、出口合規與 App Review notes。
5. 內建或測試節目級音訊、字體、插圖與產生式圖示的授權／來源紀錄，以及完整
   `LICENSE`／`NOTICE` 清單。

## 驗收方式

- 由發布者在 App Store Connect 填入資料後，將實際 URL、問卷截圖或匯出紀錄存入
  受控的發布檔案庫；本工作區只記錄 gate 結果，不保存敏感憑證。
- 用正式 Apple Distribution archive 執行 upload validation，再以 TestFlight
  測試同一版 metadata 與隱私問卷；完成後才可關閉 `AERO-V3` 並啟動 `AERO-R3`。
