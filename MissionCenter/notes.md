# 筆記

## 2026-10-08 Mac佇列補驗與Gemini商店文案

主人指定Antigravity Bridge Codex的Gemini撰寫活潑三語文案，保留「現在可以傾聽你家白月光的歌聲啦(X」。實際model gemini-3.8-flash-high，初稿／修稿同cascade terminal完成；工具無filesystem寫入能力，由Root保存回應並整合canonical、核12欄字數與功能界線。Apple兩次拒絕符號的原始stderr保留；移除副標題星星、替換描述不接受的emoji／顏文字後，ASC15目標欄exact＋18保護欄exact，共33。WhatsNew僅本機；未上傳Build、送審或發布。舊33欄封存不改。

Mac main同final-v2 binary：原創Amber/Cobalt真2首多選播放；mixed插入Video、重排Cobalt至下一首、移除future Video均保持Amber播放與時間前進。兩首shuffle開關與quit/relaunch保留順序及paused current；25秒位置回0秒，不宣稱位置恢復。僅PASS_SCOPED，不取代gapless、完整mixed EOF、iPad多選、排序／跨分頁矩陣。

fresh本輪五檔baseline於CMV停止後還原byte exact；重啟9資料表全列exact、曲庫1971／DB1980／來源114／歌單0。queue非revision欄exact（295→298），app-owned偏好exact；系統window frame與StoreKit最後檢查欄有變。私人曲目paused0秒、未播放。回收本輪原創下載／解壓／衍生fixtures共70,538,107bytes，基準與小型收據保留，WDA／relay保留。

開工30GB記USER_REPORTED；本輪root可用19.47GB，後續19.03GB。sim devices0，不容量不足不清唯一runtime；主人已授權不足時清GAI／MediBuddy可重建sim。現有final-v2Development成品不可上架，歷史Distributionactual IPA／PKG／executable缺失；新現行Distribution準備中，尚無qualification PASS。

新收據：`.cmv-local-evidence/2026-10-08-task-zero/mac-queue-gemini-copy/manifest.json`（SHA d18781df8439e0b9631bdc29c2a924b4f4dc91ad234a14bfa8dc913389b771fd）、`gemini-asc-final-readback-receipt.json`、`mac-owned-queue-gui-receipt.json`、`mac-restored-readback-receipt.json`、`cleanup-receipt.json`。任務狀態保留；iPad解鎖仍pending，不重測已接受PiP／聽感／窄Cancel，不改S01/S02或RT4封存。


## 2026-10-08T07:48:35.628326+08:00 任務清零／Apple與現行證據對帳

主人要求目標任務清零，並授權參照GAI/MediBuddy既有Apple資料。最新ASC唯讀回讀：CMV App ID6815468050、Bundle com.windsheep.cmv；IOS/MAC_OS均只有2.0 PREPARE_FOR_SUBMISSION，完整build列表0；兩平台各en-US/ja/zh-Hant localization存在，六組screenshot/preview sets均0。GAI有READY_FOR_SALE與更新IN_REVIEW；MediBuddy有READY_FOR_SALE及1.4 REJECTED。別的產品已發布不能取代CMV正式成品；CMV既有聯絡/版權/三語文案依現有授權沿用，不新建帳號或重複App Record。

final-v2 manifest526項：現行525項SHA/大小exact，唯一差異AppModelReliabilityTests.swift為firstLease=nil測試引用釋放，無產品source drift；不能稱全526exact。核對人工與工程delta，更新11個任務的過時下一步文字，状态暫不轉Done：已接受PiP/聽感/窄Cancel/約60秒等待，10GiB實填不需要，排除項不重啟。真NAS slow/stale與其餘未驗矩陣保留。

commitments只讀報告92列缺少optional current evidence envelope；這是既有證據格式遷移缺口，不能等同92項產品測試未通過，也不能刪除既有Done。任務生命週期仍以tasks.md為唯一來源。新raw與收據位於`.cmv-local-evidence/2026-10-08-task-zero/initial-reconciliation/`，原S01/S02/241archive/11cleanup/R02不改。


## 2026-10-08 使用者補充：重開機與不可重現異常

主人確認剛才曾重開機，並指定「無法重現的失敗就不視為失敗」。本輪環境中斷記 `ENV_INTERRUPTED`；未能重現且未獲足夠產品缺陷證據的異常記 `NOT_REPRODUCED`，不列產品 FAIL。保留原始紀錄；未測／工具阻擋維持待驗，不冒列 PASS，也不覆寫已有可重現證據的缺陷。詳細 scope 以 `remaining-validation-report-20261008.md` 為準。

## 2026-10-08 01:06 最終補驗

Mac mini-player 長曲名已取樣字首→完整字尾→返回字首，列普通 Mac 版面 scoped roundtrip PASS；iPad／窄窗／Reduce Motion 不延伸。載入並暫停的影片上，13模式逐一核對影片音效可用；強度30→0實際成立，0%對照停用，reset回原音30%。全部仍是UI／route scope，13種聽感不冒列PASS。補驗後再次還原Mac：`restore/mac-final-restore-readback.json` raw exact；`restore/mac-final-postlaunch-readback.json` 最终重開資料／queue内容／app-ownedprefs一致，revision自然更新。iPad raw還原已完，postlaunch/PiP暫停人工問題仍pending。最新結論取代下方01:00 checkpoint中zero未測／Mac loop待驗的舊描述。

## 2026-10-08 remaining validation canonical update

本輪 review packet：`MissionCenter/remaining-validation-report-20261008.md`。重新連線後以 `/tmp/cmv-core-local-20261008` source copy 實際執行 4 組 focused filters，共 36 tests、0 failures；Package／Sources／Tests 25 檔 SHA 與 production 全部相同。先前原工作樹 SwiftPM 啟動卡住的 0/0 只保留為 `ENV_INTERRUPTED`，不可沿用成測試失敗。

EOF host 收據 `.cmv-local-evidence/2026-10-08-remaining-validation/eof-host/eof-terminal-replay-verdict.json`：natural EOF timer 64→64 停止、level 0、same item；seek/replay 後 timer 89、playing、level 非零，compile/run actual0。因使用 scratch `VideoAudioMeter` double，只列 host AVPlayer timer lifecycle PASS，不列 native DSP／聽感／裝置 UI PASS。

slow NAS 現有兩層證據：舊 `.cmv-local-evidence/2026-10-08-remaining-validation/slow-nas/host-receipt.json`／`slow-nas-lease-verdict.json` 只列 OS API capability probe；新增 `slow-nas/production-lease/production-lease-verdict.json` 實際走 production `SourceAccessCoordinator.lease`、`SecurityScopedMediaSourceProvider.makeBookmark/resolveWithRefresh/status`，SMB 讀 65,536 bytes、NAS→test-owned local lease switch、兩個 weak lease clear 後 nil，1 test／0 failure，判定 `PASS_SCOPED_PRODUCTION_COORDINATOR_PROVIDER_NAS_READ_SWITCH_CLEAR`。`stale=false`／refreshed nil 僅代表未注入 stale，slowresolve/acquired→stale 仍 pending；不重跑已通過 10 GiB capacity。

Mac UI 為原始 tool observation：選 2 首 queue2/index0，Next 後 index1/next disabled，末曲 natural EOF 後 queue empty／停止／回原音；marquee offset 有變化。13 preset 與 custom reverb10%／delay50ms 對照返回保留屬 UI config scope，非完整聽感。iPad playing→Home PiP `PASS_SCOPED`；native PiP pause 因 tool latency/self-hiding 未證明，browser policy check 不繞過。Mac VoiceOver `USER_EXCLUDED`；iPad VoiceOver 接受使用者整體 PASS。

本輪 restore 已由 `.cmv-local-evidence/2026-10-08-remaining-validation/restore/independent-restored-readback.json` 獨立核對為 `PASS_RESTORED_RAW`：iPad 429／10／queue19 current1 revision214、Mac 1980／114／queue1962 current59 revision283；兩端 rows／integrity／queue／app-owned preferences exact。Mac 重開 paused 0:00、目前曲目「少年よ我に帰れ」；iPad postlaunch 仍 pending（app stopped，browser policy 阻擋安全 UI 重開）。13 preset 目前是 UI config PASS，非 13 種完整聽感；zero intensity 未實測（30→27 後 reset 30）。Main full-50k UI publication／p95、slow NAS stale、iPad 14 GiB、完整 loop 與 final four-seat review 仍為 Review；四席未獲新明確預算核准，不 dispatch。

### 2026-10-08 00:13 iPad 旁白整體人工驗收 PASS（AERO-PQ40，維持 Review）

主人明確回報「感覺都可以全旁白 PASS~」。本聊天依目前 iPad 操作情境接受為 iPad 旁白整體人工驗收 PASS，取代前一輪僅限聆聽頁基本操作的人工結論；證據來源為使用者回報，沒有冒稱 Codex 自行聽測或逐項驗證。未提供逐項朗讀、方向、字級等原始結果，既有工程矩陣的未知範圍仍如實保留；Mac 旁白本輪 `USER_EXCLUDED`（2026-10-08），AERO-PQ40 因跨平台與正式審查未結案仍維持 Review。旁白保持開啟，未擅自還原。

### 2026-10-08 00:11 iPad 旁白基本焦點與播放控制人工 PASS（AERO-PQ40，維持 Review）

主人回報「感覺都可以 PASS~」。依上一輪明確指示的範圍，記為 CMV 聆聽頁左右輕掃切換焦點、未卡住及雙點播放／暫停的人工 PASS，與 00:07 基本可聽見證據一併保留。未提供其他頁面／控制或直橫向、大字級的結果，不推定完整 iPad VoiceOver 矩陣或 Mac 旁白通過；集中清單已新增勾選的局部項目，任務仍維持 Review。旁白仍依主人要求保持開啟，未進行關閉或偏好還原。

### 2026-10-08 00:07 iPad 旁白基本朗讀人工回報（AERO-PQ40，維持 Review）

本聊天恢復既有 WDA 與本機遙控頁後，透過設定 UI 開啟 iPad 旁白；畫面確認綠色開關，並已返回正式 CMV 聆聽頁。主人針對「點歌名或播放按鈕，確認朗讀」回報「都有聽到喔」，作為基本朗讀可聽見的人工證據。開關截圖位於 `local-only: ipad-voiceover-enabled-20261008.png`。不延伸為完整朗讀正確性、焦點順序、雙點控制、其他頁面或 Mac 旁白通過；任務維持 Review。旁白依主人要求保持開啟，尚未還原為關閉；集中驗收清單已更新基本項目。

### 2026-10-07 人工音效回饋與 Prior Art 研究（AERO-PQ43／AERO-FX32～FX36，維持 Review）

使用者回報「音效有變化，但是沒想像中的好」，並明確選擇「日常音質與誇張場景分開設計」。僅證明使用者聽到變化；裝置、build、曲目、模式與完整聽測矩陣未提供，不標主觀音質 PASS。本輪只研究與保存事實，未修改 DSP、安裝依賴、建置或部署。

搜尋前想法：先檢查現有預設與參數耦合，區分日常音色修飾與場景塑形；不直接把混響強度提高當作音質改善。Chrome 已實讀 Signalsmith repository 與 Valhalla 官方說明，GitHub API 回讀候選版本／授權／非 archived 狀態，原始 source 只做概念比較。

| 來源／作者／查閱版本 | 分類與可學重點 | 授權／整合成本與限制 |
| --- | --- | --- |
| [Signalsmith Basics](https://github.com/Signalsmith-Audio/basics)／Signalsmith Audio／369e906e03760ec219d07b06fa06dc4fd099f377 | Learn；FDN、early reflections、room size、RT20、低高頻 damping 分離，參數平滑與尾音 reset 契約；優先作場景演算法候選 | MIT；具體重用須保留授權與著作權告示；C++＋DSP／Hilbert／Linear，需 Apple AU 封裝與實機成本量測；9月有多筆更新，不據此宣稱完整維護或安全驗收 |
| [SoundpipeAudioKit](https://github.com/AudioKit/SoundpipeAudioKit)／AudioKit／68c59e21c554b0047bc545ff511ed4e79afb5bcd | Learn；Costello FDN、Zita 的 predelay／分頻衰減／damping，Apple AU 與Swift介面；[issue 41](https://github.com/AudioKit/SoundpipeAudioKit/issues/41)參數範圍問題有對應修補commit | repository MIT；各底層模組／依賴仍須逐項授權核對；AudioKit／AudioKitEX／KissFFT／Tonic 增加依賴，不直接導入整套；最近讀回commit為4月 |
| [FunDSP](https://github.com/SamiPerttu/fundsp)／Sami Perttu／559584043aa3369e92d5aad12a5e3b003cfacfd5 | Learn；Rust 32-channel FDN／hybrid FDN、room／time／diffusion／loop-filter介面，適合離線比較或後續核心候選 | MIT OR Apache-2.0；依所選授權保留必要告示；需新的Rust realtime FFI／生命週期與效能驗證，預設files／FFT feature有依賴成本；最近讀回commit為3月 |
| [Easy Effects](https://github.com/wwmm/easyeffects)／wwmm／master（未鎖commit，僅產品流程參考） | Learn；日常 EQ／loudness／compressor／limiter 與可調處理鏈 | GPL-3.0-or-later；Reject直接引入Linux PipeWire／Qt整套與其程式碼；只學產品概念，沒有複製 |
| [ValhallaRoom 官方控制說明](https://valhalladsp.com/2011/05/02/valhallaroom-the-high-level-sliders/)／Sean Costello／2011-05-02文章 | Learn；predelay保留清晰度、early／late混合、decay、高頻衰減與輸出平衡 | 商業封閉實作；僅取公開概念，不複製演算法或預設。web fetch遭403後由Chrome正常讀取公開頁，未繞過登入或權限 |

本地親讀 NativePlaybackEngine.swift:861～879／937～946：bathroom與sewer共用smallRoom；delay wet mix綁delay時間，feedback綁reverb量；filter以Hz線性混合intensity。VideoAudioEffectsRenderer.swift:481～517同主要公式，:539將user EQ bypass；音樂的10-band user EQ可啟用。這些是source事實；尚不能證明就是使用者聽感不足的原因。

建議（未實作）：先低成本解除參數耦合與重新調音，分日常／場景兩組；若原生混響的塑形能力仍不足，再比較Signalsmith／Soundpipe／FunDSP的隔離原型。以相同歌曲、等響度A/B、耳機與喇叭、mono、音樂與影片、CPU／尾音／切換安全驗證；任何新增依賴須先完成精確授權與相容性評估。

### 2026-10-07 18:33 最終父層封面與逐首選取回歸完成（維持 Review）

18:39 最終 parent 工程封存 main-parent-artwork-final-20261007.tar.gz SHA `3db3df4849f63eb6455f098c08d4850b3aa27f9d1ab808af6503953c4cce8489`，manifest SHA `33d14bce60bdd8855ea6666a527f7fdccfe30e241801b17ec2bc51116531b264`；321 data members＋嵌入 manifest，主代理逐檔 SHA／大小與成員集合回讀 actual0。新正式審查12k總額／每席3k／每席6次工具／20分鐘已送出待核准，未派評論員；舊額度與超額紀錄不挪用。Mission Center首次同步因PQ41少驗證欄失敗，補回13欄後 sync與doctor actual0；既有legacy passport警告保留。時間戳修正與初次錯誤已記於 mission-center-sync-closeout-receipt.json，不以手填operation時間當工具實際時間。

相對已凍結來源，LibraryViews 最終採用兩行修正（8a6）：縮圖不攔截觸控，目錄 NavigationLink 的 label 明確設定矩形點擊區；VideoExperienceView a40 保持不變。正式 Main iPad binary70e 的專輯／歌手封面中央皆能進入明細，小縮圖實際勾選首首1、逐首5、取消一首4、取消全選0，六組 XML／PNG／metadata SHA 與主代理回讀均已保存。相對 Git HEAD 尚有先前工作差異，不把整體差異宣稱只有兩行。

最終安裝與觸控後資料：九張表 schema／欄位／完整 rows 含 WAL exact，queue 非 revision 值 exact（安裝前201→觸控後203），preferences 唯一差異為 SKTransactionUpdatesLastChecked 自然時間戳，其餘逐值 exact。首次比較 UTF-8 語法失敗與 corrected retry actual0 均保留；主代理已獨立回讀原始副本。最終兩行 LibraryViews CodeRabbit actual0／review_completed／0 findings，主代理核 raw nine events、來源 SHA 與出口。

Mac universal final binary51985／ZIP8be0 已由主代理核對 build actual0、deep strict0、雙架構、七份 plist bytes／values、三語系590 keys、privacy、entitlements 與 ZIP13檔逐 bytes exact；「檢查 iPad 遠端操作能力」已完成桌面交付，主代理再回讀13檔與22筆簽章原始紀錄及全部使用者資料源 exact，原版本 rollback ZIP SHA 核對。Mac1980曲／114來源、queue1962／current59／history24／revision280保留，App未啟動。Mac 畫面仍鎖定，未宣稱 Mac GUI PASS。舊 a77／QA A/B 封存保留，正式新快照評論尚未派出；聽感、完整 VoiceOver、播放中 PiP、真實 NAS 與10GiB容量仍依各自證據標待驗／受限，不標全案 Done。

### 2026-10-07 18:12 縮圖選取已修復，補測父層封面導航

Main LibraryViews一行a77已正式採用；同Main容器23827／binary58d8，首卡1、逐卡5、單卡取消4、取消全選0、中縮圖首卡1，真實XML與SHA均核對。安裝前後九張表與preferences全值exact，queue非revision exact（199→201）。LibraryViews獨立CodeRabbit actual0／review_completed／0 findings。Mac a77 universal成品d73f已建置簽章，尚未部署；QA50k已封存後移除，Main保留。

專輯NavigationLink原生按鈕可進明細；fresh截圖的封面中心兩次未導航，直接點文字標籤則成功，故未將封面座標導航列PASS。隔離的新候選將明確設定父層label VStack的contentShape(Rectangle())，production第二行尚未採用，等待實機比對。原a77縮圖選取限定PASS保留，完整父層目錄回歸仍待驗，未宣稱全案Done。

### 2026-10-07 17:47 實機續測補證（維持 Review）

Main a40 的 paused PiP entry → native return 在0:28保持位置，resume後暫停0:42，列為 PASS_SCOPED_PIP_RETURN；播放中 pause stale guard failure保留。restore3九張表、九個偏好值、queue非revision值exact（197→199）。CodeRabbit只審a40 VideoExperienceView，actual0、review_completed、0 findings，不等於formal council。

Main PID23816小縮圖首卡native與fresh screenshot center均NO_CHANGE_SCOPED；toolbar全選使19首已選，card menu正常。清單模式首卡native可選，取消後已回小縮圖。QA兩版本五張封面操作均通過但未重現Main；normal Main一行Thumbnail.allowsHitTesting(false)候選隔離建置中，production未採用、根因未確診。

候選前備份九張SQLite表與queue exact；偏好唯一差異為SKTransactionUpdatesLastChecked時間，app-owned preferences exact，原全值比較false保留。QA封存138項SHA exact，自己的NAS caches清除680188903 bytes，不等於Mac30GB恢復。17:36 OS鎖定狀態仍Yes；Mac GUI待解鎖。使用者交回iPad控制權，持續穿插觸控，未宣稱全程keepalive PASS。

2026-10-07 14:15 續測中的目前基準（取代舊資料還原指示，維持 Review）

使用者已交回 iPad 控制權；現在 Main 的權威備份為429曲／10來源／0歌單、收藏0，queue19／base19／current17／history18／revision197。保留 zh-Hant、crimsonNebula、bathroom／0.76，禁止還原歷史204曲／7來源／25項queue。完整 Support（含SQLite WAL）與preferences已備份，SHA清單位於 `.cmv-local-evidence/2026-10-07-final-runtime/runtime-baseline.json`。

本輪已實際操作直向四分頁中的設定、音效、聆聽、曲庫，浴室音效→對照原音→返回音效標籤成立，未播放／改queue。既有 QA4b/e634 receipt 可重用 50k IDs／250頁 order／recover correctness 與 pre-cancel focused evidence，不重裝 QA50k；硬體 full-50k UI publication、中途 cancellation 與 p95 仍是 Review。曲庫搜尋按鈕已開鍵盤；送文字時 WDA 服務拒絕連線，該次搜尋未驗成，不盲重送。slow NAS 已另有 production lease focused receipt；stale／slowresolve 仍 pending。

actual production video session host診斷exit0：seek／stop／wet baseline通過；自然EOF後timer58→89（一秒），非零level47→47。已安排最小terminal polling修正與EOF後seek／重播回歸，尚未通過修正版、尚未交付新版。Mac最終成品須包含arm64＋x86_64，iPad為arm64。正式新四席審查尚未啟動，完整人工朗讀／聽感及iPad10GiB條件項由另一聊天集中整理。全斷網／AirPlay／Bluetooth依使用者排除；工作前30GB僅本人回報，不能當本輪實測。

2026-10-07 01:58 完成證據封存：1172 entries逐檔SHA讀回通過，archive SHA 22ad98ac7e2ac2d55d8a5ae028063c8a803def2754c8c82c3b9edcce4525b925；僅清除本輪已完成且無process引用的local DerivedData（allocated358703104 bytes，約342MiB）。freeBytesBefore3076333568／after3427610624是當時快照，不能將工作前口述30GB與本輪單獨歸因。簽章成品／來源／raw與失敗收據均保留，WDA／relay保持運行；cleanup receipt位於 .cmv-local-evidence/2026-10-04-remaining-validation/main-final-owned-scratch-cleanup-20261007-receipt.json。

2026-10-07 01:53 最新權威 checkpoint（取代以下較早的 build pending／PiP return unknown；維持 Review）

最終 Main 為 source audit v8 的117檔，audit SHA 0da7c6296b1adba69caf722024a8512b7714b1b7860dd45f487bc38622b7bffa。Mac／iPad 最後 build actual0，strict/deep 簽章、五份 plist 所有鍵值、ZIP逐檔SHA／CRC與三張有效Sky素材非零尺寸均通過；兩端同Main bundle已安裝啟動。Mac binary 505021de01f4c52ff60ccfa0c07e5504881808bc5d90b0194586291a454e065e；iPad binary 6ba80bb96f7daa948af35b76e6bbe1f4b406584331fcb4e262d624c3b1fb3432。五個已驗程式檔已guarded promotion，workspace117來源SHA逐檔exact，未stage／commit／發布。

背景漏包修復已由兩端實際CUA畫面確認；使用者核准縮薄與透明，header44pt／左右20pt、opacity0.18，PlayerBar cover44／spacing2／padding6且控制44pt。右欄隱藏時搜尋clear X曾錯觸UpNext；最終將兩個面板按鈕並排左側，Mac日文搜尋5→清除200、iPad cobalt搜尋1→清除46，右欄仍Hidden，真觸控回歸通過。保留ReduceTransparency不透明分支。兩張不可達SkyEmeraldAurora／SkySaturnOrbit（201716bytes）先SHA exact备份再移除；SkyAmberDawn／SkyCrimsonNebula／SkyMilkyWayDepth仍打包，羊羊主題使用SheepStorybook，不刪其素材。

Mac最後交付前後9表全欄列exact，1980曲／114來源／0歌單，queue1962／cur59／hist24除revision277→280全同，amberDawn保存。iPad交付前後9表exact，204曲／7來源／0歌單、收藏0，原25／base25／cur13／hist5除revision73→76全同，使用者選的emeraldAurora保存。PiP4後另核對SQLite含WAL：僅兩首owned測試曲之playcount／lastPlayed／Z_OPT及CoreData記帳改動，非測試曲無新增／刪除／變更；原25除revision76→64全欄位相同。不能用相同DB main檔SHA忽略不同WAL。

PiP4實際 native minimize→Home→PiP返回全螢幕，返回前後1:02／3:00保持，Play後進度2:54；guarded original25還原actual0，fresh XML為會いたい、Play、Original、0:00／5:14。Home的foreground transition guard拒絕屬預期防護，screen-only重新觀察後才點返回，未弱化guard。首次portrait命名capture實際1180×820，不能當直向證據；先前slim版直向四tab證據保留，最後117版只記已觀察範圍。

Core107 tests／2 skipped／0 failures actual0；50k QA4b暖樣本58.870–141.594ms、45started／16published／0stale已驗，冷4.735／4.691秒依使用者接受；QA5未採用，不冒稱硬體全50k IDs/order或p95通過。影片13音效production session與seek／pause／resume／stop皆有限PASS，完整聽感／音訊路由／lease／slow NAS／meter與VoiceOver完整朗讀焦點仍UNKNOWN；iPad10GiB容量TOOL_LIMITED，全斷網／AirPlay／Bluetooth為USER_EXCLUDED。Pro由「Pro購買功能結案」獨立負責。

正式council沿用sealed limited紀錄；工程Luna核對不是formal closure，最後117來源尚無四席final-snapshot closure，不標Done或整體App Store ready。原超額仲裁與失敗收據保留。新證據將封存到main-final-background-cleanup-checkpoint-20261007.tar.gz；精確SHA與cleanup結果依旁附receipt／v16 checkpoint。


2026-10-07 01:20 最後117來源v8候選正在雙平台建置；Root header僅將Spacer移到queue button後，面板開關並排左側，避免iPad右欄隱藏時搜尋clear X與UpNext開關共用觸控區。已在user明確交回控制權後證明搜尋中央觸控Keyboard=true、cobalt→Loaded1；clear X錯誤開啟右欄的實測保留，展開右欄後clear→Loaded46。Mac精簡117首次NAS build actual65（XCBuildData Bad file descriptor）；metadata rename Errno13失敗保留（combined command actual2；rename個別exit未捕獲）且舊scratch未動；改用fresh local DerivedData重建actual0。最新header修正版另跑雙端build，不把前版結果當最後版PASS。iPad羊羊主題由使用者選擇後保留，直向四分頁／背景／聆聽與設定可觸控。

2026-10-07 01:09 使用者授權清理不再使用背景；reachability audit 確認 SkyEmeraldAurora（固定走SheepStorybookBackground）與SkySaturnOrbit（titanium只用MilkyWayDepth＋SaturnCloudMap shader）皆不可達。兩組imageset共201716 bytes已先SHA exact備份至unused-background-cleanup-20261007/removed-assets，再從workspace與候選移除。完整121來源先凍結備份；final source audit v7為117檔，5code modifications不變。最終雙端重建中，尚未交付精簡包。前一修正版兩端背景已由CUA確認恢復；Mac所有9資料表exact、1962queue除revision一致，theme amberDawn保存；iPad204／7與原25同樣exact、theme crimsonNebula保存。

2026-10-07 00:55 最新背景修復進行中：使用者回報 Mac／iPad 背景皆消失。root 已確認隔離來源五個 Sky imageset 只含 Contents.json，缺被引用的 HEIC；舊交付 Mac Assets.car 的 assetutil actual0 列出 7 個資產且沒有任何 Sky 背景。已從 workspace SHA exact 補回 5 張原圖，新增所有 imageset filename 引用存在性與 SHA 檢查。source audit v6 actual0，實際121檔＝歷史114＋2既有Rust fixtures＋5漏包背景；仍僅5個程式碼修改。使用者核准縮薄＋更透明已套入隔離候選：header 0.18、PlayerBar spacing2／padding6／cover44，44pt控制與 ReduceTransparency 不透明分支保留。兩端 incremental build 進行中，尚未交付背景修正版，不宣稱視覺通過。已交付前版兩端資料保存：Mac1980／114、iPad204／7及原25全表exact；新GUI月島／cobalt搜尋成功，一次語意中心重開焦點失敗保留。正式整體仍 Review。

2026-10-07 00:17 最新進行中：使用者確認「整條工具列對齊」，候選 WideRoot header／PlayerBar 共用左右20pt、明確滿寬，保留高度、材質、transport與Compact MiniPlayer。先凍結hit-test版Mac actual build0，再於安全邊界套用對齊；root source audit v5 actual0，實際116 files／5 code modifications＋2既有workspace test fixtures、workspace drift0。兩端新版建置中，未安裝／未確認搜尋焦點與版面。更新前Mac正常退出，完整app／Support／preferences SHA exact、SQLite integrity ok、1980 tracks／114 sources、queue1962／cur59／hist24；NAS SQLite回讀actual1保留，改SHA相同本機副本後actual0。iPad guarded stop／copy／relaunch actual0，204／7／0、原25／cur13／hist5備份完整，queue SHA1be81c…2a3；CUA持續原生曲庫／歌手／專輯操作，refresh不算防鎖觸控。

2026-10-06 最新容量基準：使用者更正本次開工前可用空間為 **30GB**，取代先前33GB回報；兩者皆非工具實測。已執行simctl shutdown all（actual exit0），唯一模擬器原已Shutdown。依使用者「不停iPad測試，交分身清點」指示續測；fresh Luna spawn達thread上限，改既有Luna於QA3收據後做唯讀清點。WDA／relay／活躍建置及Codex管理Bridge服務保留。

2026-10-06 21:08 容量基準更正：使用者確認本次開工前可用空間為33GB（本人回報，非本輪工具量測）。當次df約1.34GiB，swap使用9480.50MiB，不能把整體差額歸因於本輪檔案。已確認無編譯程序占用，且QA2成品binary／ZIP雜湊與封存一致後，僅清理本輪完成的QA DerivedData／cargo-target合計365380KiB；df可用1403236→1743912KiB，約1.66GiB。原始碼、成品、失敗紀錄與證據保留，其他專案模擬器及系統swap未動。

## 研究紀錄

| 搜尋前構想 | 參考來源 | 採納內容 | 授權狀態 |
| --- | --- | --- | --- |
| 沿用既有 NAS 打包 SOP | `docs/PACKAGING_AND_OPTIMIZATION.md` 與 Git 歷史 | 保留本機暫存與 electron-builder cache 策略，修正過期資訊 | 專案自有內容 |
| 關閉 `webSecurity` 並改用自訂協定 | Electron Security / Protocol 官方文件 | 採 `protocol.handle`、secure/standard/stream scheme 與核准根目錄檢查 | 官方文件，可引用概念 |
| 整理 App 圖示 | electron-builder Icons 官方文件 | 使用預設 `build/icon.png`、`build/icon.icns` 結構 | 官方文件，可引用概念 |
| 避免破壞 NAS 依賴 | 本機 Vite 錯誤與既有 SOP | 在 `/tmp` 以 `npm ci` 乾淨重建 | 專案自有決策 |
| Electron 主進程安全強化 | [Electron Security](https://www.electronjs.org/docs/latest/tutorial/security) | 限制導覽、新視窗、驗證 IPC sender、更新支援版本 | 官方文件，可引用概念 |
| 防止多實例競爭 | [Electron app API](https://www.electronjs.org/docs/latest/api/app) | 使用 `app.requestSingleInstanceLock()` 並聚焦主要視窗 | 官方文件，可引用概念 |
| 大型清單轉換快取 | [React useMemo](https://react.dev/reference/react/useMemo) | 快取大型陣列轉換並避免新陣列造成 Effect 過度觸發 | 官方文件，可引用概念 |
| 獨立架構與風險審查 | Antigravity cascade `272654c8-130a-4a3f-acd5-0def63d2d1dd` | 直接覆寫 JSON、NAS 離線存在性過濾與全量列表重算列為主要風險 | 本機授權協作；含 1 次 SEARCH_WEB 軌跡 |
| 確認 Mission Center 使用版本 | 已安裝 `.codex-plugin/plugin.json`、插件快取路徑與 SKILL.md SHA-256 | 基礎版為 0.3.1；執行中腳本來自 `0.3.1+codex.9ed1bfeca60445639f45a35d424aa16e` | 本機已安裝插件；只讀核對 |
| 將 CMV 上架流程改為可重跑任務鏈 | [rorkai/app-store-connect-cli-skills](https://github.com/rorkai/app-store-connect-cli-skills) 與本機 `asc-*` skills | 採簽章、Xcode build、TestFlight、release flow、submission health 分離；所有提交先 dry-run，`--confirm` 另需核准 | MIT；GitHub 外掛唯讀核對 |
| 預防 Guideline 2.1 資訊不足退件 | MediBuddy 任務 `01a04b26-127b-7772-a00f-3a2733ac5f2f` 的 Build 10 補件紀錄 | CMV 新增 Review Kit：完整 Notes、無剪輯實機影片、裝置／OS／核心流程、無帳號／無付費／NAS 授權方式與素材權利；資訊問題不先重建 Build | 同機專案自有紀錄；只採流程經驗，不複製敏感值 |
| 反方檢查 App Store 漏項 | Antigravity cascade `65eb3c8b-224f-4dcd-a3f3-12f2c0d66619` | 採 Privacy Manifest、FFI panic boundary、dSYM、展示素材版權與狀態語意；拒絕其「內建 NAS 掃描／保存帳密」假設 | 本機授權協作；外部磁碟未掛載時基於既有摘要，具明確未知 |
| 右欄播放佇列卡頓來源 | Apple `Understanding and improving SwiftUI performance`、Observation 官方文件 | 高頻播放秒數不再直接驅動整個 queue panel；以 Observation 快照隔離高頻粗 revision，只有 queue 順序／可見 metadata／目前曲目真正改變才發布 UI 狀態 | Apple 官方文件；採概念與 API |
| 月環即時波形既成實作 | [GRimAce11/WaveformKit](https://github.com/GRimAce11/WaveformKit)、[dmrschmidt/DSWaveformImage](https://github.com/dmrschmidt/DSWaveformImage) | 採 bounded bar count、固定 cadence、Canvas／即時 samples 與分析／呈現分工概念；CMV 保留自有 AVAudioEngine meter，不新增第三方依賴或複製程式碼 | 公開 GitHub 專案；僅參考架構概念 |
| UI 動效與效能收斂 | [pbakaus/impeccable](https://github.com/pbakaus/impeccable) 的 audit／animate／optimize 規則 | 月環降回 80 段、移除逐段旋轉向量運算、修正 circular-buffer 時序並降低 queue backdrop blur；保留主視覺、刪掉無效 GPU 工作 | MIT；僅採規則與設計原則 |
| CMV Pro 買斷定價與跨平台權益 | [Doppler 台灣 App Store](https://apps.apple.com/tw/app/doppler-mp3-flac-player/id1468459747)、[Evermusic Pro 台灣 App Store](https://apps.apple.com/tw/app/evermusic-pro-%E9%9B%A2%E7%B7%9A%E9%9F%B3%E6%A8%82%E6%92%AD%E6%94%BE%E5%99%A8%E5%92%8C%E5%9D%87%E8%A1%A1%E5%99%A8%E9%9B%B2%E6%B5%81%E5%AA%92%E9%AB%94/id905746421)、[foobar2000 台灣 App Store](https://apps.apple.com/tw/app/foobar2000/id1072807669)、[Apple 跨平台購買](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms) | 2026-09-24 Apple API 已回讀：CMV 免費 App 台灣 TWD 0；同一 iPad／Mac 紀錄的 Pro non-consumable 商品台灣 TWD 290。商品尚 MISSING_METADATA，不代表 Sandbox 購買可用 | 競品價格為 2026-09-24 觀察，可能變動；僅學習定位，未複製內容或新增依賴 |
| CMV Pro Sandbox／審核邊界 | [Apple IAP 配置概述](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases)、[Apple IAP 審核資訊](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information)、[Apple Sandbox 故障排查](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox) | 同一 App 紀錄可共用單一 IAP；付費協議須有效，商店 metadata 在 Sandbox 可能延遲至 1 小時。審核截圖應清楚顯示 App 內實際提供的項目，不以空曲庫主畫面冒充。Sandbox 不等於已送審或上架 | 官方文件，僅引用規則；測試結果依本機與 Apple API 回讀另記 |

## 2026-09-27 土星 UI 排版回復

- 使用者指出月環／播放區是在土星背景改版後變動。Git 定位：`5fdbf0e` 為改版前基準；`74df366` 首次加入播放區 24 pt layout padding 與 cover parallax。
- 恢復前版量測、移除月環 cover parallax；依最新要求保留寬版右面板下移 24 pt、淡半透明歌曲／播放與詳情卡。流光限於指定 UI 背景，月環無流光。
- 原生 macOS 簽署必須使用 `Native/CMV/CMV/CMV.entitlements`。本次交付曾誤用 `build/entitlements.mac.plist`（Electron）而讀到非 sandbox 資料位置，已重新簽署並於原生畫面確認既有 1,964 首曲目。未遷移或刪除曲庫。
- 本輪局部 UI 完成不代表整個 Pro／StoreKit 發布任務完成。

## 2026-10-02 羊羊彩虹繪本主題

- 背景與整體 UI 改為明亮童話卡通：原創彩虹天空、粗描邊奶油雲朵、奶油紙卡、可可文字與圓體。依最新使用者回饋移除所有地面與固定羊，沿用既有羊流星。
- 僅 emeraldAurora 套用；保留月環與播放區既有位置。背景圖片獨立於動畫 clock，羊流星遵循 Reduce Motion／scenePhase，最高 20 fps。
- Mac arm64 Release 最終建置成功；原生 entitlements ad-hoc 簽章與 strict verify 通過。桌面 CMV.app 已更新，舊版備份於 <USER_HOME>/.Trash/CMV-before-sheep-storybook-20261002-195121.app。
- CodeRabbit 共 2 次（各不超過 9 個小型 Swift 檔，排除大圖）；首次已確認佇列遮擋問題並修正，末次 9 檔 0 findings。獨立 Luna source／資產審查沒有確定 P0–P2。
- 原生 UI 工具啟動失敗：failed to start Node runtime: No such file or directory。只確認圖片素材與原始碼，未宣稱整頁實機視覺驗收。
- 初版 iPad Simulator Debug 曾建置、安裝與啟動；最終小修未重跑 iOS。使用者最新指定先完成 Mac，iPad 交付延後。此次自建測試 simulator 已關閉刪除。
- 本輪主題修改不代表整個 Pro／StoreKit 發布任務完成。

## 最新美術修正：日式動畫

使用者於 2026-10-02 指定改為日式動畫風格。背景已重繪為清透藍天、暖白積雲、藍紫色賽璐璐明暗與乾淨輪廓；保留巨大彩虹、完全無地面與固定羊。UI 沿用奶油色與柔和梅紫控制，原有位置不變。這次僅替換點陣資產，不修改已審查的 Swift 邏輯。

素材：imagegen `exec-09e84234-e175-4427-a2e3-b0ea88346ae0.png`。提示摘要：Original Japanese anime sky background; luminous cyan-blue summer sky, warm ivory cumulus clouds, blue-gray linework, lavender cel-shaded shadows, clean smooth painting, huge pastel rainbow; no ground, horizon, vegetation, buildings, sheep, text or interface.

## 實體 iPad Wi-Fi 遙控操作｜2026-10-03

對應 AERO-DV4／AERO-SC31 的實機驗收準備。主人要求保存「Mac 鏡像操作 iPad」聊天的既有方法並當場測試；另授權詢問「GAI月亮續杯」。本次確認使用已簽章 WebDriverAgent（WDA）XCUITest runner，並透過 Mac 的 loopback 控制頁傳送觸控。畫面是 WDA 截圖更新，不是 Apple iPhone 鏡像輸出；AirPlay 本身不提供這條觸控回傳通道。

### 前提與啟動

1. iPad 已解鎖、開發者模式啟用，與 Mac 配對且同網路可達。先用 `xcrun devicectl list devices` 回讀，再核對裝置 details 的 `ddiServicesAvailable`、`developerModeStatus` 與 transport。不要把歷史裝置 ID／IP 當固定設定，也不要保存到版本化文件。
2. 本機既有 WDA 工作區為參照聊天中的 `new-chat/work/wda`；已建置的 runner 在 `work/wda-build/Build/Products/`。用 `rg --files <既有 Products 目錄> -g '*.xctestrun'` 選擇實際存在的實機產物，不能選 Simulator runner。本輪直接重用 xctestrun，沒有重新編譯或建立／輪替憑證。
3. 以實際路徑與當次裝置 ID 取代下列佔位值，啟動一個 host；不要同時開第二個 runner，也不要在 WDA 初始化時用 devicectl 搶先啟動另一個 App。

```sh
CMV_WDA_XCTESTRUN="<已建置實機 .xctestrun 的絕對路徑>"
CMV_IPAD_ID="<當次 devicectl 回讀的 iPad ID>"
xcodebuild test-without-building \
  -xctestrun "$CMV_WDA_XCTESTRUN" \
  -destination "platform=iOS,id=$CMV_IPAD_ID" \
  '-only-testing:WebDriverAgentRunner/UITestingUITests/testRunner'
```

4. 從 host log 的 `ServerURLHere->http://<當次 iPad IP>:8100<-ServerURLHere` 取得服務位址，確認 `/status` 回 `ready: true` 後才操作。不能只憑 App 已安裝、程序存活或 HTTP 200 判定觸控成功。

```sh
CMV_WDA_URL="http://<當次 WDA log 回報的 iPad IP>:8100"
curl --noproxy '*' --connect-timeout 2 --max-time 5 "$CMV_WDA_URL/status"
CMV_IPAD_REMOTE="<參照聊天 outputs/ipad_remote.py 的絕對路徑>"
python3 "$CMV_IPAD_REMOTE" --wda "$CMV_WDA_URL" --port 8765
```

5. Mac 開 `http://127.0.0.1:8765`，可點擊畫面、更新畫面或回主畫面。既有頁面約每 1.5 秒更新；只綁 loopback。它建立並管理自己的 WDA session。不要再建立另一個 session 覆蓋它。腳本結束時會關閉 server 並刪自己的 session；WDA host 另外保留到實機驗收完成，之後僅停止本次建立的 host。

### API 與定位規則

- 不使用控制頁時，`POST /session` 傳 `{"capabilities":{"alwaysMatch":{"bundleId":"com.windsheep.cmv"}}}`，由回應的 `value.sessionId` 取得 session。每個操作者一次只持有一個 session。
- `GET /session/<id>/source` 取得 accessibility XML，`GET /session/<id>/screenshot` 的 `value` 為 Base64 PNG；`GET /session/<id>/window/size` 回傳觸控用的 point 尺寸。
- `POST /session/<id>/wda/tap` 使用 point 座標 `{"x":<point x>,"y":<point y>}`。控制頁的 `POST /tap` 使用畫面內 0–1 正規化座標，由頁面轉為 point。PNG pixel、縮放後瀏覽器尺寸與 point 不可直接混用。
- 點按前回讀畫面／XML；點按後再回讀確認預期狀態。橫直向會更換布局，本輪由直向 compact 變為橫向 sidebar，因此重新定位；側欄項目是 StaticText，不能硬找 Button。本輪寬版 XML 部分可見內容標成 `visible=false`，必須與實際截圖交叉核對，不能僅靠該旗標判定元素不存在。
- 權限、鎖定、automation mode timeout 或服務失聯時先診斷；沒有新證據不得反覆啟動。解鎖／配對／必要系統批准仍由使用者處理，不能繞過。

### 本輪觀察與證據

- 初次舊 WDA 位址與 8765 都無服務；裝置仍配對，details 確認 iPad Air 5／iPadOS 26.5、開發者模式與 DDI 可用、localNetwork tunnel connected。
- 重啟既有 runner 後 `/status` 回 `ready: true`。本機控制頁成功取得實體 CMV 畫面；以控制頁 `/tap` 點進 Settings，再切進 Music Library（XML 回讀 Loaded: 20／All songs shown · 20 total），再回 Listen Now。每個切換都取得截圖與 XML；未播放、修改曲目、變更購買權益或刪來源。
- 本機私有證據與 SHA-256：`output/mission-center-assets/ipad-remote-20261003/manifest.json` 及同目錄 PNG／XML；目錄已由既有 .gitignore 排除。原始 WDA host log 只存本機，不將裝置識別或 IP 提交 Git。
- GAI 聊天的既有紀錄證實使用同一套 WDA；build54 cleanup receipt 表示其自有 session／host 已收尾，解釋了此次服務未運作。GAI 的實測範圍與 CMV 的驗收分開記錄，不因別的 App 通過就把本專案 gate 判 Pass。
- 本輪結果：遙控鏈路與三次頁面切換通過。這不等於 AERO-DV4 的完整 NAS／背景音訊／PiP／Split View／記憶體矩陣通過；任務狀態維持原樣。

來源：[Mac 鏡像操作 iPad](thread://01a0da00-c2d6-7a41-94e0-9019367217e9?hostId=local)、[GAI月亮續杯](thread://01a0e7ca-4fdf-7ed3-994a-6d614fabc1a1?hostId=local)；均已用 read_thread 讀取，不將聊天宣稱當本輪觸控證據。

## 現有任務收尾波次｜2026-10-03

主人再次授權完成現有任務、跨領域研究、自主選擇最小安全改進，並指定 Mission Center／Antigravity Bridge／Codex Game Studios／Chrome／GitHub。沿用現有 Epic 與任務 ID，不增加產品邊界。第一波為 Q12 佇列與 I13 曲庫操作；X14 完成有證據的範圍評估；再驗 Pro、日常實機與發行 gates。主代理負責 MissionCenter、整合與驗收；Luna 分離寫入 lane，Gemini 的受限環境設計交付只作建議，不當成 source review 或編譯證據。發行外部狀態與使用者動作依具體 gate 追蹤，不虛構整體完成。

## 原 CMV 倉庫公開與清除請求｜2026-10-03

依主人最新明確指示，沿用原 `Gale0418/Celestial-Music-Vault`，已還原短暫更名並改為 Public；沒有建立額外倉庫。公開 main 的 62 個提交與 865 個 blobs 已驗證 0 個已識別私人值殘留，提交者使用 GitHub noreply。當前公開 Support／Privacy 文件匿名回讀均為 200。私有歷史備份及檢查報告只保存於本機，不推送其他 local backup／stash／internal refs。

舊 SHA 仍可由 GitHub API 讀取。主人已明确接受此限制並指示立即公開、另送清除請求。Support portal 的 Repositories 分類回 404；舊 GAI 工單已 Archived，其 follow-up 連結返回選擇帳戶。已核對官方 Support 既有郵件與 Reply-To，使用已連線 Gmail 寄出 CMV 的新請求，工具回讀 SENT。這是寄出證據，尚不是客服受理或快取清除 Pass；GAI 舊工單完成不能拿來關閉 CMV 的清除工作。請求只移除 obsolete history／cache，不刪 repo／目前主線／帳號，也不變更 Public 狀態。

## X14 本版範圍評估｜2026-10-03

`Native/SMART_LIBRARY_SCOPE.md` 記錄本版採納現有 addedAt 排序與本機歷史保存，最近播放 preset、規則 Smart Playlist、歌詞與背景 watcher 延後。未新增產品功能；核對語意、現存 source 與本輪 77-test／metadata 6-test evidence 後，低風險非感知文件評估採 critic skip。50k reconciliation 通過不是新的 150 ms UI benchmark。

## 商店草稿與隱私確認｜2026-10-03

三語 app-info 與 iOS／macOS 2.0 metadata 已寫入；33 欄回讀一致，首次上架不接受 What’s New，已保留 canonical 內容而不宣稱寫入。兩平台審核 Notes／聯絡與版權資料已填入，私人聯絡僅留 Apple 後台與權限受限 runtime 檔。年齡問卷 27 欄回讀 NONE／false 通過；不是最終審核分級結果。

App Privacy 的「不收集資料」與本機處理／manifest 一致。Apple 最後發佈按鈕要求確認回覆正確、符合法律，並承諾資料處理變更時更新；主人已同意，Chrome 已完成發佈並保存實際後台畫面。App 尚未正式送審。

X14 completion passport 已由正式 Rust transition 驗證，Review → Done 成功；只結案已核對的範圍評估，不新增延後功能。

主人已於 2026-10-03 明確回答「同意發佈」；Chrome 已按最後發佈，後台顯示數秒鐘前發佈，保留不收集資料預覽與公開 Privacy URL。此結果只確認隱私聲明發佈，不代表 App 送審。Mac universal Release 最新 build 成功，strict ad-hoc 簽章後覆蓋桌面 App，舊 App 可從垃圾桶復原；CUA 啟動顯示 1,964 首曲目且未播放。正式 Distribution 資格未由此取代。

## 本輪實機與 StoreKit 限制｜2026-10-03

實體 iPad 初步驗證 Pause／Next／Track Info／排序入口與佇列 terminate／launch 還原，未自動播放。多選及 occurrence-specific 重排未能由 WDA 穩定確證，不能把控制項可見當 Pass；舊 runner signal kill 視為工具限制，根因未證實。更新完成後仍需最新 queue fix 複驗；裝置稍後再次自動鎖定，尚未加入原創測試來源。

StoreKit compile-time 專用 DEBUG host 已證實不建立第二 AppModel／listener；pending approval 的 SKTestTransaction 變為 purchased，但 genuine 權益仍未到達，結果 0／1。購買、重啟、還原、退款與取消／失敗已有通過證據；不推論為完整三項矩陣全綠，不硬設權益或增加未證實 workaround。Apple 官方要求 Ask to Buy 核准交易經 Transaction.updates 傳遞，未找到該 hosted propagation 狀態的官方 workaround；production 根因未證實，仍需真實 Sandbox／實機驗收。

Mac 實測兩首原創 WAV 多選成功，空佇列 Add to Up Next 原會立即播放；已修為 paused metadata seed，延遲至使用者 Play／Next 才準備來源。修正版及第三輪修正後版本均已實測：加入後 Play／進度 0，重複曲目保留，明確按 Play 後進度增加，Pause 可停止。active append 路徑保留。第三輪修正後的完整佇列重排／單項移除仍未驗證：CUA 坐標操作回報 noWindowsAvailable，AX 可按播放器與選单但未獨立暴露佇列列內選單；此工具限制不視為操作通過。

## 第三輪審查與最後覆蓋版本｜2026-10-03

CodeRabbit 第三輪 4 findings 已逐項查證：有效 3 項為混合影音 append 保留既有 audio segment offset、批次資訊 Undo 移至持續可見的 TrackList toolbar，以及英文 Review Notes 匯入入口錯誤；均已修正。測試檔重複 enum／多餘大括號為誤報，實際 source parse 與先前 Xcode 執行到交易 assertion 為反證。三次審查額度已用完，修正後未宣稱另有外部零 finding 結果。

最後 production source 的 macOS universal Release、iPad device Debug build 均 BUILD SUCCEEDED；Mac Desktop 已覆蓋、strict codesign／bundle preflight 通過，1,969 首（原 1,964＋本次 5 首原創影音）保留，Track Info 可開啟並關閉。iPad 最後修正版安裝回讀 success；裝置再次鎖定，尚未完成此版操作驗收。兩平台修正後 Review Notes 遠端逐字回讀一致。

WDA 前一 host 於 remote process connection invalidated 後結束，不能推論為 CMV crash。新 host 在 Xcode preflight 等待 iPad 解鎖；僅重啟本次自有 host，未建立第二個 session。實際原創測試素材、二進位與畫面證據置於 ignored runtime 目錄，未公開使用者曲庫畫面、裝置識別或 LAN 位址。

## Review fixture 與最新受限驗收快照｜2026-10-03

前段「尚未加入原創測試來源」及「尚未完成此版操作驗收」是各自當時的歷史快照。其後原創 fixture 已可由公開 prerelease 下載：[cmv-review-fixtures-20261003](https://github.com/Gale0418/Celestial-Music-Vault/releases/tag/cmv-review-fixtures-20261003)，ZIP SHA-256 為 `e3b766ec3a828fc8d11e8ac90b1468a5cea5e8f8ba600a79184aa39e68bf72d6`。這只更新素材可取得性，不把未完成的完整審核媒體或 Sandbox 驗收標成完成。

本輪 iPad Files 解壓 AddMusic 來源由 20 首增至 25 首，通過。空佇列 Add → Play 的進度為 0，通過；佇列 `[Amber, Cobalt, Amber]` 移除未播放的 Cobalt 後為 `[Amber, Amber]`，目前曲目與進度維持不變，通過。此路徑是移除指定未播放 Cobalt，不是移除指定的重複 Amber。多選、重排、本版強制終止後還原尚未驗證；完整雙平台無剪輯影片、Split View／PiP 與 Sandbox 也尚未完成。私有 runtime evidence 僅作本機稽核，公開文件不帶裝置識別、網路位址或曲庫畫面。

本輪 WDA 只使用自有 session；session DELETE 與 host 收尾成功，沒有本輪 simulator／worker 存活。這是資源清理證據，不代表完整實機矩陣通過。

最新單一 production StoreKit listener recheck 以受限本機 log 回讀：exit 65；`activeEntitlements=1`、`unverified=0`，`allUpdates=0`、`matchingUpdates=0`、`orderRejections=0`、`hasPro=false`，約 32.3 秒逾時，判定 FAIL。診斷顯示 `compileHostFlag=true`，trace 只落在 `DEBUG && testHost`；未修改 production 解鎖邏輯，也不把結果歸咎 Apple。較早的 independent observer 32 秒 PASS 是延長等候的歷史結果，不能覆蓋本次 listener FAIL。

TrackInfo locale 的最小修正仍待 build／UI 複驗；不可宣稱最新版安裝已涵蓋。三輪 CodeRabbit 審查的有效 finding 已修正；修正後未新增外部審查輪次，不能宣稱最終零 finding。這不取代尚未完成的實機與 Sandbox gates。

## Mac Smart DJ 佇列還原缺口｜2026-10-03

桌面第三輪修正版（binary SHA-256 `8c129df1eb3a62ee1e3140d4211b4e0412087c13715d0d0beeb0086c6317a398`）由 Settings → Smart DJ 產生四首原創 WAV，Add to Queue 後 Up Next 顯示 4 total、Play 按鈕與進度 0。正常關閉並重新啟動後 Up Next 為 0 total，曲庫仍為 1,969；本機磁碟快照仍保留 version 1／revision 29／entries 4／baseEntries 4／currentIndex 0。此為實際還原失敗，不以資料檔存在判定成功；正在診斷，尚未確認根因或修正。畫面與 AX 只保存在 ignored runtime 目錄。

## Distribution 檢查修正與候選產物｜2026-10-03

本機 iOS 2.0 (1) 使用既有 Distribution 身分完成 archive 與 IPA export；未上傳。qualification 原使用 `codesign -dv`，該輸出沒有 Authority 欄位而誤拒有效簽章，已改為 `--verbose=2`。實際正式 iOS archive（arm64）檢查 exit 0，Desktop ad-hoc 負例 exit 1，其他 profile／entitlement／privacy 檢查仍保留。此輪 archive 早於最新 queue restore 修正，僅作簽署流程證據，不冒稱最終 RC。Mac candidate 仍在串行建置。

佇列還原旗標的最小修正已完成 source parse：取消中的 SwiftUI task 不再提前完成共享 restore flag；有效空快照仍採納 revision；成功 hydration 才完成 flag，既有 queue mutation guards 與不自動播放行為保留。實機重啟複驗尚未完成，取消事件本身也尚無 runtime trace，不能把推測觸發原因寫成定案。

## 核對 candidate 後的 Mac 還原與語系驗收｜2026-10-03

queuefix archive 的 binary SHA-256 為 `e59e77a7ecea161dd154840f6ccc230acc97a85bdfbbf7bc91e94f8f23c81d44`；複製為 Desktop ad-hoc 測試版後為 `dfdf4ec5debf967e16562b9dd6a903494336d766b9ffaa42a5df9725a1b7cb31`。CUA 啟動已還原四首原創 Cobalt／Violet／Amber／Silver，Up Next 4 total、Play、進度 0，曲庫 1,969；Track Info 的 Basic Information／File and Track／Done 與日期 Oct 3, 2026 為英文，限定路徑通過。較早一次複驗誤取 pre-queuefix archive，已更正 runtime receipt，不能當修正後 FAIL。

此候選含 restore 完成旗標修正，尚未含後續獨立發現的併發 revision rebase 保護。還原等待期間的新 queue mutation 必須以已載入 revision 重新保存，以免 actor 拒絕較舊 save；最小 source 修正已完成 parse，暫時 OSLog 診斷已移除，正在建立同 source 的下一組候選。沒有 runtime cancellation trace，不把該觸發原因寫成定案。雙平台 archive／IPA／Mac package 已於前候選成功、qualification 通過，仍未上傳或正式送審。

Mac 同一 queuefix 候選另驗明確 Play／Pause 狀態切換，接著對本次原創 WAV 啟動 Analyze This Track，畫面顯示 Analysis complete／Tempo around 62 BPM。這只證明該檔本機分析操作成功，不是 BPM／節目 loudness 準確度 reference 或完整使用者曲庫體感。

## 最後同 source qualification 與實機邊界｜2026-10-03

最後 distribution source manifest 與目前 source SHA 一致；Mac Release archive／signed package 及 iOS Distribution archive／IPA qualification 均通過。這些仍是 candidate 產物，尚未 upload，不等於最終 RC 或送審完成。

最後 Mac desktop 覆蓋版以同 source 實際驗證四首原創 Cobalt／Violet／Amber／Silver：current Violet 位於 index 1，Up Next 還原、Play／progress 為 0，曲庫為 1,969 首；真正 restore 且沒有自動播放，通過此限定路徑。這項結果更新前述較早的畫面還原失敗歷史快照，不延伸成完整佇列矩陣或所有來源型態通過。

最後 iPad Debug build 與 signing profile 通過，但安裝在 CoreDevice 3002／`IXRemote5 remote.installcoordination_proxy Error83` 失敗。最新鎖定狀態為 `passcodeRequired=true`、DDI usable；目前等待使用者解鎖後重試。舊 limited QA iPad 紀錄不能當成最後 source 覆蓋版通過證據。

四首本專案原創 WAV 與 pinned BS1770 做獨立比較，±0.1 LU 全部通過，最大絕對差為 0.000324；receipt 留在 ignored runtime。這只建立 fixture-level 的獨立 loudness 比較，不代表 EBU 認證、全 genre 覆蓋或完整 release gate。Sandbox 仍 pending／fail，screenshots、無剪輯 demo、rights forms 與 critic budget 仍未完成。

## 解鎖後最後 source 交付與影片路徑｜2026-10-03

解鎖後，最後 source 的 iPad Debug install 與 launch 均成功；binary SHA-256 `f7f9105e356d249183248d7a5d73a8ca173c29aab69ebcfe4161d31724ea2786` 與 final source manifest 相符。實際 QA summary 顯示 25 首曲目與本專案原創 fixture、Track Info 英文與 release `Not Available`、多選 2 項 UI 通過；enqueue 結果 Unknown，重複曲目 future remove、重排與 terminate／restore 尚未驗證。先前的 install failure 保留為歷史紀錄，不被新的成功證據抹除。

WDA test runner 本輪以 `Test crashed with signal kill.` 結束，host exit 65 後已離開；根因未知，不稱為 CMV crash。因 service unavailable，session DELETE 未能確認成功；cleanup receipt 沒有 owned host 仍存活的證據，不能把 cleanup uncertain 寫成完整通過。

同一最後 source 的 Mac CUA 原創 MOV fixture 路徑已有限通過：Play → Pause 約 1.133872027 秒，月環 → standalone native player 約 1.1291 秒且保持 paused，Return to Moon 後約 1.133872027 秒未改變；EOF 後為 Not Playing／empty，清除本次原創影片後曲庫為 1,969。這只證明單一原創影片路徑，不代表 mixed media race、PiP 或聽感認證。

App Store Connect Content Rights 已保存 `DOES_NOT_USE_THIRD_PARTY_CONTENT`，主要類別為 Music；主人再次確認不在 App 內提供內建歌曲、影片或圖片。產品範圍是 local user-authorized media，這只記錄商店權利選項與產品邊界，不等於所有私人音樂都已有可散布授權。Privacy 已有先前發佈證據。

主人新增的 Marquee overflow scope 已有 source 修正，Marquee card／PlayerBar 也已實作，正在建立新的雙平台 build；因此先前 final Distribution qualification 只屬舊 source candidate，不能宣稱為最新 source qualification。Sandbox pending／fail、screenshots、無剪輯 demo、rights forms、完整 programme matrix 與 formal critic budget 仍待完成。節目級聲學比較摘要見 `Native/ACOUSTIC_REFERENCE_QA_20261003.md`，仍不等於節目認證。

## 2026-10-03：AERO-U25 與三語商店草稿

Gemini 的受控四欄文案已審閱後整合三語 canonical；App Store Connect app-info 三語副標題及 iOS／macOS 2.0 的描述、宣傳文字共 15 欄 exact readback，一般保護欄位 24 欄 exact preserved。首發 What’s New 未寫入，未上傳／提交 App。名稱、URL、關鍵字、版權、完整 App Review Notes 沿用。

第一 Marquee candidate 雙平台編譯成功，但 Mac 實測長字部分移出可見範圍，故不能作 UI PASS。已改為每個元件 onGeometryChange 量測、要求正寬且固定動畫容器。Mac layout Debug 重建 exit 0、strict signature PASS；实际驗收中型卡片文字完整，小型卡片溢出資訊移到尾端仍可讀，短歌名與尚未播放保持固定，AX 保存完整標籤。這是有限畫面驗證，不宣稱完整 VoiceOver、Reduce Motion 實測或效能基準。修正版的雙平台 Distribution 候選仍重建中。

AERO-Q12 同份 Mac Debug 補驗：空 queue 加入原創 Cobalt 保持暫停 0；再次加入同曲保留兩個項目；只移除未播放的第二項後，原目前項保留、總數 1、仍暫停 0；正常關閉重啟還原相同一筆暫停項。最後清除本次測試 queue，使用者曲庫 1,969 首不變。完整重排、混合影音與 iPad 矩陣仍未完成。

首個 iPad candidate 已覆蓋安裝成功，但 SpringBoard 啟動回覆 Locked；沒有建立新的 WDA host/session。已要求解鎖，實機動畫與縮圖驗證維持 ToolLimited。raw screenshot／AX／ASC receipts 僅私有 runtime，不提交私人曲庫封面或裝置資料。

最後 `marquee-layout-final` 雙平台候選已完成：67 個編譯輸入前後 SHA 一致；Mac universal archive qualification／pkg 簽章、iPad Debug build／codesign、iOS archive／export／IPA qualification 全部通過。它仍非正式 RC，沒有 upload。桌面已覆蓋最後 Release 的 ad-hoc 測試副本；實際啟動保留 1,969 首、空 queue 不自動播放，短歌名固定、溢出資訊在活躍時可讀往返。

最後 iPad source 安裝另遇 CoreDevice 4000「連線後立即斷線」，未嘗試 launch／WDA。root bounded 診斷後裝置已 available／tunnel 可讀，但 `passcodeRequired=true`；`unlockedSinceBoot=true` 只代表開機後曾解鎖，不可當成目前解鎖 PASS。已在全部建置結束後再要求即時解鎖，避免等待建置導致自動鎖定。未完成前維持 ToolLimited。

遙控短案例的操作補充：先完成建置，再即時確認 `passcodeRequired=false`，依序 install／launch／啟動唯一自有 WDA host。從當次 host log 取得 URL，每次操作先讀新 source，優先點 Button／Tab，避免同名 StaticText；source 與 screenshot 串行，單一 HTTP 上限 35 秒，整個短案例上限 170 秒。畫面與幾何回讀各自驗證，不能把 HTTP 成功當 UI 通過。完成後 DELETE 自有 session 並核對回應，再 SIGINT 自有 host、確認程序結束；不終止其他任務的 runner。

公開資料整理另外遮罩歷史簽章 Team 識別碼；AERO-G17 的既有 completion passport 僅依官方 canonical digest 算法重新綁定遮罩後 task identity，status／verification／evidenceRefs／findings 完全保留，未新增或重做 QA。原 digest 與 HEAD 一致，新 digest 與目前紀錄一致；Doctor exit 0、80 tasks 通過，既有缺 passport 的 legacy warnings 如實保留。重新綁定 lineage receipt 只留私有 runtime。

StoreKit pending 唯讀診斷：最後 single-listener 測試的 `compileHostFlag=true`，approval 後 matching transaction 已 purchased、真實 `currentEntitlements` 的 activeProductCount=1；production listener allUpdates／matching／orderRejections 均為 0。因此目前證據指向事件尚未進入 receive，不能歸因 productID 過濾或交易順序拒絕，也不能定案為 Apple SDK bug。下一個最小診斷是在獨立串行 case 保留原事件契約失敗，再驗證 approval 後 production refresh 可否採納真實 verified entitlement；refresh 通過也不能替代 listener case。此輪未改測試、未重跑、未把 pending FAIL 改成 PASS。

## 最後 Marquee candidate：解鎖後 iPad 驗收｜2026-10-03

即時 `passcodeRequired=false` 後，最後 Debug binary `1f973a2c67ac28d74c62f86864dfeafce512c5a284805079ee302cd628368545` 成功覆蓋安裝並啟動。58 秒短案例顯示 Loaded: 25、直向五欄縮圖視覺收在各 card 內，未見跨欄。Raw AX 的 nested video image 仍有 width=230，不能把子節點 rect 當外層裁切結果或宣稱所有 AX bounds 都通過。

兩張畫面有文字位移，AX 保留完整標題及 metadata；完整循環、獨立短標題、VoiceOver、Reduce Motion 及效能尚未驗，Marquee runtime 判 Limited。Up Next 顯示 Synced with Up Next · 25 total／Play 且保持 paused；沒有播放或修改 queue／曲庫、沒有 NAS 或購買操作。

自有 WDA session DELETE 回 HTTP 200，host endpoint 已不可連；SIGINT 後自有 diagnostics 停滯，核對 ownership 後 TERM，controller 及診斷程序均已消失。root 獨立核對最新 binary、四個圖／XML SHA 與程序退出。私人曲庫封面和原始 receipts 只留 ignored runtime；不作公開商店素材。未建立本輪 simulator。

## 正式完成評論：首輪與證據補強｜2026-10-03

主人以「准奏」批准先前 16,000 tokens、每席 4,000、工具 24 次、30 分鐘的預算。已派三位獨立 Luna 分別盲評流程／文案、視覺／可及性、故障／持久化，再由第四位獨立 Luna 仲裁；快照為 c42375f、candidate 2.0(1)。所有稿件已封存，評論不當 smoke PASS。

視覺席在四張指定畫面中未發現可定案缺陷，仍保留 VoiceOver／Reduce Motion／效能等 unknown。仲裁保留四項：廣泛功能宣稱尚缺完整同版實機證據（High，release gate，非已證實功能不存在）、Mac 還原附件只保存 AX diff 而非完整狀態（Medium）、StoreKit pending listener 測試失敗（High，根因未知）、qualification 未保存 exact invocation 綁定（Medium，非否定一般 preflight 的 optional 設計）。

主持者已補跑最後 Release 桌面副本的原創 Cobalt：空 queue → 同曲兩筆 → 正常 quit／relaunch → 兩筆保留、current Cobalt、Play／progress 0；完整前後 AX 已保存。最後只清本次 queue，Not Playing、曲庫 1,969 不變。這補強 Mac duplicate cardinality／正常重啟／不自動播放證據，不代表 occurrence ID、重排、future remove、強制終止、iPad 或混合矩陣全部通過。

同 source 67 項 SHA 在前後均一致；已重新對 Mac archive、iOS archive 與 IPA 展開 bundle 明確執行 `--distribution --expected-version 2.0 --expected-build 1`，三次 exit 0。新私有收據記錄完整 argv、source manifest／qualifier／artifact executable／IPA SHA，補齊本次 qualification invocation 證據缺口；沒有更改 App source 或弱化簽章檢查。

預算控管偏差：流程 6、視覺 6、故障 8、仲裁 7，共 27／24 次評論工具；故障及仲裁超過各席上限。報告自估 tokens 合計 12,580，並非系統精確 usage。已停止追加評論，不宣稱預算合規或完成收斂。整體 gate 為 blocked；pending FAIL、完整實機／無障礙／聲學／Sandbox 等 coverage 尚未補齊，沒有 Done、upload 或送審。全部 raw 報告與私有路徑已排除 Git。


## 2026-10-04 全程式抓蟲續輪（進行中）

使用者授權全面稽核、最小修復與覆蓋 Mac／iPad／可回收模擬器測試。沿用 AERO-U24／Q12／F26／MON30，主代理整合；Luna 唯讀檢查播放佇列與來源背景工作，Gemini 只讀診斷 StoreKit pending。目標為沒有未修 P0/P1，並修復本輪查證的 P2/P3，不宣稱無限範圍無 bug。

2026-10-04T00:05:34+08:00 使用者同意新評論預算：critic_full／converge，總計 24,000 tokens、每席每次 3,000、工具合計 24 次、40 分鐘，涵蓋三位獨立專家、證據裁判及必要 delta／cleanup closure。正式評論須先完成本地修復驗證並凍結新 snapshot；計時從正式 dispatch 開始，既有上一輪 27/24 超支紀錄保留，不重置成通過。

本輪已確認 future audio prepare 失敗只刪 active queue 而遺留 base queue，會在關閉 shuffle 復活失效曲目並使 snapshot 不合法；restore 等待 repository 時也未檢查新播放 preparation generation。準備最小修復及實際回歸。StoreKit 加獨立 refresh reconciliation 與 external purchase probes，原 pending listener acceptance 不改成 refresh PASS。

### 2026-10-04 歌單畫面追加稽核（AERO-U24／AERO-I13）
主人指出 iPad Playlist 畫面及左右欄邏輯不一致。本輪新版實機直向 screenshot／AX 證實：空歌單 ContentUnavailableView overlay 擴張成整頁高且覆蓋 Smart DJ。先修提示卡依內容尺寸，保留 Smart DJ 操作；左右欄採實際橫向觀察與主人回覆釐清，不盲目切换導覽架構。私有證據置於 reliability-20261004 ignored 目錄。
主人已明確指定左右側欄使用一致的開關與佈局，並要求右欄長文字跑馬燈。本輪 AERO-U24 範圍追加：將寬版 iPad queue 從 inspector 改為與 Mac 共用的 inline panel；保留原 Queue 資料／操作，按鈕語意與 Reduce Motion 設定；長曲名沿用已有限幅跑馬燈，非另寫動畫循環。
主人追加指出 iPad 底部播放列視覺漂浮。本轮 AERO-U24 修復僅將 PlayerBar／MiniPlayerBar 的背景延伸至底部 container safe area，保留操作與 Home indicator 的安全距離；不移除整個 App 的安全區。須分別看直／橫向圖與 Mac 無回歸。
主人要求左右伸縮按鈕使用不同圖案：左 sidebar.left、右 music.note.list；保留同一個欄位控制 row 及 44-point 觸控區，無關資料／播放邏輯不變。

正式盲評補充發現 NativeAudioAnalyzer 的 idle cancel 會留下 UUID，讓下一次同曲分析誤取消；此屬 AERO-F27 取消契約。LocalAudioAnalyzer 已有 in-flight guard。Native 修正以每次 request token 記錄 active/cancelled，完成時清理，避免取消完成或尚未開始的請求污染下一次；八聲道焦點測試加入 idle／完成後 cancel 再分析的回歸。修復後需新 snapshot 與焦點驗證，先前 UI snapshot 不自動沿用為新程式全面通過。
主人現看桌面歌單頁指出與其他頁面格式不同；CUA 對照專輯页證實 PlaylistHub 的 List opaque white background 蓋住主題，Smart DJ row 未套共同 cloudSurface。追加 AERO-U24／I13 最小樣式修復：隱藏List底、保留List swipe/context actions，列使用同一主題卡片及邊距，空卡沿用同一surface；不是重寫歌單資料與導覽。新畫面需實測。
逐頁翻查又實際確認 CatalogTrackDetail 的 Mac List 白底遮天；共用 celestialPageBackground 在 macOS 分支原本是 no-op，補上 scrollContentBackground(.hidden)，沿用 WideRootView 的同一背景，不重複建立動畫。其他設定與來源頁保持 Form 的語意／操作。
英文 UI 的 BatchMetadataEditor 實測仍混中文標題／欄位／確認與取消，追加 AERO-I13 三語漏譯修補；Luna 工程席只負責 catalog／必要局部source，主代理驗收，不計作 formal critic 或以此取代獨立評論。

2026-10-04 評論窗口 checkpoint：新預算正式 dispatch 起算 01:37:14，截止 02:17:14；三位獨立評論＋視覺補充與獨立裁判共 15／24 次底層工具，流程席 4 次高於 chair packet 3 次。精確 tokens 不可得，不宣稱精確合規。舊四個 stable findings IDs 保留；restore 漏 guard 與任意像素輸入推測以 frozen source 反證拒絕，取消殘留已以 request token 與 hosted 2/0 修復。最終 UI／locale／取消 delta 未獨立複驗，正式 gate 仍 blocked／interrupted，不作 Done。Hardlink 增量凍結因 workspace filesystem 不支援而中止，沒有評論使用該半成品。
逐頁 Mac 八主頁與七子頁／modal 已實看；最後版 batch editor 英文 locale 已確認，取消編輯且清空測試選取，自建空 QA 歌單已回收。Catalog 白底隱藏後發現曲目文字對比不足，追加 cloudSurface 行卡片並覆用於歌單正常／缺失曲目列；双平台建置成功。iPad 真實安裝與啟動已成功，橫向空歌單／Smart DJ／貼底播放列有限驗證；最終對比版交付與驗證仍續行。

本輪逐頁後補：expanded 接下來播放主頁加共同卡片背板，避免星座標籤穿過曲目／狀態；專輯／歌手子頁三個操作 label 44-point contentShape 與 borderless，避免小觸控區及 List 自動按鈕行為。Mac 最終 universal Release build 成功，桌面覆蓋簽章驗證通過；iPad 同源最終 build／驗收續行。

最終逐頁回看追加：右欄空提示預設 ContentUnavailableView 裁字，改以可換行共用提示並保留 accessibility header；最愛空提示、設定與音樂來源 Form 使用共同 cloudSurface 背板，避免背景星座標籤穿過文字。來源頁未點重索引／重新授權，不改使用者設定與媒體。

2026-10-04 最後交付：Mac universal Release／iPad Debug 同源建置成功並覆蓋舊版本；桌面 strict／deep ad-hoc 簽章驗證成功，非 Distribution 資格。Mac 八主頁與七子頁／modal 已翻查，最後待播、右欄空提示、最愛、設定與來源頁補看。iPad 解鎖後最後版啟動成功，橫／直向歌單卡與 Smart DJ 分離、底部背景貼齊、待播背板與右欄跑馬燈已看；左右欄逐一收合／展開恢復；專輯子頁三個按鈕讀回 44 × 44。未點曲目操作、改評分、重索引或授權，保留原 25 筆待播及暫停狀態，恢復測試前橫向。原創 QA 空歌單已回收，桌面原空 queue 保留且雙欄恢復收合。

遙控補充：同名 label 不足以判斷目的，例如曲目「最愛」按鈕與側欄「最愛」；必須按所在區域與 element type 篩選，每次以新 source 驗證後才操作。最後 source delta／建置 log／二進位 SHA／實機 PNG 與 AX 存 ignored 私有 checkpoint；沒有追加逾期正式評論。Pro pending listener FAIL、完整 NAS／無障礙／聲學／Sandbox／Distribution 及最後獨立 delta 仍未完成，不宣稱 P0/P1 清零或已送審。

最後資源收尾：自有 WDA session DELETE 回應成功，核對自有 host 命令後 SIGINT，確認程序結束；本次 Simulator 已刪除，測試空歌單與選取已回收。未終止其他任務程序；舊桌面副本保留可回復備份。私有交付 checkpoint 保留最終 delta、二進位 SHA 與 PNG／AX，與先前正式評論快照分開，不能冒充獨立 delta PASS。

## 2026-10-04 音效交付證據

最後 source manifest 11／11 SHA matching；Rust 33／0、Swift 92／0、hosted 偏好 2／0，Mac／Simulator／實機 Release 均成功。Mac 同路徑覆蓋、31% 重啟記憶、六 custom binding、Reset 通過；iPad 同 App ID 覆蓋成功但啟動 Locked。Simulator 原生 Scroll Down 可捲到下半部並 Reset 回原音，physical drag 未驗。fresh Impeccable reviewer disposition `fix`：僅留下實機 touch scroll／Reset QA，FX36 保留 Review；RT4 依使用者核准完成退場。音效維護文件見 `Native/AUDIO_EFFECTS.md`，不改既有 DESIGN／tokens；未擴張為完整發行 gate 通過。

本次 QA Simulator 已 shutdown／delete；約 1.5 GB 本次 DerivedData／Rust test cache 已回收，收據、xcresult、桌面回復副本與已簽 iPad App 保留。RT4 實際退場已完成，formal Review→Done 仍保留 Review：Completion Passport 必須綁定正確 taskDigest，現有 CLI help 未提供產生方式，不以缺附件的直接 Done 繞過規則。

## 2026-10-04 可販售品質中途 checkpoint（v3，已由 v4 取代）

Core97／0、hosted AppModel／preferences4／0、v3三種Release與簽章已驗；實體iPad同ID升級、launch及保存佇列25／history5讀回通過。桌面保存佇列1964／history16；舊畫面100為分頁範圍，不能當總保存筆數。最後視覺 disposition fix 正在一次有界收斂，詳 Native/SELLABLE_QUALITY.md。

正式critic_full：not dispatched: approval/budget missing。本候選沒有新 CompletionPassport；普通 Luna、CodeRabbit、Impeccable finish review 不取代該gate。沿用references/completion-critic-council.md 的明文 numeric-budget規則，沒有當前gate總額／每席／工具／時限完整核准就不派送。Pending autoupdate clean harness FAIL根因未知，refresh PASS不能覆寫。所有正式上市與完整裝置／NAS gate保留。

## 2026-10-04 v4 最後 checkpoint

最後可追溯結果以 Native/SELLABLE_QUALITY.md、tasks.md 和 closeout.md 的v4紀錄為準。111檔manifest一致，三Release／簽章／local preflight通過、Core97／0、visual disposition ship只屬畫面範圍；Mac／iPad覆蓋啟動及queue1964／25、history16／5保留。Pending autoupdate仍FAIL，完整Sandbox／實機NAS矩陣及正式critic_full未完成，不標Done／ready。自建Simulator與QA已回收，其他裝置／production資料保留；僅系統root擁有的1716bytes StoreKitTest receipt留在本機，沒有為清理提升權限。

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

## 2026-10-04 解鎖後完整測試續驗

使用者已解鎖 iPad 並要求完成所有需要測試項目。最新 86bfcfc 候選 devicectl launch 成功，接續既有 PQ37／PQ38／PQ41／PQ43、FX36、DV4 的測試，不代表全部 gate 已完成。先執行實機操作與資料保留，再補同候選自動測試及有限故障注入；涉及真實 Sandbox、路由設備、Distribution 與正式 critic 的能力／預算另保留實際狀態，不偽造通過或自動購買。

## 2026-10-04 iPad 最大字級焦點修復

實體 iPad 開啟最大 Accessibility Dynamic Type 時，音效探索兩顆按鈕仍並排且逐字拆行；已記錄私有 XML／PNG，依 AERO-PQ40／PQ43 做最小 VStack 修復並重新建置交付。使用者明確將藍牙／AirPlay 排除本輪 CMV 驗收，不列完成阻礙；目前無 Sandbox 帳號，Pro 核准 listener-only 的已知 FAIL 獨立追蹤。

### 最新使用者修正：按鈕長文字使用跑馬燈

使用者否定僅以 VStack 解決大字級拆字，要求使用既有跑馬燈；按鈕採單行 MarqueeText 與完整 AX 名稱，Reduce Motion 靜態可讀。未交付的 VStack-only 建置只保留歷史結果，不作最後成品。AERO-PQ40／PQ43 收斂同檔最小修正，重新建置與實機驗證後交付。

## 2026-10-04 解鎖續驗與跑馬燈最終交付

最後候選 Marquee v3：111 檔 tree `f897d5917c291b8ed2551a8cddc302fa5be7e24e70db56c7283bc2647b4fc6f0`，production `721e18c58b968ee688660fb45bb184d7703d933006d2bec73397489a33200228`。來源快照與工作樹逐檔一致，三 Release、strict signing／local preflight 通過；Mac adhoc、iPad Development，不是 Distribution。來源及三成品 ZIP 完整性通過。

使用者要求以跑馬燈解決長按鈕；重用 MarqueeText，明確 HStack 避免系統 Label 圖示欄把文字擠碎。實體 iPad 最大 Accessibility 字級：兩張同框畫面證實文字位移，兩顆按鈕 164×78pt 且 AX 名稱完整；Reduce Motion 以完整兩行文字靜態顯示。最後候選實際下一音色 Orbit→Sewer、對照 Original 保留60%、恢復原音為30%／出廠custom值；靜態按鈕點擊嘗試未觀察到轉換，不計PASS。原佇列與字級還原後最後啟動保持paused。

Mac 同 ID 覆蓋啟動保留1964 entries／base、history16、index48；iPad 同 ID覆蓋啟動保留25／25、history5、index13。順序、history、index、version、shuffle、repeat均一致。一般字級67%、輔助大字級0、ReduceMotion0、原粗體1保留；音效偏好回讀Original／0.3與出廠custom值。使用者明確排除Bluetooth／AirPlay本輪gate。

自動測試範圍：Core97與Rust33、fmt／clippy／bridge PASS；完整hosted19在08c2production為18 PASS／1 FAIL（Pro pending approval listener-only timeout）；reliability3與真實SMB NAS cache7 PASS；音效偏好5在Marquee v1 PASS。v3只改同一label排列，補三build與焦點實機，不虛稱完整hosted重跑。50k NAS／完整VoiceOver、contrast、StageManager／Sandbox／Distribution仍未驗。正式critic_full因缺explicit total／per-seat／tool／wall-clock budgets未派送，無新CompletionPassport。

結果詳見 Native/IPAD_TEST_REPORT.md；私有收據位於ignored `.cmv-local-evidence/2026-10-04-ipad-unlocked/`。既有Review與In Progress保留，不標sellableReady或整體Done。

### 本輪資源回收

`cleanup-final.json`：來源111檔最後比對通過，自有controller正常exit0；WDA host收到SIGINT後exit75，兩個本輪PID均已不存在。已刪本輪使用者擁有的build／scratch與NAS測試fixtures，production資料與證據ZIP／logs保留。只有系統root擁有的1726bytes StoreKitTest receipt及父目錄因PermissionError保留，不提升權限。此殘留不影響已交付Release，亦不代表全部暫存目錄消失。最後Simulator只建置與local qualification；交付啟動為Mac／iPad兩端。

## 2026-10-04 Sandbox 帳號狀態更正與現有 Pro 實測

使用者最新確認目前一直使用 Sandbox 帳號維持 Pro，並回報未登入時 Pro／付費背景會鎖住；先前「目前無 Sandbox 帳號」是已被新資訊取代的歷史紀錄，不再作為現行阻擋。Mac 桌面實際顯示 Pro Unlocked，恢復購買完成顯示 Your Pro purchase is confirmed；正常結束並重新啟動後仍解鎖，土星環站 Pro 背景可選且實際呈現，再還原銀河夜幕。未登出、清空購買紀錄、退款或新購買。

這是目前已購權益、恢復、線上冷啟動與 Pro 背景的實測；尚未直接讀取 Transaction.environment，不以 UI 宣稱已獨立證實 Sandbox 環境。Ask to Buy 核准／拒絕使用 Xcode StoreKitTest；本機模擬與 Apple Sandbox 交易證據分開保存，不用現有 Pro 狀態代替完整交易矩陣。測試腳本已修正改名後的案例入口，要求每例 xcresult total=1／passed=1／failed=0／skipped=0，零測試不能 PASS；單一 raw StoreKit consumer 另作獨立診斷，沒有和 ProStore 同例競爭事件。


## 2026-10-04 Pro 可靠性完成要求與診斷續驗

使用者明確要求將 Pro 付費可靠性任務完成，沿用 AERO-PQ38／MON30，不建立重複任務。既有帳號可用的更正保留：Mac 現有版本恢復購買、正常重啟仍 Pro、付費背景實際呈現通過；環境依使用者回報 Sandbox，未直接回讀 Transaction.environment。

本輪獨立七例 macOS StoreKitTest 有效 xcresult 為6 PASS／1 FAIL／0 skip。Raw單consumer待核准通知PASS，raw listener＋production purchase PASS，production listener＋直接purchase FAIL；listener存活卻streamUpdates0且current verified entitlement1。只一次startup refresh及ready barrier／weak callback分離／parent建立串流均FAIL；後三實驗已撤回，正式授權行為逐字還原，只保留DEBUG專用probe。這些控制結果限縮失敗路徑，不能宣稱根因確定或修復。iPad iOS26.5 Simulator配置SKTestSession時Code3，未測到購買，已停止並刪除自建Simulator。

原始結果／分階段來源／最終118檔来源ZIP均已封存ignored私有evidence。接續單一consumer弱引用轉交production handler判別；工作樹production尚未修改，不以持續polling掩飾listener，不操作使用者退款、登出或真實付款。


### StoreKitTest propagation 交叉反證

同一物件 ObjectIdentifier 的 marker 顯示：waiter先取得timeout快照，接著讀currentEntitlements期間，raw callback才進入receive且counter 0→1；並非方法未被呼叫或弱引用失效。獨立對照：production listener在test-only `waitForCurrentEntitlement(true)` barrier後核准PASS（matching verified update至少1，沒有call ProStore.refresh／直接授權）；raw listener刪掉同樣的post-approval read也FAIL（allUpdates0）。原先「production listener本身有缺陷」的推測已由交叉反證撤回；Apple未承諾currentEntitlements會促進updates，僅記錄本機Xcode26.6的實際時序差異，不推廣成SDK契約。

已將barrier加入三個核准測試、補六個真StoreKitTest故障案例，16例逐項xcresult驗證進行中。沒有變更正式授權行為。實體iPad將以獨立QA App ID及已存在的wildcard Development profile執行；初次誤將憑證CN中的使用者ID當Team ID，建置被signing拒絕，未裝App／未測交易；已核對憑證OU與快取profile，改用正確簽章。原production App與資料保留。

### 2026-10-04 Pro 本輪驗證進度

Mac／實體 iPad StoreKitTest 各17 PASS、0FAIL、0skip，逐項xcresult ZIP CRC與實際測試數已驗。Mac真Apple Sandbox既有正式SKU直接讀到sandbox環境，商品價格／權益／恢復／fresh ProStore 1PASS；原桌面版已還原開啟，1,964曲、Pro Unlocked與銀河夜幕由畫面確認。正式ProStore排除test-host DEBUG區塊後與原始snapshot逐字一致。iPad最後真Sandbox測試於Xcode deviceprep -3等待解鎖，已向使用者提出；尚未覆蓋為PASS。另提出新的critic_full數字預算12k總tokens／每席2.5k與12工具／20分鐘，尚未獲回覆，不dispatch。

補記：iPad真Sandbox xcodebuild等待鎖定後exit65，未啟動付款assertion；同來源原App安裝因CoreDevice error60連線逾時，尚未確認。保留原版簽章／source／ZIP binding與安裝前AppData私有ZIP（CRC PASS）。AERO-PQ38以transition receipt pro-review-202610041111從In Progress→Review，MON30仍In Progress；不跳過正式critic／Passport。

使用者已核准本輪critic_full總12,000tokens／每席2,500tokens與12工具／20分鐘，三席Luna加獨立仲裁；修正與delta共用上限，不重問。採converge，等最後iPad證據後凍結snapshot再dispatch，避免消耗額度重看中途結果。

更新：裝置恢復連線，原App同ID安裝及launch成功。before資料有1-entry／revision88的QA queue，還原後讀到原25-entry／index13／history5（revision55）；DB/WAL/SHM與pinned byte-identical，偏好僅SKTransactionUpdatesLastChecked改變。未把所有資料一致誤標PASS，兩份queue皆保留。iPad真Sandbox新測actual1FAIL：environment sandbox、hasPro、商品價格、restore失敗後保留Pro、freshStore均assert通過；唯一失敗為restore success message（實際restore failure message），115.266秒。正在私人DEBUG probe加domain/code診斷，未改正式ProStore語義；已請使用者查看是否有Apple/Sandbox帳號驗證。

Xcode Devices→Take Screenshot已實際確認iPad正顯示Apple帳號密碼視窗。v2 probe已讀到Sandbox transaction、hasPro與商品價格，停在AppStore.sync；已明確請使用者在iPad本人完成，密碼不傳給Codex。私人截圖移入ignored證據，公開紀錄不含帳號。正式critic budget已核准但尚未dispatch，保留待最終實機結果。

使用者已在iPad完成Apple登入；v2真Sandbox1PASS，restoreConfirmed=true、hasPro=true、freshStore=true。最新Mac17+iPad17+Sandbox各1=36PASS/0FAIL/0skip；舊失敗分開保留。原App最後同ID安裝與launch成功，原25首queue整份JSON一致；自建QA App已移除，device handoff已写入remaining-validation。其他任務已用receipt確認原1-entry是QA中途狀態，撤回install資料遺失疑慮。

正式Pro council完成三席盲評＋獨立仲裁，snapshot pro-36-final-20261004，passed/findings=[]；18artifact hashes及4sealed report hashes一致，critic_contract.py兩task皆exit0。Native Rust length-framed task digest算法已讀實作並與9個既有Passport全數匹配，不猜digest。PQ38/MON30 current Passport通過原生Review→Done transition，另加crab-done生命週期標記並重新綁定digest。正式source未變，Pro技術結案，不代表整體發行Done；physical radio-off與Sandbox新購／退款未執行的scope限制保留。

2026-10-04 remaining-validation 最後更新：Pro裝置交接後重新安裝final v3 exact-ID，程序路徑與receipt一致。歌單List borderless修復實機上下移保持2entry且不誤播放／刪除，batch remove及ownplaylist清理通過；title升降／Violet搜尋通過。撤回一度報告的多選2首／EOF PASS：原XML實為Selected:1且只Silver；逐步觸控未使Violet勾選，不假產品FAIL。最後183track IDs與9metadata欄一致，favorite/rating/pin/playlist已清理；queue關App回讀全等25/25/history5/index13，重啟後曲目與history順序及模式一致且paused，occurrenceUUID/revision依既有實作重建。Cloud素材下載等待、真NAS/UI50k150ms與完整VO/PiP/離線矩陣保留，任務不冒標Done。詳Native/REMAINING_VALIDATION_REPORT.md。

### 2026-10-04 晚間續測

依主人要求繼續實機 QA，略過遙控多選勾選支線。AirDrop 後本機 Source-B 7 檔已匯入，183→190，原資料保留。重現 scanner 漏讀 AAC/MOV metadata，已最小修正並以實際 AVFoundation 媒體測試驗證（2 tests／0 fail／0 skip）；新 snapshot 的 iPad／Mac／Simulator Release 與 local qualification 通過，已覆蓋安裝 iPad。原檔暫移出來源後冷啟動仍以釘選副本播放到 1:02，checksum 一致；網路保持連線，不稱飛航 PASS。三分鐘音訊 73.9 秒背景返回與 PiP 暫停 enter／Home／restore 各有實機證據。NAS 13 檔 scanner＋持久化 repository 的初始／重掃／差異與來源失聯保留分支已驗；50k tiny AAC 實體生成完成，production 壓測與其餘實機矩陣接續中。詳 Native/REMAINING_VALIDATION_REPORT.md 續測節；正式 Done／Distribution／critic_full 不由中途結果推定。

### 2026-10-04 非 Pro 續測收尾

本節取代上一段「壓測接續中」的現行狀態，歷史失敗保留。Source-A/B 共 13 檔的 iPad production metadata 匯入／重掃通過，196 首與 7 來源、原 183 筆 metadata9／favorite／rating 保留；Faults 壞檔顯示可關閉錯誤且不清目錄。Smart budget 預設 10 GiB、Pinned 使用獨立根目錄；已實測原檔移走後新版冷啟動仍播放釘選副本，未塞滿 10 GiB 或完全斷網。

Mac SMB 的真實 50,000 份合法 tiny AAC 經 production scanner＋持久化 repository 完成初始索引，50,000 available／0 missing／0 issues，offset501=25；耗時約34m24、maxRSS509034496 bytes。13 檔差異／不可達保留 API 另有收據；不是 iPad FileProvider／150ms UI。

新發現 mixed 末曲 stale base 造成拒存空 queue，兩檔最小修復的 production transition／store.load focused tests 2 PASS／0 skip。新113檔 tree `011828a6e361a8afe47af503dc7a39347acb338915b99cbc86a25ba8ade56c81`，三 Release／local qualification PASS；iPad exact-ID 同 bundle 覆蓋，binary `ab5abe0feccd287ba8f7a6d2491af35196655781e67a911261489c8fd563fddd`。實機末曲3項存檔／冷啟動3項及 video→audio 自然接續通過，terminal EOF 合法降為單曲，不稱 EOF 後保留 full3。第一輪中間影片截圖沒拍到，另輪有原創影片實際圖像；結尾 Next 遭 fresh XPath／座標 guard 拒絕未送達，快速 EOF 仍待驗，不算產品失敗。Slider 遠端疑似 isSeeking stale 亦保留診斷，沒有憑推測改 production。

最後僅還原原25項 queue JSON，未覆寫DB；25／25、history5、index13、modes 與 paused 順序一致，occurrence UUID／revision 正常重建。196首／7來源、原183 metadata9 及 favorite/rating 一致，playlist0、pin0。合成資料與私有收據保留。詳 Native/REMAINING_VALIDATION_REPORT.md。八個非Pro任務 Next Step 已更新、維持 Review；本輪 scoped review 無新增 P1/P2，不冒稱 formal critic_full 或 Distribution；Pro 專項既有 Done 不更動。

2026-10-05 非Pro續測：主人最新排除完全斷網(USER_EXCLUDED)，不再列為待驗。正式critic_full範圍與12k總額／每席3k tokens、6工具、整體20分鐘已明確核准；本機測試與immutable snapshot後dispatch，四席跨輪次共用上限。iPad操作runbook已新增並核對實際RootView Done/Return semantics、queue-only lifecycle與CUA input邊界。WDA本次啟動因裝置鎖定失敗，已請本人解鎖，未盲目重啟；獨立容量／UI隔離harness與可及性契約核對繼續。

## 2026-10-06 解鎖後續測與 QA3 checkpoint（Review）

本節是解鎖後的目前狀態，保留前文作為歷史紀錄；不代表正式結案或 promotion。QA2 production video driver 在 iPad13 的限定 session 實測 `14.616 s`，13 modes 逐項事件核對、所有非 neutral wetCount 增加、seek／pause／resume／stop 通過，`stop 405→405`、`errors=0`；此範圍仍不涵蓋主觀聽感、完整 lease 或全 PiP 矩陣。

Main frozen `e288` 的 13 個 mode label 已逐一 GUI 回讀；Custom 保留 `76%／52%／262.6 ms` 並完成原音返回比較，影片自動 EOF 到 terminal 約 `54 s`。PiP Original 已實機進入、Pause→Resume，HomePiP 兩張截圖可見畫面與進度變化；從 Home 回全螢幕因 fresh guard 過期且圖像點擊無效，不能列 PASS，之後 PiP 自然 EOF 關閉。Main13 與 PiP/lease 的完整矩陣仍為 Review。

原始 queue restore receipt（`20261006T135119Z`）actual exit `0`；25 entries／base25／current13／history5，非 revision 欄位完全一致（原 queue hash 前綴 `56a8657d…226`）。允許的播放差異限於兩筆 track 的 `Z_OPT`、`playCount`、`lastPlayedAt`；CoreData history 有 4 筆新 transaction/change rows 與 primary-key allocation counters，不能解讀成整個 SQL byte identical。

QA2 search runtime 只有限定暖查詢證據：`QA-501-after-target 54.302 ms`、`Synthetic Track 50000 72.874 ms`、`星河 119.884 ms`、`Fictional Artist 03 134.315 ms`；`61 started／10 published／0 stale publication`。cold final `3242.827 ms`、empty outlier `170.059 ms` 尚未解決，沒有 p95 或整體 150 ms promotion 結論。QA3 cancellation artifact 已通過本機 build/sign/ZIP 收據，local tests `107 tests／2 skipped／0 failures`；1 ms cancellation 測試不能證明在第一批中點 deterministic cancel，硬體驗收仍待 root 執行。

容量與程序紀錄：使用者最新基準 `30 GB` supersedes 舊的 `33 GB` 歷史報告；當時 simulator 已是 Shutdown，root `simctl shutdown all` actual exit `0`。本輪已清理已完成工作留下的 cache `365380 + 505688 KiB`，swap 仍增加，不宣稱可用空間已回到 30 GB，也未處理其他任務程序。

目前 next actions 維持 Review：root 以 QA3 在硬體量 cold／empty 與取消 stage，重跑四暖查詢並保留完整 metrics；補 fresh guard 下的 PiP Home→fullscreen 與 lease／subjective listening；未達證據前不升級 150 ms 或標示 Done。MissionCenter syncdoctor 由 root 另行處理，本節未執行。

### 2026-10-06 22:04 current checkpoint v13

QA3 已備份QA2、安裝及啟動 actual0；根代理逐項核對121來源檔、只變更repository及AppModel、全部原始exit/log雜湊、ZIP每一App檔案bytes。實機冷搜尋最新target正確count1，但query→publish **14368.014ms**（退步，禁止promotion）；六個舊request只有candidates.start/cancelled沒有end，未證明處理實體批次數。昂貴enumerate前漏entry cancellation check，QA4修正及建置已委派既有Luna。

清除／重新聚焦後，完整中文、假歌手及尾端曲目暖查詢分別120.246／142.117／66.579ms，顯示200／200／1；截至尾端metrics為68started／12published／0stale。誤輸入帶`-target`尾字的紀錄保留但不算預期暖查詢通過。v6輸入教訓已加入runbook。

PiP後額外Main資料核對：對post13基準204tracks／7sources／0playlists不變；僅兩個自有測試track播放統計，CoreData新增6個change／transaction、既有history全部保留，Z_PRIMARYKEY僅allocation值。原25所有非revision字段exact。391檔新證據封存且逐entry SHA讀回通過（私有R之postunlock-hardware-qa3-archive-receipt.json）；不覆寫舊封存。MC sync committed、doctor actual0/pass，legacy completion-passport unknown warning仍保留。QA4／cold性能／PiP返回等仍未完成。


### 2026-10-06 22:50 最新續測（取代較早的 QA3／QA4 下一步，維持 Review）

QA4 原 unsigned 候選誤用 QA2 AppModel 基底，被根代理拒絕且未安裝。QA4b 保留 QA3 AppModel、121 來源檔僅 repository/tests 兩項差異；deterministic pre-cancel/recovery focused test 1 test／0 failure、unsigned build actual0。根代理完成 Development 簽章 strict/deep、五份 plist/privacy 及 ZIP 每檔 bytes 驗證。首次 QA 名稱改寫漏保留本地化 NSMotionUsageDescription；原成品保留，已另製逐鍵保留的成品（binary b1f1e4d4…9700、ZIP 73a5e842…442f），備份、同 QA bundle 補裝及啟動 actual0。Main e288/aecc 沒有 promotion。

QA4b 暖查詢：target72.727ms／中文109.128及122.753ms／虛構歌手140.992及141.594ms／50000末筆65.686ms；無結果58.870ms並顯示無符合曲目，清除後恢復200筆。原簽章包45started／16published／0stale；暖樣本都<=150ms，但沒有p95或完整50k硬體IDs/order結論。冷target4735.116ms，metadata補裝後冷末筆4691.073ms：QA3的14.368秒退步已改善，冷瓶頸仍待修；QA5真正500筆fetch分頁候選正在隔離處理，尚未實機驗收。

QA3實際捲動越過200邊界，generation69發布200→400，曲目00200/00201/00213可見、第二頁repository→publish64.672ms。不能把第一個queryStart到23分鐘後手動捲動的間隔當分頁延遲。

本機實測約7.3GiB可用，工作前30GB仍為使用者報告。唯一MediBuddy模擬器已Shutdown且保留。分身清除本次完成的241468KiB候選build cache；先前240548KiB及365380/505688KiB記錄保留。3224檔／487678713bytes證據已比對搬至NAS：原cleanup因權限actual1，2967剩餘檔再驗證0mismatch後只補本機owned舊目錄寫權、cleanup actual0；NAS與source/raw保留，舊路徑有效symlink。WDA/relay與他人程序持續運作。

PiP回全螢幕、full lease／slow NAS／meter／完整VoiceOver與iPad10GiB容量缺口照實保留；全斷網/AirPlay/Bluetooth依使用者排除，Pro由隔壁負責。正式council仍limited，沒有新增formal審查或Done宣告。checkpoint v14新增235檔封存且逐entry SHA讀回；不覆寫v13失敗或舊archives。本段的文件更新尚未另執行MC sync/doctor。


### 2026-10-06 22:54 使用者更新效能取捨

使用者表示五萬首首次載入即使等待約一分鐘也能接受。驗收重點改為初始化期間可操作、背景進度與取消，以及後續暖搜尋順暢；首次建立索引4–5秒不再當作必須壓到150ms的失敗。歷史QA3退步保留，暖搜尋150ms與資料完整性仍須依實測驗收。QA5只先審閱分頁安全性，不為cold擴大持久索引／prewarm重構；是否採用以必要性、正確性與回歸結果決定。
## 2026-10-06 23:40｜cold 取捨與 Main 續測

五萬首首次 4–5 秒依使用者最新取捨接受；封存 QA5 而不擴大 cold 最佳化。QA4b 暖樣本 58.870–141.594 ms scoped PASS；Main 隔離整合 Core actual 0，107／2 skipped／0 failures，雙平台 build 尚未交付。Root 完整盤點 actual116：3 modifications＋2 existing-workspace Rust test-fixture additions，不沿用 manifest114 是全部來源的錯誤簡稱。source audit v3 已驗 bytes，未把 detached parent cancellation 宣稱為物理中止 map/rank。

e288 Main 直向 ASCII／日文搜尋各 1 筆並核對 metadata；橫向 SearchField 可見卻未取得焦點，其他控制正常，保留新 scoped finding，遮擋原因未證實。PiP3 未成功進入，不採為 PiP PASS；原25 restored actual0／全非revision exact，204／7／0保留；overlap capture 不當作 pre-stop 證明。正式 council 既有 limited／Review 維持，沒有新正式評論。


### 2026-10-07 15:02 五萬筆重開完整性

QA bundle `com.windsheep.cmv.qa50k` 重開與讀回 actual0。第一份讀回仍為舊 initial 收據，保留且不列為重開通過證據。新 restore 收據 generatedAt `2026-10-07T06:58:20Z`，priorReceiptSHA 與 initial 原始檔完全一致。八組 query manifests、每頁 digest、ID 順序與總數全同；空查詢50,000筆／250頁，零重複、零漏筆。根驗證檔：`.cmv-local-evidence/2026-10-07-final-runtime/qa50k-restore-root-verdict.json`。範圍為 QA4b instrumented AppModel 加 exact repository；不是整份 Main 原始碼相同，UI 舊結果發布 gate 仍 LIMITED。新的事件追蹤候選正在隔離準備。

### 2026-10-07 16:15 最新候選與實機續測，維持 Review

Main frozen117 僅追加 VideoExperienceView 的 terminal polling 修復，來源 SHA `a40fdc9a…eeb8b99`；雙平台建置、簽章、plist/privacy/localization 與 ZIP 每檔讀回通過。Mac universal binary `84bd1d89…194381` 已交付 Desktop，iPad arm64 `c604b83b…27c36d9` 安裝及啟動 actual0。iPad 新版單結果自有影片 GUI 實際顯示 0:04／0:12，EOF 清空播放；新候選 PiP／seek／replay 尚未借用舊成品證據。Mac GUI 因工具回報電腦鎖定，待使用者解鎖。

Main 現行基準為429 tracks／10 sources／0 playlists與19項 queue。自有影片測試曾自動接到私人歌曲，該操作與原始失敗均保留；完成後只對 Main 容器還原今日實測前 Support／Preferences，九張資料表逐列全欄 exact、preferences 全值 exact、queue 所有非revision欄位 exact（revision197→199為重新啟動變更）。原始實體媒體未刪除。原25項及204／7只保留歷史，不作目前還原基準。

新 QA 候選 `e63454c2…6718` 已安裝，保留 Main 的 mapping 前後取消檢查，另加 atomic publication event mirror。自然冷查詢與暖替換有實際舊 generation 工作重疊、取消且零舊發布；最新目標各1筆發布及 layout。新版 initial 八組 query manifests 與獨立 Rust／repository oracle 完全相同：50,000 IDs／250頁，零重複、零漏筆。這是 instrumented projection 的限定證據；空查詢整體冷 race、完整 Main 50k UI 與 p95 未建立。第一次新版 restore 讀回仍是舊 initial，未計為 restore PASS，正在另讀。誤用取代文字而留下游標後綴的輸入 attempt 明確排除。

慢 resolve 的取消／bookmark失效提交防護與 MainActor heartbeat 斷言通過；實際本機 security-scoped lease clear／switch-then-clear／video-stop 配平通過，根代理獨立讀回 raw。真實 NAS bookmark/open capability 受限，已保存 sample 與明確 skip；不能宣稱真實 acquired→stale NAS 已量測。10GiB容量測試因 iPad 重要可用空間約3.98GiB、檔案系統約2.26GiB，低於14GiB安全門檻，未配置檔案，狀態 TOOL_LIMITED。Mac 工作前30GB是使用者提供的參考，僅回收本次完成 cache，不處理私人資料或其他工作程序。

直向小縮圖第四格在先前 Main 測試未選取，QA 同樣位置可選取；新版 Main 重啟後第一格原生按鈕操作亦未變更，截圖中心觸控則成功。正在核對 relay 命中位置與 Main hit-test，根因未確認、未宣稱修復。實際觸控持續穿插，但未將全程防鎖時間間隔標為 PASS。正式 council 未新增執行，既有額度限制及人工聽感／完整 VoiceOver 缺口保留。

16:23 補充：新版 QA restore-check-3 已有 fresh mode restore，generatedAt `2026-10-07T08:17:23Z`，priorReceiptSHA 精確對應新 initial `fca94cba…042b44a`；八組 manifests 全同、沒有 error。分身及根代理分別讀回確認，根收據 `qa50k-new-guard-restore-root-verdict.json`。兩份先前 stale initial 仍保留 NOT_PASS；行政帶回前景與 restore launch 都是 PID23700，不能據此斷言唯一延遲原因。copy 工具 actual0，但分身外層 zsh 曾誤用保留變數 status，該外層錯誤亦留存，未重跑 copy。完整性收據不包含 UI 發布 gate；該 gate 由另外的自然 cold／warm 原生操作事件證明。下一個合成封面 A/B 專案僅限 QA namespace，不改 Main 或既有全量驗收收據。

### 2026-10-07 22:00 土星背景緊急修復

使用者回報土星背景消失。實機舊 Main 顯示白底；工作區的土星使用 ShaderLibrary.saturnScene，但 frozen117 漏收既有 SaturnAtmosphere.metal，舊 iPad／Mac 成品均缺 default.metallib。舊背景覆蓋聲明因此失效；先前封面、多選等限定實測保留。新 corrected118 與最新 parent117 每檔 SHA 完全相同，唯一補回原 Metal（60670630…5c7d89），Library8a6／Videoa40 保留，不恢復已退休的靜態背景。

首次 builder 誤選較舊117基線，根代理在交付前攔下；失敗65、interrupted retry、plist parse failure 與 launch64 原始紀錄保留。正確雙平台 CompileMetal／MetalLink、strict codesign、原語系與隱私／external pinned entitlements 核對通過。來源缺 entitlements 由原既有外部簽章輸入補足，實際 decoded exact，沒有觀察到權限流失。

iPad 新 binary66996／ZIPa874 已安裝，launch retry0；土星與光環在直向、橫向、曲庫頁實際恢復，小縮圖單格1→cancel0通過，七組原始截圖/XML SHA 與 Main identity 已由根代理獨立核對。安裝前後九張資料表含 WAL 全列全欄相同，queue 非revision相同（209→211），preferences 僅 StoreKit 自然時間戳差異，titaniumEclipse保持選取；重開播放進度0:00，不宣稱恢復先前1:03。

Mac 新 binary9697／ZIP523c 已交付 Desktop，行政備份及 rollback 保存，交付前後資料 exact；根代理另核對新 Desktop binary與deep strict0。CUA 實際啟動並暫切土星環軌站，設定及收聽頁原生截圖均看見土星與光環，PASS_SCOPED_MAC_SATURN_GUI。已透過UI還原原星海晨光並回收聽暫停；原生截圖保留在工具輸出，未存本地PNG。交付資料exact不借用為GUI後全資料exact。

新增唯讀 verify-runtime-resource-inputs.py，檢查來源 Metal SHA、ShaderLibrary／stitchable contract、catalog filename、編譯 metallib／symbol、external entitlements pin。old117負向actual1，新118 iPad／Mac正向actual0。收據集中 /tmp/cmv-saturn-shader-repair-20261007；新版工程封存待完成。iPad遙控其後Errno61中斷，已請服務擁有者診斷，無法宣稱持續觸控防鎖。正式 council 未新增派出，全案與人工聽感／VO／完整五萬首Main UI等既有缺口仍保留，不轉全案Done。

22:03 封存補充：Saturn checkpoint `saturn-shader-repair-final-20261007.tar.gz` 72,825,385 bytes、SHA `a5e0a156d32c64ddabe0d801a2d6c70ce52586fdf7f14228d34808a86bca90bc`，292 data members＋embedded manifest；根代理逐檔 bytes／SHA、無重複 member、manifest bytes 與最新 Desktop readback 均 exact。首次特別讀回採錯 tar prefix，檢視 manifest 後修正，保留原失敗，不更改封存。這是 shader hotfix 的限定工程 checkpoint。

後續唯讀資料核對：Mac GUI 後一致快照九張表 schema／全欄全列仍相同，queue 除 revision280→283 外全值相同；偏好只新增視窗位置紀錄及 StoreKit timestamp，外部偏好全值相同。根代理獨立SELECT／plist核對 actual0，收據 `.cmv-local-evidence/2026-10-07-final-runtime/saturn-mac-post-gui-root-readback.json`。此新收據在封存後產生，單獨保留，不重寫已封存 tar。Recovery3曾status ready，但實際relay source502與runner22:03退出；根代理CUA更新仍Errno61，成功callback已由owner撤回，receipt未生成；維持工具阻礙、根因未明，不列恢復PASS。

遙控後續診斷（服務owner回報）：recovery3 xcresult summary actual0記錄 `Test crashed with signal kill.`，22:00:48短暫status200與22:03:02 runner退出的時點差異已釐清；目前非wrong URL/session證據，未歸因test-timeouts。作為owner診斷回報保存，Root未自行讀回xcresult；正在查system crash/jetsam終止原因，尚未恢复實際觸控，不能宣稱keepalive或服務穩定PASS。

Recovery4 後續：使用者於服務owner chat授權重啟服務一次，實際exit65／automation initialization timeout，無ready、無relay、無fresh畫面。Root獨立讀回 restart-receipt 與 raw log SHA exact，核對逾時文字；既有兩份SIGABRT报告為不同PID，只能限定早前XCTest初始化異常，不證明本次共同根因。收據 `.cmv-local-evidence/2026-10-07-final-runtime/wda-recovery4/restart-receipt.json`。未重啟整台iPad，土星與資料既有scopedPASS保留，剩餘觸控仍工具阻礙。

## 2026-10-08 Apple審核資料沿用邊界

主人授權參照GAI與MediBuddy。CMV既有審核聯絡／版權已填，公開文案33欄fresh exact；Review Kit已補七類資訊對照。不能沿用其他App的隱私回答、示範影片、版本或功能宣稱；本App Record兩平台2.0草稿／build0／六組截圖集合0。無遠端變更。

## 2026-10-08 現行 Distribution 完成／iPad 續驗交接

Mac universal PKG 18,253,407 bytes／SHA e98984cd…031e5、iPad arm64 IPA 14,788,526 bytes／SHA e150dfeb…989d 已建立；四份 archive／出口 bundle 的 Distribution qualification、strict codesign 均exit0。主代理親核95檔production exact、profiles與binary／dSYM UUID，完整251 payload／241,901,191bytes封存manifest SHA 75ed75bd…8f270。詳 Native/DISTRIBUTION_CHECKPOINT_20261008.md。未安裝出口、上傳、提交或發布，不推導整體RC／runtime通過。Mac export helper不支援與iPad缺mapping兩次exit1原始紀錄保留，修正ExportOptions後出口成功。

iPad舊WDA本輪確認已exit65，原relay使用失效session；以既有xctestrun test-without-building重啟自有WDA，再只重啟身分核對過的自有relay。原HTTP8766 fresh畫面已觀察CMV；沒有重編或重裝CMV。fresh裝置passcodeRequired=false，舊待解鎖描述不再是當前阻擋。主代理停止CMV後原子copy五檔基準：DB429tracks／10sources／0playlists、queue19／base19／history19／current1／revision229。原創CMV-Review-Fixtures兩曲仍在但excluded；不播放目前19首私人收藏。本轮iPad M6／有限矩陣由Luna唯一操作，結果尚待直接收據與還原驗收。

review-evidence-index僅為11個指定ID的criterion→receipt對帳，不是critic判定；本次修正真正Verification中的過時重建、聽感、容量與已排除條件，保留歷史證據与工程缺口，不轉Done。root最新可用18,043,428KiB，未容量不足，未清理必要runtime／活躍WDA。正式Full completion council尚未新增dispatch。

## 2026-10-08 音效既有收據補核

主代理讀回swift-test-AudioEffectsTests.raw SHA31cf1ecc…ce82b與三份現行source SHA exact，14／0中直接有mono engine、mono44100 video、anti-phase Orbit、設定不重排timeline、pause mute／play restore及renderer lifecycle passed。唯讀index將13preset stereo harness的限制誤延伸成「沒有mono／anti-phase host工程證據」，本append更正；沒有新測試或裝置／聽感／正式critic升格。主收據 /tmp/cmv-task-zero-20261008/audio-criterion-readback/primary-audio-criterion-readback.json。原索引保留作修正前對帳，不改其歷史輸出。

## 2026-10-08T09:47:41.069584+08:00 metadata修復／Mac排序與iPad M6最新scope

205份自有AAC小檔合計770,213bytes已在Mac實際匯入。歌名、藝術家、專輯、修改時間八方向的可見頭尾與第200／201首均與獨立oracle一致；random追加第二頁前後共同頭端與尾端一致，不宣稱205全列GUI捕捉。第二次尾端viewport多一個前項T020，整viewport等式false是視窗範圍不同，共同13項及末5項exact。原Development final-v2 scope；測後停止CMV、六檔原子還原byte exact，launch後九表全欄/schema exact、queue非revision exact298→301，App-owned prefs exact；可見1971首且paused0:00／6:25。新排序封存218payload manifest SHA a54abc4a6d81e352272b1847d00d64d2ccd8e113a78bd8a34d5564f372dc8882，入口 `.cmv-local-evidence/2026-10-08-task-zero/mac-sort-matrix/`。

iPad M6：真2selected、批次加入queue19→21、Cancel與九表全欄還原exact、queue除revision exact229→232、prefs僅Store timestamp changed。播放所選兩次未觀察播放器變更，保留UNKNOWN；不PASS或產品FAIL。selectedTwoScreen沒有localPNG，選取由XML直接綁定。worker實際沿用Chrome1/tab903829336原ASC頁改HTTP8766，非原IAB；如實記deviation。封存54payload manifest SHA 56f7660c117388abac82bdd99ed211be4ddeb41242e58a84c7092f8ff03f55b2，parent逐檔讀回。

Mac真匯入另重現Apple itsk/trkn與itsk/disk曲／碟序205全nil，已共享exact classifier最小修正Parser／Scanner，拒不相干key；before parser/scanner exit1，after parser/scanner/focus exit0。fixture scanner需CMV_SORT_FIXTURE_ROOT，無env會XCTSkip，未偽稱一般CI自動覆蓋。修復封存27payload manifest SHA 407354111b7ca2a13799d91b4a6f41c42fff4807f4b0e280b82271439f2adf1f，兩檔精準delta SHA 7c524055ed38dd576f0e9d2daaf3844357f6a07ea7eed21fff4c57b58bff316f。source已變，舊Distribution退為前候選資格證據；修正版Development与Distribution由Luna另建，未安裝／未upload／未submit。Gemini白月光三語草稿與ASC33欄exact已完成，未重寫。

本次只更新Next與append-only evidence，不跳任務狀態、不動RT4/S01/S02舊封存；full council budgets尚未核准，未dispatch。

## 2026-10-08T10:05:07.629309+08:00 修正版正式成品完成／Mac真匯入回歸

Parser/Scanner兩production改動後已重新建立Mac universal/iPad arm64 Development與Distribution。主代理實際核95before/after/current exact、四Distribution qualification/strict codesign exit0、profiles get-task-allow false或absent/devices absent/allDevices false、signed與profileidentifier exact、binary/dSYM UUID exact，MacPKG signature exit0。新MacPKG18,257,143bytes SHA dd8e48f832d5fff33c12828b765004e60a7cb61ed701459d5078c677fc1b29a5；新iPadIPA14,790,512bytes SHA19cedc64f1b6067fae6b940f1543c470ab2ec55df592fca1456e8aa622345ffb。primary封存140payload manifestSHA14a151a979b677a4dba684ffa0d47e6c93b791c7ab8530f1aee2cb84989020f2。Archive目錄逐檔manifest綁定，不用directory假SHA；重新簽署後archive與出口binary SHA各別列，UUID一致。

Mac同路徑Desktop/CMV.app覆蓋新Development SHAa41fbc5e5938dd15aa9fb7b29082033fc5336d8b56402847de490e8385c867c0，staged source95 exact。GUI重新匯入205合法小檔，production持久化title/artist/album/albumArtist/track/disc/genre/date/mtime各205exact，SongInfo T200直接顯示曲200／碟3；未播放私人。六檔停機原子還原byte exact，launch後九表schema/全欄rows exact、queue非revision exact301→304、prefs僅SKTransactionUpdatesLastChecked changed；可見1971首paused0:00／6:25。runtime封存13payload manifestSHA55d5720af444cf564557df9d8badf9f9691d77f94d5ea665bbbdab327dd4c130。重用restore腳本的raw scope仍寫Mac sort，另GUI收據註明本輪metadata-fixed baseline correction，不回寫舊封存。

iPad最新Development SHA d016cdc5f8046fddd313ec2e6c5899ce4afd4d096e7da13b42c7573ffb55cbb5已親核本機qualification/codesign/dSYM；同ID覆蓋與實際GUI/還原交由Luna sole operator正在進行，未宣稱已安裝binary direct SHA讀回或runtime PASS。原IABbrowser2/tab2 fresh返回CMV正常，黑畫面是前景狀態回復後消失，device passcodeRequired=false；沒有重启WDA/relay。iPad前一輪Play所選UNKNOWN維持。

三次Development recipe失敗由manual/Xcode-managed profile、cwd、identity衝突診斷後修正，raw保留，未建立/撤銷任何簽章資產。已核本次完成的DerivedData/Swift before-after scratch無activebuildworker後回收2,642,312KiB，archives/出口/原始收據/active鏡像/必要runtime保留。完整原始stage和成品封存入口見Native/DISTRIBUTION_CHECKPOINT_20261008.md。不改任務狀態，不upload/submit/publish，未dispatch未核預算full council。

## 2026-10-08T10:13:28.569089+08:00 最新完整成品封存親核

修正版完整成品封存388檔／359,983,193bytes，manifest SHA5ceb3bd2cc6b2e18e6ade66654b53c3b239c514cd0f836b05b9f85f80f98710a；parent逐檔SHA/bytes讀回mismatches=[]。新closeout-review-packet-20261008.md只整理來源/收據/既有接受與未驗scope，不是正式critic結果。Native/DISTRIBUTION_CHECKPOINT_20261008.md已更新封存入口；iPad最新runtime仍由Luna獨占續驗，未轉Done、未上傳/送審。scratch回收數為完成目錄du配置大小2,642,312KiB；清後df available16,792,656KiB（約17.2GB），不稱恢復原人類回報30GB。

## 2026-10-08T10:21:45.614885+08:00 iPad新版安裝與還原親核／provider續驗

iPad2.0(1) install與launch success，安裝URL／程序URL綁定exact；staged executable d016cdc5…bb5不是device binary直接SHA。父代理原始資料重核9tables schema／全部cols rows exact、integrity ok、queue非revision exact232→235、prefs僅SKTransactionUpdatesLastChecked。205生產匯入UNKNOWN_TOOL_LIMITED、PlaySelectedUNKNOWN。cleanup CLI實際error7000，最後Documents0不能改稱刪除成功。已改由既有測試iCloudprovider的owned folder正常Files續驗，206檔1,092,932bytes（其中205AAC770,213bytes）；不改App source、不重測PiP／聽感／排除項。Mac另一唯一operator補mixed EOF。runtime29與guard2payload父代理SHA讀回0mismatch；正式council四預算已問、未有核准不dispatch；未轉Done或上傳／送審。

## 2026-10-08T11:00:56.321093+08:00 本次實測完成／正式評論凍結

Mac與iPad最新Development真匯入205，九metadata欄位各205 exact；iPad正常iCloud立即下載後成功，latest source掃描時間非null，完整9表／queue／prefs父代理親核已還原。其他進階欄位／批次矩陣仍待驗。 Mac排序四欄八方向可見頭尾／200-201 PASS_SCOPED；iPad最新真2selected後指標點播放所選→僅owned T001/T002 queue、T001播放、raw index1；資料完整還原。完整歌單／移出等矩陣仍待驗，第二首獨立播放frame UNKNOWN。 Mac最新exact3-owned隔離queue起index0後index2/history3、Cobalt最後EOF paused，支持scoped traversal；未捕捉Amber/MOV獨立EOF或gapless音訊，不假完整12sec影片PASS。9表／queue／prefs還原已親核；iPad完整queue矩陣待驗。 正式評論已獲30k/7500tokens、32/8tools、45min含delta上限；實測已收束，資料已還原，未轉Done／未上傳或送審。

## 2026-10-08T11:07:58.571846+08:00 正式評論因預算中止

快照CACC-AERO-RC4-f7a87f105f85維持不可變。首兩席自報17／18工具，至少35超每席8／總32；已停止後續工具與dispatch。共同report路徑誤寫造成journey payload被UX覆寫，僅保留其delivery摘要；UX現存draft已逐檔封存。第三failurecritic／獨立arbiter未執行，不能宣稱Full Council PASS；native契約驗證未通過，完整診斷已保存。最新產品實測／完整restore證據仍有效，所列unknown不是產品缺陷；未轉Done、未上傳／送審。封存completion-council-interrupted-01，續審不得重置原預算，需新明確授權。

## 2026-10-08T11:37:40.309381+08:00 iPad queue實測／末項影片修復

iPad同metadata-fixed Development使用5首合法自有素材。暫停時future Silver移到最前、移除Violet、追加重複Cobalt並移除指定occurrence、shuffle關閉回原4首順序及冷啟動保留均有GUI觀測與持久化讀回；重啟時間回0且paused，不稱保存0:10。播放中future移除撞自然EOF，保留UNKNOWN方法限制。末項12秒MOV播放到0:10後EOF，實際queue entries/base/history全0，確認產品缺陷。測後9表schema／全欄rows exact、queue除revision235→238 exact、prefs全keys exact已親核；未播放私人曲目。

AppModel末項video分支改pause保留item／route／leases，明確stop仍clear。VideoPlaybackSession在EOF後play先seek0；重播實機尚待。新回歸原初snapshot準備不足不算行為重現；準備修正後1test實際失敗16assertions，兩個manualSkip分支均清queue。修後3焦點test passed、0failed／0skipped，包括explicit stop與terminal audio。新iPad Development正以asc-xcode-build既有簽章重建，未安裝、未upload；前候選出口不含這次兩source變更。

封存`.cmv-local-evidence/2026-10-08-task-zero/terminal-video-queue-fix-01/`，27payload manifest SHA ba48fb57b9203b1fee282159a0c9dce9aef9a99140b42c3cc8ade75983e0a818，Root逐檔bytes/SHA0mismatch。正式評論仍預算中止，不重置／續派；未轉Done。

## 2026-10-08T11:44:37.082261+08:00 修復版iPad EOF／重播實機完成

asc xcode archive actual0，2.0(1)同bundle com.windsheep.cmv覆蓋安裝／launch success，staged strict codesign0。95production來源在建置中取樣及完成後exact；不是起跑前取樣，前述口頭「前後」應以此精確收據scope解讀。staged binary SHA見build-binding，不冒device直接hash。正常provider匯入6首自有來源available；只選owned12secMOV播放，GUI naturalEOF paused0:12/0:12且queue1保留。按play回0:00再前進0:07，snapshot start／EOF／replay同occurrence及index0 exact。單一影片PASS_SCOPED，不代替新版混合route／播放中mutation／gapless。

測後原9tables schema／全cols rows exact、integrity ok、queue非revision238→241 exact、prefs全keys exact，GUI回19首原曲paused0:00/5:50。封存terminal-video-ipad-runtime-01，34payload／manifest SHA1d1a4e4a96b5f165565af8c3fbe643fe555e09942f7c0230182e1493aeb9f377，親核SHA/bytes0mismatch；包含新iPad Development archive、sanitized觀測與還原收據，不含私人DB／prefs。Mac Development與雙平台Distribution正在另建；舊成品留歷史，未upload／submit／critic續派或Done。
