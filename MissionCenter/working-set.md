<!-- Generated materialized view. Do not edit directly; rebuild from canonical MissionCenter files. -->
<!-- mission-center-derived schema=1.0 fingerprint-format=sha256-v2-lf source-fingerprint=3260f4dd6ed458be515eda3e731265557014e8e6b4a0639c389412fa0538c01d -->
# 當前工作集

- 唯一真實來源: `tasks.md`
- 可執行項目數: 6

| ID | 標題 | 優先級 | 狀態 | 下一步 | 依賴 | 驗證方式 | 阻塞原因 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AERO-MON30 | 完成一次性 Pro 商品、功能解鎖與購買驗收 | P0 | In Progress | StoreKit 2／升級頁／action gates 切片完成；2026-09-26 台灣價格改為 NT$150 並由 Apple API 回讀，App 免費，真實 iPad 升級頁審核截圖已上傳且商品 READY_TO_SUBMIT；批次離線、CMV 資料庫批次編輯、Smart DJ 操作及土星環軌站主題已實作；接續 StoreKit／Sandbox 矩陣、iPad 實機購買與素材 gate | AERO-MON29 | 免費日常播放無退步；成功、取消、待處理、失敗、退款／撤銷、恢復與已購離線啟動皆有證據；兩平台商品、文案與 RC 一致 |  |
| AERO-E3 | AeroMusic 2.0 SwiftUI＋Rust 原生重建 | P0 | In Progress | 🦀 critic_full PASS；本機 universal Development archive 已驗證；完成實機／沙盒／授權素材與 Distribution archive qualification 後進入 AERO-R3 TestFlight | AERO-E2 | macOS 15+ 與 iPadOS 18+ 通過完整驗收並可送審 |  |
| AERO-V3 | 效能、故障、實機、隱私與 App Store 驗證 | P0 | In Progress | 🦀 目前工作樹的本機與 Simulator 回歸全綠；依 `Native/APP_STORE_GATE.md` 補授權節目 reference material、實機／沙盒／隱私驗證、送審 metadata 與 Distribution archive，完成後進入 AERO-R3 TestFlight | AERO-A3, AERO-C3, AERO-U3 | 自動測試、實機矩陣、隱私與沙盒檢查通過；最終 critic findings 全數 disposition |  |
| AERO-R3 | TestFlight、App Store 送審與 Electron 安全退場 | P0 | In Progress | 先執行 AERO-AC4 唯讀盤點；同步等候 AERO-RC4 的程式品質依賴完成 | AERO-V3 | iPadOS／macOS 分平台完成簽章、實機、Metadata、TestFlight、strict submission health 與送審；原生版核准穩定且退場清單再獲核准 |  |
| AERO-AC4 | Apple 帳號、合約與 App Record 唯讀盤點 | P0 | In Progress | 2026-09-24 Apple API 已回讀 CMV App Record、iOS／macOS 2.0 lane 與帳號持有人單人角色；Chrome 商務頁顯示免費／付費協議有效、銀行與稅表已完成；待核對來源紀錄後轉 Review |  | 產出 Ready／Blocked／Manual 盤點；所有來源可追溯且 Git／Mission Center 無 Apple ID、P8、密碼或憑證內容 |  |
| AERO-RC4 | 鎖定 CMV 2.0 Release Candidate 基準 | P0 | Blocked | 完成所有 Review／In Progress 發行阻擋任務及 Pro 購買驗收，重跑 Swift、Rust、FFI、Mac、iPad 與本機 App Store gates | AERO-M6, AERO-U24, AERO-F25, AERO-F26, AERO-F27, AERO-SD4, AERO-Q12, AERO-I13, AERO-X14, AERO-MON30 | 無未知 P0／P1；工作樹、提交、測試、雙平台建置與 qualification 證據能唯一對應 | 目前受未結清程式、體驗審查與 Smart DJ 可操作性阻擋；不得把 Debug／Simulator 成功誤稱為 Distribution ready。2026-09-08 依核准商業方向加入 MON30，並依使用者「任務功能完成才上架」要求納入 Q12／I13／X14；X14 的評估結論不必然新增功能，文案須依最終範圍核對。 |
