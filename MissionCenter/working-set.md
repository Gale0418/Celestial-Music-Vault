<!-- Generated materialized view. Do not edit directly; rebuild from canonical MissionCenter files. -->
<!-- mission-center-derived schema=1.0 fingerprint-format=sha256-v2-lf source-fingerprint=94486dffe130ced0ab7055c1c9b63856fe89c5898d9b8619d02ef3fc62bc2187 -->
# 當前工作集

- 唯一真實來源: `tasks.md`
- 可執行項目數: 6

| ID | 標題 | 優先級 | 狀態 | 下一步 | 依賴 | 驗證方式 | 阻塞原因 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AERO-MON30 | 完成一次性 Pro 商品、功能解鎖與購買驗收 | P0 | In Progress | 純 pending listener acceptance 仍 FAIL：active entitlement 1、updates0、hasProfalse；detached 實驗無改善已撤回，refresh 診斷 PASS 不能取代 acceptance；接續可控外部事件／SDK配置診斷與真實 Sandbox，商品準備證據保留 | AERO-MON29 | 免費日常播放無退步；成功、取消、待處理、失敗、退款／撤銷、恢復與已購離線啟動皆有證據；兩平台商品、文案與 RC 一致 |  |
| AERO-E3 | AeroMusic 2.0 SwiftUI＋Rust 原生重建 | P0 | In Progress | c42375f 正式三席盲評＋獨立仲裁為 blocked；已補 Mac 完整還原 AX 與 exact Distribution qualification 收據，接續 StoreKit pending 根因／Sandbox 與完整同版 coverage，未收斂前不進 TestFlight | AERO-E2 | macOS 15+ 與 iPadOS 18+ 通過完整驗收並可送審 |  |
| AERO-V3 | 效能、故障、實機、隱私與 App Store 驗證 | P0 | In Progress | 🦀 本輪核心回歸通過，StoreKit pending 與完整實機矩陣仍未完成；依 `Native/APP_STORE_GATE.md` 補授權節目 reference material、實機／沙盒／隱私驗證、送審 metadata 與 Distribution archive，完成後進入 AERO-R3 TestFlight | AERO-A3, AERO-C3, AERO-U3 | 自動測試、實機矩陣、隱私與沙盒檢查通過；最終 critic findings 全數 disposition |  |
| AERO-R3 | TestFlight、App Store 送審與 Electron 安全退場 | P0 | In Progress | 先執行 AERO-AC4 唯讀盤點；同步等候 AERO-RC4 的程式品質依賴完成 | AERO-V3 | iPadOS／macOS 分平台完成簽章、實機、Metadata、TestFlight、strict submission health 與送審；原生版核准穩定且退場清單再獲核准 |  |
| AERO-RC4 | 鎖定 CMV 2.0 Release Candidate 基準 | P0 | Blocked | 完成所有 Review／In Progress 發行阻擋任務及 Pro 購買驗收，重跑 Swift、Rust、FFI、Mac、iPad 與本機 App Store gates | AERO-M6, AERO-U24, AERO-F25, AERO-F26, AERO-F27, AERO-SD4, AERO-Q12, AERO-I13, AERO-X14, AERO-MON30, AERO-U25 | 無未知 P0／P1；工作樹、提交、測試、雙平台建置與 qualification 證據能唯一對應 | 目前受未結清程式、體驗審查與 Smart DJ 可操作性阻擋；不得把 Debug／Simulator 成功誤稱為 Distribution ready。2026-09-08 依核准商業方向加入 MON30，並依使用者「任務功能完成才上架」要求納入 Q12／I13／X14；X14 的評估結論不必然新增功能，文案須依最終範圍核對。 |
| AERO-SD4 | 補齊 Smart DJ 與聲學分析可操作入口 | P0 | In Progress | 已新增歌單／設定 Smart DJ 入口、候選限制、推薦理由、播放／入列；現在收聽可對音訊啟動／取消本機分析。接續使用者現有曲庫播放、Airplane Mode、VoiceOver 與日常操作體感驗收；50k 留作壓力回歸 | AERO-F25, AERO-F26, AERO-F27 | Mac／iPad 可在飛航／離線狀態實際建立並播放 Smart DJ queue；未分析曲目不阻塞播放；VoiceOver、Reduce Motion 與現有曲庫回歸通過；50k 壓測不取代日常體感 |  |
