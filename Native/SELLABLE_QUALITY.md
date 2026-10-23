# CMV 可販售品質稽核 · 2026-10-04

目前為 Review 候選，尚不能宣稱正式販售 ready。建置、局部操作與安裝通過不等於完整上市驗收。

最新音色探索候選為 Marquee v3，限定驗證見 [PLAYFUL_LISTENING.md](PLAYFUL_LISTENING.md)；`source-marquee-v3.json` 已保存，三端建置／兩端交付、source／archive integrity、實體 iPad 交付與 UI 驗收已完成。前一輪 `86bfcfc`、後續推薦體驗候選（`4b4e297`）與 v4（`d254334`）品質紀錄保留原範圍，不能當成 v3 以外的完整回歸。

## 2026-10-04 Pro 可靠性補驗（目前結果）

Mac 與實體 iPad 的隔離 StoreKitTest 交易矩陣均為 **17 PASS／0 FAIL／0 skip**。涵蓋核准／拒絕、外部購買通知、購買／重建 Store／恢復／退款、取消與錯誤、商品載入與恢復網路錯誤、未驗證交易、商品不存在、退款通知撤銷與重複購買／恢復防護。逐項實際測試數及原始 xcresult 已封存，零測試或 skip 不算通過。故障網路為注入錯誤，重啟案例為重新建立 ProStore，不擴大稱為實體斷網冷啟動。

歷史七例 6 PASS／1 FAIL 與 hosted 19 例 18 PASS／1 FAIL 原始收據保留。新增交叉控制證明：raw listener 若不做核准後的 fixture 權益等待，同樣收不到更新；原 production listener 在 test-only `currentEntitlements` 傳播等待後收到 matching verified update 並解鎖。因此撤回「production listener 本身故障」的舊推論，修正測試同步方式。測試仍要求真正的交易更新，不呼叫 ProStore.refresh 代替核准通知，不直接授權；這是觀察到的 StoreKitTest 時序差異，不宣稱 Apple 保證讀取權益會強制發布更新。

正式 ProStore 授權／監聽行為未變；診斷限 `DEBUG && CMV_STOREKIT_TEST_HOST`。測試腳本支援隔離 Bundle ID、目的裝置與可選既有 Development Team，沒有在公開腳本寫入私人裝置 ID。

真實 Apple Sandbox：Mac 使用正式 SKU 的既有驗證交易，直接確認 `Transaction.environment == .sandbox`，商品價格非空；權益讀取、恢復及 fresh ProStore 再讀均 PASS（1 項實際執行、零 skip）。沒有新購、退款、登出或清空使用者交易。原桌面 App 已重新開啟，實際顯示 1,964 首與 Pro Unlocked，背景仍為銀河夜幕。iPad 最新 v2 probe 在使用者完成 Apple 驗證後1 PASS；歷史鎖定／連線逾時／未登入restore失敗保留，最新原App與資料已還原，見文末。

私有來源、ZIP CRC 驗證、逐項 logs／summaries 與原始失敗保存於 ignored `.cmv-local-evidence/2026-10-04-pro-sandbox-verification/`。iOS 26.5 Simulator 歷史 SKTestSession Code=3 為 setup 失敗；目前實體 iPad 17 項通過已補上本機交易覆蓋，不再把該 Simulator setup 失敗列為現有 Pro blocker。正式 critic_full 與獨立仲裁已 passed，CompletionPassport 通過原生 transition；AERO-PQ38／MON30 為 Done，其他整體上市 gates 保留。

## 2026-10-04 解鎖後補驗摘要

以下是 iPad 解鎖後 baseline production `08c2c5` 候選的補驗，以及已完成的 Marquee v3 交付驗收；歷史候選的原始範圍仍保留。Marquee v3 只有 `AudioEffectsView` 圖示＋文字 HStack，以及動態 Marquee／Reduce Motion 靜態完整換行修正，v3 收據已與舊 UI 收據分開。

