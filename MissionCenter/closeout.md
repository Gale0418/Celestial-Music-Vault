# 收尾

## 2026-10-09 收工容量回收

本輪清理已完成，移除約2.30GB已完成建置暫存／重複副本；實際可用空間增加約2.05GB，讀值約27.52GB。兩份final archive與全部dSYMs壓存NAS逐檔驗證，正式IPA／PKG SHA清前清後一致；使用者曲庫、原始碼、原多日測試、送審回執與其他任務／運行中模擬器完整保留。global共享cache未清，lsof超時未當作通過；以完成任務所有權、具體CMV project plist與fresh程序檢查限定範圍。詳 `post-submit-storage-cleanup-01/cleanup-receipt.json` 及 `archive-preservation.json`。正式archive原/tmp路徑為歷史定位，重開時從retainedZip還原，不需重建或重新上傳。

## 2026-10-09 雙平台正式送審收工

- 摘要：iPadOS／macOS 2.0（1）已正式上傳與送審，兩平台及 CMV Pro 目前均 **WAITING_FOR_REVIEW**。尚未 Apple 核准或公開上架。
- 已完成：sealed 正式包與正確 build 綁定；四主題×兩裝置八張图，三語24筆素材全部處理完成並核對一致；Privacy published；兩份正式 --confirm 与獨立回讀；任務 Next／狀態／多日驗證紀錄整理。
- 未完成：Apple 審核結果、可能的補件、核准後 MANUAL 發佈；完整工程 scope 仍 limited，RC4未知範圍保留。
- 驗證：兩包SHA、24素材與兩平台 submission/version readback PASS_SCOPED；MissionCenter doctor exit0／tasks pass／92tasks，legacy passport warning保留。正式評論詳 S04 chair，未冒稱 full-scope PASS。
- 工具限制：同步摘要 `mission-center sync` 仍 exit1／command_error，含本次明確目標與里程碑的 --rewrite-summaries 亦失敗；raw存 asc-release-submit-01/mission-center-final-sync.json。canonical tasks、daily-log、smoke-tests、closeout及送審回執已更新；brief／working-set等衍生摘要未手改，不能當最新送審狀態。
- 回顧：後續用兩個精確 reviewSubmission ID 查 Apple 狀態，沿用現有單，不重傳或重新建立；已有人工通過項目不因摘要故障重測。
- 最新入口：階段收工紀錄 `closeouts/cmv-20261009-review-submitted.md`（local-only，未納入版本控制）；正式送審回執 `release-submission-receipt.md`（local-only，位於 ignored evidence）；[本日煙霧驗證](smoke-tests.md)。以下全部是歷史 checkpoint。


## 2026-10-08 07:36 Xcode / WDA TOOLING_RECOVERY_PASS_SCOPED

Xcode／WDA／鏡像連線修復完成，TOOLING_RECOVERY_PASS_SCOPED。官方Components安裝後iPad及Any iOS destination恢復available；WDA build-for-testing actual0／TEST BUILD SUCCEEDED，ready status與HTML/XML/PNG HTTP200成立。主人已手動重載並直接確認『已看到 iPad 畫面』；owner的CUA同tab讀回已連線，沒有繞過網址政策。

Root親核recovery-02的50檔payload／15,854,585bytes SHA與大小全exact、五檔before/after byte exact；SQLite複本integrity ok、429曲／10來源／0歌單，queue19 current1 rev226保留。WDA同bundle更新僅一份，CMV未重安，原install URL相同；不稱fresh installed CMV binary SHA已核。沒有播放、選檔、停機還原或重測窄Cancel。

已回收本輪確認閒置Symbols與完成的compile cache/intermediates，共5,915,204KiB（約5.64GiB）；symbol metadata保留，清後destination仍eligible、XML/PNG HTTP200。Mac最新可用17.40GB（16.21GiB）。保留唯一必要iOS平台/runtime及active BuildProducts；WDA host與relay仍供主人使用，未終止其他程序。

