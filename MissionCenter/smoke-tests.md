# 冒煙測試

| 日期 | 對應任務 ID | 測試內容 | 測試方式 | 預期結果 | 實際結果 | 通過 / 失敗 | 類型 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-08-12 | AERO-T1 | 維護前安全測試基準 | `npm test` | 兩支安全測試通過 | `security-smoke.cjs` 因寫死 `D:/MyGame/music` 失敗 | 失敗 | automated |
| 2026-08-12 | AERO-V1 | 維護前 Vite 建置基準 | `npm run build` | 產生 `dist/` | NAS 上 rolldown binding 被 macOS system policy 阻擋 | 失敗 | automated |
| 2026-08-12 | AERO-T1 | 跨平台安全測試 | `npm test` | 兩支安全測試通過 | 兩支測試皆 PASS | 通過 | automated |
| 2026-08-12 | AERO-V1 | 乾淨驗證與打包 | `AEROMUSIC_OUTPUT_DIR=/tmp/aeromusic-final ./scripts/build-macos.sh` | 測試、Lint、Vite build、App/DMG 打包成功 | 0 errors、4 個已記錄 Hook warnings；App 與 DMG 產生成功 | 通過 | automated |
| 2026-08-12 | AERO-S1 | 安全協定與 CORS 回歸 | 啟動暫存 App 並檢查 Electron console | 視窗正常，無 CORS 錯誤 | 首輪抓到 CORS 後補齊所有 source path；最終重測無錯誤 | 通過 | manual |
| 2026-08-12 | AERO-C1 | 桌面交付 | 核對 DMG SHA-256、啟動 Desktop App、檢查主程序與 Renderer | 成品一致且可執行 | 證據不足：歷史紀錄只有縮寫 DMG SHA-256 `9c1def5b...bd5e61a`，工作區沒有對應 DMG 可重算；Desktop 主程序與 Renderer 正常；SHA 判定跳過 | 部分通過（SHA 跳過） | automated / evidence-incomplete |
| 2026-08-12 | AERO-P2 | 原子存檔與 NAS 離線保護 | `npm test`、故障注入、損壞主檔與離線路徑 fixture | 備份復原、離線資料保留、重疊寫入序列化且失敗不毒死 queue | 三項持久化測試 PASS；`npm run lint` 無錯誤 | 通過 | automated |
| 2026-08-12 | AERO-S2 | Electron 與相依安全強化 | 暫存乾淨副本執行 `npm test`、`npm run build`、`npm audit --json` | 安全行為與建置通過，無已知漏洞 | tests/build PASS；audit 0 vulnerabilities | 通過 | automated |
| 2026-08-12 | AERO-F2 | 大型曲庫效能與 Hook 資料流 | 20,000 首 fixture、`npm run lint -- --max-warnings=0` | 排序正確且低於 5 秒；零 Hook warning | 排序 76–103 ms；Lint 0 warning | 通過 | automated |
| 2026-08-12 | AERO-R2 | 離線資源與 Chrome UI 回歸 | Chrome 檢查破圖、console、搜尋、導覽、沉浸模式與 Esc | 無外部字型/封面依賴且主要互動正常 | 無破圖與 console 錯誤；所有互動 PASS | 通過 | manual |
| 2026-08-12 | AERO-T2 | 封裝 App 與單一實例 | 從 `/tmp` 以獨立 user-data 啟動兩次 App，檢查主程序與 Renderer sandbox | App 正常啟動且第二次只聚焦既有視窗 | 主程序維持 1 個；Renderer 帶 `--enable-sandbox`；無新增 crash report | 通過 | manual |
| 2026-08-12 | AERO-V2 | 1.0.0 簽章與 DMG 完整性 | `codesign --verify --deep --strict`、`hdiutil verify`、Info.plist 檢查 | App/DMG 簽章有效、映像 checksum 有效、ATS 關閉任意連線 | Apple Development 本機簽章通過；DMG CRC VALID；`NSAllowsArbitraryLoads=false` | 通過 | automated |
| 2026-08-12 | AERO-V2 | 最終唱反調審查 | Gemini 唯讀 diff 審查＋Codex 模擬安全/資料/效能/UX/發布專家 | 無可重現阻擋問題 | Gemini `FINAL_REVIEW_PASS`；兩個低風險建議已採納 | 通過 | review |
| 2026-08-12 | AERO-C2 | 桌面 1.0.0 交付 | 桌面成品重算 SHA-256、驗簽、核對版本/ATS 並直接啟動 | App/DMG 與候選一致且可直接使用 | 證據不足：歷史紀錄只有縮寫 DMG SHA-256 `f2f9bfc8...f2f4f9`，工作區沒有對應 DMG 可重算；App/DMG 簽章有效、版本 1.0.0、ATS=false、主程序正常；SHA 判定跳過 | 部分通過（SHA 跳過） | release / evidence-incomplete |
| 2026-08-14 | MC-M1 | 舊版 Done 驗證債遷移 | 執行 `normalize_mission_center.py .` 與 `doctor_mission_center.py .` | 欄位無需改寫；5 個舊 Done ID 僅列為未驗證警告；Doctor 無錯誤 | `normalized=False`；5 個 legacy debt 警告；`MissionCenter doctor: OK` | 通過 | automated |
| 2026-08-14 | MC-V1 | 受管摘要、派生檢視與 HUD 同步 | 執行 `sync_mission_center.py . --rewrite-summaries`、`mission_maintenance.py . status`與 `python3 -m json.tool output/mission-center-assets/visual-state.json` | project/progress 採新版受管標記；摘要不過期；HUD JSON 可解析且任務狀態一致 | 受管標記已寫入；`stale=false`；HUD JSON 解析成功並顯示 MC-E1/MC-M1/MC-V1 | 通過 | automated |
| 2026-08-14 | MC-E1 | MissionCenter 現代化綜合契約 | 重跑 Doctor、maintenance status 與 HUD JSON 解析 | 無驗證錯誤、派生檢視新鮮、HUD 可用；舊證據債明確保留 | 子任務驗證全部通過；舊 Done 維持 warning-level debt，無假造通過紀錄 | 通過 | automated |
| 2026-08-14 | MC-M2 | Mission Center 0.3.1 版本與契約 | 讀取已安裝 plugin manifest、比對 personal/plugin SKILL.md SHA-256，以 0.3.1 腳本執行 sync、snapshot、resume 與 Doctor | manifest 基礎版為 0.3.1；技能內容一致；Resume schema 1.1 新鮮並包含新版 checkpoint；Doctor 無錯誤 | 版本 `0.3.1+codex.9ed1bfeca60445639f45a35d424aa16e`；雙方 SHA-256 僅記錄縮寫 `01f176ab...f01d3`，未取得完整檔案或機器 checksum，SHA 判定跳過；`sourceFresh=true`；Doctor OK | 部分通過（SHA 跳過） | automated / evidence-incomplete |
| 2026-08-14 | MC-E1 | MissionCenter 0.3.1 現代化重驗 | 以 0.3.1 的 normalize、sync、snapshot、resume、Doctor 與 HUD JSON 驗證完整工作區 | 欄位正規、受管摘要與 HUD 同步、Resume packet 新鮮、Doctor 無錯誤 | 0.3.1 契約全部通過；5 個舊 Done 僅保留 warning-level debt | 通過 | automated |
