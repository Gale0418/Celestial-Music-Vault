# 月環、接下來播放與背景工作稽核

## 驗收狀態

**Mac 感知已有通過回饋，完整可靠性／iPad 驗收仍未完成。** 使用者先前在第一輪 Release 試播回報右欄仍卡；2026-09-08 10:49 最新回饋已明確表示「沒有卡頓」。下方早期失败紀錄保留作為修正歷程，不代表最新感知結論。
目標是維持右欄捲動與月環連續性，並完成播放／掃描／快取相關可靠性及較低資源 iPad 的驗證。
最終視覺方向是大量音柱形成放射光芒，不以減少柱數作為最終效能解法。
使用者補充每根音柱每半秒或一秒輪動；目前保留四秒整圈掃描與逐柱平滑起伏。最新白根主題色柔霧／外側藍影樣式已完成 Mac 截圖驗證；iPad 實機與 FPS 尚未測量。資源預算新風險另見 `IPAD_RESOURCE_AUDIT_20260908.md`。

### 05:17 整合版複驗

- `/tmp/cmv-integrated-performance-build.log`：Release BUILD SUCCEEDED。
- `/tmp/CMVCacheTests-integrated.log`：35 項測試，34 通過、1 失敗。快取同尺寸修改檢測已通過；五萬首暖搜尋耗時 0.275056583 秒，超過 0.15 秒門檻。測試與介面試播同時進行，存在資源競爭，尚不能判定單獨執行的效能。
- `/tmp/cmv-integrated-playing-20260908.sample.txt`：主執行緒 109 個樣本中 96 在 NSHostingView / GraphHost.flushTransactions，仍有大量 FlexFrame / UnaryChildGeometry 版面運算。取樣不是 FPS；不能宣布卡頓已修好。
- CUA 成功進入歌曲頁並送出播放第一首操作，但後續畫面回讀逾時，尚未可靠驗證播放畫面及右欄捲動。

### 05:20 後續定位

- 關閉本次測試 app 後單獨重跑五萬首測試仍失敗（暖搜尋 0.499205292 秒）；不能只歸因於試播競爭。證據：`/tmp/CMVCacheTests-search-isolated.log`。搜尋優化交由 cache_io_fix，門檻不變。
- 月環插值原本固定在 1/60 秒內完成，而影片 meter 約 30 Hz。新增 snapshot 的實際發布間隔（限制 1/60～0.1 秒），使前後樣本依來源節奏平滑銜接。這是動畫連續性修正，尚未經視覺驗收，不能宣稱解決布局熱點。
- iPad Simulator Release 相容性 build 已啟動，log：`/tmp/cmv-ipad-performance-build.log`；不得在看到終態前記為通過。

### 05:28 搜尋整合驗證與月環對照準備

- 上述 iPad Simulator Release build 已確認 `BUILD SUCCEEDED`。此結果早於後續搜尋快取及月環容器切換修改，不能取代最終版本跨平台檢查。
- 搜尋新增單一最近 query 的匹配 ID 快取；canonical tokens 為 key，保留 substring AND 語意，排序/分頁仍在取得匹配後執行。所有索引寫入/刪除會清除快取，不保留無上限的歷史查詢。
- 最終搜尋版本整合 core suite：`/tmp/CMVCacheTests-bounded-search-full.log`，**35 tests / 0 failures**，包含五萬首暖搜尋 `<150ms` 原門檻，未放寬。
- `git diff --check` 通過。macOS 月環對照 build 已啟動：`/tmp/cmv-ring-ab-build.log`。
- 暫時的 `CMV_RING_HOSTING=1` 環境變數啟用月環 nested host，預設直接 Canvas。兩種配置共用同一 binary 做量測；此診斷開關及最終預設尚待實測決定，不是已驗收的正式效能修正。
- 本機 xctrace 確認提供 SwiftUI、Animation Hitches、Time Profiler templates；尚未錄製這輪 trace。不可把 template 可用當作已完成分析。

### 05:39 實機播放及容器對照

