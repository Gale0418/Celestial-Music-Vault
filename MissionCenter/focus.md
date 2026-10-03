<!-- Generated materialized view. Do not edit directly; rebuild from canonical MissionCenter files. -->
<!-- Deprecated compatibility view: focus.md is generated from tasks.md only and must never be edited or treated as a second lifecycle source. -->
<!-- mission-center-derived schema=1.0 fingerprint-format=sha256-v2-lf source-fingerprint=94486dffe130ced0ab7055c1c9b63856fe89c5898d9b8619d02ef3fc62bc2187 -->
# P0 焦點

- 唯一真實來源: `tasks.md`
- 未完成 P0: 17

| ID | 標題 | 狀態 | 下一步 | 依賴 | 驗證方式 |
| --- | --- | --- | --- | --- | --- |
| AERO-MON30 | 完成一次性 Pro 商品、功能解鎖與購買驗收 | In Progress | 純 pending listener acceptance 仍 FAIL：active entitlement 1、updates0、hasProfalse；detached 實驗無改善已撤回，refresh 診斷 PASS 不能取代 acceptance；接續可控外部事件／SDK配置診斷與真實 Sandbox，商品準備證據保留 | AERO-MON29 | 免費日常播放無退步；成功、取消、待處理、失敗、退款／撤銷、恢復與已購離線啟動皆有證據；兩平台商品、文案與 RC 一致 |
| AERO-E3 | AeroMusic 2.0 SwiftUI＋Rust 原生重建 | In Progress | c42375f 正式三席盲評＋獨立仲裁為 blocked；已補 Mac 完整還原 AX 與 exact Distribution qualification 收據，接續 StoreKit pending 根因／Sandbox 與完整同版 coverage，未收斂前不進 TestFlight | AERO-E2 | macOS 15+ 與 iPadOS 18+ 通過完整驗收並可送審 |
| AERO-V3 | 效能、故障、實機、隱私與 App Store 驗證 | In Progress | 🦀 本輪核心回歸通過，StoreKit pending 與完整實機矩陣仍未完成；依 `Native/APP_STORE_GATE.md` 補授權節目 reference material、實機／沙盒／隱私驗證、送審 metadata 與 Distribution archive，完成後進入 AERO-R3 TestFlight | AERO-A3, AERO-C3, AERO-U3 | 自動測試、實機矩陣、隱私與沙盒檢查通過；最終 critic findings 全數 disposition |
| AERO-R3 | TestFlight、App Store 送審與 Electron 安全退場 | In Progress | 先執行 AERO-AC4 唯讀盤點；同步等候 AERO-RC4 的程式品質依賴完成 | AERO-V3 | iPadOS／macOS 分平台完成簽章、實機、Metadata、TestFlight、strict submission health 與送審；原生版核准穩定且退場清單再獲核准 |
| AERO-RC4 | 鎖定 CMV 2.0 Release Candidate 基準 | Blocked | 完成所有 Review／In Progress 發行阻擋任務及 Pro 購買驗收，重跑 Swift、Rust、FFI、Mac、iPad 與本機 App Store gates | AERO-M6, AERO-U24, AERO-F25, AERO-F26, AERO-F27, AERO-SD4, AERO-Q12, AERO-I13, AERO-X14, AERO-MON30, AERO-U25 | 無未知 P0／P1；工作樹、提交、測試、雙平台建置與 qualification 證據能唯一對應 |
| AERO-SD4 | 補齊 Smart DJ 與聲學分析可操作入口 | In Progress | 已新增歌單／設定 Smart DJ 入口、候選限制、推薦理由、播放／入列；現在收聽可對音訊啟動／取消本機分析。接續使用者現有曲庫播放、Airplane Mode、VoiceOver 與日常操作體感驗收；50k 留作壓力回歸 | AERO-F25, AERO-F26, AERO-F27 | Mac／iPad 可在飛航／離線狀態實際建立並播放 Smart DJ queue；未分析曲目不阻塞播放；VoiceOver、Reduce Motion 與現有曲庫回歸通過；50k 壓測不取代日常體感 |
| AERO-SG4 | 雙平台簽章、Capabilities 與沙盒資格 | Backlog | 以 asc／Xcode 盤點並建立最小必要 Distribution 資產，核對 macOS Sandbox、bookmark、background audio 與 iPad capabilities | AERO-AC4, AERO-RC4 | iPadOS／macOS archive 使用正確 Team、Distribution identity、profiles 與 entitlements；strict codesign 通過 |
| AERO-DV4 | Mac／iPad 實機、NAS 與故障矩陣驗收 | Backlog | 執行 macOS 與 iPadOS 實機測試：來源授權、重啟恢復、stale／撤銷、NAS 睡眠、背景播放、PiP、Split View、記憶體壓力 | AERO-SG4 | `Native/APP_STORE_GATE.md` 實機項目具日期、裝置、OS、觀察與 Pass／Fail；失敗不清庫、不凍結 UI |
| AERO-MD4 | 商店 Metadata、隱私、截圖、Review Kit 與審核素材 | In Progress | 建立 canonical metadata，補齊 zh-Hant／en-US／ja-JP 商店文案及雙平台對應截圖、Support／Privacy URL、年齡分級、權利聲明、實機無剪輯示範影片與 Review Notes | AERO-AC4, AERO-RC4 | App Store Connect 所有必填欄位可由版本化資料重現；Privacy manifest／問卷一致；展示音樂、封面與影片授權可追溯 |
| AERO-BD4 | 產生並上傳 iPadOS／macOS Release Build | Backlog | 先解析遠端安全 build number，分平台 archive／export／qualification；上傳前保存 dry-run 與 artifact 身分 | AERO-SG4, AERO-DV4, AERO-MD4 | IPA／PKG 與提交 SHA、版本、build number、架構、簽章、dSYM 唯一對應；App Store Connect 處理狀態為 VALID |
| AERO-TF4 | iPadOS＋macOS TestFlight 封閉測試 | Backlog | 建立／確認封閉測試群組、What to Test、分平台分發與回饋矩陣 | AERO-BD4 | 兩平台指定 build 均完成封閉測試；核心 NAS／播放／影片／離線路徑無 P0／P1 |
| AERO-SH4 | 雙平台 Submission Health 與送審預演 | Backlog | 對 IOS／MAC_OS 執行 strict validate、review doctor、build／version／privacy／availability 核對並修復可證實阻擋項 | AERO-TF4 | 兩平台無 blocking issue；warnings、Manual／Web-session 項目與剩餘風險完整 disposition |
| AERO-SB4 | App Store 分平台正式送審 | Backlog | 先對準確 App／Version／Build 執行 `--dry-run`；呈現 plan 後取得主人再次明確核准才可 `--confirm` | AERO-SH4 | 保存 app、platform、version、build、submission ID 與所有已確認 mutation；狀態進入 Waiting for Review／In Review |
| AERO-RV4 | 審核監控、問題回覆與核准觀察 | Backlog | 監控分平台狀態與 App Review 訊息；只依具體拒絕證據建立修復任務 | AERO-SB4 | 審核結果、訊息、修復、重新驗證與重送決策可追溯；核准後完成穩定觀察 |
| AERO-U24 | CMV 目前工作樹端到端可靠性複查 | Review | 2026-10-04 頁面樣式／locale／取消與佇列修復已交付；Mac 八主頁七子頁、iPad 最後版橫直向歌單／左右欄／44-point 觸控區已焦點驗證；Core 84/0；保留 Pro listener FAIL、NAS／無障礙／Sandbox／同候選 Distribution 及獨立 delta 缺口，不作 Done | AERO-U23, AERO-M6 | 所有 finding 具檔案行號、觸發條件與最小驗證；Swift／Rust 與雙平台 build 結果如實記錄；P0/P1 皆有後續 task disposition |
| AERO-F25 | 修正五萬首搜尋與目錄的全量重建瓶頸 | Review | 背景 trackCount 與共用縮圖 cache 已實作，cache 3 項 hosted 通過；固定像素與 actor 串行解碼，未量測 50k／NAS 150ms 或 memory 峰值；保留原壓力驗收 | AERO-U24 | 50k 連續輸入可在 150 ms 內更新；最佳結果不因第 501 筆以後而遺漏；目錄載入不呈 O(n²) |
| AERO-F26 | 消除影片 EOF 競態與慢速來源播放卡頓 | Review | 本輪修 future prepare failure 遺留 base queue、來源探測取消，Core 回歸通過；Mac／iPad 覆蓋候選有限UI驗證；慢 NAS／mixed media／meter 同候選完整驗收待補 | AERO-U24 | EOF 前快速切歌不跳過新曲；慢 NAS 準備期間 UI 可操作；月環只顯示真實 PCM 能量且不因節流降至約 11 Hz；音訊 lease 於結束及清除後歸零 |
