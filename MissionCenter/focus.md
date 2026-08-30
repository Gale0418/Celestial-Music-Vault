<!-- Generated materialized view. Do not edit directly; rebuild from canonical MissionCenter files. -->
<!-- Deprecated compatibility view: focus.md is generated from tasks.md only and must never be edited or treated as a second lifecycle source. -->
<!-- mission-center-derived schema=1.0 fingerprint-format=sha256-v2-lf source-fingerprint=65fef6fcbaa18fbe316e5e3289d7291ad5c3be4631b7e0273b8b81d3f1247136 -->
# P0 焦點

- 唯一真實來源: `tasks.md`
- 未完成 P0: 4

| ID | 標題 | 狀態 | 下一步 | 依賴 | 驗證方式 |
| --- | --- | --- | --- | --- | --- |
| AERO-E3 | AeroMusic 2.0 SwiftUI＋Rust 原生重建 | In Progress | 🦀 critic_full PASS；本機 universal Development archive 已驗證；完成實機／沙盒／授權素材與 Distribution archive qualification 後進入 AERO-R3 TestFlight | AERO-E2 | macOS 15+ 與 iPadOS 18+ 通過完整驗收並可送審 |
| AERO-V3 | 效能、故障、實機、隱私與 App Store 驗證 | In Progress | 🦀 本機與 Simulator 回歸全綠；universal Development archive 與 codesign gate 已通過；依 `Native/APP_STORE_GATE.md` 補授權節目 reference material、實機／沙盒／隱私驗證、送審 metadata 與 Distribution archive，完成後進入 AERO-R3 TestFlight | AERO-A3, AERO-C3, AERO-U3 | 自動測試、實機矩陣、隱私與沙盒檢查通過；最終 critic findings 全數 disposition |
| AERO-R3 | TestFlight、送審與 Electron 安全退場 | Backlog | 封閉測試通過後送審 | AERO-V3 | 原生版穩定且退場清單獲核准 |
| AERO-G17 | CodeRabbit 審查最新面板並簽章交付桌面 main | Review | 本機審查、雙平台建置、簽章與桌面啟動皆通過；推送並複核 GitHub main 後結案 | AERO-U16 | CodeRabbit findings 全數 disposition；Mac／iPad build、strict codesign、entitlements、桌面啟動、GitHub main 與 Mission Center Doctor 通過 |