- `cmv-ring-ab-build.log` 已 BUILD SUCCEEDED。相同 binary 的 inline / nested host 均透過 CUA 成功播放第一首「1・2・3」影片；inline 截圖確認進度 0:20 → 0:43，右欄捲動後顯示「千本桜」等後段項目。操作成功不等於已量到流暢 FPS。
- inline：`/tmp/cmv-inline-ring.sample.txt`，3 秒 / 10 ms 取樣，主執行緒 38 個樣本，其中兩處 GraphHost.flushTransactions 分別 13、18；ps 快照 CPU 45.2%。nested：`/tmp/cmv-hosted-ring.sample.txt`，主執行緒 63，兩處 GraphHost 分別 50、10；ps 快照 CPU 101.1%。兩次取樣的播放時點與捲動重疊不完全相同，不得宣稱嚴格性能提升倍率或 FPS。
- 未得到 nested host 改善的證據，移除月環的 wrapper 及暫時環境切換，保留直接 Timeline/Canvas。背景 wrapper 未改動，仍待檢查其必要性。
- xctrace launch 誤對應到桌面舊 bundle；停止該次測量，改以確認過的測試 PID 附加。兩份 SwiftUI trace 都回報 no SwiftUI data；Animation Hitches 產出近 4 GB，停止以免磁碟耗盡。三份不可用 trace 及確認無程序占用、同時段產生的三個 instruments*.ktrace 已移除，可重新錄製；不保留假通過證據。
- 已終止本次啟動的測試 app 與錄製 helper。清理後 `/tmp` 所在 APFS 可用 8.4 GiB；未刪音樂、專案檔或桌面 app。
- 核心 35/35 結果仍有效；移除診斷切換後的 app 編譯及最終體感驗收尚未完成。

### 05:42 可見缺陷修正

- `cmv-direct-ring-build.log` 已確認 exit 0。上一轮實際截圖顯示外伸音柱碰到側欄邊界：NowPlaying 的 mediaWorld 現在保留四周 44 點（總寬 88）音柱空間，直向/橫向直徑計算同步扣除此空間，避免只按中央圓形排版。
- 右欄目前播放樣式改為同時比對佇列 index 與 track ID，避免相同曲目重複排入時多列同時高亮。混合影音路由另有 firstIndex(ID) 的 occurrence 風險，已交 playback_review 唯讀確認，尚未宣稱整條重複播放路由已修好。
- 上述新 UI 修改的編譯：`/tmp/cmv-ring-layout-build.log`，仍待終態；截圖驗證未完成。

### 05:45 配置驗證與下一個可靠性修正

- `cmv-ring-layout-build.log` 與 `cmv-ring-layout-ipad-build.log` 均確認 BUILD SUCCEEDED。
- CUA 最新實際播放截圖確認四周音柱不再切到側欄。測試版 `/tmp/CMVPerformanceRun/CMV.app`、PID 15103 留在開啟狀態供使用者體感驗收，已送出非阻塞回饋問題。當時 iPad build 仍在進行，不用該時段 CPU/FPS 宣稱性能。
- playback_review 確認混合路由 occurrence bug：`[A,A,V]` 第二個 A 結束時 firstIndex(ID) 取回第一個 A，可能反覆播放第二個 A；`[A,V,A,V]` 也可能跳回前段 V。必須記錄全路由 occurrence 並區分 engine audio segment local index。
- cache_io_fix 接手此最小修正（AppModel 路由，必要純函式及回歸測試），主代理不與其同時修改 AppModel。此問題尚未修好，完整目標維持未完成。

### 05:49 音柱靜音停留重現

- 直接從目前 `AppModel.swift` 擷取原始 `AudioEnergySnapshot` / `AudioEnergyState`，透過 Swift stdin 執行，未另寫一份替代邏輯。
- 序列：`receive(1)` → 25 ms → 記錄 writeIndex → `receive(0)`。輸出 `zeroAdvancesHistory=false`，證實播放中零音量被提前 return，舊波形不流出。
- 已併入 cache_io_fix 當前 AppModel 所有權：零音量應遵循限流、衰減與歷史寫入；真正暫停維持獨立處理。待修正後重跑相同原始類別測試，尚未記為通過。
- 使用者體感回饋仍待回覆，測試 app PID 15103 已確認仍執行，不重啟或覆蓋其 bundle。

### 靜音修正的直接驗證