窄Cancel仍沿用主人USER_PASS；PiP、聽感、等待容忍、容量scope接受結果不變。工具修復門檻已解除；真NAS slow/stale實际刺激仍未觸發，整體 Review／limited，不列產品FAIL、不宣稱全項PASS或新的full council passed。

收據：xcode-wda-recovery-02-20261008/recovery-receipt.json SHA6c77926200d7ee281d31a920efde4fcaeb9c72ab35a993f93e16074062232dac；delta-manifest SHA5a70cd3fcef6cf6cd5647a9ebce330ba360357434b154c9c59fbbc49b0b35f07；Root readback：tooling/recovery02-primary-readback.json。


## 2026-10-08 07:06 narrow USER_PASS / NAS checkpoint

窄窗資料夾選擇器取消：主人確認以前已測過、沒問題，採 USER_PASS，不重測。這是既有人工验收確認，不稱本輪工具自動操作或精確374pt實測；舊 UNKNOWN_TOOL_BLOCKED 收據保留歷史。

真SMB自有目錄重建實驗 build0／actual0，production provider/coordinator 解析及64KiB讀回exact。OS stale=false／refreshedBookmark=nil；resolve約1.66ms、read約9.18ms。未觸發真NAS慢速或stale refresh，記 UNKNOWN_ACTUAL_NAS_STALE，不列產品FAIL，不稱該情境PASS。Root已核raw/source/cleanup，raw錯名SHA256欄實為SHA1，另有append-only更正。

窄窗工具attempt的40檔payload SHA/bytes由Root核對；429曲／10來源／0歌單、queue19 current1 revision226，停止基線五檔before/after exact、SQLite integrity ok，未GUI操作或改資料；未核新installed binary SHA。『測試 iPad 連線』主人另授權修好Xcode/WDA，owner獨占recovery-02並報告下載唯一iOS平台bundle；修復尚未完成，與人工PASS分開。

目前窄窗、PiP、整體聽感與容量均不待答。真NAS slow/stale未觸發，整體 Review／limited checkpoint；S01/S02不改寫。本輪無CMV source修改或成品替換，不宣稱全部PASS、clean convergence或上架完成。

Evidence: council/manual-deltas/manual-narrow-picker-user-pass-20261008.json; nas-final-recovery/primary-readback.json; human SHA 71e1e2791d2d6e8eaff0c87b633df5deff7d2b0bae5ac17f7e371e19b17e56a6


## 2026-10-08 06:35 小檔快取工程驗收完成（整體仍 Review）

主人回報iPad已用53.5GB／總64GB，約可用10.5GB；完整10GiB實填 `USER_NOT_REQUIRED`，容量不再待答。既有同source真SMB小檔cache raw7／7沿用；新增production-identical macOS小檔harness **11／11 checks PASS**（32／32／64bytes、smart budget64、淘汰oldest、pinned保護、新actor重新實例化與SHA讀回），Rust cache **3／3 tests PASS**（budget／LRU-pinned／u64 aggregate overflow）。Root已讀回raw、核對來源與fixture預期digest；本次build/target/fixture均已回收，只保留小型harness及證據。收據 `cache-small-scope/primary-readback.json`。此為小檔工程scope，不稱iPad硬體或完整10GiB實機壓測PASS。

目前主要剩 **真NAS slow／stale refresh** 與 **窄窗picker取消**；其餘已列工程scope限制保留。整體Review，S02舊標準結論與封存不改寫；沒有新產品實作、裝置操作或store上傳。

## 2026-10-08 06:19 iPad 容量／測試範圍更新（整體仍 Review）

已直接讀回主人 turn `01a11870-9a94-7850-9f0f-cd79630fc6c2` 原話與容量scope收據（SHA `6e907b0f…`、manifest `9e40c79d…`）。主人最新回報iPad已用 **53.5GB／總64GB**，按顯示數字約剩 **10.5GB（9.78GiB）**，記 `USER_REPORTED`；設定顯示有四捨五入，不稱machine exact。容量待答已解除。主人說不需把10GB全部塞入，完整10GiB實填改 `USER_NOT_REQUIRED`，舊14GiB安全門檻不再阻擋縮小scope；這不代表完整10GiB實機壓測PASS。改核對既有小檔實際cache／縮小budget淘汰／pinned保護／重開與metadata計數邊界收據，有缺口才補最小測試；未配置大檔或刪私人資料。

