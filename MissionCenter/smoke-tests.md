# 冒煙測試

| 日期 | 對應任務 ID | 測試內容 | 測試方式 | 預期結果 | 實際結果 | 通過 / 失敗 | 類型 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-08-12 | AERO-T1 | 維護前安全測試基準 | `npm test` | 兩支安全測試通過 | `security-smoke.cjs` 因寫死 `D:/MyGame/music` 失敗 | 失敗 | automated |
| 2026-08-12 | AERO-V1 | 維護前 Vite 建置基準 | `npm run build` | 產生 `dist/` | NAS 上 rolldown binding 被 macOS system policy 阻擋 | 失敗 | automated |
| 2026-08-12 | AERO-T1 | 跨平台安全測試 | `npm test` | 兩支安全測試通過 | 兩支測試皆 PASS | 通過 | automated |
| 2026-08-12 | AERO-V1 | 乾淨驗證與打包 | `AEROMUSIC_OUTPUT_DIR=/tmp/aeromusic-final ./scripts/build-macos.sh` | 測試、Lint、Vite build、App/DMG 打包成功 | 0 errors、4 個已記錄 Hook warnings；App 與 DMG 產生成功 | 通過 | automated |
| 2026-08-12 | AERO-S1 | 安全協定與 CORS 回歸 | 啟動暫存 App 並檢查 Electron console | 視窗正常，無 CORS 錯誤 | 首輪抓到 CORS 後補齊所有 source path；最終重測無錯誤 | 通過 | manual |
| 2026-08-12 | AERO-C1 | 桌面交付 | 核對 DMG SHA-256、啟動 Desktop App、檢查主程序與 Renderer | 成品一致且可執行 | DMG `9c1def5b...bd5e61a`；Desktop 主程序與 Renderer 正常 | 通過 | automated |
| 2026-08-12 | AERO-P2 | 原子存檔與 NAS 離線保護 | `npm test`、故障注入、損壞主檔與離線路徑 fixture | 備份復原、離線資料保留、重疊寫入序列化且失敗不毒死 queue | 三項持久化測試 PASS；`npm run lint` 無錯誤 | 通過 | automated |
| 2026-08-12 | AERO-S2 | Electron 與相依安全強化 | 暫存乾淨副本執行 `npm test`、`npm run build`、`npm audit --json` | 安全行為與建置通過，無已知漏洞 | tests/build PASS；audit 0 vulnerabilities | 通過 | automated |
| 2026-08-12 | AERO-F2 | 大型曲庫效能與 Hook 資料流 | 20,000 首 fixture、`npm run lint -- --max-warnings=0` | 排序正確且低於 5 秒；零 Hook warning | 排序 76–103 ms；Lint 0 warning | 通過 | automated |
| 2026-08-12 | AERO-R2 | 離線資源與 Chrome UI 回歸 | Chrome 檢查破圖、console、搜尋、導覽、沉浸模式與 Esc | 無外部字型/封面依賴且主要互動正常 | 無破圖與 console 錯誤；所有互動 PASS | 通過 | manual |
| 2026-08-12 | AERO-T2 | 封裝 App 與單一實例 | 從 `/tmp` 以獨立 user-data 啟動兩次 App，檢查主程序與 Renderer sandbox | App 正常啟動且第二次只聚焦既有視窗 | 主程序維持 1 個；Renderer 帶 `--enable-sandbox`；無新增 crash report | 通過 | manual |
| 2026-08-12 | AERO-V2 | 1.0.0 簽章與 DMG 完整性 | `codesign --verify --deep --strict`、`hdiutil verify`、Info.plist 檢查 | App/DMG 簽章有效、映像 checksum 有效、ATS 關閉任意連線 | Apple Development 本機簽章通過；DMG CRC VALID；`NSAllowsArbitraryLoads=false` | 通過 | automated |
| 2026-08-12 | AERO-V2 | 最終唱反調審查 | Gemini 唯讀 diff 審查＋Codex 模擬安全/資料/效能/UX/發布專家 | 無可重現阻擋問題 | Gemini `FINAL_REVIEW_PASS`；兩個低風險建議已採納 | 通過 | review |
| 2026-08-12 | AERO-C2 | 桌面 1.0.0 交付 | 桌面成品重算 SHA-256、驗簽、核對版本/ATS 並直接啟動 | App/DMG 與候選一致且可直接使用 | DMG `f2f9bfc8...f2f4f9`；App/DMG 簽章有效；版本 1.0.0；ATS=false；主程序正常 | 通過 | release |
