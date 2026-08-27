<!-- Generated materialized view. Do not edit directly; rebuild from canonical MissionCenter files. -->
<!-- mission-center-derived schema=1.0 fingerprint-format=sha256-v2-lf source-fingerprint=294b16c88f5a3692ad460d1badd42afac8226243afa393ee67e8dfcf503d1ac8 -->
# 任務簡報

- 最後整理: 2026-08-28
- 來源指紋: `294b16c88f5a3692ad460d1badd42afac8226243afa393ee67e8dfcf503d1ac8`
- 唯一真實來源: `tasks.md`
- 專案: AeroMusic 維護與交付
- 北極星: 以 SwiftUI Apple 平台外殼＋Rust 純邏輯核心交付可獨立使用的 macOS 15+ 與 iPadOS 18+ 私人曲庫播放器
- 週期: AeroMusic 2.0 原生重建

## 今日摘要 · 2026-08-28
- 2026-08-28 02:34 +08:00｜變更：完成 AERO-F5，統一原生音訊／影片播放入口並更新桌面試用版｜原因：大型播放鍵空 queue 時無反應，且 MP4 等含影像媒體只進音訊管線｜影響：新增可遷移 MediaKind、AVFoundation 實際軌道／可播放能力判斷、Root shell 影片呈現、Mac AVPlayerView 與 iPad AVPlayerViewController／PiP 自動播放；純音訊維持 Gapless 核心。壞檔不再中止整個掃描或誤把既有曲目標 missing；混合 queue 不把影片送進 NativePlaybackEngine；來源 lease 於關閉影片後釋放。Swift 15/15、針對性 incomplete-scan 測試、Mac／iPad build、現有 NAS MP4 動態畫面與三輪 CodeRabbit 修正皆通過；桌面舊 App 已移至垃圾桶可復原。
- 2026-08-28 01:34 +08:00｜變更：完成 AERO-D5 並啟動 AERO-F5｜原因：原生桌面版曲庫可見但媒體無法開啟，使用者並明確要求 MP4／其他影片格式顯示畫面｜影響：實際 UI 確認主畫面大型「播放」在空 queue 時吞掉 `unresolvedTrack` 而完全無反應；MP4 雖被索引但沒有依 video track 路由 AVKit。NAS MP4 實檔可由 `AVAudioFile` 解 AAC，故修復改採 AVFoundation 軌道能力分類，含畫面媒體走 Mac AVPlayerView／iPad AVPlayerViewController＋PiP，純音訊維持原播放核心。另記錄三份同名 App 導致 LaunchServices／SwiftData store 誤辨；Desktop 同 bundle ID 重啟後 112 個來源可恢復 available，簽章差異保留為交付風險。
- 2026-08-28 00:48 +08:00｜變更：完成 AERO-ND1，以最新 source 的 SwiftUI＋Rust 2.0 原生 App 更正桌面交付｜原因：使用者指出 AERO-LG1 交付的是 Electron 舊介面並要求試用新版｜影響：桌面 App 現為 `com.aeromusic.native` 2.0，視窗「夜航收藏」已啟動；舊 Electron App 與 DMG 移至垃圾桶可復原；Distribution／notarization／TestFlight gate 維持未完成。
- 2026-08-28 00:36 +08:00｜變更：完成 AERO-LG1，重新打包並更新桌面 Electron 保留版｜原因：使用者要求移除桌面舊版並交付目前程式｜影響：`AeroMusic.app` 與 `AeroMusic-1.3.2-arm64.dmg` 已以驗證後新包替換；舊檔移至垃圾桶可復原；App 從桌面啟動成功，原生 2.0 與 Electron 退場 gate 不變。
- 2026-08-28：AERO-LG1 桌面 Electron 保留版重新打包、可復原替換與啟動驗證完成。 已記錄冒煙測試: 78.
- 2026-08-28：AERO-ND1 最新 SwiftUI＋Rust 2.0 原生版桌面試用交付與啟動驗證完成。 已記錄冒煙測試: 79.

## 重要護欄 (1)
- GR-001

## 需要時再讀
- 目前工作（2 項）→ `working-set.md`
- 修改任務生命週期／順序 → `tasks.md`
- 查閱理由／證據 → `decisions.md`、`notes.md`、`smoke-tests.md`
- 簡報／工作集過期或截斷 → 執行 `mission_maintenance.py sync` 後再讀 canonical files