目前主要仍是真NAS slow／stale refresh與窄窗picker取消；小檔cache工程scope由Root核對既有執行證據，未核對前不補造PASS。S01／S02／241archive／11cleanupdelta保持不變；Mac約30.575GB及人工/性能已接受結果沿用。

## 2026-10-08 06:09 主人驗收標準／聽感更新（整體仍 Review）

已直接讀回「測試 iPad 連線」主人 turn `01a11866-b964-7383-855d-898514aab835`：五萬首等待約一分鐘可接受，聽感沒問題。既有 Main 暖查詢 p95 relevance 7193.785ms／title 5650.963ms 符合新容忍範圍，記 `USER_ACCEPTED_WAIT_CRITERION`，解除舊 150ms 的目前驗收阻擋；不宣稱達到 150ms、所有操作最大值小於 60 秒或 iPad 硬體效能已量測。Mac 整體音樂／影片聽感 `USER_PASS`。人工收據 SHA `14124185…`、3檔 delta-manifest SHA `931cb34e…` 已逐檔核對。

目前主要剩餘：真 NAS slow／stale refresh、窄窗 picker 取消、iPad 當前可用容量待答。fresh devicectl 只證明 iPad 總量 64GB，沒有目前可用數值；先前 4.79GB 不當作現在保證，10GiB 壓測維持 `PENDING_FRESH_AVAILABLE_CAPACITY`。Mac fresh df 可用 30.575GB（28.475GiB）。S02 blocked 是舊標準下的封存結論；原 raw／S01／S02／sealed 評論保留，新 delta 只修正目前驗收判讀，不重測、改實作或競爭裝置。其餘工程 scope 限制仍見本輪報告。

## 2026-10-08 06:03 PiP 人工驗收更新（整體仍 Review）

主人已確認 PiP 進入、暫停、播放、返回 CMV與時間／曲目／pause state正常，5項皆USER_PASS；來源為「測試 iPad 連線」最新人工原話，收據SHA53164d07…已核對。這項結果取代下方歷史的PiP人工pending；原工具unknown與241archive／11cleanupdelta／S01／S02及sealed評論保持不變，不冒稱工具自動重現。

目前主要剩餘：Main50k150ms FAIL、Mac實際聽感待答、iPad10GiB壓力測試的14GiB容量前置未達、真NAS slow/stale unknown、窄picker取消unknown。只對帳與同步狀態，不重啟裝置、重測或展開新效能實作。

## 2026-10-08 05:08 最終驗收／清理 checkpoint（整體仍 Review）

S02 `cmv-closeout-20261008-s02` 已封存861檔（manifest `248e2972…`），三席獨立focused評論＋separatearbiter全部同快照綁定/報告SHA核對；overall **blocked**。九個stable findings：同候選runtime/完整526來源/兩個AXlabel/lease去重/證據scope已scoped fixed，舊deliverypending反證排除；性能P1保留、lateEOF僅未重現假說不列產品FAIL。沒有clean convergence、不標Done、不上架。CodeRabbit未run；critic_contract.py缺失，JSON parse/hash核對不能當結構validator通過。

Main性能仍實際超150ms。原版暖p95 relevance7193.785ms/title5650.963；QAonlyfixedwide/backend变體864–1497ms仍不合格，未promote。既有raw已有完整generation綁定的task/debounce/model/page/pub timestamps，無需重複加instrumentation：posthoc40×2顯示query→task p95318.730/398.582ms；39個非空string的task→debounce p95394.466/457.351ms（目標sleep30ms，Main resume延遲）；page→pub<0.7ms。不是純layoutCPU推論。後續性能實作切片需隔離query/loading對row/action的反覆重算，保留displayed-page actions/cancellation，做單一可回退A/B；本輪未以未驗原型替換正式成品。AERO-M3已由歷史Done重開Review，與AERO-F25共享缺口。