- 完整 Core **97 PASS／0 failure／0 skip**；Rust **33 PASS／0 failure**，`fmt`、`clippy` 與 Swift-Rust bridge 均 PASS，Rust module source 未變。
- 完整 hosted **19：18 PASS／1 FAIL／0 skip**；唯一失敗是 pending approval listener-only 自動解鎖。新拆分的 decline 測試 PASS；此為歷史結果；本輪焦點 17 例／平台已通過，見上方補驗。
- Reliability **3 PASS**。Cache 真實 I/O fault 先保留 DB／queue／cache，清除 fault 後 retry PASS；真實 SMB cache **7 PASS**。這不是 50,000-track 全 NAS integration，仍未涵蓋完整初始／差異索引、150 ms 與壓力矩陣。
- Mac 同 ID 覆蓋後啟動與保存通過：1,964 entries／base、history 16、index 48；iPad 同 ID 覆蓋後啟動與保存通過：25 entries／base、history 5、index 13。
- Reduce Motion 實機 `0 → 1 → 0` 還原與自訂 Reverb `0 → 47.7%`、compare 保留 60% 已在 production `08c2c5` 候選驗證。
- 最大字級的按鈕拆字為實際 finding；Marquee v3 已保存 `source-marquee-v3.json`（tree `f897d591…`、production `721e18c5…`）。三端建置、source 111／111 snapshot、source ZIP、三個 final app ZIP、Mac／iPad 同 ID 交付與實體 iPad UI 驗收均已 PASS。
- 音效偏好 **5 PASS／0 failure／0 skip** 屬 Marquee v1，收據為 `audio-marquee-final-summary.json`，不延伸為 v3 驗收。
- v3 UI 收據確認最大字級動態文字位移、固定 164×78 button frame 與完整 AX labels；Reduce Motion 靜態 `Next Sound`／`Compare Original` 為完整兩行且無拆字／截尾。Next Sound 為 `Orbit Sweep → Sewer`，Compare Original 保留 60%，GUI reset 回到 Original／30%／custom factory defaults；static action 嘗試未觀察到 transition，排除為 PASS。
- v3 設定還原確認較大輔助字級 0、一般文字 67%、Reduce Motion 0、Bold 原本 ON 保留，Original／0.3／custom factory defaults 由 GUI、native AX 與 plist readback 交叉確認。
- 使用者明確排除 Bluetooth／AirPlay 設備，本輪不列為 CMV 完成阻擋。使用者最新確認目前正使用 Sandbox 帳號維持付費狀態；Mac 實際顯示 Pro Unlocked。「沒有 Sandbox 帳號」的舊假設已撤回，本輪 Pro 交易補驗結果見上方，不再以舊 pending FAIL 表示現況。

## 已修正

- 恢復原生播放列音效入口：原音、低音、人聲、電子、八種場景及自訂，共 13 模式；強度與六項自訂持久化。影片使用原音。DSP 常駐，不在 render callback 配置記憶體、上鎖或存取檔案。
- Selected source 必要，future source 分別容錯；移除失敗 occurrence 同步更新 base queue，避免重播幽靈項目。
- 重複曲目採兩階段計畫核對；先遷移 cache，再登記 canonical ID、持久保存佇列、提交 DB 與更新 runtime。Pinned cache 優先保留，舊檔刻意保留供既有播放引用；遷移失敗不刪 DB 曲目。
- 序列化最新佇列快照；保存失敗可重試並顯示可讀錯誤。Mac 正常結束等待保存，失敗可留在 App；iOS 背景有限時間保存。不承諾強制終止能保存。
- 空曲庫直接提供匯入入口，大字級曲目 metadata 自然換行、44 pt 操作保留；窄 iPad／accessibility size 使用原生 tabs。
- 修正實際模擬器播放遇到的 AVFAudio `-10868`：effects graph 明確採 48 kHz stereo，前段 mixer 轉換檔案格式。實際 negotiated iOS format 未記錄，不把格式推論當 runtime 值。
- 啟動恢復佇列不再依賴 QueuePanel 被掛載；iPad 首次進入現在收聽可還原已保存 metadata，保持暫停。
- 歷史 baseline 已移除舊 Electron／React／Node 與舊打包流程 40 個 tracked 檔案，清理約 361 MB 舊 ignored 產物；保留 SwiftUI＋Rust、曲庫與音樂。這不是 Marquee v3 cleanup 收據。

