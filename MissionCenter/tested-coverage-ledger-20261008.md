# 累積驗收紀錄｜2026-10-08

本紀錄集中保存數日實測及主人已確認的結果，避免已驗項目因舊 checkpoint 再次列為待測。`tasks.md` 仍是任務生命週期唯一來源；此檔是證據索引，不把有限通過推成整項 Done。歷史失敗與舊候選收據保留，後續修復結果另列。

## 主人已接受的結果

| 項目 | 結果與範圍 | 來源／重測規則 |
| --- | --- | --- |
| iPad PiP | USER_PASS：進 PiP、暫停、播放、返回 CMV；時間、曲目及 pause state 正常 | 主人逐項確認；不重測 |
| 兩端聽感、iPad 旁白 | USER_PASS；主人確認聽感 OK、回聲為效果感受 | 主人人工聆聽；不冒聲學無縫量測 |
| 窄幅 picker 取消 | USER_PASS | 主人確認以前已測過；不冒本輪精確窗寬自動化 |
| 五萬首搜尋等待 | 約一分鐘符合主人接受標準 | 不重新以零等待判失敗 |
| iPad 填滿 10 GiB | USER_NOT_REQUIRED | 主人要求不用塞滿；53.5/64 GB 為主人回報 |
| Mac VO、全斷網、Bluetooth、AirPlay | USER_EXCLUDED | 不重啟已排除範圍 |

人工接受的原始脈絡及收據入口見 [原收尾檢查點](closeout-checkpoint-20261008.md)；以上不因本轮工具中斷變回未知。

## 工程與實機已驗範圍

