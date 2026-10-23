# 2026-10-08 修正版結案審查準備包

這是主代理凍結正式 completion council 的審查輸入，非評論結論或任務 Done 證明。歷史測試結果按各自時間保留；以下最新增補優先。舊 S01／S02 與其結論保持原樣。

本候選修正標準 m4a 的曲／碟序匯入。95 份 production source 的 build 前／後／現行 SHA 一致；相對前候選只變更 `AudioMetadataParser.swift` 與 `IncrementalScanner.swift`。新增測試另有 source SHA 與修正前失敗／修正後通過收據。正式成品入口：[Distribution 檢查點](../Native/DISTRIBUTION_CHECKPOINT_20261008.md)。

## 可直接核對的證據

以下路徑均相對 ignored `.cmv-local-evidence/2026-10-08-task-zero/`；不將私人資料庫、聯絡資料或簽章識別資訊寫入公開文件。

| 範圍 | 本次直接結果 | 證據 |
|---|---|---|
| metadata 修復 | 標準 `itsk/trkn`／`itsk/disk` nil 已重現；精準 classifier 與無關 tag 拒絕，parser／205 scanner／既有 parser focus after exit 0 | `metadata-track-disc-fix/`；27 payload manifest `40735411…adf1f` |
| 最新建置與資格 | 兩 Development、四 Distribution bundle；95 source exact、簽章/profile/UUID、PKG 簽章直接親核 | `metadata-fixed-primary/`；140 payload manifest `14a151a9…020f2` |
| 最新完整成品 | 388 檔、359,983,193 bytes，父代理逐檔 SHA／bytes 相符；含 95 source、archives、exports、解包 App 與 raw | `metadata-fixed-artifacts/`；manifest `5ceb3bd2…710a` |
| Mac 修復後實際匯入 | 同位置更新 App；205 小檔九 metadata 各 205 exact；Song Info T200 曲200／碟3；六檔／九表／queue／prefs 還原成立 | `mac-metadata-fixed-runtime/`；13 payload manifest `55d5720a…c130` |
| Mac 排序 | 四欄八方向的可見頭尾、第200／201首符合 oracle；random 追加頁面前後共同頭尾一致；六檔／九表還原 | `mac-sort-matrix/`；218 payload manifest `a54abc4a…8882`；原 Development final-v2 scope |
| iPad M6 前一輪 | 真2 selected、queue19→21、Cancel、九表／queue／prefs 還原；Play 所選未觀察到變更，仍 UNKNOWN | `ipad-m6-matrix/`；54 payload manifest `56f7660c…5b2` |
| Gemini 商店文案 | Gemini 完成三語活潑文案；繁中白月光句保留；ASC15目標＋18保護欄 fresh 回讀 exact，首次 WhatsNew 僅本機 | `mac-queue-gemini-copy/`；既有封存，未重新委派或送審 |

95 source 同一性不把不同 Development／Distribution executable 當同一 installed runtime。上述排序是可見取樣與邊界觀察，不能寫成 205 GUI 全列捕捉；random 全 viewport 陣列因多一個前項而不同，共同尾序列與末五項一致。

## 人工結果與排除

PiP 進入／暫停／播放／返回、時間／曲目／pause state、兩端整體聽感、iPad 整體旁白及窄 picker Cancel 均沿用主人 USER_PASS；五萬首等待約一分鐘為接受標準。Mac 旁白、全斷網、Bluetooth、AirPlay 為 USER_EXCLUDED；iPad 完整 10GiB 實填 USER_NOT_REQUIRED，不再要求塞滿裝置。這些項目不重測，也不以舊 UNKNOWN 阻擋。

## 還未清零的範圍

iPad 最新 Development 2.0(1) 同 ID 安裝／啟動已直接讀回；停機基準與還原後九表 schema／全部欄位 rows 相同，queue 僅 revision232→235，prefs 僅 SKTransactionUpdatesLastChecked 改變。205素材僅拷入隱藏appData，正式GUI匯入與 PlaySelected仍 UNKNOWN。原 cleanup 指令失敗7000，最後Documents清單0；沒有中間讀回，不能說刪除成功或證明原Documents全部保留。實際選到另外的iCloud Source-A，scan timestamp仍null；已改用既有iCloud測試目錄內本次owned專用資料夾正常Files續驗。其餘任務仍依 `tasks.md` 的實際條件：Q12 的完整 mixed EOF／gapless 與 iPad queue 矩陣、I13 剩餘進階欄位／批次矩陣、U25 完整動畫循環／背景停動／短字靜態／效能、SD4 與實際 NAS slow／stale 的缺口未升格。現有 injected 工程或真 SMB 成功讀回，不能冒稱實際 slow／stale 已觸發。