iPad旁白/整體聽感USER_PASS；Mac旁白、全斷網、Bluetooth、AirPlay USER_EXCLUDED不算阻擋。仍待PiP手指暫停/Mac聽感；iPad4.79GB<14GiB安全前置，10GiB壓力未配置；真NAS slow/stale scope未驗、窄picker取消未知、signedfixtureheadless權限限定。這些未知不是產品FAIL，也不是PASS。正式Mac已還原原曲0:00paused，資料還原與新候選鏈見canonicalreport。

清理已完成：fresh simulator devices/runtime均空；舊與本輪完成的DD/.build/全域modulecache、WDA可重建Build/Index等、已不使用的iPad per-version debugSymbols cache已清。舊locks為2026-07-02無holder，finalized為2026-08-27；exactps/lsof無debugger，sharedCoreSimulator服務不等於此cache使用，保留小型metadata證據並整版本刪除供將來正常重建。owner自建8766relay正常結束、無LISTEN/WDAhost。曲庫/音樂/privatebaseline資料、source/formal/rollback/證據仍保留；不終止其他任務程序。現在實測Mac可用 **27.29GB（25.41GiB）**；開工30GB是主人回報，未虛称全數恢復。

目前權威入口：[本輪報告](remaining-validation-report-20261008.md)、[人工待驗](manual-verification-checklist.md)；工程/council/cleanup收據均於本輪 `.cmv-local-evidence/2026-10-08-final-closeout/`。以下較早checkpoint均為歷史。

- 摘要: AeroMusic 1.0.0 已完成可靠性、安全、效能、離線體驗與 macOS 發行強化並交付桌面。
- 已完成: 原子存檔與備份復原；NAS 離線保護；Electron/IPC/導航 hardening；20,000 首排序；離線資源；Chrome 與封裝 App 回歸；Apple Development 本機簽章；DMG 交付
- 未完成: 正式對外公證需另備 Developer ID Application 憑證與 notarytool profile；非本次本機交付阻擋
- 風險: 預設示範串流仍需 SoundHelix 網路；Apple Development 簽章不等於 Developer ID 公證
- 冒煙測試: npm test；零警告 lint；Vite 8 build；audit 0；Chrome UI；Electron 單例；codesign strict；hdiutil verify；桌面啟動
- 回顧: NAS 專案應固定在 /tmp 乾淨建置；成品 plist 必須在簽章前 fail-closed 驗證；UI 與成品實測能抓到單元測試外問題

## AeroMusic 2.0 螃蟹版本機收尾 · 2026-08-27