| 平台／日期 | 操作／預期 | 實際結果與限制 | 證據入口 |
| --- | --- | --- | --- |
| Mac、iPad／10-08 | 真 provider 匯入 205 AAC；九 metadata 正確 | 兩端各九欄 ×205 exact、source available、全資料還原；不是所有進階欄位 GUI 矩陣 | metadata 修復27 payload，manifest40735411…f1f；daily-log 11:00 |
| Mac／10-08 | 四欄八方向排序及跨 200/201 分頁一致 | PASS_SCOPED；可見頭尾及共同項驗證，不冒每列全矩陣 | mac-sort-matrix，218 payload，manifest a54abc4a…8882 |
| iPad／10-08 | 两首選取後播放 | owned T001/T002 queue、T001 GUI 播放、raw index1；T002 獨立畫面 UNKNOWN；完整還原 | daily-log 11:00；ipad-provider-root 選取播放收據 |
| Host／10-08 | standby 排程、timeline、ID ownership 修復 | 最終 45 XCTest、0 fail、0 skip；包含 render deadline；不是實機聲學 gapless | standby-queue-repair-01，14 payload，manifest 8f869b55…deb1 |
| Mac／10-08 | 播放中重排、移除、追加重複 occurrence、精準刪除尾項 | latest Core：6→5→6→5，無 seek/Next/Previous；自然 Long→Silver→Cobalt→Amber→MOV；末項 12/12 paused 保留 queue，replay 前進；完整還原 | [Core 實機封存](../.cmv-local-evidence/2026-10-08-task-zero/mac-standby-fixed-runtime-01/manifest.json)，26 payload，6755c69b…e9e4 |
| Mac／10-08 | 歌單建立／改名、六首加入、上下移、單曲移出、批次取消／五首移出、空歌單清理、取消選取 | PASS_SCOPED；原檔 SHA exact；完整還原。批次artist preview/undo及冷啟動見後續補驗；其他欄位與iPad歌單後續結果見下方晚間切片 | [歌單批次封存](../.cmv-local-evidence/2026-10-08-task-zero/mac-batch-playlist-runtime-01/manifest.json)，18 payload，83c90d31…2b28 |
| Mac／10-08 | logical exclude 後側欄 count 更新 | 修前 batch2 logical 成功但 count stale P2；修後單曲及批次單選入口 1977→1976→1975、篩選6→5→4、僅2首 excluded；14份原檔 exact，9表、queue319→322、App 偏好還原。最新一次 batch2／實體垃圾桶未重驗 | [count 修復封存](../.cmv-local-evidence/2026-10-08-task-zero/mac-sidebar-count-runtime-01/manifest.json)，13 payload，99e7f5b3…b7eb |
| Mac／10-08，最新countfix | 批次歌手preview／cancel／apply／undo及冷啟動 | 2首選取：preview/cancel不寫入、apply僅selected2 artist/override、undo6首捕捉欄exact；第二patch冷啟動GUI/raw保留；原7檔不變，9表/queue322→325/App偏好還原；僅artist GUI，不冒各欄及異質undo矩陣 | [批次資訊封存](../.cmv-local-evidence/2026-10-08-task-zero/mac-metadata-batch-runtime-01/manifest.json)，12payload，manifest6a0372c07f8d20794db2dca2962ff0a6e25f466bb2ad1a7a9464649092525745 |
| Mac／10-08，最新countfix | 八欄批次預覽、套用與不同原歌名復原；歌曲資訊 | 兩首8欄exact，其他4不變；native undo六首捕捉欄exact；Song Info直接顯示8欄及時長/加入日期。當日default日期，不冒calendarediting或所有欄異質原值；9表/queue325→328/App偏好還原 | [八欄收據](../.cmv-local-evidence/2026-10-08-task-zero/mac-metadata-fields-runtime-01/manifest.json)，10payload，manifest61e8909bd958b2756876a01e239ada0022ac60091c715a23fe798f7db7ee8a7f |
| Mac／10-08，最新countfix | 進階排序六欄十二方向 | 專輯歌手/類型/曲目編號/唱片編號/加入時間/發行日期，首尾24組對205實際資料全exact，各方向末尾載入205；不是全205中間GUI列。205原檔不變，9表/queue328→331/App偏好還原 | [六欄排序收據](../.cmv-local-evidence/2026-10-08-task-zero/mac-advanced-sort-runtime-01/manifest.json)，8payload，manifesta359686d56cabb07fd49dca913bcc44b7dd929861c1bba6e8acd0815504d374c |
| Mac／10-08，最新countfix | 時長及評分不同值升降冪 | 6首各6不同值，完整6列×4方向GUI與persisted值exact；評分經原生menu設定，原7檔未變，9表/queue331→334/App偏好還原 | [時長評分收據](../.cmv-local-evidence/2026-10-08-task-zero/mac-duration-rating-runtime-01/manifest.json)，8payload，manifest0cb79275adc30015bb7cad9b268127deb6ee7095ee669da7df503208dc8a30fd |
| Mac／10-08，最新countfix | Smart DJ 建立／播放、分析與冷啟動 | 5音訊推薦與queue順序exact，未分析即播放；Violet分析version3後時間前進，Long0:17；冷啟動occurrence/順序/index3與分析exact、paused0:00。原7檔不變，9表/queue334→337/App偏好還原；不冒位置恢復、Silver播放或聲學gapless | [Smart DJ收據](../.cmv-local-evidence/2026-10-08-task-zero/mac-smartdj-runtime-01/manifest.json)，13payload，manifest1a5e6c5e…a3876 |
| Mac元件／10-08，最新source | 跑馬燈完整來回、短字靜態與背景恢復 | 原樣元件harness：同序列開頭→中段→尾端→返回、OK靜態/完整AX/200pt可見邊界；注入background靜態、真hide Scene background/raise active並恢復位移。兩ps CPU累計顯示不變；不冒整App效能、ReduceMotion或iPad驗收 | [跑馬燈元件收據](../.cmv-local-evidence/2026-10-08-task-zero/marquee-component-runtime-01/manifest.json)，6payload，manifest55f73c678771c510b266bcf20d115f8c207ee977ae49e53e5d9fc5c58419d586 |
| Mac／10-08，最新countfix | 原曲庫暫停狀態前景／背景資源 | 三段各20秒：平均單核心CPU 24.61%→7.20%→0.05%；恢復原1971/0:00 paused，9表/queue含revision/App偏好exact。不是播放／匯入壓力或全動畫frame追蹤；RSS首次上升不推全效能PASS | [Mac背景收據](../.cmv-local-evidence/2026-10-08-task-zero/mac-idle-background-runtime-01/manifest.json)，9payload，manifestff0a45a2e69752c6823e58d92eb8d9869410293823bbcc07cc37b021ea5e4f22 |
| Mac／10-08，最新countfix | 四EQ選取／正常退出／冷啟動 | 原音/低音增強/人聲/電子逐項GUI與保存值exact、0.3/自訂值保留、paused0:00、queue內容不變；原9表/queue337→340/偏好全keys還原。不冒裝置PCM輸出或44pt實測 | [四EQ收據](../.cmv-local-evidence/2026-10-08-task-zero/mac-eq-runtime-01/manifest.json)，13payload，manifestab2fd485fa49f6f5ac1a6882acf6fea317a50b0aa84744d3dfe04d463ebdfede |
| Mac／10-08，最新countfix | 實際App長短文字卡片 | 短字靜態、105字完整AX/位移、marker尾端停留及返回位移；完整自然回開頭UNKNOWN。原9表/queue340→343/App偏好還原，iPad暫停 | [本輪文字收據](../.cmv-local-evidence/2026-10-08-task-zero/mac-marquee-app-runtime-01/manifest.json)，6payload，manifestad25952761e6cc9f018d15dd48dc8e70fd679865435bc5aac25e054379a8898a |
| Mac／10-08，最新countfix | 自訂音效七值冷啟動／對照／重設 | 七GUI與保存payload exact、對照保留、重設中性值；原9表/queue343→346/App偏好還原。不冒worker/PCM/iPad | [自訂音效收據](../.cmv-local-evidence/2026-10-08-task-zero/mac-custom-effects-runtime-01/manifest.json)，8payload，manifest63eec9fa28b4cfe36b7370abe062f93127da077eaa407c561b7dca541d12ced5 |
| Mac核心／10-08，latest source exact | 播放中520次音效切換 | 13模式×40、12節點拓樸逐次exact、時間前進、running/timeline failures0、clearQueue收尾；獨立host核心，非整App/iPad | [快速切換收據](../.cmv-local-evidence/2026-10-08-task-zero/mac-rapid-effects-core-01/manifest.json)，16payload，manifest36a078a2a735adbcb80d29818e30e6df2bd0166e41f729a3cebc736964745753 |
| Mac／10-08，最新countfix | 實際App文字自然來回 | 24字稍微overflow：同序列開頭→END尾端→開頭，短T001靜態，full AX；105字完整cycle未捕捉。原9表/queue還原，ReduceMotion待確認 | [循環收據](../.cmv-local-evidence/2026-10-08-task-zero/mac-marquee-cycle-runtime-01/manifest.json)，5payload，manifestfa33e076f1411a6e619f9c8e6f9f22eeb4afc453d711636dd7f391d0ee1ba2a8 |
| Mac／10-08，最新countfix | 86字多語長文字來回 | 完整尾端→返回完整開頭、full86AX、短T001靜態；34frame兩批含23秒觀察間隔，只核8frame；原資料完整還原 | [長文字收據](../.cmv-local-evidence/2026-10-08-task-zero/mac-marquee-long-runtime-01/manifest.json)，5payload，manifest9b8d4162d2011598382ae3ee45551ce3f414f7c5edd12dcb318567da39649702 |
| iPad／10-08，較早 terminal 修復候選 | 單一 owned MOV 自然 EOF／replay | 12/12 paused、queue1 保留、replay0→7；9表／queue238→241／偏好還原；不是最新完整 mixed 矩陣 | terminal-video-ipad-runtime-01，34 payload，1d1a4e4a…f377 |
| iPad／10-08，最新 countfix | 正常 iCloud picker 匯入六首，播放所選，自然路徑及 future 重排 | source available/6 exact；Long GUI0:22/2:00 playing；原生 Silver 移最前操作跨自然 EOF，raw 路徑 Long→Cobalt→Amber→Silver→Violet→MOV、index5/history6。未逐首畫面確認，末項 EOF/replay、remove/duplicate、歌單與 count 尚未驗；WDA exit65／connection refused 為工具中斷 | [本輪 iPad 封存](../.cmv-local-evidence/2026-10-08-task-zero/ipad-sidebar-count-runtime-paused-01/manifest.json)，11 payload；manifest 21d9196239e311600ecdf156253b2bf3fc17b88669948d81e65be5a59f3267a5 |
| NAS／既有＋10-08 | SMB 成功讀取、cache、slow/stale 契約 | 真 SMB64KiB exact、stale=false；歴史 Mac10GiB PASS_SCOPED；小 cache Swift11/Rust3、local stale/injected slow PASS_SCOPED。真 NAS slow/stale 未刺激，UNKNOWN | closeout-checkpoint、NAS 原始收據；不把未知當失敗 |
| 音效／既有＋10-08 | mono44100、anti-phase Orbit、設定不重置 timeline、pause mute/play restore | AudioEffects14 工程通過；13 preset stereo harness＋主人聽感接受；非連續聲學無縫量測 | daily-log「音效既有收據補核」及 AudioEffects raw |
| 雙平台／10-08，最新 countfix | 四 archive、兩出口、簽章／profile／entitlements／dSYM 對應 | 4 archive0、95 source exact、2 export0、6 qualification0、4 binary/dSYM UUID exact；243 payload SHA/bytes親核0 mismatch。未 upload/submit/publish | [最新成品封存](../.cmv-local-evidence/2026-10-08-task-zero/sidebar-count-fixed-artifacts-01/manifest.json)，manifest 96457300…ceca；Native/DISTRIBUTION_CHECKPOINT_20261008.md |
| 雙平台成品／10-08 | Distribution簽章Team直接對應 | actual兩archive Team與原建置recipe exact；SG4依賴RC4仍Blocked，保持Backlog，未上傳 | [Team收據](../.cmv-local-evidence/2026-10-08-task-zero/signing-team-readback-01/manifest.json)，1payload，manifest14c50daa1bedead33eaa81fc3d13d4d9ece0adb615331150b2dabed97040ede8 |
| 隱私來源／10-08，latest source | 本機資料流靜態對照 | 12主要來源SHA/bytes exact、57 Swift/Rust檔指定網路token0hits；StoreKit/SwiftData/cache/queue/分析讀碼，非封包或遠端問卷驗證。Mac確認後physicalTrash政策例外本機補正、待公開同步 | [來源收據](../.cmv-local-evidence/2026-10-08-task-zero/privacy-source-readback-01/manifest.json)，1payload，manifesteed64de08c9be5e6629ab77a192102415db1bde0034f2e8d8a7cb959c3118843 |
| 商店資料／10-08 | Gemini 三語活潑白月光文案與 ASC 回讀 | 15目標＋18保護欄，共33 exact；WhatsNew本機；未上傳成品，截圖仍待 | closeout-checkpoint「Gemini商店文案」及 gemini-asc-final-readback-receipt |
| ASC／10-08，本次fresh | 版本／build完整分頁及隱私登入阻礙 | 兩平台2.0 PREPARE_FOR_SUBMISSION、builds0；隱私問卷未回讀，CLI無web session/Chrome登入頁，等主人登入；非問卷PASS | [後台收據](../.cmv-local-evidence/2026-10-08-task-zero/asc-privacy-current-readback-01/manifest.json)，1payload，manifest92390f2569367c4bae2927f82bc584c0cf13208702963546938481b064ac7ceb |
| 資料復原／各輪 | 測試後保留私人曲庫／queue／偏好 | 各已封存輪次有9表全欄列與schema、queue非revision及App偏好比較；Mac NS/StoreKit系統keys變動明記。最新iPad本輪9表exact／integrityok／queue244→247非revision exact／preferences全keys exact | 各 runtime restore/readback 收據；private baseline只留tmp，不入Git／封存 |

