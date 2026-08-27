# AeroMusic 2.0 跨領域架構審查

- 日期：2026-08-26
- Mission Center：`AERO-R4`
- 範圍：Swift 6／SwiftUI、SwiftData、NAS 掛載來源、AVFoundation 音訊與影片、離線分析／快取、macOS 15+、iPadOS 18+
- 結論：現況是可建置的垂直骨架，不是可供五萬首曲庫驗收的 2.0。先修正資料、來源授權與播放三條核心邊界，再擴充 Metadata、Smart DJ、快取與夢幻介面，總返工最低。
- 2026-08-27 蟹化增補：使用者核准 SwiftUI 原生外殼＋`AeroCoreRS` Rust 靜態核心。Rust 以 shadow implementation 起步，只接管可用 value DTO 差分驗證的純邏輯；不採 Tauri、React 或 WebView。
- 2026-08-27 蟹化補強：釘選／智慧快取現在以 checksum-verified `cachedURL` 支援離線播放；TrackList、專輯與歌手畫面改為 offset 分頁；Mac Wide shell 接受資料夾拖放；啟動時會重新檢查持久來源並在可解析時刷新 stale bookmark。這些變更已由 Swift／Rust 測試與雙平台 Debug build 驗證。
- 2026-08-27 Rust 邊界補強：cache eviction policy 已透過 `aero_core_eviction_plan_v1` 接入 `FileOfflineCacheStore`；Rust 回傳需淘汰的 value-only IDs，Swift 仍負責檔案刪除、manifest 與 checksum。至此掃描差分、播放時間軸／增益、搜尋排序、PCM／DJ 與快取淘汰均有 runtime bridge；AVFoundation／SwiftData／sandbox／UI 仍刻意保留在 Swift。

## 證據規則

本報告只把工作區實際程式碼、Apple／EBU 官方文件及代表性公開專案當成證據。Antigravity 已完成獨立挑戰，但其回覆引用了數個工作區不存在的檔名；因此只採納能由本機或一手來源重現的假說。Codex Game Studios 僅使用 architecture-review 的 Findings／Risks／Recommendation 結構，不套用遊戲引擎假設。

## 專家議會結論

| 視角 | Finding | Risk | Recommendation |
| --- | --- | --- | --- |
| SwiftData／併行 | 掃描先累積完整陣列，repository 在 `@MainActor` 抓出來源全量資料後單次儲存 | 50k 匯入造成記憶體峰值、UI 卡頓與長交易 | `@ModelActor` 專屬資料層；跨 Actor 僅傳 `Sendable` snapshot／ID；每 250–500 筆短生命週期 context 批次提交 |
| NAS／沙盒 | 掃描器自行 start/stop security scope；播放、Metadata、分析與快取沒有共用存取生命週期 | 掃描結束後其他管線失去授權；離線、過期與撤權混成同一錯誤 | 建立 reference-counted `SourceAccessCoordinator` 與 scope lease；stale bookmark 原子更新；離線絕不標記刪除 |
| 音訊／DSP | `preloadNode` 只排程而未同步啟動；目前曲目完成後才重新排下一首 | 這是自動下一首，不是 sample-accurate gapless | 以明確 `AVAudioTime` 建立連續樣點時間軸；先做 PCM fixture 驗證，再驗 AAC／MP3 priming；將狀態機與 render callback 分離 |
| 響度／母帶 | 分析器只有 RMS 與 sample peak，卻回傳 LUFS；PeakLimiter 未形成可驗證 true-peak 策略 | 響度值錯誤、正增益 clipping、切換爆音 | 依 BS.1770／EBU R128 實作 K-weighting、絕對／相對 gating、channel weighting；離線估 true peak；增益平滑與 limiter fixture |
| 大型曲庫／搜尋 | UI 固定只取前 200 筆，沒有 load-more；搜尋在主執行緒用三欄 contains | 150 ms 目標無證據、使用者永遠看不到第 201 首以後 | cursor/keyset 分頁；正規化搜尋欄位與 SwiftData `#Index`；若 contains 仍不達標，以第一方模型建立 token index entity，不碰 SwiftData 私有 SQLite |
| 快取／可靠性 | copy 採先刪後複製；`verify` 只看存在；LRU 倚賴 filesystem access date | 中斷留下缺檔、損毀誤判有效、淘汰順序不可靠 | `.partial` 暫存＋原子 replace；SHA-256／大小 manifest；自管 last-access；釘選與智慧快取分離預算 |
| iPad／Mac UX | 夢幻背景固定 20 fps、70 顆星與大型 blur；Reduce Motion 仍保留 Timeline | 分割畫面、低電量與輔助設定下持續耗電且可讀性下降 | App inactive／Low Power／thermal serious 時停動畫；Reduce Motion 使用真正靜態構圖；Reduce Transparency／Increase Contrast 使用不透明語意表面 |
| App Store／隱私 | 背景音訊骨架存在，但 interruption、route change、完整 remote commands 與實機 PiP 尚未完成 | 鎖屏、拔耳機、AirPlay、PiP 還不能驗收 | iPad 影片堅持 `AVPlayerViewController` 原生全螢幕與 PiP；不要採 Antigravity 提議的「純音訊假影格 PiP」；補背景／路由／中斷測試 |
| QA／可維護性 | 目前只有少量骨架測試，沒有 50k、NAS 故障或 frame-accurate fixture | 功能宣稱超過證據 | 每個模組先定 protocol seam 與 deterministic fixture；Simulator 做廣度、Mac/iPad 實機做音訊、沙盒、熱與記憶體證據 |

