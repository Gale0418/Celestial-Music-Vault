# CMV 本輪驗收紀錄 · 2026-10-08

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


更新UTC：2026-10-07T22:09:45.118694+00:00。目前 **Review／未完成收尾**；不宣稱全部PASS或App Store ready，未上傳商店。使用者要求完整補測，最終四席審查額度已無上限授權，Mac旁白／全斷網／Bluetooth／AirPlay依本人要求排除。

## 本輪目前結果

| 範圍 | 可追溯結果 | 範圍限制 |
|---|---|---|
| 同源final-v2成品 | Mac Release universal arm64＋x86_64、iPad Release arm64，實際build0／既有簽章strict0／Rust符號與編譯Emerald資產核對。Mac `be9c4d1f…`、iPad `4d684522…`。 | 本機Developer簽章，不是Distribution、TestFlight或正式提交。 |
| Emerald／Saturn | 恢復精確Emerald退休資產；兩端實際完整彩虹。動態resource guard檢出缺asset負例，正式app正例0；Saturn改對存在的MilkyWayDepth背景並保留shader。 | 同候選成品與實際畫面；不稱全素材授權總稽核。 |
| Mac GUI／還原 | final-v2實際播放／暫停、搜尋Que九結果、Emerald；最終重開原曲0:00paused。九表schema/逐列exact、1980tracks／114sources／0歌單、queue1962 current59 revision289→292且其他字段exact、app-ownedprefs exact。 | 完整資料回讀；fresh final CUA AX已露出上一首／下一首／隨機播放／開啟影片／清除與可見queue曲名。較早缺名為上下文回傳差異；未執行Mac旁白。 |
| iPad GUI／還原 | 同候選實際音樂／影片播放、Next、暫停、Emerald。最大輔助字級、ReduceMotion長曲名靜態、約374pt真窄窗核心控制scoped PASS。九表逐列exact、429/10/0、queue19 current1 revision220→223且其他字段exact、prefs及OS原值還原。Root重算封存241檔SHA全部一致。 | 374pt是截圖估值；窄picker取消未知，擴回原尺寸後返回。不補造窄窗完整矩陣PASS。 |
| Swift focused | production-identical25來源的Queue13／Reliability14／Metadata8／SmartDJ1，共36 PASS／0。 | macOSpackage範圍；初始0/0環境中斷不列產品FAIL，不重跑無變更測試。 |
| Native DSP | 13preset的4096-frame工程樣本finite／nonsilent／unclipped、zero-intensity exact、reprepare無tail；AudioEffects14/0、lifecycle2/0。 | macOSarm64工程範圍。raw是log＋metrics，沒有serialized逐樣本PCM，不代替iPad或人工聽感。 |
| EOF／queue | AVPlayer host自然EOF timer64→64、level0、seek/replay89ticks；Mac兩首queue、Next最後一首、自然EOF清空已實測。 | host meter double不代替native DSP。未重現的lateEOF猜測不能寫成產品FAIL。 |
| Lease修復 | AppModel按standardized URL去重；1000同根count1、第二根2、clear0/weaknil、64KiBreadexact；unsigned hosted實際1/0。 | signed headless fixture accessDenied，列環境access限制；不稱signed sandbox/end-to-end權限PASS。 |
| NAS | 真SMB production coordinator/provider實讀64KiB、switch/clear/weaknil。錯誤路徑2/0；actualOS stale只來自owned local fixture；slowresolve為injected harness。 | 真SMB rename後file missing，未產生stale refresh，保留能力缺口，不稱真NAS stale PASS。 |
| 50k correctness | 既有50000唯一IDs／250頁order／restore；bounded-heap Release排序oracle與pre-cancel後恢復已有實際PASS。 | 不代替hardware中途取消或Main150ms。 |
| Main50k原版 | 四組40/40出版、query/generation/observedQuery完整綁定，無timeout或publication前cancel。relevance冷p956266.079ms／暖7193.785；title冷7399.793（5秒sample影響）、暖5650.963。 | 真Main pipeline至MainActor state publication，非像素；舊150ms可重現未達保留為歷史；依主人最新約60秒容忍範圍，既有暖p95接受，不再列目前阻擋。未證明所有操作max<60秒或iPad硬體效能。冷／暖及受取樣影響範圍分開。 |
| QA版面對照 | 移除逐列ViewThatFits的fixed-wide診斷版，同40×2全部IDs/title/order exact；relevance暖p951174.688ms、title暖1497.219ms。 | 有明確改善但仍未達150；wide-only，不promote正式版，不稱narrow/a11y PASS。fixed-height因無因果證據未run。backend phase另40×2已完成，全80 binding與結果exact；總p95 relevance922.811ms/title864.007ms。repository p95約196.631/209.088，Rust/hydration與調度另計，扣phase/debounce剩餘牆鐘p95約682/689ms，不能稱純layout CPU或production150ms PASS。 |
| 人工與條件項 | iPad旁白、兩端整體聽感與PiP五項USER_PASS；Mac旁白等USER_EXCLUDED。 | 最新主人回報已用53.5GB／64GB，約可用10.5GB，USER_REPORTED且非machine exact；完整10GiB實填USER_NOT_REQUIRED，舊14GiB門檻不再阻擋縮小scope。小檔工程已PASS_SCOPED：既有真SMB7／7、新localharness11／11 checks及Rust3／3tests，raw/source/digest由Root核對；非iPad硬體或10GiB實填。 |

