<!-- Generated materialized view. Do not edit directly; rebuild from canonical MissionCenter files. -->
<!-- mission-center-derived schema=1.0 fingerprint-format=sha256-v2-lf source-fingerprint=77b15c24986c9267b49ef0e6de3d4936e9f8df1605f29d557c8900e80b6a21c3 -->
# 當前工作集

- 唯一真實來源: `tasks.md`
- 可執行項目數: 6

| ID | 標題 | 優先級 | 狀態 | 下一步 | 依賴 | 驗證方式 | 阻塞原因 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AERO-AC4 | Apple 帳號、合約與 App Record 唯讀盤點 | P0 | Blocked | 發布者以 CMV 有權限的 App Store Connect API profile 執行 `asc auth login`；登入後只讀確認 Team／角色、協議、`com.windsheep.cmv` App Record 與 IOS／MAC_OS lane |  | 產出 Ready／Blocked／Manual 盤點；所有來源可追溯且 Git／Mission Center 無 Apple ID、P8、密碼或憑證內容 | `asc 4.11.0` 可用但 2026-09-01 唯讀 `auth status` 顯示零 credentials，無法查 App Record／協議；MediBuddy 只採 2.1 流程經驗，未複製任何 key／Apple ID。Xcode 26.6、1 個 Development identity、Bundle ID `com.windsheep.cmv`、版本 2.0（1）已確認 |
| AERO-RC4 | 鎖定 CMV 2.0 Release Candidate 基準 | P0 | Blocked | 完成所有 Review／In Progress 發行阻擋任務，重跑 Swift、Rust、FFI、Mac、iPad 與本機 App Store gates | AERO-M6,AERO-U24,AERO-F25,AERO-F26,AERO-F27,AERO-SD4 | 無未知 P0／P1；工作樹、提交、測試、雙平台建置與 qualification 證據能唯一對應 | 目前受未結清程式、體驗審查與 Smart DJ 可操作性阻擋；不得把 Debug／Simulator 成功誤稱為 Distribution ready |
| AERO-E3 | AeroMusic 2.0 SwiftUI＋Rust 原生重建 | P0 | In Progress | 🦀 critic_full PASS；本機 universal Development archive 已驗證；完成實機／沙盒／授權素材與 Distribution archive qualification 後進入 AERO-R3 TestFlight | AERO-E2 | macOS 15+ 與 iPadOS 18+ 通過完整驗收並可送審 |  |
| AERO-M6 | 補齊原生歌曲選取、批次操作與右鍵選單 | P1 | In Progress | 驗證批次工具列在播放器／窄幅 safe area 仍可見，完成全曲庫排序與穩定隨機排列的實機回歸 | AERO-M3,AERO-F6 | 選取後播放、加入歌單、取消、移出 CMV均在選取列附近直接可見；窄幅 iPad 不隱藏核心動作；歌名／藝術家／專輯／修改時間可升降冪排序；隨機排列跨分頁維持同一順序 |  |
| AERO-V3 | 效能、故障、實機、隱私與 App Store 驗證 | P0 | In Progress | 🦀 目前工作樹的本機與 Simulator 回歸全綠；依 `Native/APP_STORE_GATE.md` 補授權節目 reference material、實機／沙盒／隱私驗證、送審 metadata 與 Distribution archive，完成後進入 AERO-R3 TestFlight | AERO-A3,AERO-C3,AERO-U3 | 自動測試、實機矩陣、隱私與沙盒檢查通過；最終 critic findings 全數 disposition |  |
| AERO-R3 | TestFlight、App Store 送審與 Electron 安全退場 | P0 | In Progress | 先執行 AERO-AC4 唯讀盤點；同步等候 AERO-RC4 的程式品質依賴完成 | AERO-V3 | iPadOS／macOS 分平台完成簽章、實機、Metadata、TestFlight、strict submission health 與送審；原生版核准穩定且退場清單再獲核准 |  |

## 下一步候選

- AERO-BD4 — 產生並上傳 iPadOS／macOS Release Build
- AERO-DV4 — Mac／iPad 實機、NAS 與故障矩陣驗收
- 以上僅為候選，開始前仍須在 `tasks.md` 升格為 Ready。
