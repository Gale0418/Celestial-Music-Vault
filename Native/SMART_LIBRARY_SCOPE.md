# CMV X14 智慧曲庫範圍決議

更新：2026-10-03

這份文件是 X14 的範圍評估交付，可作為本次評估的結案證據；它不是把延後功能誤寫成已完成，也不是 App Store 提交 gate。它只採用現有程式碼與本輪可追溯驗收紀錄能支持的行為。

## 採納到目前版本

### 1. 以既有加入日期排序代表「最近加入」

CMV 已有可持久化的加入日期。`Track.addedAt` 被定義為曲目首次進入曲庫的時間，重掃不會改變它（`Native/CMVCore/Sources/CMVDomain/Models.swift:20-21,56-57`）。SwiftData 記錄在新增時使用插入時間（`Native/CMVCore/Sources/CMVLibrary/LibraryModels.swift:47-49,93-104`）。

排序底座已存在：`LibraryTrackSort.addedAt`（`Native/CMVCore/Sources/CMVDomain/Models.swift:298-306`）、SwiftData 的 `addedAt` descriptor（`Native/CMVCore/Sources/CMVLibrary/SwiftDataLibraryRepository.swift:1541-1546`），以及曲庫 UI 的「加入曲庫時間」排序選項（`Native/CMV/CMV/LibraryViews.swift:628-683`）。

因此目前版本採納以下明確語意：

- 「最近加入」使用現有 `addedAt`，不另建日期欄位或重算規則。
- 依既有 repository 分頁與穩定次序顯示；同值時沿用標題／ID 的穩定 tie-break。
- 重掃、來源重新授權與 NAS 暫時離線不得把既有加入日期改成目前時間。
- `modifiedAt` 是來源檔案修改時間，不是加入時間；不能拿它補造或推導 `addedAt`。
- 這代表既有排序能力；它不宣稱已經有獨立的「最近加入」首頁或智慧歌單。

### 2. 保留既有播放歷史資料

SwiftData 已保存 `playCount`、`skipCount` 與 `lastPlayedAt`（`Native/CMVCore/Sources/CMVLibrary/LibraryModels.swift:62-64`）。播放／跳過會經由 repository 更新計數與最後播放時間（`Native/CMVCore/Sources/CMVLibrary/SwiftDataLibraryRepository.swift:1027-1037`），AppModel 的兩條播放路徑也會呼叫這個操作（`Native/CMV/CMV/AppModel.swift:1632,1697`）。

因此目前版本採納「本機保存播放歷史」作為既有資料行為，並讓它繼續供現有 Smart DJ 與資料保全使用；它不是本次新增的最近播放 UI，也不代表已有播放歷史頁面。

## 延後到下一版本

### 最近播放 preset

延後建立面向使用者的「最近播放」固定入口。雖然資料已有 `lastPlayedAt`，目前 `LibraryTrackSort` 只有 `addedAt`、`releaseDate`、`modifiedAt` 等排序，沒有 `lastPlayedAt`（`Native/CMVCore/Sources/CMVDomain/Models.swift:298-306`）。現在加入 preset 會同時引入缺少歷史時的排序語意、分頁穩定性、跨重啟 UI 讀取與無障礙驗收；這些證據尚未形成 X14 交付物。

下一版本若採納，驗收契約應固定為：最新 `lastPlayedAt` 優先、沒有歷史的曲目置底、同時間以標題／ID 穩定排序；首次播放、跳過、重啟、分頁與空結果都要有 repository／UI 回歸證據。現階段不得在商店文案寫成已有「最近播放」檢視。

### 規則 Smart Playlist

目前 `PlaylistRecord` 儲存的是名稱與固定 `trackIDs`（`Native/CMVCore/Sources/CMVLibrary/LibraryModels.swift:129-153`），repository 也只提供一般歌單 CRUD（`Native/CMVCore/Sources/CMVLibrary/SwiftDataLibraryRepository.swift:1048-1063`）。`Native/CMVCore/Sources/CMVAnalysis/SmartDJ.swift:1-50` 是依評分、最愛、播放訊號與聲學資料排序並產生理由的 Smart DJ，不是可保存、可重算的規則歌單。

因此延後規則歌單，不把 Smart DJ、手動歌單或全量掃描改名成 Smart Playlist。下一版本若實作，最小模型應只使用本機已有欄位，保存 Codable 規則、固定排序與上限，在 actor 內分頁評估並顯示符合理由；規則結果不能因 NAS 暫離線而刪除曲目或手動歌單資料。這項工作應等 `AERO-Q12` 佇列契約與 `AERO-I13` 曲庫／歌單操作收斂後再排期（`MissionCenter/tasks.md:43-46`）。