## 優先 Findings

### P0 — 五萬首匯入邊界不成立

- `IncrementalScanner.swift:12-44` 回傳完整 `[ScannedMediaFile]`；`SwiftDataLibraryRepository.swift:5-47` 在主 Actor fetch 全量、建 dictionary、逐筆 mutate、最後一次 save。
- 修正：scanner 改成 `AsyncThrowingStream<ScanBatch>` 或等價 batch sink；`LibraryDataActor` 擁有自己的 `ModelContext`；批次 upsert 與短交易；UI 只接收節流後的進度 snapshot。
- 驗收：50k fixture 匯入期間主執行緒無長工作、記憶體峰值受控；中途取消後資料庫可再次掃描；NAS 離線不把 unseen 標記 missing。

### P0 — 來源授權不是全 App 的資源生命週期

- `IncrementalScanner.swift:14-15` 只在掃描期開 scope；`NativePlaybackEngine.swift:85-103`、`LocalAudioAnalyzer.swift:12-44` 與 `FileOfflineCacheStore.swift:47-52` 直接讀 URL。
- `MediaSourceAccess.swift:37-45` 將所有解析錯誤壓成 `.permissionRequired`，無法可靠區分 stale／撤權／來源離線。
- 修正：由 `SourceAccessCoordinator` 解析 bookmark 並發行 lease；掃描、播放、分析、Metadata、copy 各自持有 lease 到 I/O 結束。狀態機明確分 `available / offline / reauthorizationRequired / scanning`。
- 驗收：重啟、睡眠 NAS、斷 Wi-Fi、撤銷授權、stale bookmark 都保留曲庫；所有 start/stop 成對且無長期資源成長。

### P0 — Gapless 宣稱與實作不符

- `NativePlaybackEngine.swift:91-103` 把下一首排到 `preloadNode`，但沒有呼叫它的 `play(at:)`；目前曲目 callback 再 `skipForward()`，會重新開檔與排程。
- 修正：先建立不依賴 UI 的 `PlaybackTimeline` 與明確 completion callback type；用連續 sample time 預排 buffer／segment。不要先假設「雙 node」或「單 node」必然正確，以 fixture 與 route-change 行為選擇。
- 驗收：PCM 邊界標記 fixture 不遺失、不重複 frame；AAC／MP3 另測 priming／padding；seek、EQ、ReplayGain 切換無 pop。

### P1 — 響度只是 RMS，不是 R128

- `LocalAudioAnalyzer.swift:20-43` 只累加 channel RMS 與 sample peak，沒有 K-weighting、block gating、channel weighting 或 true peak。
- 修正：分析結果加 `standardVersion`；ReplayGain 標籤優先；缺標籤才排程 BS.1770 分析；track／album gain 分開；輸出增益 ramp；limiter 的 ceiling 與 release 必須有 fixture。
- 驗收：以 EBU 參考序列或可重現 fixture 比對容差，不再把普通 RMS 命名為 LUFS。

### P1 — 快取缺乏完整性與原子性

