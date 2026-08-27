# 收尾

- 摘要: AeroMusic 1.0.0 已完成可靠性、安全、效能、離線體驗與 macOS 發行強化並交付桌面。
- 已完成: 原子存檔與備份復原；NAS 離線保護；Electron/IPC/導航 hardening；20,000 首排序；離線資源；Chrome 與封裝 App 回歸；Apple Development 本機簽章；DMG 交付
- 未完成: 正式對外公證需另備 Developer ID Application 憑證與 notarytool profile；非本次本機交付阻擋
- 風險: 預設示範串流仍需 SoundHelix 網路；Apple Development 簽章不等於 Developer ID 公證
- 冒煙測試: npm test；零警告 lint；Vite 8 build；audit 0；Chrome UI；Electron 單例；codesign strict；hdiutil verify；桌面啟動
- 回顧: NAS 專案應固定在 /tmp 乾淨建置；成品 plist 必須在簽章前 fail-closed 驗證；UI 與成品實測能抓到單元測試外問題

## AeroMusic 2.0 螃蟹版本機收尾 · 2026-08-27

- 摘要: Swift 6／SwiftUI Apple 外殼與 std-only Rust value core 已完成可重建的本機交付；來源復原、夢幻 AppIcon、送審 metadata gate 與 universal archive 均已納入證據鏈。
- 已完成: 12 個 2.0 里程碑標為 `crab-done`；Swift 14/14、Rust 19 core＋8 FFI＋1 shared、fmt、Clippy、Codex Game Studios validation、macOS／iPad Simulator Release build、generic iOS device arm64 Release compile、Mac universal Development archive strict codesign／App Store preflight、MissionCenter Doctor 與 HUD 同步。
- 已補強: stale bookmark 自動 refresh 與原生重新授權 picker；AppIcon 1024／512 RGB 無 Alpha；`qualify-app-store.sh` 強制驗證 `CFBundleIconName=AppIcon`；送審 metadata／授權責任集中於 `Native/APP_STORE_METADATA.md`。
- 未完成: 實體 Mac／iPad NAS 與背景／PiP／sandbox 矩陣；Apple Distribution 憑證／profile、App Store Connect／TestFlight；Privacy／Support 公開 URL、商店資料與素材授權；Electron 退場。這些不以模擬器或 Development signing 冒充完成。
- GitHub: `origin/main` 可讀且與本地 HEAD `2c42c03` 同步；`gh pr list --state all` 為空；2.0 變更尚未 commit／push，避免未經授權改變遠端歷史。
- 證據: `Native/ARTIFACT_MANIFEST.md` 雜湊驗證通過；`MissionCenter/tasks.md`、`smoke-tests.md`、`daily-log.md` 已同步；HUD helper reused `http://127.0.0.1:51768/`；Doctor 保留既有 legacy warning，無新增錯誤。
- 最新本機補強：`OfflineCacheStore.cachedURL` 先驗證 SHA-256 再供播放，釘選內容可在來源離線時直接使用；歌曲、專輯與歌手 UI 改為分頁載入；Mac 支援拖放資料夾加入音樂來源；啟動時重新檢查已保存來源。Swift 14/14、Rust 19 core＋8 FFI＋1 shared、macOS／iPad Simulator Debug build 均通過；未改變實機／Distribution／TestFlight 外部 gate。
- 最新裝置盤點：已配對 iPad 可被 `devicectl` 看見，但 Developer Disk Image 尚未掛載；最新 generic iOS arm64 Release bundle 已通過 App Store preflight，實機安裝、NAS／背景播放／PiP 仍不宣稱完成。
- 最新獨立 review：Antigravity request `b8d9af7c-0e8b-4d4a-a6cb-2f66f5d6953b` 以 Hub-visible 唯讀 RPC 回覆 `verdict=PASS`，無 blocking finding；其列出的 NAS／DDI／Distribution／TestFlight 仍與本文件外部 gate 一致。
- 最新簽章證據：Xcode `-prepareDeviceSupport` 已為 iPad13,16 完成支援準備；自動開發簽章仍因本機沒有 Team `2ZYLUFSC25` 帳號及 `com.aeromusic.native` profile 失敗，故不宣稱實機安裝或 TestFlight。
- Electron legacy packaging：`npm run pack` 已完成 `dist-app/mac-arm64/AeroMusic.app`（約 195 MB），Apple Development 簽章與內部 strict verify 通過；notarization 因缺少 Developer ID／notary profile 跳過。這只代表舊版封裝基線恢復，不改變 Electron 必須等原生 TestFlight 後才退場的 gate。
- Rust boundary finalization：cache eviction policy 已經由 `aero_core_eviction_plan_v1` 接入實際 Swift cache actor；Rust 負責純 value LRU／pinned 決策，Swift 負責 Apple 檔案與權限邊界。至此可安全 Rust 化的純邏輯都有 runtime bridge；UI、AVFoundation、SwiftData、sandbox、PiP 仍刻意維持 Swift。
- MediBuddy signing cross-check：採用其「certificate／Xcode account／profile Team 分層」排障結論後，AeroMusic 以實際 profile Team 成功產生 signed arm64 device App；配對 iPad 安裝仍因裝置鎖定導致 DDI mount 失敗，實機 gate 保持未完成。

## MissionCenter 現代化與歷史債清理 · 2026-08-14

- 摘要: 現有 MissionCenter 已非破壞式升級至新版任務契約，保留全部歷史任務、決策與驗證證據。
- 已完成: 受管 project/progress 摘要、P0 焦點、每日紀錄、HUD 狀態、legacy Done audit 與 Doctor 驗證。
- 未完成: 5 個舊 Done 任務無法在不偽造證據的前提下還原標準 smoke record，保留為明確警告債。
- 驗證: MissionCenter Doctor OK；maintenance status 新鮮；`visual-state.json` 可解析；新任務均有通過紀錄。
