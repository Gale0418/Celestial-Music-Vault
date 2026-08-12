# 任務

| ID | 標題 | 類型 | 父層 | 優先級 | 狀態 | 負責人 | 依賴 | 下一步 | 驗證方式 | 估時 | 標籤 | 備註 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| AERO-E1 | AeroMusic 穩定化、整理與 macOS 交付 | Epic |  | P0 | Done | Codex |  | 已完成 | App 與 DMG 可在桌面使用 | 8 | execution, verification | 採最小安全變更 |
| AERO-R1 | 盤點既有流程與官方現行做法 | Task | AERO-E1 | P0 | Done | Codex + Gemini |  | 保存決策與證據 | 本機稽核、Gemini 稽核與官方文件已比對 | 1 | intake, research | 使用者已授權採推薦方案 |
| AERO-T1 | 修正跨平台安全測試 | Task | AERO-E1 | P0 | Done | Codex | AERO-R1 | 已完成 | npm test 通過 | 1 | execution, verification |  |
| AERO-S1 | 以安全自訂協定取代 file:// 與 webSecurity:false | Task | AERO-E1 | P0 | Done | Codex | AERO-R1 | 已完成 | 協定單元測試與 Electron 煙霧測試通過 | 2 | execution, security | HTTPS 串流限 SoundHelix 白名單 |
| AERO-O1 | 整理建置資源與可重建輸出 | Task | AERO-E1 | P1 | Done | Codex | AERO-R1 | 已完成 | dist/dist-app 已移除且忽略；圖示已歸位 | 1 | execution | 三個 CRLF-only 差異已正規化為 LF |
| AERO-D1 | 更新 README 與既有打包文件 | Task | AERO-E1 | P1 | Done | Codex | AERO-T1,AERO-O1 | 已完成 | 文件命令可重複執行 | 1 | docs | 已記錄標準 SMB 重連位址 |
| AERO-V1 | 乾淨依賴、測試、Lint、建置與打包驗證 | Task | AERO-E1 | P0 | Done | Codex | AERO-T1,AERO-S1,AERO-O1,AERO-D1 | 已完成 | smoke tests 已記錄 | 2 | verification | `/tmp` 乾淨建置通過 |
| AERO-C1 | 交付 App/DMG 與收尾 | Task | AERO-E1 | P0 | Done | Codex | AERO-V1 | 已完成 | 桌面產物存在且 App 已啟動 | 1 | closeout | 舊 App 已移至垃圾桶備份 |
| AERO-E2 | AeroMusic 全面可靠性、效能與發行強化 | Epic |  | P0 | Done | Codex | AERO-E1 | 已完成 | 全部子任務具驗證證據且新版 App/DMG 可用 | 12 | execution, verification | 1.0.0 已完成本機簽章與桌面交付 |
| AERO-P2 | 原子存檔、備份復原與 NAS 離線資料保護 | Task | AERO-E2 | P0 | Done | Codex + Gemini |  | 已完成 | 損壞主檔可復原；離線歌曲不被抹除；重疊存檔序列化 | 3 | persistence, nas, security | Gemini 完成審查；Bridge 實作 lane 失敗後由 Codex 接手並驗證 |
| AERO-S2 | Electron 導航、IPC、單一實例與相依安全強化 | Task | AERO-E2 | P0 | Done | Codex | AERO-P2 | 已完成 | npm audit 無已知可修高危；安全測試通過 | 2 | electron, security | Electron 42.9、builder 26.15、Vite 8.2；audit 0 |
| AERO-F2 | 大型曲庫效能與可維護性改善 | Task | AERO-E2 | P1 | Done | Codex + Gemini | AERO-P2 | 已完成 | 進度更新不重算排序；大型資料基準通過 | 3 | performance, react, architecture | 20,000 首排序測試通過；零 Hook warning |
| AERO-T2 | 資料、播放與 UI 回歸測試擴充 | Task | AERO-E2 | P0 | Done | Codex | AERO-P2,AERO-S2,AERO-F2 | 已完成 | 自動測試、Chrome/Electron 煙霧與回歸矩陣全過 | 2 | qa, regression | Chrome UI、封裝 App 啟動與單例皆通過 |
| AERO-R2 | 離線體驗與 macOS 發行資訊整理 | Task | AERO-E2 | P1 | Done | Codex | AERO-S2,AERO-F2 | 已完成 | 斷網不破壞核心本機播放；發行 metadata 正確 | 1 | release, offline, ux | 1.0.0、Music 分類、本機字型與封面；未簽署限制保留 |
| AERO-V2 | 乾淨建置、稽核、打包與全方位對抗審查 | Task | AERO-E2 | P0 | Done | Codex + Gemini | AERO-T2,AERO-R2 | 已完成 | lint/test/audit/build/pack/互動驗證具可重複證據 | 1 | verification, release | Gemini FINAL_REVIEW_PASS；模擬專家無阻擋問題；本機 Apple Development 簽章通過 |
| AERO-C2 | 新版桌面交付與本輪結案 | Task | AERO-E2 | P0 | Done | Codex | AERO-V2 | 已完成 | 桌面成品可啟動、雜湊已記錄、工作區可重建 | 1 | closeout, delivery | 桌面 App/DMG 1.0.0 已啟動；舊版移至垃圾桶；基準 66ae6a1 |
