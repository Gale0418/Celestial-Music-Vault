<!-- Generated materialized view. Do not edit directly; rebuild from canonical MissionCenter files. -->
<!-- mission-center-derived schema=1.0 fingerprint-format=sha256-v2-lf source-fingerprint=9d3b3024e42cf1b35986700bd7691b955d95b3df364db7d76b26c2a74564894a -->
# 當前工作集

- 唯一真實來源: `tasks.md`
- 可執行項目數: 2

| ID | 標題 | 優先級 | 狀態 | 下一步 | 依賴 | 驗證方式 | 阻塞原因 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AERO-E3 | AeroMusic 2.0 SwiftUI＋Rust 原生重建 | P0 | In Progress | 🦀 critic_full PASS；本機 universal Development archive 已驗證；完成實機／沙盒／授權素材與 Distribution archive qualification 後進入 AERO-R3 TestFlight | AERO-E2 | macOS 15+ 與 iPadOS 18+ 通過完整驗收並可送審 |  |
| AERO-V3 | 效能、故障、實機、隱私與 App Store 驗證 | P0 | In Progress | 🦀 本機與 Simulator 回歸全綠；universal Development archive 與 codesign gate 已通過；依 `Native/APP_STORE_GATE.md` 補授權節目 reference material、實機／沙盒／隱私驗證、送審 metadata 與 Distribution archive，完成後進入 AERO-R3 TestFlight | AERO-A3,AERO-C3,AERO-U3 | 自動測試、實機矩陣、隱私與沙盒檢查通過；最終 critic findings 全數 disposition |  |

## 下一步候選

- AERO-R3 — TestFlight、送審與 Electron 安全退場
- AERO-M6 — 補齊原生歌曲右鍵操作選單
- 以上僅為候選，開始前仍須在 `tasks.md` 升格為 Ready。