| iPad／10-08晚間，最新countfix | 六選取、歌手單欄preview/confirm/undo、空白取消及離線釘選 | 六選取/批次列直接GUI；確認前無寫入、确认後6exact、undo歌名/歌手/mask exact；離線新增6失敗0，非離線來源失效播放測試 | [本輪收據](../.cmv-local-evidence/2026-10-08-task-zero/ipad-user-resume-batch-terminal-01/manifest.json)，5payload，manifest470004c2c4e83f9e6d43aba2105ea249f4d5ac328232d15d96a94fc9eecb212b |
| iPad／10-08晚間，最新countfix | mixed末項自然EOF／replay與fresh還原 | 六首queue index5/repeat off，直接GUI12/12 paused→同末項5/12 playing；queue三snapshot exact。五檔啟動前bytes exact、冷啟動九表全欄/schema、queue247→250非rev、prefs全keys exact/integrityok；cache不在五檔基準 | [本輪收據](../.cmv-local-evidence/2026-10-08-task-zero/ipad-user-resume-batch-terminal-01/manifest.json)，private基準只留tmp |
| ASC／10-08晚間，解除登入後 | Apple已發布隱私宣告GUIfresh | 直接顯示不收集資料、資料類型不會收集、canonical政策URLexact；未遠端編輯或發布，不代表CLI web session恢復 | [Apple回讀](../.cmv-local-evidence/2026-10-08-task-zero/asc-privacy-unlocked-readback-01/manifest.json)，1payload，manifest1fe3a9d651204174b594fb30ca680a2163c35741d3bebcdec360f79c7c909e81 |

