<!-- Generated materialized view. Do not edit directly; rebuild from canonical MissionCenter files. -->
<!-- Deprecated compatibility view: focus.md is generated from tasks.md only and must never be edited or treated as a second lifecycle source. -->
<!-- mission-center-derived schema=1.0 fingerprint-format=sha256-v2-lf source-fingerprint=938f134d724ec307d7499d34ff7770dcb314f9209451715efdf2fb08a1143d3b -->
# P0 焦點

- 唯一真實來源: `tasks.md`
- 未完成 P0: 6

| ID | 標題 | 狀態 | 下一步 | 依賴 | 驗證方式 |
| --- | --- | --- | --- | --- | --- |
| AERO-E3 | AeroMusic 2.0 SwiftUI＋Rust 原生重建 | In Progress | 🦀 critic_full PASS；本機 universal Development archive 已驗證；完成實機／沙盒／授權素材與 Distribution archive qualification 後進入 AERO-R3 TestFlight | AERO-E2 | macOS 15+ 與 iPadOS 18+ 通過完整驗收並可送審 |
| AERO-V3 | 效能、故障、實機、隱私與 App Store 驗證 | In Progress | 🦀 本機與 Simulator 回歸全綠；universal Development archive 與 codesign gate 已通過；依 `Native/APP_STORE_GATE.md` 補授權節目 reference material、實機／沙盒／隱私驗證、送審 metadata 與 Distribution archive，完成後進入 AERO-R3 TestFlight | AERO-A3, AERO-C3, AERO-U3 | 自動測試、實機矩陣、隱私與沙盒檢查通過；最終 critic findings 全數 disposition |
| AERO-R3 | TestFlight、送審與 Electron 安全退場 | Backlog | 封閉測試通過後送審 | AERO-V3 | 原生版穩定且退場清單獲核准 |
| AERO-U24 | CMV 目前工作樹端到端可靠性複查 | Review | 稽核報告已完成；等待確認後依序執行 AERO-F25、AERO-F26、AERO-F27，修正前不得把目前工作樹視為最終發行候選 | AERO-U23, AERO-M6 | 所有 finding 具檔案行號、觸發條件與最小驗證；Swift／Rust 與雙平台 build 結果如實記錄；P0/P1 皆有後續 task disposition |
| AERO-F25 | 修正五萬首搜尋與目錄的全量重建瓶頸 | Review | 讓搜尋索引跨查詢重用、移除 500 候選截斷，並將歌手／專輯分組改為增量或資料庫聚合 | AERO-U24 | 50k 連續輸入可在 150 ms 內更新；最佳結果不因第 501 筆以後而遺漏；目錄載入不呈 O(n²) |
| AERO-F26 | 消除影片 EOF 競態與慢速來源播放卡頓 | Review | 進行雙平台與慢速來源／快速切歌回歸，確認 generation guard、observer teardown 與 lease 平衡 | AERO-U24 | EOF 前快速切歌不跳過新曲；慢 NAS 準備期間 UI 可操作；音訊 lease 於結束及清除後歸零 |