- 摘要: Swift 6／SwiftUI Apple 外殼與 std-only Rust value core 已完成可重建的本機交付；來源復原、夢幻 AppIcon、送審 metadata gate 與 universal archive 均已納入證據鏈。
- 已完成: 12 個 2.0 里程碑標為 `crab-done`；Swift 14/14、Rust 19 core＋8 FFI＋1 shared、fmt、Clippy、Codex Game Studios validation、macOS／iPad Simulator Release build、generic iOS device arm64 Release compile、Mac universal Development archive strict codesign／App Store preflight、MissionCenter Doctor 與 HUD 同步。
- 已補強: stale bookmark 自動 refresh 與原生重新授權 picker；AppIcon 1024／512 RGB 無 Alpha；`qualify-app-store.sh` 強制驗證 `CFBundleIconName=AppIcon`；送審 metadata／授權責任集中於 `Native/APP_STORE_METADATA.md`。
- 未完成: 實體 Mac／iPad NAS 與背景／PiP／sandbox 矩陣；Apple Distribution 憑證／profile、App Store Connect／TestFlight；Privacy／Support 公開 URL、商店資料與素材授權；Electron 退場。這些不以模擬器或 Development signing 冒充完成。
- GitHub: `origin/main` 可讀且與本地 HEAD `2c42c03` 同步；`gh pr list --state all` 為空；2.0 變更尚未 commit／push，避免未經授權改變遠端歷史。
- 證據: `Native/ARTIFACT_MANIFEST.md` 雜湊驗證通過；`MissionCenter/tasks.md`、`smoke-tests.md`、`daily-log.md` 已同步；HUD helper reused `http://127.0.0.1:51768/`；Doctor 保留既有 legacy warning，無新增錯誤。
- 最新本機補強：`OfflineCacheStore.cachedURL` 先驗證 SHA-256 再供播放，釘選內容可在來源離線時直接使用；歌曲、專輯與歌手 UI 改為分頁載入；Mac 支援拖放資料夾加入音樂來源；啟動時重新檢查已保存來源。Swift 14/14、Rust 19 core＋8 FFI＋1 shared、macOS／iPad Simulator Debug build 均通過；未改變實機／Distribution／TestFlight 外部 gate。
- 最新裝置盤點：已配對 iPad 可被 `devicectl` 看見，但 Developer Disk Image 尚未掛載；最新 generic iOS arm64 Release bundle 已通過 App Store preflight，實機安裝、NAS／背景播放／PiP 仍不宣稱完成。
- 最新獨立 review：Antigravity request `b8d9af7c-0e8b-4d4a-a6cb-2f66f5d6953b` 以 Hub-visible 唯讀 RPC 回覆 `verdict=PASS`，無 blocking finding；其列出的 NAS／DDI／Distribution／TestFlight 仍與本文件外部 gate 一致。
- 最新簽章證據：Xcode `-prepareDeviceSupport` 已為 iPad13,16 完成支援準備；自動開發簽章仍因本機沒有可用 Team 帳號及 `com.aeromusic.native` profile 失敗，故不宣稱實機安裝或 TestFlight。
- Electron legacy packaging：`npm run pack` 已完成 `dist-app/mac-arm64/AeroMusic.app`（約 195 MB），Apple Development 簽章與內部 strict verify 通過；notarization 因缺少 Developer ID／notary profile 跳過。這只代表舊版封裝基線恢復，不改變 Electron 必須等原生 TestFlight 後才退場的 gate。
- Rust boundary finalization：cache eviction policy 已經由 `aero_core_eviction_plan_v1` 接入實際 Swift cache actor；Rust 負責純 value LRU／pinned 決策，Swift 負責 Apple 檔案與權限邊界。至此可安全 Rust 化的純邏輯都有 runtime bridge；UI、AVFoundation、SwiftData、sandbox、PiP 仍刻意維持 Swift。
- MediBuddy signing cross-check：採用其「certificate／Xcode account／profile Team 分層」排障結論後，AeroMusic 以實際 profile Team 成功產生 signed arm64 device App；配對 iPad 安裝仍因裝置鎖定導致 DDI mount 失敗，實機 gate 保持未完成。

## MissionCenter 現代化與歷史債清理 · 2026-08-14

- 摘要: 現有 MissionCenter 已非破壞式升級至新版任務契約，保留全部歷史任務、決策與驗證證據。
- 已完成: 受管 project/progress 摘要、P0 焦點、每日紀錄、HUD 狀態、legacy Done audit 與 Doctor 驗證。
- 未完成: 5 個舊 Done 任務無法在不偽造證據的前提下還原標準 smoke record，保留為明確警告債。
- 驗證: MissionCenter Doctor OK；maintenance status 新鮮；`visual-state.json` 可解析；新任務均有通過紀錄。

## 2026-10-04：音效與舊版退場交付

原生音效入口、四 EQ（含原音）、八場景、強度與六項自訂已接入常駐 live graph。Mac 同路徑覆蓋且操作／正常重啟記憶／原音重設通過；實機 iPad 同 App ID 覆蓋成功，啟動因 Locked 尚待解鎖。Swift 92／0、Rust 33／0、hosted preferences 2／0、三種 Release build 通過。iPad 觸控捲動、完整 VoiceOver、AirPlay／路由恢復、實機聽感及低延遲量測仍未驗，FX32／33／36 保留 Review。

