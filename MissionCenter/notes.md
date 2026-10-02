# 筆記

## 研究紀錄

| 搜尋前構想 | 參考來源 | 採納內容 | 授權狀態 |
| --- | --- | --- | --- |
| 沿用既有 NAS 打包 SOP | `docs/PACKAGING_AND_OPTIMIZATION.md` 與 Git 歷史 | 保留本機暫存與 electron-builder cache 策略，修正過期資訊 | 專案自有內容 |
| 關閉 `webSecurity` 並改用自訂協定 | Electron Security / Protocol 官方文件 | 採 `protocol.handle`、secure/standard/stream scheme 與核准根目錄檢查 | 官方文件，可引用概念 |
| 整理 App 圖示 | electron-builder Icons 官方文件 | 使用預設 `build/icon.png`、`build/icon.icns` 結構 | 官方文件，可引用概念 |
| 避免破壞 NAS 依賴 | 本機 Vite 錯誤與既有 SOP | 在 `/tmp` 以 `npm ci` 乾淨重建 | 專案自有決策 |
| Electron 主進程安全強化 | [Electron Security](https://www.electronjs.org/docs/latest/tutorial/security) | 限制導覽、新視窗、驗證 IPC sender、更新支援版本 | 官方文件，可引用概念 |
| 防止多實例競爭 | [Electron app API](https://www.electronjs.org/docs/latest/api/app) | 使用 `app.requestSingleInstanceLock()` 並聚焦主要視窗 | 官方文件，可引用概念 |
| 大型清單轉換快取 | [React useMemo](https://react.dev/reference/react/useMemo) | 快取大型陣列轉換並避免新陣列造成 Effect 過度觸發 | 官方文件，可引用概念 |
| 獨立架構與風險審查 | Antigravity cascade `272654c8-130a-4a3f-acd5-0def63d2d1dd` | 直接覆寫 JSON、NAS 離線存在性過濾與全量列表重算列為主要風險 | 本機授權協作；含 1 次 SEARCH_WEB 軌跡 |
| 確認 Mission Center 使用版本 | 已安裝 `.codex-plugin/plugin.json`、插件快取路徑與 SKILL.md SHA-256 | 基礎版為 0.3.1；執行中腳本來自 `0.3.1+codex.9ed1bfeca60445639f45a35d424aa16e` | 本機已安裝插件；只讀核對 |
| 將 CMV 上架流程改為可重跑任務鏈 | [rorkai/app-store-connect-cli-skills](https://github.com/rorkai/app-store-connect-cli-skills) 與本機 `asc-*` skills | 採簽章、Xcode build、TestFlight、release flow、submission health 分離；所有提交先 dry-run，`--confirm` 另需核准 | MIT；GitHub 外掛唯讀核對 |
| 預防 Guideline 2.1 資訊不足退件 | MediBuddy 任務 `01a04b26-127b-7772-a00f-3a2733ac5f2f` 的 Build 10 補件紀錄 | CMV 新增 Review Kit：完整 Notes、無剪輯實機影片、裝置／OS／核心流程、無帳號／無付費／NAS 授權方式與素材權利；資訊問題不先重建 Build | 同機專案自有紀錄；只採流程經驗，不複製敏感值 |
| 反方檢查 App Store 漏項 | Antigravity cascade `65eb3c8b-224f-4dcd-a3f3-12f2c0d66619` | 採 Privacy Manifest、FFI panic boundary、dSYM、展示素材版權與狀態語意；拒絕其「內建 NAS 掃描／保存帳密」假設 | 本機授權協作；外部磁碟未掛載時基於既有摘要，具明確未知 |
| 右欄播放佇列卡頓來源 | Apple `Understanding and improving SwiftUI performance`、Observation 官方文件 | 高頻播放秒數不再直接驅動整個 queue panel；以 Observation 快照隔離高頻粗 revision，只有 queue 順序／可見 metadata／目前曲目真正改變才發布 UI 狀態 | Apple 官方文件；採概念與 API |
| 月環即時波形既成實作 | [GRimAce11/WaveformKit](https://github.com/GRimAce11/WaveformKit)、[dmrschmidt/DSWaveformImage](https://github.com/dmrschmidt/DSWaveformImage) | 採 bounded bar count、固定 cadence、Canvas／即時 samples 與分析／呈現分工概念；CMV 保留自有 AVAudioEngine meter，不新增第三方依賴或複製程式碼 | 公開 GitHub 專案；僅參考架構概念 |
| UI 動效與效能收斂 | [pbakaus/impeccable](https://github.com/pbakaus/impeccable) 的 audit／animate／optimize 規則 | 月環降回 80 段、移除逐段旋轉向量運算、修正 circular-buffer 時序並降低 queue backdrop blur；保留主視覺、刪掉無效 GPU 工作 | MIT；僅採規則與設計原則 |
| CMV Pro 買斷定價與跨平台權益 | [Doppler 台灣 App Store](https://apps.apple.com/tw/app/doppler-mp3-flac-player/id1468459747)、[Evermusic Pro 台灣 App Store](https://apps.apple.com/tw/app/evermusic-pro-%E9%9B%A2%E7%B7%9A%E9%9F%B3%E6%A8%82%E6%92%AD%E6%94%BE%E5%99%A8%E5%92%8C%E5%9D%87%E8%A1%A1%E5%99%A8%E9%9B%B2%E6%B5%81%E5%AA%92%E9%AB%94/id905746421)、[foobar2000 台灣 App Store](https://apps.apple.com/tw/app/foobar2000/id1072807669)、[Apple 跨平台購買](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms) | 2026-09-24 Apple API 已回讀：CMV 免費 App 台灣 TWD 0；同一 iPad／Mac 紀錄的 Pro non-consumable 商品台灣 TWD 290。商品尚 MISSING_METADATA，不代表 Sandbox 購買可用 | 競品價格為 2026-09-24 觀察，可能變動；僅學習定位，未複製內容或新增依賴 |
| CMV Pro Sandbox／審核邊界 | [Apple IAP 配置概述](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases)、[Apple IAP 審核資訊](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information)、[Apple Sandbox 故障排查](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox) | 同一 App 紀錄可共用單一 IAP；付費協議須有效，商店 metadata 在 Sandbox 可能延遲至 1 小時。審核截圖應清楚顯示 App 內實際提供的項目，不以空曲庫主畫面冒充。Sandbox 不等於已送審或上架 | 官方文件，僅引用規則；測試結果依本機與 Apple API 回讀另記 |

## 2026-09-27 土星 UI 排版回復

- 使用者指出月環／播放區是在土星背景改版後變動。Git 定位：`5fdbf0e` 為改版前基準；`74df366` 首次加入播放區 24 pt layout padding 與 cover parallax。
- 恢復前版量測、移除月環 cover parallax；依最新要求保留寬版右面板下移 24 pt、淡半透明歌曲／播放與詳情卡。流光限於指定 UI 背景，月環無流光。
- 原生 macOS 簽署必須使用 `Native/CMV/CMV/CMV.entitlements`。本次交付曾誤用 `build/entitlements.mac.plist`（Electron）而讀到非 sandbox 資料位置，已重新簽署並於原生畫面確認既有 1,964 首曲目。未遷移或刪除曲庫。
- 本輪局部 UI 完成不代表整個 Pro／StoreKit 發布任務完成。

## 2026-10-02 羊羊彩虹繪本主題

- 背景與整體 UI 改為明亮童話卡通：原創彩虹天空、粗描邊奶油雲朵、奶油紙卡、可可文字與圓體。依最新使用者回饋移除所有地面與固定羊，沿用既有羊流星。
- 僅 emeraldAurora 套用；保留月環與播放區既有位置。背景圖片獨立於動畫 clock，羊流星遵循 Reduce Motion／scenePhase，最高 20 fps。
- Mac arm64 Release 最終建置成功；原生 entitlements ad-hoc 簽章與 strict verify 通過。桌面 CMV.app 已更新，舊版備份於 <HOME_PATH>
- CodeRabbit 共 2 次（各不超過 9 個小型 Swift 檔，排除大圖）；首次已確認佇列遮擋問題並修正，末次 9 檔 0 findings。獨立 Luna source／資產審查沒有確定 P0–P2。
- 原生 UI 工具啟動失敗：failed to start Node runtime: No such file or directory。只確認圖片素材與原始碼，未宣稱整頁實機視覺驗收。
- 初版 iPad Simulator Debug 曾建置、安裝與啟動；最終小修未重跑 iOS。使用者最新指定先完成 Mac，iPad 交付延後。此次自建測試 simulator 已關閉刪除。
- 本輪主題修改不代表整個 Pro／StoreKit 發布任務完成。

## 最新美術修正：日式動畫

使用者於 2026-10-02 指定改為日式動畫風格。背景已重繪為清透藍天、暖白積雲、藍紫色賽璐璐明暗與乾淨輪廓；保留巨大彩虹、完全無地面與固定羊。UI 沿用奶油色與柔和梅紫控制，原有位置不變。這次僅替換點陣資產，不修改已審查的 Swift 邏輯。

素材：imagegen `exec-09e84234-e175-4427-a2e3-b0ea88346ae0.png`。提示摘要：Original Japanese anime sky background; luminous cyan-blue summer sky, warm ivory cumulus clouds, blue-gray linework, lavender cel-shaded shadows, clean smooth painting, huge pastel rainbow; no ground, horizon, vegetation, buildings, sheep, text or interface.
