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