- 對 worker 修改中的實際 `AudioEnergyState` 重跑同一 Swift stdin 序列，輸出 `zeroAdvancesHistory=true`、`zeroDecaysEnergy=true`、`interpolationBounded=true`，exit 0。只支持零樣本歷史與衰減修正，不等於整個 AppModel 或流暢度驗收完成。
- 路由修正仍在整合：主代理要求避免 route getter 每次配置整個 UUID 陣列，並涵蓋「純音訊第二個 A 正在播放時追加影片」的 occurrence 保留。待 worker 完成後整合編譯與回歸。

### 路由整合與獨立審查

- worker 已完成 full-route occurrence / segment offset；主代理核對 NativePlaybackEngine 在 callback 前更新 currentIndex，並確認 append 使用加入前 displayQueue index、清除路由同步清除游標。補正 fallback 缺少 return，以及 `await playback.load` 後的請求 generation 檢查。
- `/tmp/CMVRouteTests-full.log`：36 tests / 0 failures。新增測試只驗證純 occurrence resolver；沒有冒稱 AppModel 端到端自動 advance 已測完。
- `/tmp/cmv-final-route-macos.log`、`/tmp/cmv-final-route-ipad.log` 均 BUILD SUCCEEDED；macOS bundle strict codesign verify 與 git diff --check 通過。執行中的 PID 15103 仍是前一版，不含這批新路由／靜音修正。
- CodeRabbit 使用隔離快照 `/tmp/cmv-review-z07amU`，12 個變更檔 + 2 個必要參照 Swift 檔，共 367636 bytes；無媒體、圖片、建置產物，未修改原 repo 分支或提交。CLI 0.7.6 已登入。
- 首次命令於送審前因無預設 base branch 失敗；明確 `--base main` 後第二次命令已進入 reviewing。隔離 repo 無 remote，CLI 明示使用 free CLI allowance。記錄 `/tmp/cmv-coderabbit-20260908-base.ndjson`，結果尚未完成；不計為審查通過。

### CodeRabbit 完成與核對

- 第二次命令 exit 0，review_completed，12 reviewed files，**2 issues / minor**。本輪共 2 次命令嘗試，第一個在基準分支前置檢查失敗，只有第二個進入 review；未使用付費 credits。
- 接受 LibraryViews 的 separatePlayer 問題：fallback AlbumWorldView 原本讀 audioIsPlaying，獨立影片播放時會停動畫；改為低頻共用 getter isCurrentMediaPlaying。
- 拒絕 supersession 測試的「timeout 導致閘門不釋放」說法：`await fulfillment` 不拋錯，timeout 返回後緊接 `gate.release.signal()`，且此行位於 `await older.value` 之前，現有路徑不會因所述原因卡住。未為誤報新增修改。
- core 36/36 結果不受上述 UI 單行修正影響；最終再次雙平台編譯記錄為 `/tmp/cmv-reviewed-macos.log`、`/tmp/cmv-reviewed-ipad.log`，尚待終態。

### 最新交付驗證狀態

- `/tmp/cmv-reviewed-macos.log`、`/tmp/cmv-reviewed-ipad.log` 均已 BUILD SUCCEEDED，測試複本 strict codesign verify 通過。
- 關閉舊測試 PID 15103 後更新 `/tmp/CMVPerformanceRun/CMV.app`；最新 PID 18252。CUA 已確認新版本播放「1・2・3」影片到 0:16，音柱未裁切。桌面旧 app 未覆蓋，原 repo 未提交或推送。
- CodeRabbit 隔離資料夾已刪除，僅保留 NDJSON 結果；原始碼與測試證據保留。沒有活躍的 review/build/worker 工作需等待。
- 已完成本輪程式修正、核心 36/36、雙平台編譯、獨立審查及基本實播；**仍未證明右欄與歌曲頁同樣順暢，也未取得使用者對逐根輪動節奏的確認**。目前測試版保留開啟供回饋，AERO-F26 不標 Done。
- 重複 occurrence 有純 resolver 測試及引擎 callback wiring review；沒有錄到重複同 ID 的完整 AppModel 自動 advance 實播，不以此宣稱端到端覆蓋。

## 證據及判讀