| iPad／10-08晚間，最新countfix | 歌單與曲庫保留 | 建立→六首加入→移除Long但曲庫六首仍在→MOV上移→改名→冷啟動全欄exact→刪除歌單且曲庫全欄exact | [11payload封存](../.cmv-local-evidence/2026-10-08-task-zero/ipad-playlist-dj-queue-evening-01/manifest.json)，manifest c7cfe07e77e05f93ff86d6f8dc05e14574aad87d6099ae0033867249229bdc8f |
| iPad／10-08晚間，最新countfix | SmartDJ未分析播放、播放中queue增刪與冷啟動 | 五首自有WAV未分析仍直接播放/自然前進；future移除、append保留current與原前綴、同track不同occurrence、短窗只移除指定duplicate；五項coldlaunch非revision全欄exact，279→282，paused不自動播放 | 同上；第一次Long移除讀回跨EOF只驗指定項移除，短窗Cobalt補測成功；分析後播放另見下一個分析/count切片 |
| iPad／10-08晚間 | 第二輪完整資料復原 | 啟動前五檔bytes exact；啟動後九表/schema/全列與queue247→250非revision exact、integrityok；prefs僅SKTransactionUpdatesLastChecked不同，原19首/原曲目0:00 paused；cache非基準 | 同上；不冒偏好全keys exact |