## 驗證結果與範圍

| 驗證 | 結果 | 限制 |
| --- | --- | --- |
| baseline Core 完整套件 | 97／97、0 failure、0 skip | 解鎖後 baseline 收據；包含 44.1 kHz 左右聲道非靜音、有限輸出及可靠性對立狀態；v3 未宣稱重跑 |
| baseline Rust workspace | 33／33 | Rust source 本輪未再更動，沿用同 source 的已執行結果；v3 未宣稱重跑 |
| baseline hosted 完整套件 | 18 PASS／1 FAIL／0 skip（19 項） | 08c2 baseline；唯一 FAIL 為 pending approval listener-only；新拆分 decline PASS |
| baseline reliability | 3 PASS／0 failure／0 skip | 08c2 baseline；Cache fault 清除後 retry 保留 DB／queue／cache 的真實 I/O 流程已驗 |
| baseline SMB cache | 7 PASS／0 failure | 08c2 baseline；真實 SMB cache 收據；不是 50,000-track 全 NAS integration |
| Marquee v1 音效偏好 | 5 PASS／0 failure／0 skip | `audio-marquee-final-summary.json`；不代表 v3 實機驗收 |
| Hosted AppModel＋preferences | 4／4 | 佇列 restore／write retry 及偏好；不是 StoreKit 矩陣 |
| 歷史 Hosted StoreKit＋可靠性＋偏好 | 8 PASS／1 FAIL／0 skip | 保留舊候選範圍；current 結果以上方解鎖後 hosted 完整套件為準 |
| 三語 catalog | 560 組、0 問題 | 不等於完整 VoiceOver 操作通過 |
| baseline v4 Release | Mac arm64＋x86_64、Simulator arm64、Device arm64 全部 exit 0 | 建置前後 111 檔 manifest 一致；不代表 Marquee v3 |
| 最後 v4 簽章／preflight | Mac sandbox adhoc、iPad Development strict verify 與兩端 local preflight 通過 | 非 Apple Distribution／upload qualification |
| Marquee v3 build／交付 | **PASS（限定範圍）** | `marquee-v3-gates.json` 三端 Release exit 0；`staged-marquee-v3.json` Mac adhoc／iPad Development strict＋local preflight PASS，Simulator unsigned＋local preflight PASS；三端建置、兩端交付，仍非 Distribution |
| Marquee v3 source／archive | **PASS** | `source-marquee-v3-integrity.json` 111／111 與 source ZIP 完整；`marquee-v3-archive-integrity.json` 三個 final app ZIP 完整 |
| Marquee v3 Mac／iPad preservation | **PASS** | `desktop-marquee-v3-delivery.json`、`ipad-marquee-v3-delivery.json`；資料與 version／shuffle／repeat preservation 均 true |
| Marquee v3 iPad UI／設定 | **PASS（限定範圍）** | `marquee-v3-ui-results.json`、`ipad-settings-restoration.json`、`ipad-marquee-v3-final-startup.xml`；不取代完整 VoiceOver／Stage Manager／contrast／裝置矩陣 |

歷史 StoreKit pending timeout 的原始收據保留；其根因推論已由上方交叉控制修正。目前焦點交易矩陣為兩平台各 17 PASS，不延伸為重新執行完整 AppModel／preferences hosted 套件。

## 實際成品操作與資料

