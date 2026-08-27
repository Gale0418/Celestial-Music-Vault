<!-- Generated materialized view. Do not edit directly; rebuild from canonical MissionCenter files. -->
<!-- mission-center-derived schema=1.0 fingerprint-format=sha256-v2-lf source-fingerprint=12f37e125fb2f83ad8d194035f4f9acc16d3cd8516209d4c3765b737e2802f5b -->
# 任務簡報

- 最後整理: 2026-08-27
- 來源指紋: `12f37e125fb2f83ad8d194035f4f9acc16d3cd8516209d4c3765b737e2802f5b`
- 唯一真實來源: `tasks.md`
- 專案: AeroMusic 維護與交付
- 北極星: 以 SwiftUI Apple 平台外殼＋Rust 純邏輯核心交付可獨立使用的 macOS 15+ 與 iPadOS 18+ 私人曲庫播放器
- 週期: AeroMusic 2.0 原生重建

## 今日摘要 · 2026-08-27
- AERO-V3 最終螃蟹回歸：CodeRabbit 依 1 小時 3 次／每次最多 150 檔限制，三輪只餵 125 個小檔案；高可信問題已逐項驗證並修正（ABI 計數防護、cache 原子清理、來源狀態非主執行緒、SwiftData 搜尋記憶體、iPad 來源管理、播放 shuffle/repeat、App Store manifest）。Rust 19 core＋7 FFI＋1 shared、Swift 14/14、Swift↔Rust bridge、shell syntax、manifest hash、MissionCenter Doctor 全部通過；iPhone 要求與產品明確排除範圍衝突，5.1 以外聲道布局因 v1 ABI 無 layout 物件保留 accepted risk。實機解鎖、Distribution／TestFlight、授權素材仍未提前關閉。
- 使用者核准「蟹化 GO」：新增 AERO-RS3 與 AERO-B3，採 SwiftUI 原生外殼＋Rust shadow core；拒絕 Tauri/WebView。第一切片為 std-only scan-diff 純邏輯、Swift oracle 差分測試與 `/tmp` Cargo build。
- AERO-RS3 已建立 `AeroCoreRS`：std-only、`forbid(unsafe_code)`、deterministic scan reconciliation 與共享 TSV oracle；Rust 5 tests、Swift 4 tests、Apple 三 targets、Mac/iPad builds 及 CodeRabbit 0 issues。依高影響完成閘門停在 Review；critic_full 未派送，因尚缺總額／每席／工具／牆鐘預算核准。
- 使用者核准 critic_full 預算但指定留到 V3 最終會議；RS3 因未接 runtime、可逆且 CodeRabbit 0 issues，以低風險非感知 skip 關閉，AERO-B3 轉 In Progress。HUD 既有 server 於 `127.0.0.1:54065` 正常，已在 Codex 右側開啟最新 42% 畫面。
- AERO-B3 完成：新增獨立 FFI crate、版本化 bytes-in／owned-buffer-out C ABI、panic boundary、Swift RAII client、Xcode target 選擇腳本與可重跑 Swift bridge smoke。Rust 9 tests、Swift↔Rust runtime smoke、macOS 與 arm64 iPad Simulator 最終連結皆通過。
- 依使用者要求全面檢查原任務的蟹化需求：L3／P3／M3／A3／C3 已補上 Rust 純邏輯責任與 Swift 平台責任；U3 保持 SwiftUI／AVKit，避免把 Apple UI 物件硬塞過 FFI。AERO-L3 轉 In Progress。
- AERO-L3 完成：App runtime 已改由 Rust v1 reconciliation 決定 upsert／missing，Swift SourceAccessCoordinator 持有 security scope、LibraryDataActor 分批套用結果。50k Rust ABI 與 50k SwiftData 分別通過；8 個 Swift 測試涵蓋取消、離線不清庫與持久 store 重啟；Mac/iPad Simulator build 通過。AERO-P3 轉 In Progress、M3 轉 Ready。
- AERO-P3 完成：Rust v1 ABI 接管 sample timeline 與 ReplayGain／peak gain 規劃；Swift AVAudioEngine 改為雙節點經 transition mixer、同 host-time 共用 sample timeline，並接上 Limiter、EQ、Now Playing、remote commands、iOS background session／interruption／route recovery。13 個 Rust tests、3 條真實 ABI smoke、8 個 Swift tests、Mac/iPad build 全綠；AERO-M3 轉 In Progress。
- [TRUNCATED] 62 additional items require canonical file access.

## 重要護欄 (1)
- GR-001

## 需要時再讀
- 目前工作（2 項）→ `working-set.md`
- 修改任務生命週期／順序 → `tasks.md`
- 查閱理由／證據 → `decisions.md`、`notes.md`、`smoke-tests.md`
- 簡報／工作集過期或截斷 → 執行 `mission_maintenance.py sync` 後再讀 canonical files
