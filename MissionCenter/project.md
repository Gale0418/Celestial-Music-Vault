<!-- mission-center-managed-summary v=1 -->
# 專案

- 專案: 星穹私藏音樂庫 Celestial Music Vault（CMV）維護與交付
- 目標: 以 SwiftUI Apple 平台外殼＋Rust 純邏輯核心交付可獨立使用的 macOS 15+ 與 iPadOS 18+ 私人曲庫播放器
- 週期: CMV 2.0 原生重建
- 標籤: native, swiftui, rust, ffi, multiplatform, execution, verification
- 活動紀錄:
  - 已依目標建立初始任務樹。
  - 2026-08-12：使用者授權採 Codex 推薦方案與本機 Antigravity/Gemini 全工作區檢查。
  - 2026-08-12：Gemini 完成第一輪唯讀稽核；第二輪 RPC 失敗且收據不可重試，改由 Codex 接管已縮小的實作範圍。
  - 2026-08-12：安全協定、專案整理、測試、Lint、乾淨建置、DMG 與桌面交付完成。
  - 2026-08-12：完成測試、打包、煙霧測試與桌面交付。 已記錄 Smoke tests: 6.
  - 2026-08-13：啟動 MissionCenter 新版契約遷移；保留舊任務與驗證證據，不偽造歷史通過紀錄。
  - 2026-08-26：使用者核准 AeroMusic 2.0 SwiftUI 原生重建；Electron 保留到原生版完成驗收後才退場。
  - 2026-08-26：AERO-D3 完成；Celestial Cloud Atlas 三張核准稿、產品／設計權威及可建置的 macOS／iPadOS 原生骨架已建立，轉入 AERO-L3。
  - 2026-08-26 05:30 +08:00｜變更：建立 AERO-G3 與 GR-001 任務先行門檻｜原因：使用者要求所有工作先登記 Mission Center｜影響：往後沒有對應 task ID、下一步與驗證方式，不得開始程式、設計或架構實作。
  - 2026-08-26 05:45 +08:00｜變更：建立 AERO-R4 跨領域研究與架構審查｜原因：使用者要求結合多專業、Gemini、GitHub 與網路證據全面找出更佳方案｜影響：AERO-L3／P3／U3 的細節先接受研究校正，不在證據完成前擴大實作。
  - 2026-08-26｜變更：完成 AERO-R4 並採用資料／授權／播放三邊界優先順序｜原因：本機稽核與一手資料證實骨架不足以承載 50k、NAS 與 frame-accurate Gapless｜影響：先完成 L3 的 ModelActor、batch ingest 與 scope lease；夢幻 UI 保留但延後至核心可驗證後 harden。
  - 2026-08-27｜變更：使用者核准 AeroMusic 蟹化，新增 AERO-RS3／B3｜原因：Rust 成為明確產品偏好，但仍要求 Mac＋iPad 原生品質與低維護｜影響：Swift 保留 Apple 平台層，Rust 只接管純邏輯核心；先 shadow parity，再接窄幅 C ABI，不採 Tauri。
  - 2026-08-27｜變更：AERO-RS3 完成本機與 CodeRabbit 技術驗證後進入 Review｜原因：高影響架構需 critic_full，但未取得 3 critic＋1 arbiter 的明確預算核准｜影響：B3 暫不啟動；現有 Swift App 與 Rust shadow core 均維持可建置，無預設實作切換。
  - 2026-08-27｜變更：使用者核准 critic_full 完整預算並指定移至 V3 最終會議｜原因：先完成核心功能，避免每個可逆 shadow 切片重複消耗四席評論額度｜影響：RS3 以未接 runtime／可逆／CodeRabbit 0 issues 的 skip disposition 關閉，B3 開始執行；最終會議預算與停止條件已保留。
  - 2026-08-27｜變更：完成 B3 並將後續任務逐項蟹化｜原因：使用者要求原本任務同步採最終 Rust 邊界，而不是只新增孤立 shadow core｜影響：Xcode 已自動連結三 Apple target staticlib；L3／P3／M3／A3／C3 明確拆分 Swift 平台責任與 Rust 純邏輯責任，U3 維持 SwiftUI／AVKit。
  - 2026-08-29｜變更：啟動 AERO-N10 品牌更名與 Rust 1.98 基線統一｜原因：使用者將自維護應用程式正式命名為「星穹私藏音樂庫 Celestial Music Vault（CMV）」，且明確授權舊應用身分全部退場｜影響：原生／Electron 現行來源、Bundle ID、資料容器、偏好 key、`cmv://` scheme、Swift module、Rust crate／FFI、Xcode 與專案資料夾全部改用 CMV；不建立舊身分遷移層。Rust toolchain 與兩個 crate 的 MSRV 統一為 1.98；歷史驗證紀錄保留原名。
  - 2026-08-29｜完成：AERO-N10 CMV 全身分更名與 Rust 1.98 基線統一｜證據：專案根目錄、原生／Electron 共用 `com.windsheep.cmv`、Xcode／Swift／Rust 路徑與 ABI 已改為 CMV；舊 DerivedData 與 build cache 清除。Electron test／lint／build、Swift 16/16、Rust fmt／Clippy／20 tests、8 項 Swift bridge、macOS arm64 與 iPad Simulator arm64 Debug build 全部通過；現行來源舊身分稽核無命中｜後續：維持 AERO-V3 的實機／Distribution／TestFlight 外部 gate，不將歷史證據回寫成新名稱。
  - 2026-08-29｜完成：AERO-G11 CodeRabbit 審查與 GitHub main 發布前 gate｜證據：三輪 review 均控制在 145 個狀態項並排除 8 個大型 PNG，依序 raised 3／5／0 issues；所有有效 canonical task ID 問題已修正，migration 與 fingerprint 誤報有明確 disposition。Electron、Rust 1.98、Swift 16/16、8 項 bridge、Mac／iPad Debug build 與 Mission Center Doctor 全部通過｜影響：更名差異可直接提交 main，不建立額外分支。
  - 2026-08-29｜變更：重啟 AERO-M6 舊版曲庫操作 parity｜原因：使用者指出原生 CMV 無法像 Electron 一樣全選後一次移出曲庫，並要求追回既有操作｜影響：已恢復搜尋範圍全選、macOS ⌘A、播放所選、批次加入歌單、批次移出，以及單首右鍵／更多選單的大部分舊版操作。移出採持久 excluded tombstone、同步清除歌單引用，實體 NAS／磁碟檔保留且重新索引不復活；實體垃圾桶失敗會恢復曲目與歌單原順序。影音混合 queue 的下一首／加入目前佇列與歌單內容移除仍須另做不中斷播放的安全實作，因此 AERO-M6 保持 In Progress。
- 開放問題:
  - 無