- `FileOfflineCacheStore.swift:47-52` 先刪再 copy；雖 import CryptoKit，未使用 checksum；`verify` 僅檢查檔案存在。
- 修正：保留副檔名與 media type；partial copy 完成後驗證 size／SHA-256，再 replace；manifest 記錄來源 identity、最後存取、pin 狀態與分析版本。
- 驗收：copy 中斷不破壞既有有效檔；篡改／截斷可被發現；LRU 永不刪 pinned。

### P1 — 原生 UI 稽核為 11/20（Acceptable）

| Dimension | Score | 關鍵證據 |
| --- | ---: | --- |
| Accessibility | 2/4 | 部分 label 與 48 pt row 已存在，但來源狀態靠 8 pt 顏色點、動態背景缺真正 Reduce Motion／Transparency 策略 |
| Performance | 1/4 | 20 fps Timeline＋Canvas＋大型 blur 永久執行；搜尋與 fetch 在 main context |
| Appearance & Theming | 3/4 | 有共用 theme roles，但內容層廣泛 `ultraThinMaterial`，與 Apple 材質分層指引衝突 |
| Platform Conformance | 3/4 | List、Form、NavigationSplitView、SF Symbols 都原生；queue／播放內容仍是假資料 |
| Adaptivity | 2/4 | Mac split shell 已有，但 iPad portrait/narrow 的 bottom tabs＋mini player 契約尚未落地 |

- 正面項目：夢幻 Celestial Cloud Atlas 已脫離黑膠隱喻；導覽使用原生元件；系統字體與 SF Symbols 為主；設計權威明確承諾 Dynamic Type、VoiceOver 與 Reduce Motion。
- 修正順序：`$impeccable optimize` → `$impeccable adapt` → `$impeccable harden` → `$impeccable polish`，完成後重新 audit。

## 代表性 GitHub prior art

