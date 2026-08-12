# 冒煙測試

| 日期 | 對應任務 ID | 測試內容 | 測試方式 | 預期結果 | 實際結果 | 通過 / 失敗 | 類型 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-08-12 | AERO-T1 | 維護前安全測試基準 | `npm test` | 兩支安全測試通過 | `security-smoke.cjs` 因寫死 `D:/MyGame/music` 失敗 | 失敗 | automated |
| 2026-08-12 | AERO-V1 | 維護前 Vite 建置基準 | `npm run build` | 產生 `dist/` | NAS 上 rolldown binding 被 macOS system policy 阻擋 | 失敗 | automated |
| 2026-08-12 | AERO-T1 | 跨平台安全測試 | `npm test` | 兩支安全測試通過 | 兩支測試皆 PASS | 通過 | automated |
| 2026-08-12 | AERO-V1 | 乾淨驗證與打包 | `AEROMUSIC_OUTPUT_DIR=/tmp/aeromusic-final ./scripts/build-macos.sh` | 測試、Lint、Vite build、App/DMG 打包成功 | 0 errors、4 個已記錄 Hook warnings；App 與 DMG 產生成功 | 通過 | automated |
| 2026-08-12 | AERO-S1 | 安全協定與 CORS 回歸 | 啟動暫存 App 並檢查 Electron console | 視窗正常，無 CORS 錯誤 | 首輪抓到 CORS 後補齊所有 source path；最終重測無錯誤 | 通過 | manual |
| 2026-08-12 | AERO-C1 | 桌面交付 | 核對 DMG SHA-256、啟動 Desktop App、檢查主程序與 Renderer | 成品一致且可執行 | DMG `9c1def5b...bd5e61a`；Desktop 主程序與 Renderer 正常 | 通過 | automated |