使用者覆核改為現在移除舊 Electron／React／Node 與打包流程，40 個 tracked 舊檔與約 361 MB ignored 產物已退場；Git 復原基準保留，音樂、曲庫、憑證不動。此決策取代舊退場時序，不代表原生 TestFlight／App Store 正式 gate 已完成。收據、截圖與桌面備份保留於本輪私有 runtime，私人資料不提交。

## 2026-10-04：可販售品質 v4 本機交付 checkpoint

已修13音效、來源與duplicate/cache/queue保存可靠性、首次匯入、大字級、音效graph格式及compact啟動restore。Core97／0、Rust同source33／0、hosted可靠性／偏好4／0；clean StoreKit總8 PASS／1 FAIL／0 skip，pending自動解鎖仍FAIL，根因未知。最後Mac universal、Simulator arm64、Device arm64 Release／strict簽章與兩端local preflight通過；非Distribution資格。111檔source tree `d254334ab047b5df9eb82724f5e8683bf89a1d04d898f4983cfc9c4fad085ad1` 建置前後一致。

Mac Desktop與實體iPad同ID覆蓋、啟動通過，Mac曲庫1964／保存queue1964／history16、iPadqueue25／history5保留。舊畫面100為分頁範圍，非總queue數。獨立視覺初審fix、一次有界修正後ship；duration遮蔽finding依native safeAreaInset／ScrollView反證撤回。iPad CUA點擊仍noWindowsAvailable；未冒稱實機觸控／完整VoiceOver／Sandbox／NAS／路由通過。

私人收據、captures、完整失敗xcresult與已驗完整性的原始／前候選／最後成品ZIP保留於ignored `.cmv-local-evidence/2026-10-04-quality/`。本次自建Simulator已刪，其他MediBuddy裝置仍保留；QA App正常結束並回收自有container。正式critic_full未dispatch：當前gate approval/budget missing；沒有新CompletionPassport，不標Done／ready。詳 Native/SELLABLE_QUALITY.md。

## 2026-10-04 AERO-PQ42 推薦體驗候選

- 使用者要求改到敢推薦：自備音樂引導、canonical 加入來源、Pro 離線成功條件／批次整理範圍、Smart DJ Pro 與理由、三語介紹稿完成；不變更商業模式，不發布。
- 111 檔 source tree `4b4e297504ff1e2cdb1ebe7251fd6e351de95ab2fb6b1ba6bb9ec49e98dda78a`；雙 Release exit 0，三語568／0，三語商店欄位長度與 diff check 通過。獨立 copy reviewer 可接受；實際發現並修復語言切換後品牌／佇列停舊語言，最後候選熱切三語通過。
- Mac 同 ID 覆蓋啟動與資料保留已驗：曲庫／佇列1964、history16、index48。iPad 同 ID 安裝與前後快照一致：25、history5、index13；CoreDevice 明確 Locked 拒絕啟動，已請解鎖，未宣稱啟動 PASS。
- PQ42 為 Review；既有 Pro pending autoupdate FAIL、Sandbox、完整NAS／實機無障礙、Distribution與正式critic gates不閉合。新文案不替代舊候選測試或外部門檻。
- 成品、資料與logs保存ignored私有evidence；版本化詳見 Native/RECOMMENDATION_KIT.md。

## 2026-10-04 AERO-PQ43 音色探索候選

使用者要求提升聆聽樂趣；依 Game Studios dev-story 完成八場景「下一個音色」與暫時「對照原音／返回音效」，保留強度、自訂值、偏好與佇列。不增加 DSP／render 工作、遊戲獎勵、帳號或付費策略。實際發現 popover 關閉回呼延後，已用 presentation state 與完成按鈕直接恢復修正。

111 檔 tree `86bfcfcf637b6cc1331f592c4c585b35992a9e7b8ce53eeee27760f8755f9b89` 前後一致；最終 hosted 5 PASS／0 FAIL／0 skip、三語574／0、雙Release、strict簽章／local preflight通過。完整 Core／Rust／StoreKit 未重跑，原品質候選保留範圍；首輪 NAS xcresult 儲存失敗不算 PASS，最後本機有效 result 已保存完整性驗證ZIP。獨立唯讀review無可重現finding，reviewer未完成的build不算測試通過。

