# AERO-M6 批次操作與排序回歸

## 範圍

2026-09-08 主人授權先推進不依賴月環體感／Apple 登入的工作。本輪只處理歌曲多選、批次操作與排序；不擴張 Q12 完整佇列持久化、I13 metadata 管理或 SD4 Smart DJ。

## 已確認問題與修正

- `orderedSelectedTracks` 在 await 曲庫 ID 後才讀取選取集合，會混合不同時間的使用者意圖。改在點按時捕捉 IDs、query、sort、ascending、random order。
- 批次動作可重入，快速連點可能重複加入。共用入口同步設置忙碌旗標，所有返回路徑用 defer 復原；只停用相關選取控制，不覆蓋全畫面。
- 成功後無條件清空會抹除新查詢的選取。成功時僅在相同 query generation 扣除已處理 IDs；失敗保留選取。切換查詢仍可使用，已送出的動作遵循送出時快照。
- 全選讀取期间禁止勾選／取消全選互相覆蓋；尚未顯示新查詢或隨機順序尚未準備完成時不送出批次動作。
- 排序／全選列原為不可捲動 HStack；改成水平捲動，保留文字標籤與原生按鈕。

## 獨立檢查

Antigravity 首次 request `cmv-m6-review-20260908-01` 明確回報沒有檔案工具，不能當 source review。第二次 `cmv-m6-snippet-20260908-02` 提供實際 608–690 行片段，確認 await 選取漂移與無條件清除問題。採納 snapshot、防重入、defer 與 random-ready guard；「刪除必然留下孤兒 ID」不成立，因 fetchPage 原本會清除選取，未據此擴張修改。

Luna 僅負責 core 排序／分頁測試與唯讀檢查，不與主代理同時寫 UI。

## 驗證進度

- 第一輪 Mac Release：`/tmp/cmv-m6-macos.log`，BUILD SUCCEEDED。
- 原測試版 Mac UI 基線：1,967 首曲庫選取第一首後，批次列位於選取列下方，播放所選、加入接下來播放、取消選取、移出 CMV 可見；沒有歌單時加入歌單停用。這不是本輪新 binary 驗證。
- 最終 Mac／iPad Release：`/tmp/cmv-m6-macos-final.log`、`/tmp/cmv-m6-ipad.log` 均 BUILD SUCCEEDED；測試 App strict codesign 通過，執行檔 cmp 與 Mac build 一致。
- 四種欄位升降冪、搜尋跨頁與 trackIDs 往返排序的固定 fixture 通過；整合者以 `swift test --package-path Native/CMVCore --scratch-path /tmp/CMVRouteTests --skip-build --filter CMVCoreTests.testLibrarySortFieldsRemainBidirectionalAndPageStable` 確認 1 test／0 failures，保存 `/tmp/cmv-m6-sort-verified.log`。未重跑 full suite 或將此測試宣稱為 50k 效能基準。
- 最新 Mac 測試 App PID 29944：單曲選取後加入佇列成功；空佇列沿用既有自動播放行为。暫停第一首後追加「1925」，原曲仍保持暫停，右側新增第二列；返回歌曲頁選取已清除，可重新操作。全選顯示 1,967 首，取消後恢復全選按鈕。
- 未對使用者曲庫執行刪除／垃圾桶測試；目前没有歌單，故新增歌單內容的 runtime 成功／失敗路徑仍待驗。窄幅 iPad／VoiceOver 仍待實機或有資料的 Simulator 驗證。
- 不以 source review、Simulator build 或 CUA 等待時間宣稱 iPad 實機、VoiceOver、效能或月環感知驗收通過。

## Mission Center

`tasks.md` 的 M6 維持 In Progress 並更新下一步。Rust resume 回 derived view stale；sync 與 transition AERO-M6 Review 都回 command_error；失敗後重新讀 tasks.md 確認狀態未變。status 可正常讀取 canonical tasks，但 sourceFresh=false。未手改衍生摘要、未使用 Python fallback，沒有宣稱任務已 Done。

## 剩餘風險與下一步

2026-09-08 續驗：Swift 完整 39 項測試通過（`/tmp/cmv-f25-20260908.log`），其中 `testExcludedTracksStayHiddenAfterRescanAndLeavePlaylists` 使用獨立 in-memory store，確認批次加入重複 ID 去重、移出同步移除歌單引用、重新掃描不復活已移出歌曲，以及還原時恢復歌單次序。這是 repository 資料契約的通過證據；不替代按鈕、VoiceOver 或實體檔案端到端驗收，未變更使用者曲庫。

本輪為 M6 可交接切片，不是全專案結案。保留有資料的 iPad 窄版／VoiceOver、歌單批次與安全移出流程驗收；完成後才關閉 M6 並解鎖 Q12／I13。F26 的月環／右欄感知驗收與 Apple 帳號阻擋各自保留，互不冒充。
