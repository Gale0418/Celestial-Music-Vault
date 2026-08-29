# CMV 2.0｜V3 本機證據審查

日期：2026-08-27

## 驗證結果

- Rust workspace：`cargo fmt`、`cargo clippy --workspace --all-targets -- -D warnings`、19 core tests、1 shared fixture、8 FFI checks 全部通過。
- SwiftData／cache：scratch `swift test` 14/14 通過，包含 50k 批次資料、Metadata／ReplayGain tag parser、歌單 CRUD、最愛、評分、分析 profile、SHA-256 與 pinned/LRU。
- Swift↔Rust bridge：reconciliation、50k、playback、search、paged search、PCM analysis、Smart DJ smoke 全部通過；paged search 於 500 candidates 為約 2.5 ms。
- Xcode：macOS arm64 與 arm64 iPad Simulator（iPad Air 11-inch M4、OS 26.5）均 `BUILD SUCCEEDED`。
- Release app bundle 已驗證包含 `PrivacyInfo.xcprivacy`；Mac utility window source/build 回歸通過。
- universal Release archive `/tmp/CMV-macOS-universal.xcarchive` 已完成；App binary
  含 `arm64`／`x86_64`，Apple Development 簽章、`codesign --verify --deep --strict`、
  embedded entitlements 與 privacy manifest 均通過。Distribution 憑證／TestFlight
  仍未宣稱完成。
- iOS generic device arm64 Release compile 與 iOS Simulator arm64＋x86_64 universal
  Release compile 均 `BUILD SUCCEEDED`（`CODE_SIGNING_ALLOWED=NO`）；兩個輸出內的
  Rust archive 切片與 App binary 已用 `lipo -info` 核對一致。這是架構／連結驗證，
  不等同實機安裝、背景音訊或 Distribution 簽章通過。
- `Info.plist` 已補 `UILaunchScreen` 與 iPad portrait／landscape 四向宣告；新鮮
  iPad Simulator Release Validate 不再回報 launch/orientation 缺漏。Xcode 仍提示
  未使用 AppIntents framework，屬 informational，未引入不必要依賴。
- 新鮮 iPad Simulator app bundle 的 `Info.plist` 與 `PrivacyInfo.xcprivacy` 均通過
  `plutil -lint`，privacy manifest hash 與 source 一致；CoreSimulator 服務層的
  launch 卡頓另列環境 follow-up，不冒充產品驗收結果。
- `Native/scripts/qualify-app-store.sh` 已將送審前 bundle／plist／privacy／架構／簽章
  檢查集中化；macOS universal、iOS Simulator universal、iOS device arm64 三種輸出
  均通過 preflight。這降低換憑證或換實機後的維護風險，但不取代實機與 TestFlight gate。
- 50k 搜尋的 SwiftData 全表 predicate 已改為 actor 內 token→ID 倒排索引；命中後只
  回傳少量同步 snapshot，並在最愛／評分／播放／分析／掃描更新時刷新。完整 Swift
  12/12 的 150ms assertion 通過，並以 mutation regression 確認 snapshot 在最愛／評分／播放／分析更新後同步，避免以放寬門檻掩蓋效能退化。
- 上述搜尋修正後已重建固定 universal Development archive，並再次通過 strict
  codesign 與 `Native/scripts/qualify-app-store.sh`；artifact 不再沿用修正前輸出。
- 原規格中的睡眠計時器已補進 PlaybackEngine：15／30／60／90 分鐘可設定、可取消，
  到時在 MainActor 自動 pause 並清除狀態；Mac PlayerBar 與 iPad Now Playing 共用同一控制。
- 原規格中的內嵌封面流程已補齊：AVURLAsset async metadata 讀取 artwork、SwiftData
  external storage 持久化 `Track.artworkData`，Mac／iPad `AlbumWorldView` 依平台以
  NSImage／UIImage 顯示，缺圖時保留夢幻 celestial fallback；單張資料上限 20 MiB。
- Metadata 掃描現在對明確 `REPLAYGAIN_TRACK_GAIN`／`R128_TRACK_GAIN` comment 進行
  嚴格解析，並保存 track／disc number；未知 comment 不會被誤當作增益。新增 parser
  regression 後 Swift package 14/14 通過。
- 歌單播放已改為依 `trackIDs` 順序建立完整 PlaybackQueue，跨來源逐一解析 bookmark
  並持有 scoped lease 到播放結束，不再只載入第一首。
- stale／撤銷來源現在提供原生「重新授權」資料夾選擇器；更新 bookmark 會保留既有曲目與歌單，
  然後重新啟動差異掃描。這補上可在使用者介面完成的復原路徑；實體 Finder／檔案 App 與 NAS
  故障矩陣仍需在 Apple 實機驗證。
- 歌單 CRUD 已補齊：SwiftData repository 提供刪除操作，PlaylistHub 以原生 swipe action
  提供重新命名／刪除入口；新增刪除回歸後 Swift package 12/12 通過，Mac／iPad
  universal Release build 也通過。