- 獨立 Mac QA：自製 44.1 kHz stereo WAV 首次匯入、播放／暫停、自訂混響、重設與正常結束／重啟兩筆 paused queue 已驗；最後 v4 再確認實際播放到 0:24 後暫停、13 模式選單、六項 custom sliders、捲動及恢復原音。正常重啟恢復 paused queue，不保存 elapsed position，不宣稱強制終止保存。
- iPad Simulator：v2 格式修正後實際 44.1 kHz 播放到 0:45；最後 v4 啟動即恢復 saved metadata，不必先開佇列。最大 Dynamic Type portrait capture 與完整 AX 樹已保存；完整觸控／展開播放器覆蓋受 CUA `noWindowsAvailable` 限制，不能寫 PASS。
- 實體 iPad：最後 v4 同 Bundle ID 覆蓋安裝、啟動與程序存在通過，無 uninstall。安裝後保存快照讀回 25 筆佇列／25 base／5 歷史，current index 13。這不等於實機觸控、聲音聽感、路由或 Sandbox 交易驗收。
- Mac Desktop 最後 v4 已同路徑覆蓋並啟動，實際顯示 1,964 首曲目及 paused transport。保存 JSON 為 1,964 entries／base、16 history、current index 48；舊候選畫面「100」只是 UI 分頁範圍，不能當總佇列筆數。
- Marquee v3 另以 `desktop-marquee-v3-copy.json`／`desktop-marquee-v3-delivery.json`／`ipad-marquee-v3-delivery.json` 確認同 ID 覆蓋／安裝、啟動與保存：Mac 1,964 entries／base、history 16、index 48；iPad 25 entries／base、history 5、index 13，entries／base／history／index／version／shuffle／repeat 均 preservation true。`ipad-marquee-v3-final-startup.xml` 確認啟動時 Tracks 25、pause/play、Original 與原影片 5:14。

## 獨立審查

CodeRabbit 已修正 cache migration 的順序問題；其 blanket cancellation 建議依 future-source 反證拒絕。音訊／accessibility 4 檔與 startup restore 2 檔分別 0 findings。Canonical map 不回滾，避免已 durable 快照重新保存被刪除 loser ID。

獨立視覺初審為 `fix`；一次有界修正後，最後 disposition 為 `ship`（僅本輪視覺範圍）。已移除重複 kicker、提升 metadata／queue 對比、按非 custom 390 pt／custom 640 pt 收斂 Mac 音效面板；大字級 mini-player 採穩定兩行曲名與另排的 44 pt 控制，完整標題仍供 VoiceOver 讀取。保留既有真實雲景／星座／光帶。

Reviewer 先提出 duration 遮蔽疑慮；核對 `CompactRootView.safeAreaInset` 與 Now Playing `ScrollView` 後撤回：畫面為內容超出首 viewport 的正常裁切，沒有 overlay 遮蔽的證據。未任意加重複 bottom inset；實際 iPad 捲到底仍未驗。該 `ship` 不取代交易、裝置矩陣或正式 Mission 終驗。

## 仍阻擋正式販售

1. Pro 本機交易矩陣兩平台各 17 項已通過；真實 Sandbox 既有權益、恢復及fresh Store兩平台均已通過。真實新購／退款未操作，實體斷網冷啟動與 Distribution qualification 不由注入錯誤測試取代；正式 Pro completion review 與Passport已通過，Pro技術任務已Done。
2. 完整 iPad 觸控、VoiceOver、Increased Contrast、Stage Manager、背景／鎖定及其他裝置／UI 矩陣未完成。Marquee v3 已完成限定的動態／靜態文字、AX、設定還原、交付與 preservation 驗收，但不延伸為完整矩陣；cleanup 已完成，唯一受保護 uid0 receipt 殘留見 `cleanup-final.json`。
3. 實際 50,000-track NAS 初始／差異索引、暫離線、延遲與記憶體壓力未完成；過往 fixture 結果不代替全 NAS integration。Cache 真實 I/O fault 的 DB／queue／cache 保留、清 fault 後 retry 已 PASS，但不擴大解讀為 50k NAS 驗收。
4. 同候選 Distribution qualification、上傳驗證、正式商店素材／授權與完整 programme matrix 尚未完成。本輪沒有提交或上傳。
5. 尚無本候選正式 `critic_full`／CompletionPassport。一般 Luna、CodeRabbit、設計 reviewer 不取代該 gate；因目前沒有 explicit total／per-seat／tool／wall-clock budgets，正式 `critic_full` 未 dispatch，不標 Done。

## 收據與復原

111 個 build source／test／設定／資產的 manifest 可追溯到 HEAD `7e033ae3b776f116695b3f2df0f0293bd76322f9`。最後 v4 tree SHA-256 為 `d254334ab047b5df9eb82724f5e8683bf89a1d04d898f4983cfc9c4fad085ad1`，本機 build snapshot 逐檔比對 111／111 一致，建置後再次比對一致。