同 RC 授權商店截圖、無剪輯示範、正式結案評論、上傳／TestFlight／送審仍待完成。Distribution 出口尚未安裝為 runtime；沒有上傳、提交或發布。本輪 focused 回歸通過不表示前候選 Swift38／Rust34 已全部在修復後重跑。

## 正式 completion council 的必要預算

依 installed Mission Center `references/completion-critic-council.md`，正式 gate 需三位獨立 critic 加獨立 arbiter；主代理整理與封存 worker 不算評論席。規則原文：

> Do not dispatch unless the user has explicitly approved the total budget, per-seat budget, tool budget, and wall-clock budget for this gate.

主人已明確回答「核准上述四種預算」：總量30,000 tokens、每席7,500、工具總32次／每席8次、整個gate45分鐘，包含必要delta共用預算。三位獨立Luna critic加獨立Luna arbiter；現行本機結果封存後dispatch，缺口保留UNKNOWN，仍不可冒稱Full Council PASS。授權記錄見 `critic-authorization-20261008.json`（local-only，未納入版本控制）。


## 2026-10-08T10:21:45.614885+08:00 iPad 最新候選直接驗收

封存 `ipad-metadata-fixed-runtime/`：29 payload，manifest448b7d4…f377b；guard唯讀診斷2 payload，manifest3b049f16…281d8。父代理逐31payload SHA／bytes全相符，另直接用原始本機SQLite與queue/plist重核完整還原；不保存私人原始DB到公開文件。staged binary SHA只綁定安裝CLI與裝置AppURL，並非從裝置binary直接讀回SHA。修正版Mac剩餘mixed EOF與iPad正常provider匯入各有唯一GUIoperator；尚未產生它們的PASS。


## 2026-10-08T11:00:56.321093+08:00 最新 provider 與隔離 queue 驗收（取代前述 ongoing）

正常 Files「立即下載」後重選同owned資料夾，iPad真正匯入205，九metadata各205 exact、source available與成功掃描時間非null。父代理直接SQLite核對全部205。T001/T002已真選取，原生控制Play未改queue；依fresh screenshot點畫面按鈕後，佇列僅T001/T002，T001播放frame成立；raw兩UUID全owned/index1/history2，第二首獨立播放frame仍UNKNOWN。最新還原9表完整schema／columnrows exact，queue除revision232→235 exact，prefs全部key exact；正常GUI已回原paused0:00/5:50。封存`ipad-provider-latest/` manifest f990815d3318445cf833bda71bcc594cdf9becaf1174b72ac0a59b1845cee6ad。

Mac exact3-owned隔離queue起始index0，raw雙份SHA一致，之後index2/history3與Cobalt0:09/0:20播放、最後0:20/0:20paused。只支持scoped traversal，沒有Amber/MOV各自EOF frame／無gaplesscapture，不宣稱整段12秒影片PASS。latest9table與queue完整restore父代理核對；封存`mac-mixed-eof-isolated/` manifest f0568921203d2b8307baa9db368455dddeb5aba337a502c42276c88952fc2017。

CodeRabbit本次最小曲／碟序classifier修補屬deterministic low-risk，不涉及簽章／發布／遷移邏輯變更，依optional risk gate略過外部上傳；before-fail/after-focused test與雙平台205真匯入證據已封存。不是CodeRabbit PASS；原RC required未知coverage仍阻擋完整結案。

## 2026-10-08T11:07:58.571846+08:00 正式評論因預算中止

快照CACC-AERO-RC4-f7a87f105f85維持不可變。首兩席自報17／18工具，至少35超每席8／總32；已停止後續工具與dispatch。共同report路徑誤寫造成journey payload被UX覆寫，僅保留其delivery摘要；UX現存draft已逐檔封存。第三failurecritic／獨立arbiter未執行，不能宣稱Full Council PASS；native契約驗證未通過，完整診斷已保存。最新產品實測／完整restore證據仍有效，所列unknown不是產品缺陷；未轉Done、未上傳／送審。封存completion-council-interrupted-01，續審不得重置原預算，需新明確授權。