| 證據 | 能支持什麼 | 不能支持什麼 |
| --- | --- | --- |
| 舊桌面 Debug sample，主執行緒 48/71 samples 在 layout/render | 應查版面及觀察更新 | 不是 FPS、不是 CPU 百分比 |
| 第一輪 Release 成功播放曲庫影片，使用者回報仍卡 | 現有修正尚未達標 | 不能以 build 成功關閉驗收 |
| Release sample footprint 185.4 MB，主執行緒 120/233 在 layout | 沒有全佇列 PCM 塞滿 RAM 的證據 | 不能排除 I/O 競爭或影片解碼影響 |
| 動畫隔離版取樣仍大量處於 AttributeGraph / layout | 隔離本身尚不足以證明改善 | 沒有可靠的自動捲動或幀率證據 |
| prefetch 同步 copy/hash 占用 cache actor | 切歌的 cachedURL 可被背景預取阻塞 | 不能當成月環唯一根因 |

原始取樣：

- `/tmp/cmv-perf-20260908.sample.txt`
- `/tmp/cmv-release-playing-20260908.sample.txt`
- `/tmp/cmv-isolated-startup.sample.txt`
- `/tmp/cmv-isolated-playing-20260908.sample.txt`

CUA 曾有 timeout / noWindowsAvailable；部分操作實際成功但回讀失敗。不得把工具等待秒數當作 UI 延遲，也不得把未可靠送達的捲動算通過。

## 已確認與正在修改的問題

1. `NowPlayingView` 透過共用播放 revision 與內嵌進度 getter 觀察秒數，牽動大型 layout。拆分 `PlaybackProgressView`，鏡像低頻播放／音量／控制狀態。
2. 右欄使用 LazyVStack 及零距離評分拖曳；改原生 List、SpatialTapGesture。效能效果仍須實測。
3. 背景與月環每幀更新仍會進入 SwiftUI graph；嘗試獨立 hosting graph，保持 hit-test 穿透與固定 proposal，不宣稱已解決。
4. 播放操作含多層 ViewThatFits + ScrollView，反覆量測同一組 controls；簡化為單一水平捲動區。星空改 background，不參與 navigation 尺寸提案。
5. 清除佇列未失效 AppModel 的準備 generation，慢速載入可在清除後重新播放；已補失效。
6. 掃描／播放的 bookmark resolve 原在 MainActor；改背景解析，拒絕覆蓋更新的授權；取消不視為來源離線。
7. 加入來源在主執行緒解析既有 bookmark／建立新 bookmark，且 `hasDirectoryPath` 只看 URL hint；改序列化背景準備，真正查目錄屬性，資料庫錯誤不偽裝無既有來源。
8. prefetch actor 被整檔 copy/hash 占用；Luna 正在改唯一 staging、短 commit、取消／supersession；主代理要求 UUID token 避免 ABA，並補 deterministic admission 測試。

## 最終驗收清單（尚待逐項取得證據）

- 同一媒體、相同佇列長度、相同視窗尺寸，右欄與歌曲頁捲動比較；不能一邊編譯一邊宣稱 benchmark。
- 月環角度連續、音柱依真實音訊變化；確認使用者所選的半秒／一秒語意，再做高密度壓測。
- 播放、暫停、快速前後切歌、影片與音訊切換；進度拖曳後切歌不可 seek 到新曲的舊位置。
- 清除期間有 pending load／bookmark I/O 時，佇列不能復活。
- 佇列更新、評分、隨機、重複、睡眠計時器不得因降低觀察範圍而漏刷新。
- 大型檔案預取、取消、同 track 競爭、既有快取查詢及 checksum／rollback。
- 慢速或離線來源、重複 folder drop、無 trailing slash 目錄、檔案誤投、背景掃描期間捲動及切歌。
- macOS Release、受影響 Swift 測試、完整 Swift suite 結果；共用 SwiftUI 變更需 iPad build，未跑不得稱通過。
- 最新產物的簽章／entitlements、實際啟動與使用者感知驗收；完成前不替換桌面舊版。

## 協作與來源

- Impeccable optimize / craft-floor：保留既有 PRODUCT.md、DESIGN.md 視覺方向，量測前後、不以少畫內容替代驗收。
- Apple：<https://developer.apple.com/videos/play/wwdc2025/306/>。
- Antigravity `cmv-scan-audit-20260908-02` 有完成 marker，但工具環境無讀檔權限，僅當假說提示，非 source review 通過。
- Mission Center Rust resume 回 derived view stale；sync 回 command_error。未使用 Python fallback；AERO-F26 保持未結案。