| iPad／10-08晚間，最新countfix | 分析後播放與logical移出/count | Long分析version3/BPM91.7，直接GUI同曲1:39/2:00playing；六自有移出後active25→19、搜尋0/側欄19，非自有全欄exact、435records保留；同provider host原檔hash exact。五檔beforelaunch bytes與afterlaunch九表/queue/prefs全keys exact還原 | [5payload封存](../.cmv-local-evidence/2026-10-08-task-zero/ipad-analysis-count-evening-01/manifest.json)，manifest 3af9e3577f0063903d753fc87b7246c2316a5b69beceb305ead4fb28f7e70fd2；未做重新索引/重啟排除、單首分析不冒全曲庫效能 |

| iPad／10-08晚間，最新countfix | 自訂七值/cold／原音對照 | 七值GUI變更及cold保存exact，compare roundtrip保存exact；私人曲目paused。九表與queue253→256非revision還原exact；prefs被CFPreferences快取覆寫，restore尚未通過；CMV已stop/baseline prefs再次copy，等待reboot後首次launch前再copy | [6payload partial](../.cmv-local-evidence/2026-10-08-task-zero/ipad-custom-cold-evening-partial-01/manifest.json)，manifest ed22efc42cdf1d7110bd1c914af6fd8fb4ace373fc64f14ddd086a424062c94b；不冒四EQ/worker absence/完整還原PASS |

歷史開發候選的 scoped PASS 保留。最新 countfix 相對 Core 候選仅 AppModel／LibraryViews 兩檔變更，受影響側欄已補驗；其餘驗證按 source lineage 沿用，不宣稱所有歷史 GUI 皆在最新 binary 重跑。舊 iPad standby 卡住的 P1 留歷史，Host修復與 Mac最新自然遍歷另列；不能抹掉失敗，也不能讓舊失敗遮掉新結果。

