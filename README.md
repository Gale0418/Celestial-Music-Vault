# 星穹私藏音樂庫 Celestial Music Vault（CMV）

Celestial Music Vault（CMV）是一個以 **macOS 15+／iPadOS 18+** 為目標的私有音樂資料庫與播放器。CMV 2.0 的現行主線採 **Swift 6、SwiftUI、SwiftData、AVFoundation／AVKit**，並以 **Rust 1.98.1** 實作可跨平台驗證的純邏輯核心；音樂、影片、NAS 路徑與分析資料都留在使用者自己的裝置與儲存來源。

> **目前狀態（2026-10-23）：** Native 2.0 是唯一現行主線。2.0（3）已推送 GitHub main，兩平台成品均上傳 Apple、處理為 `VALID` 並附至版本。Mac 已重新提交，狀態為 `WAITING_FOR_REVIEW`；iPad 尚未重新送審，仍待替換 13 吋 required 截圖。已購買 Pro 頁明示永久使用並收起購買／恢復按鈕，Mac／實體 iPad 均已驗證。Mac 三語 6 張與 iPad 11 吋三語 6 張實機商店圖已回讀為 `COMPLETE`；13 吋模擬器拍攝因視窗控制失效未完成展示圖，已關閉。未宣稱 Apple 核准。舊 Electron／React／Node 已依 AERO-RT4 退場。詳見 [審查修復紀錄](Native/REVIEW_FIXES_20261023.md)。

## CMV 2.0 能做什麼

- 透過系統資料夾選擇器加入本機或 NAS 掛載資料夾，使用 security-scoped bookmark 保存授權。
- 面向大型私人曲庫設計，目標規模最高 50,000 首；NAS 暫時離線、Wi-Fi 中斷或 bookmark 失效時不把曲庫誤當成刪除。
- 原生播放支援 gapless、ReplayGain／R128 normalization、limiter、EQ、系統媒體控制、背景音訊與 AirPlay。
- 管理歌曲、專輯、歌手、歌單、最愛、評分、歷史與 artwork；支援本機離線釘選與有容量預算的智慧快取。
- MP4／MOV／M4V 依實際媒體軌道走 AVKit：Mac 使用原生 AVPlayerView，iPad 使用 AVPlayerViewController／PiP。
- BPM、key、loudness 與 Smart DJ 的核心分析／排序完全在裝置上執行；可操作 UI 入口仍由發行任務追蹤，不提前當成已完成商店功能宣稱。
- 無帳號系統、無雲端 AI、無分析追蹤器，也不會上傳私人音訊。

完整產品邊界請看 [`PRODUCT.md`](PRODUCT.md)，視覺與互動契約請看 [`DESIGN.md`](DESIGN.md)。

## 支援與隱私權

操作問題與錯誤回報請看 [使用支援](SUPPORT.md)；資料處理方式請看 [隱私權政策](PRIVACY.md)。GitHub Issues 是公開頁面，請先遮蔽私人媒體、路徑與聯絡資料，不要提交帳密或購買憑證。

## 技術架構

```text
Native/CMV/          SwiftUI 多平台 App（macOS + iPadOS）
Native/CMVCore/      Swift Package：domain / library / playback / cache / themes
Native/CMVCoreRS/    Rust 1.98.1 純邏輯核心 + versioned C ABI
Native/scripts/      fast / full local / App Store qualification gates
docs/design/         版本化的核准設計 reference
docs/history/        歷史驗證快照，不作為現行 source gate
MissionCenter/       任務、決策、驗證與發行 gate
```

Rust 的邊界刻意保持狹窄：它負責 reconciliation、搜尋排序、playback timeline／gain、聲學分析、Smart DJ 與 cache policy 等 deterministic logic；Swift 仍獨占 SwiftUI、SwiftData、security-scoped URL、AVFoundation、AVKit 與 Apple 平台 I/O。

## 開發需求

### Native 2.0

- Xcode 26 或更新版本
- Swift 6 toolchain
- Rust **1.98.1**（根目錄 `rust-toolchain.toml` 已固定版本，含 `rustfmt`、`clippy` 與 Apple targets）
- macOS 開發環境

日常快速驗證：

```bash
Native/scripts/run-fast-gates.sh
```

發行前完整本機驗證：

```bash
Native/scripts/run-local-gates.sh
```

`run-local-gates.sh` 會跑 Rust／Swift 測試、macOS／iPad Simulator Release build、bundle／AppIcon／privacy preflight、canonical macOS archive qualification、Rust 1.98.1 toolchain contract 與 MissionCenter Doctor。它需要可用的 canonical archive 與 MissionCenter Rust CLI；實機、Distribution、TestFlight 等外部 gate 不會被本機腳本假裝完成。

## 設計 reference

CMV 2.0 的三張核准構圖已移出工具工作目錄，永久版本化於：

- [`docs/design/references/cmv-macos-celestial.png`](docs/design/references/cmv-macos-celestial.png)
- [`docs/design/references/cmv-ipad-landscape-celestial.png`](docs/design/references/cmv-ipad-landscape-celestial.png)
- [`docs/design/references/cmv-ipad-portrait-celestial.png`](docs/design/references/cmv-ipad-portrait-celestial.png)

`.impeccable/` 現在視為工具工作狀態，不再是產品設計權威來源。

## 隱私與安全模型

- 使用者先在 Finder 或 Files app 掛載／授權來源；CMV 不實作 SMB 帳密登入，也不保存 NAS credential。
- 暫時不可用的來源只改變 availability，不清除曲庫紀錄。
- Pinned media 與 smart cache 分區；被釘選的內容不受 LRU 淘汰。
- Apple 平台物件與 sandbox 權限只由 Swift 端持有，Rust FFI 只交換 bounded value payload。
- Diagnostics 使用 Apple 平台機制；不建立雲端帳號、遙測或私人音訊上傳路徑。

## 發行原則

Native 2.0 build 2 的兩平台 archive、Distribution export、qualification、實體已解鎖畫面驗證與 Apple upload／attach 已完成。build 3 補上更明確的已購買狀態；iPad 13 吋 required screenshot 與 iPad 重新送審仍待完成；Mac 已等待審查，TestFlight 分發與 App Store 核准另行確認。已完成的簽章與成品資格不等於 Apple 核准或公開上架。

本輪舊版退場的 Git 復原基準是 `7e033ae3b776f116695b3f2df0f0293bd76322f9`。需要取回歷史檔案時，可使用 `git show 7e033ae3b776f116695b3f2df0f0293bd76322f9:path` 查閱，或使用 `git restore --source 7e033ae3b776f116695b3f2df0f0293bd76322f9 -- paths` 復原指定路徑。
