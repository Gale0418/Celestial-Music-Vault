<!-- Generated materialized view. Do not edit directly; rebuild from canonical MissionCenter files. -->
<!-- Deprecated compatibility view: focus.md is generated from tasks.md only and must never be edited or treated as a second lifecycle source. -->
<!-- mission-center-derived schema=1.0 fingerprint-format=sha256-v2-lf source-fingerprint=77b15c24986c9267b49ef0e6de3d4936e9f8df1605f29d557c8900e80b6a21c3 -->
# P0 焦點

- 唯一真實來源: `tasks.md`
- 未完成 P0: 17

| ID | 標題 | 狀態 | 下一步 | 依賴 | 驗證方式 |
| --- | --- | --- | --- | --- | --- |
| AERO-E3 | AeroMusic 2.0 SwiftUI＋Rust 原生重建 | In Progress | 🦀 critic_full PASS；本機 universal Development archive 已驗證；完成實機／沙盒／授權素材與 Distribution archive qualification 後進入 AERO-R3 TestFlight | AERO-E2 | macOS 15+ 與 iPadOS 18+ 通過完整驗收並可送審 |
| AERO-V3 | 效能、故障、實機、隱私與 App Store 驗證 | In Progress | 🦀 目前工作樹的本機與 Simulator 回歸全綠；依 `Native/APP_STORE_GATE.md` 補授權節目 reference material、實機／沙盒／隱私驗證、送審 metadata 與 Distribution archive，完成後進入 AERO-R3 TestFlight | AERO-A3,AERO-C3,AERO-U3 | 自動測試、實機矩陣、隱私與沙盒檢查通過；最終 critic findings 全數 disposition |
| AERO-R3 | TestFlight、App Store 送審與 Electron 安全退場 | In Progress | 先執行 AERO-AC4 唯讀盤點；同步等候 AERO-RC4 的程式品質依賴完成 | AERO-V3 | iPadOS／macOS 分平台完成簽章、實機、Metadata、TestFlight、strict submission health 與送審；原生版核准穩定且退場清單再獲核准 |
| AERO-AC4 | Apple 帳號、合約與 App Record 唯讀盤點 | Blocked | 發布者以 CMV 有權限的 App Store Connect API profile 執行 `asc auth login`；登入後只讀確認 Team／角色、協議、`com.windsheep.cmv` App Record 與 IOS／MAC_OS lane |  | 產出 Ready／Blocked／Manual 盤點；所有來源可追溯且 Git／Mission Center 無 Apple ID、P8、密碼或憑證內容 |
| AERO-RC4 | 鎖定 CMV 2.0 Release Candidate 基準 | Blocked | 完成所有 Review／In Progress 發行阻擋任務，重跑 Swift、Rust、FFI、Mac、iPad 與本機 App Store gates | AERO-M6,AERO-U24,AERO-F25,AERO-F26,AERO-F27,AERO-SD4 | 無未知 P0／P1；工作樹、提交、測試、雙平台建置與 qualification 證據能唯一對應 |
| AERO-SD4 | 補齊 Smart DJ 與聲學分析可操作入口 | Backlog | 在曲庫／現在收聽提供可發現的本機分析與 Smart DJ 操作；背景排程可取消，顯示進度、失敗復原與每首選歌理由 | AERO-F25,AERO-F26,AERO-F27 | Mac／iPad 可在飛航／離線狀態實際建立並播放 Smart DJ queue；未分析曲目不阻塞播放；VoiceOver、Reduce Motion 與 50k 曲庫回歸通過 |
| AERO-SG4 | 雙平台簽章、Capabilities 與沙盒資格 | Backlog | 以 asc／Xcode 盤點並建立最小必要 Distribution 資產，核對 macOS Sandbox、bookmark、background audio 與 iPad capabilities | AERO-AC4,AERO-RC4 | iPadOS／macOS archive 使用正確 Team、Distribution identity、profiles 與 entitlements；strict codesign 通過 |
| AERO-DV4 | Mac／iPad 實機、NAS 與故障矩陣驗收 | Backlog | 執行 macOS 與 iPadOS 實機測試：來源授權、重啟恢復、stale／撤銷、NAS 睡眠、背景播放、PiP、Split View、記憶體壓力 | AERO-SG4 | `Native/APP_STORE_GATE.md` 實機項目具日期、裝置、OS、觀察與 Pass／Fail；失敗不清庫、不凍結 UI |
| AERO-MD4 | 商店 Metadata、隱私、截圖、Review Kit 與審核素材 | Backlog | 建立 canonical metadata，補齊 zh-Hant 主文案、Support／Privacy URL、年齡分級、權利聲明、雙平台截圖、實機無剪輯示範影片與 Review Notes | AERO-AC4,AERO-RC4 | App Store Connect 所有必填欄位可由版本化資料重現；Privacy manifest／問卷一致；展示音樂、封面與影片授權可追溯 |
| AERO-BD4 | 產生並上傳 iPadOS／macOS Release Build | Backlog | 先解析遠端安全 build number，分平台 archive／export／qualification；上傳前保存 dry-run 與 artifact 身分 | AERO-SG4,AERO-DV4,AERO-MD4 | IPA／PKG 與提交 SHA、版本、build number、架構、簽章、dSYM 唯一對應；App Store Connect 處理狀態為 VALID |
| AERO-TF4 | iPadOS＋macOS TestFlight 封閉測試 | Backlog | 建立／確認封閉測試群組、What to Test、分平台分發與回饋矩陣 | AERO-BD4 | 兩平台指定 build 均完成封閉測試；核心 NAS／播放／影片／離線路徑無 P0／P1 |
| AERO-SH4 | 雙平台 Submission Health 與送審預演 | Backlog | 對 IOS／MAC_OS 執行 strict validate、review doctor、build／version／privacy／availability 核對並修復可證實阻擋項 | AERO-TF4 | 兩平台無 blocking issue；warnings、Manual／Web-session 項目與剩餘風險完整 disposition |
| AERO-SB4 | App Store 分平台正式送審 | Backlog | 先對準確 App／Version／Build 執行 `--dry-run`；呈現 plan 後取得主人再次明確核准才可 `--confirm` | AERO-SH4 | 保存 app、platform、version、build、submission ID 與所有已確認 mutation；狀態進入 Waiting for Review／In Review |
| AERO-RV4 | 審核監控、問題回覆與核准觀察 | Backlog | 監控分平台狀態與 App Review 訊息；只依具體拒絕證據建立修復任務 | AERO-SB4 | 審核結果、訊息、修復、重新驗證與重送決策可追溯；核准後完成穩定觀察 |
| AERO-U24 | CMV 目前工作樹端到端可靠性複查 | Review | 稽核報告已完成；等待確認後依序執行 AERO-F25、AERO-F26、AERO-F27，修正前不得把目前工作樹視為最終發行候選 | AERO-U23,AERO-M6 | 所有 finding 具檔案行號、觸發條件與最小驗證；Swift／Rust 與雙平台 build 結果如實記錄；P0/P1 皆有後續 task disposition |
| AERO-F25 | 修正五萬首搜尋與目錄的全量重建瓶頸 | Review | 讓搜尋索引跨查詢重用、移除 500 候選截斷，並將歌手／專輯分組改為增量或資料庫聚合 | AERO-U24 | 50k 連續輸入可在 150 ms 內更新；最佳結果不因第 501 筆以後而遺漏；目錄載入不呈 O(n²) |
| AERO-F26 | 消除影片 EOF 競態與慢速來源播放卡頓 | Review | 以最新 macOS build 實播本機／NAS 音樂，確認月環能量連續、無進度弧，並觀察快速切歌與兩秒後智慧預取無可聽中斷 | AERO-U24 | EOF 前快速切歌不跳過新曲；慢 NAS 準備期間 UI 可操作；月環只顯示真實 PCM 能量且不因節流降至約 11 Hz；音訊 lease 於結束及清除後歸零 |