| 專案 | 維護／授權 | 決策 | 我們取什麼、拒絕什麼 |
| --- | --- | --- | --- |
| [SFBAudioEngine](https://github.com/sbooth/SFBAudioEngine) | 活躍；2026-06 有 0.13.0 release；MIT；ObjC/C/C++ 與多依賴 | Learn | 學 decoder capability、seek overflow guard、ring-buffer、engine configuration recovery 與 render completion race 的測試思路；因第一方-only、依賴與退出成本不採套件 |
| [Swiftfin](https://github.com/jellyfin/Swiftfin) | 活躍；Swift；MPL-2.0 | Learn | 學 `AVPlayerViewController` 包裝、PiP 狀態與恢復流程；不複製程式、不引入 server/client domain |
| [IINA](https://github.com/iina/iina) | 活躍；Swift；GPL-3.0；macOS only | Learn / Reject | 學影片視窗狀態、PiP 邊界案例；拒絕 GPL 程式、mpv 依賴與 Mac-only 架構 |
| [AudioKit](https://github.com/AudioKit/AudioKit) | 活躍；Swift；MIT | Learn / Reject | 學 audio graph 可測試性與 DSP 封裝；功能面過廣且違反 runtime 第一方-only，故不採依賴 |
| [fooyin](https://github.com/fooyin/fooyin) | 活躍；2026-08 有 0.12.5 release；GPL-3.0；Qt/C++ | Learn / Reject | 學大型曲庫 stable identity、metadata 失敗仍保留評分／playcount、watcher 失敗可觀測性；拒絕程式碼、平台與依賴 |

結論不是 NIH：這些成熟專案證明播放器真正困難在 seek 邊界、buffer 狀態、route/config change、資料 identity 與故障恢復。AeroMusic 保持 Apple-first-party，但應把相同問題製成 fixture 與狀態機，而不是複製依賴。

## Adopt／Adapt／Learn／Reject

- **Adopt**：Swift 6 strict concurrency；Apple 原生媒體控制、AVPlayerViewController PiP；security-scoped bookmark；offline-first catalog；產品／設計權威；分離 pinned 與 smart cache。
- **Adapt**：SwiftData 改為 ModelActor＋batch contexts＋index；AVAudioEngine 改成可驗證 sample timeline；夢幻 Canvas 改為情境感知靜態／低更新率兩種 composition；四主題只改 atmosphere。
- **Learn**：從成熟播放器吸收 ring buffer、seek overflow、configuration recovery、metadata failure preservation、stable identity 與 release regression fixtures。
- **Reject**：以 `@MainActor` 做大量匯入；把雙節點預載稱為 gapless；把 RMS 稱 LUFS；用空／自製影格濫用 PiP；直接接 SwiftData 私有 SQLite FTS；引入 ffmpeg/mpv/第三方 SMB；把 NAS 暫時離線當刪除；用第三方程式碼換短期速度。

## 最終目標架構

```text
SwiftUI (@MainActor)
  ├─ QueryFacade -> TrackPage / SourceSnapshot / QueueSnapshot (Sendable values)
  ├─ LibraryDataActor (@ModelActor; batch ingest, keyset pages, indices)
  ├─ SourceAccessCoordinator (bookmark resolution, scoped leases, reachability state)
  ├─ PlaybackCoordinator (control actor)
  │    └─ SampleTimelineScheduler -> AVAudioEngine render graph
  ├─ AnalysisScheduler -> BS.1770 / BPM / key / features (versioned, cancellable)
  ├─ CacheActor -> atomic files + manifest + pinned/smart eviction
  └─ VideoCoordinator -> AVPlayerView (Mac) / AVPlayerViewController + native PiP (iPad)
```

即時 render path 不做 allocation、鎖、資料庫、檔案 I/O 或 Swift concurrency hop；控制 actor 只排程已準備好的資料。跨 actor 不傳 SwiftData model，只傳 immutable snapshot／identifier。

## 可逆交付順序

1. **L3-A 資料與授權地基**：先加 DTO、ModelActor、batch scanner、scope lease 與 50k/NAS fixtures；不改 UI 資訊架構。
2. **P3-A 播放正確性**：建立 sample timeline、elapsed clock、seek overflow guard、interruption／route tests；先 PCM 後壓縮格式。
3. **A3-A 響度基準**：R128 versioned analyzer、ReplayGain policy、gain ramp／limiter fixtures；BPM/key 後接且低優先序。
4. **C3-A 可恢復快取**：partial＋atomic replace＋manifest＋checksum＋LRU；故障注入後再接預取。
5. **M3/U3 體驗**：真正分頁與搜尋、Metadata、iPad adaptive shell、靜態 Reduce Motion sky、opaque accessibility surfaces、原生影片 PiP。
6. **V3 發行證據**：MetricKit／OSLog signposts、實機 memory／thermal／background、sandbox、privacy manifest、App Review checklist。

每一步先新增／更新 Mission Center 任務與驗收命令；若某步不通過，只回退該 protocol implementation，不推翻其他模組。

## 一手資料

- Apple：[SwiftData 大量匯入與查詢（WWDC26）](https://developer.apple.com/videos/play/wwdc2026/8017/)、[#Index／#Unique（WWDC24）](https://developer.apple.com/videos/play/wwdc2024/10137/)、[ModelActor](https://developer.apple.com/documentation/swiftdata/modelactor/modelcontext)
- Apple：[Security-scoped URL](https://developer.apple.com/documentation/foundation/url/startaccessingsecurityscopedresource())、[bookmark options](https://developer.apple.com/documentation/foundation/nsurl/bookmarkcreationoptions/withsecurityscope)
- Apple：[AVAudioPlayerNode scheduleSegment](https://developer.apple.com/documentation/avfaudio/avaudioplayernode/schedulesegment(_:startingframe:framecount:at:completioncallbacktype:completionhandler:))、[媒體播放設定](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback)、[中斷](https://developer.apple.com/documentation/AVFAudio/handling-audio-interruptions)、[route changes](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes)
- EBU：[R 128 v4](https://tech.ebu.ch/docs/r/r128v4_0.pdf)、[Tech 3343](https://tech.ebu.ch/docs/tech/tech3343.pdf)
- Apple：[AVPlayerViewController](https://developer.apple.com/documentation/avkit/avplayerviewcontroller)、[標準播放器 PiP](https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-in-a-standard-player)
- Apple：[Materials](https://developer.apple.com/design/human-interface-guidelines/materials)、[Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)、[Motion](https://developer.apple.com/design/human-interface-guidelines/motion)
- Apple：[MetricKit](https://developer.apple.com/documentation/metrickit/monitoring-app-performance-with-metrickit)、[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
