<!-- Generated materialized view. Do not edit directly; rebuild from canonical MissionCenter files. -->
<!-- mission-center-derived schema=1.0 fingerprint-format=sha256-v2-lf source-fingerprint=646b37e349adee700f1c0d3d23ef4f136c53f32f0096eb30da0eb0ce1ba96ac8 -->
# 當前工作集

- 唯一真實來源: `tasks.md`
- 可執行項目數: 3

| ID | 標題 | 優先級 | 狀態 | 下一步 | 依賴 | 驗證方式 | 阻塞原因 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AERO-E3 | AeroMusic 2.0 SwiftUI＋Rust 原生重建 | P0 | In Progress | 🦀 critic_full PASS；本機 universal Development archive 已驗證；完成實機／沙盒／授權素材與 Distribution archive qualification 後進入 AERO-R3 TestFlight | AERO-E2 | macOS 15+ 與 iPadOS 18+ 通過完整驗收並可送審 |  |
| AERO-M6 | 補齊原生歌曲選取、批次操作與右鍵選單 | P1 | In Progress | 在不重啟目前影音的前提下補齊「設為下一首／加入目前佇列」，再建立歌單內容頁供單曲移除 | AERO-M3,AERO-F6 | 全選涵蓋目前搜尋結果而非只選可見分頁；批次移出保留實體檔案、從歌單清除且重新索引不復活；macOS 右鍵與 `⋯` 共用操作模型；混合影音 queue 的插入不得重啟目前曲目或破壞 gapless |  |
| AERO-V3 | 效能、故障、實機、隱私與 App Store 驗證 | P0 | In Progress | 🦀 本機與 Simulator 回歸全綠；universal Development archive 與 codesign gate 已通過；依 `Native/APP_STORE_GATE.md` 補授權節目 reference material、實機／沙盒／隱私驗證、送審 metadata 與 Distribution archive，完成後進入 AERO-R3 TestFlight | AERO-A3,AERO-C3,AERO-U3 | 自動測試、實機矩陣、隱私與沙盒檢查通過；最終 critic findings 全數 disposition |  |

## 下一步候選

- AERO-R3 — TestFlight、送審與 Electron 安全退場
- 以上僅為候選，開始前仍須在 `tasks.md` 升格為 Ready。