- 離線快取已補上可用入口：TrackList 歌曲操作選單可釘選／取消釘選，AppModel 先解析
  security-scoped bookmark 再交給 pinned store；UI 以 pinned-only 狀態查詢刷新，smart
  cache 仍維持可淘汰邊界。
- iPad 影片 importer 現與 Mac 共用 `VideoWindowStore`，sheet 生命週期持有並釋放 security-scoped lease；Debug 雙平台 build 回歸通過。
- Mission Center Doctor：OK；既有歷史 Done 驗證債仍為 warning，沒有被改寫成通過。
- 最新 iPad Air 11-inch M4 Simulator Release bundle 已安裝並啟動（PID 98685）；等待首幀後視覺截圖正常，空佇列／mini player／夢幻深色表面可讀。
- 重新授權修補版亦已在同一 iPad Air 11-inch M4 Simulator 安裝／啟動（PID 23225）；等待 8 秒截圖
  `/tmp/cmv-ipad-reauthorize.png` 可讀，確認新 UI bundle 沒有啟動回歸。

## 已處理的 P1

### [P1] 播放入口尚未完成實際 queue 載入（已修正）

`AppModel.play(track:context:)` 現在會依 `sourceID` 取得 bookmark、解析並保留
security-scoped lease、拒絕 path traversal，再呼叫 `load(_:resolvedURLs:)` 與
`play()`. 歌曲列播放按鈕已接上此入口，避免空 queue 播放。

驗證：macOS 與 iPad arm64 build 成功；bridge／Rust／Swift 測試全數通過。

### [P1] 響度分析尚為可重現校準核心（已修正）

Rust analysis version 2 現在包含 K-weighting、400 ms／75% overlap、absolute
與 relative gate；fixture 改為 1 kHz 參考 tone，校準至 −23 LUFS。

限制：目前 fixture 仍是授權可重現的 tone，不等同完整節目材料認證；送審前仍需補授權節目 reference material。

## 尚待送審前處理

### [P2] AVFoundation metadata API（已修正）

`IncrementalScanner.swift` 已改用 `AVURLAsset` 與 async `load(.commonMetadata)`／
`load(.stringValue)`；隔離 Swift package 測試與兩平台 Xcode build 均無該 deprecation warning。

## critic_full 會議紀錄

三席 critic 已由 Antigravity bridge 送達，且均附固定 request id：

- C1 `9c5c951b-9f29-4fb4-bc4b-36b1d5aa53e7`：CONDITIONAL。原始 iOS bookmark、direct URL lease、未批次掃描、cache 原子替換／副檔名、檔案時間 LRU 均已修正；當時將 stale bookmark 自動重授權列為 P2 accepted-risk，後續已補自動 refresh 與手動重新授權入口。
- C2 `6c6bbfd8-4e72-4ac7-a81d-8fe7fc532311`：CONDITIONAL。播放 elapsed、duplicate／batch、cache、sample-rate coefficients 均已修正；N+2 proactive scheduling 列為 P2 建議。
- C3 `31e786ab-e41f-40ab-9435-286d681824b9`：CONDITIONAL。PlayerBar／NowPlaying、44pt targets、最愛／卡片死路與 mini-player 展開均已修正；Mac utility-window 已補上並完成雙平台 build 回歸。

最終 arbiter request `d83a7d91-8af2-4e1a-b3a1-351a1b30c2ed` 依規則以同一 request id 重試三次，均回 HTTP 500／`DELIVERY_UNKNOWN`；後續新 request `40d9c8fb-c191-46af-9b08-4b69ab9207fd` 仍失敗。Bridge health 恢復後改用 legacy cascade `a627c128-b840-4d40-a8ea-bb80d84037c3` 取得可驗證 arbiter JSON：`verdict=PASS`、無 blocking findings，兩項 P2 accepted-risk，並准許進入實機／TestFlight qualification gate。

### AERO-T4 focused bridge review

2026-08-27 以 request `c9b7a2d1-9db3-4c1c-8c5a-202d0f1f9b63` 取得 Antigravity focused review：
`CONDITIONAL`、無 blocking finding。建議明確指定 cargo PATH、iOS device／simulator
target mapping、multi-arch `lipo`、build phase 順序與 shell quoting；本次已逐項落實並以
macOS universal、iOS device arm64、iOS Simulator universal 編譯回歸驗證。剩餘條件仍是
實機與正式 Distribution／TestFlight gate，並非本機程式碼阻擋。

## 結論與下一步

V3 尚未完成，AERO-V3 留在 In Progress。三席 critic 所指出 P1 均已修正，arbiter 已
核准進入下一道 qualification gate；stale bookmark 的本機自動 refresh 與手動重新授權已補上，
剩餘 P2 建議為 N+2 預排與實體流程驗證，另有
明確的產品送審閘門（詳見 `Native/APP_STORE_GATE.md`）：授權節目 reference material、實機／沙盒／隱私矩陣，以及
Distribution 簽署 archive／TestFlight；目前已有 Apple Development universal archive，
但仍無 Distribution archive。
Electron 退場與正式送審保持未執行。