Mac獨立QA以原創44.1k stereo WAV實際播放，九次場景循環保持29%與兩首順序，播放持續前進；對照返回、編輯退出、Escape與重啟保留設定通過。Desktop同ID覆蓋啟動、binary對應與曲庫／queue1964、base1964、history16、index48及模式保留。iPad同ID覆蓋與快照byte identity通過（25／25、history5、index13）；首個安裝連線中斷，檢查連線後一次重試成功。新候選啟動被Locked拒絕，待使用者解鎖，不宣稱觸控／聽感PASS。

PQ43維持Review，未宣稱整體販售／推薦ready或正式critic閉合。成品、舊桌面備份、來源ZIP、資料與原始log在ignored `.cmv-local-evidence/2026-10-04-playfulness/`；版本化詳 Native/PLAYFUL_LISTENING.md。既有 StoreKit pending、Sandbox／完整NAS／無障礙／Distribution gates 不變。

## 2026-10-04 解鎖續驗與跑馬燈最終交付

最後候選 Marquee v3：111 檔 tree `f897d5917c291b8ed2551a8cddc302fa5be7e24e70db56c7283bc2647b4fc6f0`，production `721e18c58b968ee688660fb45bb184d7703d933006d2bec73397489a33200228`。來源快照與工作樹逐檔一致，三 Release、strict signing／local preflight 通過；Mac adhoc、iPad Development，不是 Distribution。來源及三成品 ZIP 完整性通過。

使用者要求以跑馬燈解決長按鈕；重用 MarqueeText，明確 HStack 避免系統 Label 圖示欄把文字擠碎。實體 iPad 最大 Accessibility 字級：兩張同框畫面證實文字位移，兩顆按鈕 164×78pt 且 AX 名稱完整；Reduce Motion 以完整兩行文字靜態顯示。最後候選實際下一音色 Orbit→Sewer、對照 Original 保留60%、恢復原音為30%／出廠custom值；靜態按鈕點擊嘗試未觀察到轉換，不計PASS。原佇列與字級還原後最後啟動保持paused。

Mac 同 ID 覆蓋啟動保留1964 entries／base、history16、index48；iPad 同 ID覆蓋啟動保留25／25、history5、index13。順序、history、index、version、shuffle、repeat均一致。一般字級67%、輔助大字級0、ReduceMotion0、原粗體1保留；音效偏好回讀Original／0.3與出廠custom值。使用者明確排除Bluetooth／AirPlay本輪gate。

自動測試範圍：Core97與Rust33、fmt／clippy／bridge PASS；完整hosted19在08c2production為18 PASS／1 FAIL（Pro pending approval listener-only timeout）；reliability3與真實SMB NAS cache7 PASS；音效偏好5在Marquee v1 PASS。v3只改同一label排列，補三build與焦點實機，不虛稱完整hosted重跑。50k NAS／完整VoiceOver、contrast、StageManager／Sandbox／Distribution仍未驗。正式critic_full因缺explicit total／per-seat／tool／wall-clock budgets未派送，無新CompletionPassport。

結果詳見 Native/IPAD_TEST_REPORT.md；私有收據位於ignored `.cmv-local-evidence/2026-10-04-ipad-unlocked/`。既有Review與In Progress保留，不標sellableReady或整體Done。

### 本輪資源回收

`cleanup-final.json`：來源111檔最後比對通過，自有controller正常exit0；WDA host收到SIGINT後exit75，兩個本輪PID均已不存在。已刪本輪使用者擁有的build／scratch與NAS測試fixtures，production資料與證據ZIP／logs保留。只有系統root擁有的1726bytes StoreKitTest receipt及父目錄因PermissionError保留，不提升權限。此殘留不影響已交付Release，亦不代表全部暫存目錄消失。最後Simulator只建置與local qualification；交付啟動為Mac／iPad兩端。

## 2026-10-04 Pro 可靠性未完成 checkpoint