## 證據入口

- 本輪工程、成品、效能、NAS、DSP、清理：`.cmv-local-evidence/2026-10-08-final-closeout/`。
- final-v2建置／簽章／資產／Mac還原／Root iPad封存核對：`ui/final-v2/`，Mac最新 `mac-final-postlaunch-readback.json`。
- Main50k全40 raw與Root綁定核對：`performance/main-ui-qa/runtime/primary-baseline-validation.json`；A/B `layout-probe/primary-comparison.json`；兩個sample各有observer scope說明。
- Lease：`reliability/lease-repair.json`與`hosted-lease/`；原xcresults retained，生成DD已清。
- iPad實機完整原始圖/XML／restore：`.cmv-local-evidence/2026-10-08-ipad-takeover-01a11765/continuation/`；`archive-receipt.json`、`final-v2-ui-continuation-receipt.json`、`ui-final-postlaunch-receipt.json`。
- 原36focus／NASproduction／EOFhost：`.cmv-local-evidence/2026-10-08-remaining-validation/`。

## 審查與剩餘工作

S01 immutable與S02 parent-linked861檔snapshot均seal；S02三席focusedfinal＋independentarbiter全部報告SHA與同快照綁定，9IDs/6lanes已逐項查證，結論blocked（不是cleanclosure）。完整ledger `council/chair-s02-ledger.json`。不得把S01當最新final-v2結果；目前Main性能P1依主人約60秒容忍標準解除驗收阻擋；S02依舊150ms的結論保留，不改寫成150ms PASS。QA版面對照未promote，這轮只判讀已有資料，不重測或新增實作。仍留真NAS、窄picker與已列工程scope限制；iPad容量已USER_REPORTED，full10GiB改USER_NOT_REQUIRED，小檔工程scope11／11＋Rust3／3已由Root讀回通過，非硬體壓測。

CodeRabbit未執行，ordinary risk-based review unavailability如實記錄；沒有上傳／外部審查PASS。安裝的critic_contract.py缺失，JSON可parse不是結構validator PASS。required unknown不能轉Done，會保留精確unfinished checkpoint。

人工剩餘見[集中清單](manual-verification-checklist.md)。iPad連線由「測試 iPad 連線」獨占，Root只讀證據、傳送授權範圍交接；不競爭裝置。OS與資料已還原，owner已正常停止自建8766relay，fresh無LISTEN、WDAhost不存在；不用舊PID假称仍在線。

## 工作資源清理

依主人最新授權，已移除舊Shutdown simulator、iOS26.5 simulator runtime、完成final-v2與lease DerivedData、8個已完成scratch中的可辨識SwiftPM cache、3個無ps/lsof引用的舊全域DerivedData。原證據、source、fixture、曲庫、簽章profile、現用QA與WDA保留；現在已確認本輪iPaddebug完成、exactpath無ps/lsof/debugger，鎖標記為舊無holder，per-version DeviceSupport/cache約5.5GiB也已清，保留metadata供查證。開工前30GB為主人回報，非實測起點；先前Mac可用27.29GB≈25.41GiB；最新df可用30.575GB≈28.475GiB。

重開機／斷線為ENV_INTERRUPTED；沒有足夠可重現缺陷證據則NOT_REPRODUCED，不列產品FAIL；未執行項仍不自動PASS。這不抹除舊150ms未達的raw；目前暖p95依主人約60秒容忍標準接受。