## 重開機後補充（2026-10-08）

自訂音效測後還原已完成：[5 payload final](../.cmv-local-evidence/2026-10-08-task-zero/ipad-custom-cold-restore-final-01/manifest.json)，manifest SHA `01d0ba91f10964813d97fae9164b2adffbeda922bdf027233541b79629ab70f3`。九表/schema/全列、queue253→258非revision與effects encoded key exact；偏好只有StoreKit檢查時間更新。GUI浴室100%/paused，獨立Luna唯讀複查通過。舊partial的等待狀態保留為歷史。

iPad四EQ選取及冷啟動已完成：[4 payload封存](../.cmv-local-evidence/2026-10-08-task-zero/ipad-four-eq-runtime-01/manifest.json)，manifest SHA `30290777ae5149bc91afc3639d08339789477bf74856c5f5aae62d44da32ee33`。原音/低音增強/人聲/電子各selected/cold payload exact，強度與custom六值保留，未播放私人歌曲。測後九表及queue258→268非revision exact；effects解析全部值exact，但encoded JSON key order不同，嚴格raw比較曾assert失敗；解析後其餘偏好只StoreKit時間不同。不冒PCM輸出、44pt或worker absence通過。

八欄批次 metadata 與首頁排序補驗：[11 payload封存](../.cmv-local-evidence/2026-10-08-task-zero/ipad-eight-metadata-sort-heads-runtime-01/manifest.json)，manifest SHA `20d70670aaad6cf4ae83f0bd5500c41dc3c3231dce8baebf796528810ce7decb`。205 owned fixture 匯入後224 active；preview 八欄未提前寫入，套用只改 T001/T002 八欄、其餘618筆不變，undo 全620筆八欄 exact 回復。Song Info 直接顯示八欄/時長/加入日期。專輯歌手、類型、曲目編號、唱片編號、加入時間、發行日期各升降冪可見前12，對實際205資料 strict exact；不冒205中間列、末頁或跨分頁已驗。測後九表 schema/所有欄列、queue268→271非revision、effects encoded 與全部 prefs exact 還原，GUI 原19首/0:00 paused。曾誤點兩首 owned 離線釘選，新2/失敗0；快取不在五檔還原範圍。預設當日日期，不冒日曆編輯。WDA host04 exit65後以既有成品啟動host05關閉test timeout、relay06恢復；不把控制服務中斷當產品fail。

## 真正剩餘的範圍

- iPad 最新矩陣：custom偏好完整還原、四EQ與八欄 metadata/異質undo已補；排序末頁/跨分頁、時長評分distinct與文字仍待。已驗歌單/DJ未分析/queue mutation/duplicate/coldlaunch/末項EOF均封存，不重跑。
- I13：兩端八欄 preview/apply/undo 及 Song Info 已補；iPad 六欄十二方向首頁12已補，末頁/跨分頁仍待。Mac六欄十二方向首尾與時長/評分distinct完整6列四方向保留；205中間GUI列未逐列擷取。
- U25：原樣Mac元件循環／短字靜態／背景恢復已補scoped；最新Mac暫停狀態背景CPU降低已量測；Mac actual App86字長文字全文AX/位移/尾端/自然返回與短字靜態已補；ReduceMotion、完整App背景停動畫面及iPad直接矩陣仍待；其他負載沒有量測，不因此新增必做壓測；SD4：Mac Smart DJ queue/play、analysis/play、冷啟動已補驗；iPad DJ未分析建立/播放/加入queue及分析後播放已由晚間切片補齊；Reduce Motion授權與直接證據仍待。
- 音效：兩端四EQ選取/冷啟動與iPad自訂七值/cold/對照/完整偏好還原已補；工程13preset輸出、人工聽感、Mac520次核心切換保留。44pt與完整App/iPad快速切換graph、兩端完整route/worker範圍仍依FX33～FX36條件，不把保存驗證當全部輸出通過。
- 真 NAS slow/stale 實际刺激；同候選授權商店截圖及未剪輯 demo。
- 正式四席評論原輪超限中止的歷史保留；主人晚間明確授權超額繼續，原上限改用量參考，仍需三critic與独立arbiter真實新報告。上傳／送審與發布仍未執行。