雙平台隔離StoreKitTest交易矩陣各17 PASS／0FAIL／0skip，Mac真Apple Sandbox正式SKU權益、價格、restore、fresh Store 1PASS；原桌面版正常顯示Pro Unlocked及1,964曲。正式ProStore非test-host程式與原始snapshot逐字一致，修正的是測試fixture等待。

尚未完成：iPad真Sandbox因鎖定未啟動（exit65），原App還原安裝遇CoreDevice error60；解鎖後先確認原版與資料，再續測。可回復artifact與安裝前資料私有ZIP均CRC通過。正式critic_full數字預算已提出尚未核准，不dispatch、不建立假Passport、不標Done。AERO-PQ38為Review、MON30仍In Progress；其他AppStore gates未改為完成。所有原始失敗與目前PASS收據保留於 ignored `.cmv-local-evidence/2026-10-04-pro-sandbox-verification/`。

## 2026-10-04 Pro 技術可靠性完成

先前未完成checkpoint已由新證據結清：Mac／實體iPad本機各17PASS，真Sandbox各1PASS，共36PASS/0FAIL/0skip；iPad由使用者完成Apple登入後restore成功。原App與25首正式queue已還原，自建QA App移除並交接其他QA。三席Luna＋独立仲裁converge passed、findings=[]，雜湊／contract／Passport與原生transition通過；AERO-PQ38／MON30為Done＋crab-done。

正式授權／監聽行為未改；harness等待修正、selectors fail-closed及故障矩陣補強已驗。歷史失敗保留，未宣稱physical radio-off cold launch或真Sandbox新購／退款。Distribution、完整App其他QA與整體上市gate仍另行追蹤。詳Native/PRO_RELIABILITY_REPORT.md。

## 2026-10-05 非 Pro 續測 checkpoint（未交付／未結案）

- 摘要：依使用者核准加入影片音效，維持單一 AVPlayerItem tap 與既有影音時鐘；新版已建置及封存，實機驗收未完成，非 Pro 任務保持 Review。
- 已完成：Core13／App9焦點測試與 root readback；Main114檔來源、12 overlays與workspace相符；iPad arm64／Mac universal Release成品簽章、raw plist、ZIP逐檔／SHA／CRC及真正local qualification通過；Mac v2語系序列化問題修為v3。實際10GiB NAS smart／pin／trim／checksum驗收通過並清理自製資料；iPad操作方法與失敗界線寫入 runbook。
- 未完成：Mac／iPad本人解鎖；AVPlayer同資產no-tap baseline／ready/error診斷與影片實機13音色／原音／seek／PiP回歸；最新QA50k搜尋及iPad10GiB；新版兩端交付與資料保留；原始25queue最終還原。停止前讀queue遇CoreDevice error4000，尚未進行停止／寫入／啟動；不可宣稱已還原。
- 風險：真AVPlayer probe為0PASS／3FAIL、9 assertions失敗、pending／waiting／time0，分類INCONCLUSIVE_FAILED_PROBE，不能只憑鎖定判成環境限制。五萬首搜尋先前部分查詢超過150ms；新版UI尚待重測。全斷網／AirPlay／Bluetooth為USER_EXCLUDED，Pro Done不重評，Distribution另有既有gate。
- 冒煙測試：詳 smoke-tests.md 10-05表；Core／App焦點通過與native失敗分開記錄，Main只代表本機成品。199檔frozen-source／focused／capacity archive已逐entry讀回；原始failed xcresult、compiled與diagnostic test source、裝置錯誤皆封存於私有evidence。
- 回顧：Apple plist lint不足以抓到XML編碼宣告不一致；必須解析原始bytes。command JSON與copied payload分路徑。真觸控才能保持iPad醒著；兩端鎖定需要本人解鎖，不用舊畫面判成功。本輪4個Main build roots回收約1.14GB，自有native probe scratch／runner已清；WDA host exit65，relay SIGINT exit130，兩個PID均不存在；未停止他人程序。
- 完成評論：使用者已核准critic_full三個獨立Luna＋不同仲裁，總12k tokens／每席3k／每席6tools／20min；尚未dispatch。待上述驗證完成並凍結snapshot後執行，無本輪新Passport或整體Done聲明。