既有frozen raw posthoc分段：query→task p95318.730/398.582ms，非空query task→debounce p95394.466/457.351ms；page→pub<0.7ms，完整80generation綁定。空string依法跳過debounce，初版posthoc假設40debounce的assertion已修正為39且保留原因，非產品FAIL。新的容忍標準下不再把state-isolation A/B列本輪必要修復；未實作或promote，正式候選維持原樣。

## 2026-10-08 06:03 PiP 人工結果對帳

已直接read_thread核對主人5項PiP人工USER_PASS。收據 `.cmv-local-evidence/2026-10-08-ipad-takeover-01a11765/manual-pip-20261008/user-verification-receipt.json`，SHA `53164d071cd6e2e64c5b5d10d3e2f3a4738e879d8d6856c56e75c7db7426b63e`。候選關聯依最後已安裝4d684522…，沒有freshdevicequery或newinstall；原toolunknown與S02結論保留為歷史，新manualdelta移除PiP pending。仍留上述五項主要缺口與其他工程scope限制，整體Review。

## 2026-10-08 06:09 主人驗收標準／聽感更新（整體仍 Review）

已直接讀回「測試 iPad 連線」主人 turn `01a11866-b964-7383-855d-898514aab835`：五萬首等待約一分鐘可接受，聽感沒問題。既有 Main 暖查詢 p95 relevance 7193.785ms／title 5650.963ms 符合新容忍範圍，記 `USER_ACCEPTED_WAIT_CRITERION`，解除舊 150ms 的目前驗收阻擋；不宣稱達到 150ms、所有操作最大值小於 60 秒或 iPad 硬體效能已量測。Mac 整體音樂／影片聽感 `USER_PASS`。人工收據 SHA `14124185…`、3檔 delta-manifest SHA `931cb34e…` 已逐檔核對。

目前主要剩餘：真 NAS slow／stale refresh、窄窗 picker 取消、iPad 當前可用容量待答。fresh devicectl 只證明 iPad 總量 64GB，沒有目前可用數值；先前 4.79GB 不當作現在保證，10GiB 壓測維持 `PENDING_FRESH_AVAILABLE_CAPACITY`。Mac fresh df 可用 30.575GB（28.475GiB）。S02 blocked 是舊標準下的封存結論；原 raw／S01／S02／sealed 評論保留，新 delta 只修正目前驗收判讀，不重測、改實作或競爭裝置。其餘工程 scope 限制仍見本輪報告。


## 2026-10-08 06:19 iPad 容量／測試範圍更新（整體仍 Review）

已直接讀回主人 turn `01a11870-9a94-7850-9f0f-cd79630fc6c2` 原話與容量scope收據（SHA `6e907b0f…`、manifest `9e40c79d…`）。主人最新回報iPad已用 **53.5GB／總64GB**，按顯示數字約剩 **10.5GB（9.78GiB）**，記 `USER_REPORTED`；設定顯示有四捨五入，不稱machine exact。容量待答已解除。主人說不需把10GB全部塞入，完整10GiB實填改 `USER_NOT_REQUIRED`，舊14GiB安全門檻不再阻擋縮小scope；這不代表完整10GiB實機壓測PASS。改核對既有小檔實際cache／縮小budget淘汰／pinned保護／重開與metadata計數邊界收據，有缺口才補最小測試；未配置大檔或刪私人資料。

目前主要仍是真NAS slow／stale refresh與窄窗picker取消；小檔cache工程scope由Root核對既有執行證據，未核對前不補造PASS。S01／S02／241archive／11cleanupdelta保持不變；Mac約30.575GB及人工/性能已接受結果沿用。


## 2026-10-08 06:35 小檔快取工程驗收完成（整體仍 Review）

主人回報iPad已用53.5GB／總64GB，約可用10.5GB；完整10GiB實填 `USER_NOT_REQUIRED`，容量不再待答。既有同source真SMB小檔cache raw7／7沿用；新增production-identical macOS小檔harness **11／11 checks PASS**（32／32／64bytes、smart budget64、淘汰oldest、pinned保護、新actor重新實例化與SHA讀回），Rust cache **3／3 tests PASS**（budget／LRU-pinned／u64 aggregate overflow）。Root已讀回raw、核對來源與fixture預期digest；本次build/target/fixture均已回收，只保留小型harness及證據。收據 `cache-small-scope/primary-readback.json`。此為小檔工程scope，不稱iPad硬體或完整10GiB實機壓測PASS。

目前主要剩 **真NAS slow／stale refresh** 與 **窄窗picker取消**；其餘已列工程scope限制保留。整體Review，S02舊標準結論與封存不改寫；沒有新產品實作、裝置操作或store上傳。