各任務的完整條件以 tasks.md 為準。補驗只針對尚缺範圍或後續變更影響項目；已接受與已有有效 scoped 證據不反覆重測。


## 2026-10-09 補驗對帳（保留前述歷史）

- iPad 205 首歌名末頁升降冪、兩首不同時長雙向、兩首不同評分雙向均已分別封存；不再將這三項列為尚未測。
- iPad 長字唯一端點 END→BEGIN→END 自然往返及短 STATIC 固定位置已實測；前背景採樣證據僅代表 DisplayLink／TimelineView 活動下降。新版 Reduce Motion 仍待授權與來源綁定驗證。
- 左右欄入口與土星固定構圖已在最新 iPad 候選覆蓋實測，六張橫直向 native PNG 留存；頂端整條底色已移除，兩顆各 44pt 控制分居左右。
- 2026-10-09 混合佇列：播放中未來影片重排、移除、下一首插入均觀察長曲維持播放且進度前進；插入後七個 occurrence、shuffle 開／關恢復原順序、正常冷啟動 queue 非 revision 全欄 exact 已補。封存 `ipad-mixed-queue-restored-01`（7 payload，manifest SHA256 `a184dc65fe490d9adff7c50c5e8ebd6ebdb63ed4497fe4a1ea4a9b8413d02979`）。
- 上述混合 GUI 狀態取樣未量測 PCM 零間隙；冷啟動 UI 顯示 0:00 暫停，沒有把持久化相同誤報成已驗證恢復 seek。測後原始五檔寫回／讀回 byte exact，正常 launch 後九表全列 exact、429 原曲／原 queue／encoded effects 恢復；preferences 僅 StoreKit 檢查時間不同。
- 商店 13 吋模擬器 build／install／boot 均已成功，但實際 CMV UI 尚未載入，正式 capture 仍為 0；最新 source 的發行 archive 與正式四席評論尚未完成。任務狀態以 tasks.md 為準，未用新增窄證據宣稱全面完成。


### 2026-10-09 Mac覆蓋、資料還原及商店素材補記

2026-10-09 本輪最新 source 95/95 ordinary Mac before/after、distribution before/after/current exact；IPA/PKG 實際SHA/簽章架構驗證已封存 latest-release-prepared-01。Mac同bundle新版覆蓋、正常GUI啟動1971曲後還原九表全列/queue非revision/encoded effects exact、app-owned prefs changed0。商店頁唯讀確認iPad13與Mac分平台獨立截圖欄位，各0/10；依主人最新規格生成四主題×兩裝置八張英文宣傳圖、原創歌手置於月輪，root讀回Mac2560×1600/iPad2064×2752、RGB無alpha及SHA8/8。生成介面為示意、實際UI忠實度仍待；原30場景capture/demo、正式評論、upload/submit未完成，不Done。

證據：`.cmv-local-evidence/2026-10-09-task-zero/latest-release-prepared-01/`；Mac還原實際收據`/tmp/cmv-task-zero-20261009-afternoon/mac-overwrite/store-restore-final-comparison.json`；八張素材`Native/ReviewMedia/vtuber-covers/20261009/single-device/manifest.json`。素材尺寸PASS不等於商店審核PASS。

### 2026-10-09 現行發行資格／評論封包補記

2026-10-09：現行雙平台四個archive/export Distribution資格actual0與dSYM UUID一致；SDK權限檢查工具補profile未授予automatic key拒絕，root9tests0/兩出口guard0，production不變。正式三席S01盲評＋S02漏件修復已啟動；S02的541項SHA核實。五項Next更新現行成品，舊Next保存output/mission-center-critique/20261009-current-next-reconciliation.json、任務status零變更。原生Screenshot/Preview/Xcode CUA均timeoutReached，iPadWiFi disconnected；不宣稱實機補驗或商店上傳完成。