私有收據、captures、原始失敗 xcresult、桌面原始／前候選回復 ZIP 位於 `.cmv-local-evidence/2026-10-04-quality/`，由 `.gitignore` 排除。私人裝置 ID、原始使用者佇列與帳號不進公開文件。歷史 baseline 的 QA／build 資源紀錄與本輪 v3 cleanup 分開；本輪 cleanup 已依 `cleanup-final.json` 完成，不終止其他任務或刪除使用者音樂。

本輪主要收據：`core-final.log`、`hosted-v2-summary.json`、`hosted-candidate-summary.json`、`build-results-v4.json`、`source-final-v4.json`、`source-after-v4-builds.json`、`desktop-delivery-v4.json`、`ipad-delivery-v4.json`、`sim-delivery-v4.json`、`mac-qa-v4.json`、`review-dispositions.json`。最新可供本機檢視的 QA captures 為 `captures/mac-final-v4-qa.png`、`mac-final-v4-effects.png`、`mac-final-v4-effects-custom.png` 及 `ipad-final-v4-portrait-a11y.png`（皆為本專案自製 fixture，不包含使用者曲庫）。

解鎖後 Marquee v3 以 `source-marquee-v3.json` 追蹤：tree `f897d591…`、production source `721e18c5…`。`marquee-v3-gates.json`、`source-marquee-v3-integrity.json`、`marquee-v3-archive-integrity.json`、交付與 UI／設定收據均已完成；這些是限定範圍的 v3 驗收，不取代完整上市矩陣。

`cleanup-final.json` 確認 source 111 recheck PASS、controller exit 0、WDAhost 收到 SIGINT 後以 exit 75 停止，兩個 own PID 均不存在；所有 user-owned scratch／build／NAS fixtures 與自建 testHost 檔案均已移除。唯一殘留為 uid0 的 `dd/Build/Products/Debug/CMV.app/Contents/_MASReceipt/receipt`，1,726 bytes，及其受保護父目錄；PermissionError／OSError 未以提升權限處理。production userAppData 保留，source／app／test integrity ZIP 與 logs 保留於 ignored evidence。

Mission 維持 **Review**；Pro 補驗已執行 Mission Center sync／doctor（通過，legacy Passport warnings 保留）；尚未建立本輪 CompletionPassport。v3 build／兩端交付／實體 iPad／資料還原已驗收，仍受外部上市 gates 限制。

### 最新 iPad Sandbox 補驗結果（目前）

使用者在裝置本人完成 Apple 帳號驗證後，私人 v2 probe 的正式 SKU smoke **1 PASS／0 FAIL／0 skip**：direct transaction environment Sandbox、商品價格、既有 Pro、AppStore.sync 恢復成功與 fresh Store 均通過。先前1 FAIL與等待密碼的截圖保存為歷史證據，不混算最新PASS，不宣稱為ProStore程式缺陷。兩平台17例本機交易＋各1例真Sandbox，最新共 **36 PASS／0 FAIL／0 skip**。

原 iPad App 同ID還原、launch通過；production 25 entries／25 base、history5、index13整份queue JSON一致。先前1-entry revision88為另一組QA中途狀態，另一任務已還原原始25首，並有device回讀receipt，不將其誤判為install資料遺失或写回覆蓋。DB與pinned檔未變，StoreKit內部cursor可正常更新；本輪自建QA App已移除。裝置已以共享工作區handoff交接其他QA，本輪Pro不再操作它。

正式 critic_full 已完成：3位Luna＋獨立仲裁，converge passed／findings=[]，四份報告與來源雜湊核對、contract validator及CompletionPassport通過；AERO-PQ38／MON30已由原生transition轉Done。網路故障為注入、fresh Store不等於實體斷網冷啟動；真實新購／退款未操作。完整Distribution與整體App gates仍各自保留，不包裝成已上架。

Pro 技術結案的完整範圍與結果見 [PRO_RELIABILITY_REPORT.md](PRO_RELIABILITY_REPORT.md)；整體App Store readiness依原gate追蹤。
