# 決策

- 2026-08-12：採「保守維護」；修正可重現問題與明確安全風險，不進行 AudioContext 拆分、列表虛擬化或新增依賴。
- 2026-08-12：保留既有三個僅有換行格式差異的工作樹修改，不回復或覆寫。
- 2026-08-12：依 Electron 官方建議，以自訂安全協定取代 `file://` 與 `webSecurity: false`，且只允許已核准音樂根目錄。
- 2026-08-12：NAS 上的原生 Node binding 受 macOS 系統政策限制；驗證與打包改在 `/tmp` 乾淨副本進行，不刪除 NAS 上既有 `node_modules`。
- 2026-08-12：`dist/`、`dist-app/`、Mission Center HUD 輸出皆視為可重建產物並加入忽略規則；原始碼與任務紀錄保留。
- 2026-08-12：改良稽核採 `council_lite + decision`；先處理原子化存檔、單一實例與相依套件安全更新，再做大型曲庫效能與模組拆分，避免高風險一次性重構。
- 2026-08-12：第二輪採完整專家會議與 Studio 分波執行；P0 先阻止存檔損壞與 NAS 離線靜默刪除，再處理 Electron、安全依賴、React 效能、測試與發行。唱反調觀點被採納：不一次性重寫大型 Context，先用測試鎖定行為。
- 2026-08-12：MediBuddy 與鑰匙圈盤點只找到 Apple Development 憑證；AeroMusic 1.0.0 採本機開發簽章交付，明確不宣稱 Apple 公證。建置腳本已預留 Developer ID Application＋notarytool keychain profile 的正式 lane，敏感值不進 repository。
- 2026-08-12：electron-builder 產物的 ATS 預設會覆寫成允許任意連線；在簽章前以 `plutil` 強制關閉並 fail closed，再由 `codesign` 與 `hdiutil verify` 驗證成品。
- 2026-08-13：MissionCenter 遷移採非破壞式就地升級；`tasks.md` 繼續為唯一任務生命週期來源，舊版 Done 但無法重建標準驗證者改以 `legacy-done-audit.json` 列為警告債，不補寫假的通過紀錄。
- 2026-08-14：發現前次實際以 0.2.1 工具驗證後重開 MC-E1；改以已安裝插件 manifest `0.3.1+codex.9ed1bfeca60445639f45a35d424aa16e` 為版本根據，確認 personal skill 與 plugin skill SHA-256 一致，並以 0.3.1 腳本補齊 `working-set.md`、`critical-lessons.md`與新版 execution checkpoint。
