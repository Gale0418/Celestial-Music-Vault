<!-- Generated materialized view. Do not edit directly; rebuild from canonical MissionCenter files. -->
<!-- mission-center-derived schema=1.0 fingerprint-format=sha256-v2-lf source-fingerprint=586dbab585af50de384676688adf68217292246e3d98bb389364aa2836c85524 -->
# 當前工作集

- 唯一真實來源: `tasks.md`
- 可執行項目數: 3

| ID | 標題 | 優先級 | 狀態 | 下一步 | 依賴 | 驗證方式 | 阻塞原因 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AERO-E3 | AeroMusic 2.0 SwiftUI＋Rust 原生重建 | P0 | In Progress | 🦀 critic_full PASS；本機 universal Development archive 已驗證；完成實機／沙盒／授權素材與 Distribution archive qualification 後進入 AERO-R3 TestFlight | AERO-E2 | macOS 15+ 與 iPadOS 18+ 通過完整驗收並可送審 |  |
| AERO-M6 | 補齊原生歌曲選取、批次操作與右鍵選單 | P1 | In Progress | 驗證批次工具列在播放器／窄幅 safe area 仍可見，完成全曲庫排序與穩定隨機排列的實機回歸 | AERO-M3,AERO-F6 | 選取後播放、加入歌單、取消、移出 CMV均在選取列附近直接可見；窄幅 iPad 不隱藏核心動作；歌名／藝術家／專輯／修改時間可升降冪排序；隨機排列跨分頁維持同一順序 |  |
| AERO-V3 | 效能、故障、實機、隱私與 App Store 驗證 | P0 | In Progress | 🦀 本機與 Simulator 回歸全綠；universal Development archive 與 codesign gate 已通過；依 `Native/APP_STORE_GATE.md` 補授權節目 reference material、實機／沙盒／隱私驗證、送審 metadata 與 Distribution archive，完成後進入 AERO-R3 TestFlight | AERO-A3,AERO-C3,AERO-U3 | 自動測試、實機矩陣、隱私與沙盒檢查通過；最終 critic findings 全數 disposition |  |

## 下一步候選

- AERO-R3 — TestFlight、送審與 Electron 安全退場
- AERO-I13 — 補齊進階曲庫欄位、歌曲資訊與歌單內容管理
- 以上僅為候選，開始前仍須在 `tasks.md` 升格為 Ready。