### 歌詞

受查的 `Track` domain model 沒有歌詞屬性（`Native/CMVCore/Sources/CMVDomain/Models.swift:3-27`），目前也沒有 X14 所需的歌詞儲存欄位、解析器或畫面證據。因此延後歌詞，不引入網路 provider、帳號、雲端同步或第三方服務。

下一版本若要做，最小範圍應限於媒體內嵌的可選文字、非同步載入；缺失或格式不支援只能顯示空狀態，不能阻塞索引、播放或來源重掃。未完成格式矩陣、資料遷移與 VoiceOver 驗收前，不得宣稱支援歌詞。

### 背景來源變更 watcher

目前 `IncrementalScanner` 是 actor 內的目錄列舉與批次 metadata 掃描（`Native/CMVCore/Sources/CMVLibrary/IncrementalScanner.swift:41-70`）。AppModel 目前提供來源狀態探測（`Native/CMV/CMV/AppModel.swift:818-902`）與排程／串行掃描（`Native/CMV/CMV/AppModel.swift:1823-1844`）；受查路徑沒有 `FSEvents`、`DispatchSourceFileSystemObject` 或等效檔案事件 watcher。

因此延後背景 watcher，不把啟動時狀態探測、重新授權或手動重掃說成背景監看。下一版本若實作，事件只能作為 debounce 後的掃描提示；只有來源可達且完整掃描成功時才能 reconciliation 遺失項目，NAS offline、權限失效、事件遺失與部分掃描都必須保留既有曲庫／歌單資料。需要另做新增、修改、移動、刪除、事件風暴、事件遺失、NAS 重連與 50k 壓力矩陣。

## 可重現的驗收評估

### 已有證據

- `Native/CMVCore/Tests/CMVCoreTests/MetadataOperationTests.swift:162-174` 有 `testAddedAtDateSortIsStableAcrossPages`，直接驗證加入日期排序在分頁間的穩定性。
- `MissionCenter/smoke-tests.md:29-31,101` 記錄既有 50k fixture／逐頁讀取／搜尋與 reconciliation 證據；`MissionCenter/tasks.md:35,37,43` 也記錄 50k 曲庫、搜尋與來源安全的既有驗收背景。
- `Native/CMVCore/Sources/CMVLibrary/LibraryModels.swift:62-64`、`SwiftDataLibraryRepository.swift:1027-1037` 提供播放歷史保存的程式證據；這不是最近播放 preset 的測試證據。

### 本輪狀態

本輪評估採用 root 提供的實際測試證據：metadata 相關 6-pass 回報，以及 `/tmp/cmv-core-tests-20261003.log` 的完整 77-test log。該 log 顯示 `testAddedAtDateSortIsStableAcrossPages` 通過、`testFiftyThousandTrackReconciliationPersistsInBatches` 通過（83.715 秒），完整套件為 77 tests、0 failures。這是本輪可追溯的核心資料證據，不是對未執行項目的推測。

這份 log 不提供獨立的 raw 50k／150 ms benchmark，因此本文件只主張 50k reconciliation 測試通過，不把 `MissionCenter/smoke-tests.md:101` 的歷史 150 ms 斷言描述成另外一個本輪效能 Pass。Mac／iPad build、UI、實機、歌詞與 watcher 並未由這份核心 log 證明。

若需在另一個 checkout 重現，至少可執行：

```sh
swift test --package-path Native/CMVCore --filter MetadataOperationTests.testAddedAtDateSortIsStableAcrossPages
swift test --package-path Native/CMVCore --filter testFiftyThousandTrackReconciliationPersistsInBatches
```

若目前測試名稱或 runner 已變更，應先以 source／`swift test --list-tests` 校正命令；本輪結果以 `/tmp/cmv-core-tests-20261003.log` 為準，不把文件中的命令本身當成測試結果。

## 功能宣稱邊界

目前版本可以依實際 build 證據描述「曲目可依加入曲庫時間排序」及「播放歷史在本機保存並供既有功能使用」。

目前版本不得宣稱：

- 有獨立最近播放檢視或最近播放 preset。
- 有可保存、可解釋、可重算的 Smart Playlist。
- 有歌詞顯示或歌詞服務。
- 有背景檔案變更 watcher 或即時自動重掃。
- X14 的延後功能已實作、已通過實機驗收，或已上架；本次只能結案「範圍評估」，不能把評估結案當成功能全完成。

本次 X14 評估可結案：採納既有加入日期排序與播放歷史保存，其他切片明確延後。Apple 審核、測試者、Sandbox、權利來源或其他外部發布 gate 不在本文件範圍；那些狀態須以各自的實際證據記錄，不能由 X14 評估推定。
