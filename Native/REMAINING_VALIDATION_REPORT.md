# CMV 剩餘驗收公開報告

2026-10-07 01:53 最新權威 checkpoint（取代以下較早的 build pending／PiP return unknown；維持 Review）

最終 Main 為 source audit v8 的117檔，audit SHA 0da7c6296b1adba69caf722024a8512b7714b1b7860dd45f487bc38622b7bffa。Mac／iPad 最後 build actual0，strict/deep 簽章、五份 plist 所有鍵值、ZIP逐檔SHA／CRC與三張有效Sky素材非零尺寸均通過；兩端同Main bundle已安裝啟動。Mac binary 505021de01f4c52ff60ccfa0c07e5504881808bc5d90b0194586291a454e065e；iPad binary 6ba80bb96f7daa948af35b76e6bbe1f4b406584331fcb4e262d624c3b1fb3432。五個已驗程式檔已guarded promotion，workspace117來源SHA逐檔exact，未stage／commit／發布。

背景漏包修復已由兩端實際CUA畫面確認；使用者核准縮薄與透明，header44pt／左右20pt、opacity0.18，PlayerBar cover44／spacing2／padding6且控制44pt。右欄隱藏時搜尋clear X曾錯觸UpNext；最終將兩個面板按鈕並排左側，Mac日文搜尋5→清除200、iPad cobalt搜尋1→清除46，右欄仍Hidden，真觸控回歸通過。保留ReduceTransparency不透明分支。兩張不可達SkyEmeraldAurora／SkySaturnOrbit（201716bytes）先SHA exact备份再移除；SkyAmberDawn／SkyCrimsonNebula／SkyMilkyWayDepth仍打包，羊羊主題使用SheepStorybook，不刪其素材。

Mac最後交付前後9表全欄列exact，1980曲／114來源／0歌單，queue1962／cur59／hist24除revision277→280全同，amberDawn保存。iPad交付前後9表exact，204曲／7來源／0歌單、收藏0，原25／base25／cur13／hist5除revision73→76全同，使用者選的emeraldAurora保存。PiP4後另核對SQLite含WAL：僅兩首owned測試曲之playcount／lastPlayed／Z_OPT及CoreData記帳改動，非測試曲無新增／刪除／變更；原25除revision76→64全欄位相同。不能用相同DB main檔SHA忽略不同WAL。

PiP4實際 native minimize→Home→PiP返回全螢幕，返回前後1:02／3:00保持，Play後進度2:54；guarded original25還原actual0，fresh XML為會いたい、Play、Original、0:00／5:14。Home的foreground transition guard拒絕屬預期防護，screen-only重新觀察後才點返回，未弱化guard。首次portrait命名capture實際1180×820，不能當直向證據；先前slim版直向四tab證據保留，最後117版只記已觀察範圍。

Core107 tests／2 skipped／0 failures actual0；50k QA4b暖樣本58.870–141.594ms、45started／16published／0stale已驗，冷4.735／4.691秒依使用者接受；QA5未採用，不冒稱硬體全50k IDs/order或p95通過。影片13音效production session與seek／pause／resume／stop皆有限PASS，完整聽感／音訊路由／lease／slow NAS／meter與VoiceOver完整朗讀焦點仍UNKNOWN；iPad10GiB容量TOOL_LIMITED，全斷網／AirPlay／Bluetooth為USER_EXCLUDED。Pro由「Pro購買功能結案」獨立負責。

正式council沿用sealed limited紀錄；工程Luna核對不是formal closure，最後117來源尚無四席final-snapshot closure，不標Done或整體App Store ready。原超額仲裁與失敗收據保留。新證據將封存到main-final-background-cleanup-checkpoint-20261007.tar.gz；精確SHA與cleanup結果依旁附receipt／v16 checkpoint。


2026-10-07 00:55 最新背景修復進行中：使用者回報 Mac／iPad 背景皆消失。root 已確認隔離來源五個 Sky imageset 只含 Contents.json，缺被引用的 HEIC；舊交付 Mac Assets.car 的 assetutil actual0 列出 7 個資產且沒有任何 Sky 背景。已從 workspace SHA exact 補回 5 張原圖，新增所有 imageset filename 引用存在性與 SHA 檢查。source audit v6 actual0，實際121檔＝歷史114＋2既有Rust fixtures＋5漏包背景；仍僅5個程式碼修改。使用者核准縮薄＋更透明已套入隔離候選：header 0.18、PlayerBar spacing2／padding6／cover44，44pt控制與 ReduceTransparency 不透明分支保留。兩端 incremental build 進行中，尚未交付背景修正版，不宣稱視覺通過。已交付前版兩端資料保存：Mac1980／114、iPad204／7及原25全表exact；新GUI月島／cobalt搜尋成功，一次語意中心重開焦點失敗保留。正式整體仍 Review。

2026-10-07 00:17 最新權威進度：使用者確認整條上下工具列對齊，候選採左右20pt／滿寬，保留高度、材質與播放控制；root audit確認實際116 source files、5 code modifications＋2既有workspace fixtures，工作區程式碼尚未覆蓋。先前hit-test版Mac編譯通過並凍結；對齊版兩端建置進行中，尚未交付、不宣稱搜尋焦點或版面PASS。更新前Mac完整app／Support／偏好SHA exact、SQLite完整性ok、1980 tracks／114 sources與原1962 queue保存；iPad guarded stop／copy／relaunch通過，204／7／0與原25 queue保存。NAS上SQLite首次回讀失敗保留，SHA相同本機副本通過；備份PASS不等於新版交付PASS。正式審查仍limited／Review，斷網依使用者排除。

2026-10-06 21:15 已恢復遙控並实际CUA操作。Main launch／copy actual0，原25/base25/current13/history5除revision全欄一致，fresh XML與畫面Original、Play、0:00/5:14；當前重新安裝自有3首fixture補驗Main音效，最終仍需還原。QA namespace備份、QA2安裝與flag launch actual0；14.616秒iPad production session診斷13 modes逐個supported/processed/advancing、12非原音wet增量，seek/pause/resume/stop通過，timer405→405/errors0，root獨立事件核對PASS_SCOPED。4暖查詢54.302/72.874/119.884/134.315ms均<=150，中文12500／歌手19215完整候選、首200發布；61started、10published無stale publication。冷final query3242.827ms與清空170.059ms超標保留，不列整體效能PASS、不promotion Main。

2026-10-06 21:08 容量基準更正：使用者確認本次開工前可用空間為33GB（本人回報，非本輪工具量測）。當次df約1.34GiB，swap使用9480.50MiB，不能把整體差額歸因於本輪檔案。已確認無編譯程序占用，且QA2成品binary／ZIP雜湊與封存一致後，僅清理本輪完成的QA DerivedData／cargo-target合計365380KiB；df可用1403236→1743912KiB，約1.66GiB。原始碼、成品、失敗紀錄與證據保留，其他專案模擬器及系統swap未動。

2026-10-06 20:48 本機準備完成：隔離 QA artifact2（flag-only影片診斷）actual build／sign／strict均0，raw5plist與ZIP逐檔bytes／CRC回讀通過，binary `b902805c…f96c`／ZIP `b0a0c6fd…cbb7`；11MB合成fixture SHAe227…b1c已確認在Bundle，driver SHAeffc…055c。未部署、未跑iPad，不能列硬體PASS。artifact1專用原probe量50k搜尋，artifact2專用全13 mode實際tap／timer／seek／pause／resume／stop診斷；共享Main與Pro來源及資料均未變更。等待本人重啟／解鎖，優先完成Main原25 postlaunch回讀，再backup QA50k namespace後部署。

2026-10-06 20:38 最新裝置狀態：WDA 自有 recovery 一度 ready=true，建立控制 session 時 runner 被 signal kill，actual xcodebuild exit65／relay startup exit1；原服務42968先前已不存在，未終止其他任務程序。停止 Main 後原25 queue 已逐位元回讀 exact（SHA919079…df5），後續 launch 因 Locked actual exit1，故僅 PASS_STOPPED_ORIGINAL25_BYTES，不列 postlaunch PASS，也未重驗目前音效偏好。已請本人重開 iPad 並解鎖，未再盲重啟。新版50k QA artifact1 binary7caba8…ba61／ZIP0eb7b0…fd38，本地 root source119SHA／raw5plist／strictsign0／ZIPCRC PASS，尚未部署、性能尚未實測；artifact2加入flag-only影片完整session診斷，獨立建置續行。工程Bridge片段評論由trajectory實際DONE＋兩marker核對，接受13count guard／duration tolerance強化，巢狀函式宣告順序編譯錯說法以hostactualcompile0反證；它不替代正式council。

2026-10-06 20:14 追加 Mac host 真 production VideoPlaybackSession 診斷：`root-final-receipt.json` SHA `216b4498…6120`，實際 compile/run exit0、15.488秒；13 presets逐個supported／processed／clock advancing，12非原音要求各自wet counter增加（custom設定含reverb52/delay262.6/bass3）；seek／pause／resume／stop通過，停止前後Timer412／412、errors0。完整class／observer與frozen114對照只計數器/accessors，CMVCore sources逐檔exact。這是Mac host有限診斷，不代替iPad13模式GUI、聽感、iOS音訊session或歷史0/3 XCTest。舊5.248秒guard不足與root第一輪readiness太早exit3均保留。自有Swift scratch已清理。

2026-10-06 20:12 最新補驗：postcouncil 字體已由 raw XML 確認 Larger OFF 0／Slider 67%；native Cancel 關閉曾誤開的 Remove 確認，未執行 Remove。postcouncil 唯讀 Support 全表／欄／列與 post-rapid baseline 相同、204 tracks／7 sources／0 playlists，queue 原25除revision全同；不把誤點算 Deselect 成功。隨後僅安装已封存 owned3 影片 fixture，進行13模式GUI補驗，WDA已回 Connection refused；目前queue fixture仍待後續還原，不能引用先前paused原25圖當目前狀態。服務診斷進行中；未送達觸控不算通過或防鎖。隔離50k效能候選已讀回8份rawlog SHA與Swift正規化相同／Rust production無差異，106 Swift／25 Rust及新增20,005筆test通過；仍待同probe iPad≤150ms，未promotion。正式council維持limited／Review。

日期：2026-10-06（延續 10-05 驗收）。本文只引用本輪私有收據的檔名與結果，不列帳號、裝置識別、憑證、私人 URL 或使用者 clip。Pro／StoreKit、Distribution、TestFlight 與商店審查維持既有 gate，不在本報告改判。

## 最新 2026-10-06 checkpoint（進行中，未結案）

本段是目前唯一權威摘要：fixed2 成品 e288／aecc 已雙安裝；post-rapid root 唯讀核對為 queue 除 revision 外 exact 25／base25／current13／history5，SQLite 不列全欄列 exact，204 tracks／7 sources／0 playlists 保持，僅 3-track playcount／lastPlayed／Z_OPT 與 CoreData history／bookkeeping 改動。Mac actual GUI 只記 scoped：Listen Now→LibraryList→Small→selection 0→1→0→List→Listen Now、paused Original；iPad actual GUI 只記 scoped：fontmax toolbar reachability、narrow four-tab navigation、native Zoom MAX 與 Main paused 0:00／5:14 Original，字體還原已由 postcouncil raw readback 確認 OFF0／67%，範圍證據見本頁最新補驗。圖像評論指出 scrolled BatchEdit title 位於 nav 下；最新 100% 實機微調捲動 counter image 中，原 Batch Edit Info 與 Deselect 均完整可見，最後 1 call 的獨立 visual 僅部分反證永久不可達，root／arbiter 不先定性為全域 defect 或 PASS。正式審查為 limited，chair record receipt `AERO-PQ41-cmv-final-20261006-13b10557bc0a.json`；3blind flow／visual／failure 各累積 6，原 arbiter 9／6 超額回合 `INADMISSIBLE` 保留為歷史。使用者已核准 replacement 3k／6 calls／10 min 取代 arbiter 累積 4 calls，但 token usage 未實際計數，不宣稱 exact quota compliance；review reports 已封存。D raw fixed2 install success 並 continuation launch success。維持 Review（非 Done）；performance FAIL、capacity `TOOL_LIMITED`、full VoiceOver／full wet／slow NAS 仍未知。

e288 rapid EOF receipt `qa-completion-navigation-ipad-rapid-eof-scoped-verdict-20261006.json` 為 `PASS_SCOPED_IPAD_NEAR_EOF_QUEUE_SELECTION`：paused video 2:50／3:00→Play→Next 後 terminal audio 仍 playing 0:27／0:54；另一段 video slider 2:44／3:00→Play→明確選第一首 queue track，跨前一段 video EOF 後 audio 仍由 0:09→0:39／3:00 playing。這是有限 near-EOF cases，不是 exhaustive subsecond race、慢 NAS／meter full matrix 或 listening PASS。

post-rapid preservation 的 `final-receipt.json` 為唯讀核對，queue 除 revision 外 exact 25／base25／current13／history5；SQLite 不可寫成 post-rapid 全欄列 exact：完整 204 tracks／7 sources／0 playlists 保持，差異限 3-track 的 playcount／lastPlayed／Z_OPT 與 CoreData history／bookkeeping，屬允許差異且不代表資料遺失。new native product tap receipt `product-tap-pipeline-receipt.json` 僅為 standalone partial diagnostic：13 是 wet buffers，不是 13 presets；final item 仍 unknown，歷史 0／3 probe failure 不洗白。正式審查 chair record 為 limited，reports 已封存；3blind flow／visual／failure 各 6，原 arbiter 9／6 超額為 `INADMISSIBLE`，replacement 3k／6 calls／10 min 已核准但 token usage 未實際計數。known performance FAIL、capacity `TOOL_LIMITED`、full VoiceOver／full wet／slow NAS 仍未知，維持 Review。

fixed2 後的最新 iPad scoped receipts：`qa-completion-navigation-ipad-fontmax-scoped-verdict-20261006.json` 為 `PASS_SCOPED_FONTMAX_TOOLBAR_REACHABILITY`（landscape Sort menu、selection 0→1→0、批次列垂直捲到底部）；`qa-completion-navigation-ipad-narrow-scoped-verdict-20261006.json` 為 `PASS_SCOPED_NARROW_FOUR_TAB_NAVIGATION`（Listen→Playlist→Settings→Library、AllTracks push/back、MiniPlayer sheet open／向下 dismiss、四 tabs 恢復）。narrow 僅有 SpringBoard XML，不能升格完整 accessibility focus PASS。

### 歷史 pre-final data-after-GUI checkpoint（已由最新 scoped receipts 更新）

font restore raw `qa-completion-navigation-ipad-font-restored-20261006.xml` 讀回 LargerSwitch 0、unnamed Slider 67%；window native Zoom 已回 MAX，Main restored `qa-completion-navigation-ipad-restored-main-20261006.png`／`.xml` 回讀 paused 0:00／5:14 Original。當時 data-after-GUI 仍在唯讀核對、formal 審查尚未開始；該段保留為歷史，不覆寫目前 council 3 份 sealed review 進行中的狀態。已知 50k performance FAIL、capacity `TOOL_LIMITED`、AVPlayer probe `UNKNOWN`，整體維持 Review。

v6 live helper 使用 `ipad_remote_v6.py`，Python SHA `ac205aba89006867361a941905a9f2f29e8bc259946103e76c95c2b5e301c1c2`、HTML SHA `e1da5e2b33cd376e4ba7528564c20f4c9672c8d2c9baa221fb1eb1d5d0e2e1ba`；v5 保留為歷史入口，guards 全部保留。default-off checkbox 的 VoiceOver 雙點模式只把 image tap 切為 WDA `doubleTap`；root actual mocks py／node exit 0，CUA 實際 doubleTap 1 次 Library→Listen，回讀 paused 0:00／5:14。

VoiceOver fresh Settings 綠色 ON 首次提示→Use VoiceOver→Main 單點 Library、雙點 Listen→Settings 仍綠色 ON→actual toggle OFF，source `Switch` value 0。綠色 ON 僅是 visual；ON source 沒有 Switch、只有 Cell，不能編造 value 1 或完整焦點／朗讀 PASS，仍為 `UNKNOWN_CAPABILITY`；OFF 有精確 raw 0。receipts：`qa-completion-v6-voiceover-on-readback-20261006.xml`、`qa-completion-v6-voiceover-on-after-main-20261006.xml`、`qa-completion-v6-voiceover-main-doubletap-listen-20261006.xml`、`qa-completion-v6-voiceover-restored-off-20261006.xml`（各自同 tag 的 `.png`／`.json` 亦保留）。

### 歷史 build pending checkpoint（已由 fixed2 更新）

Source114 新 manifest `339650…348d` 與 RootView `0e7…`／LibraryViews `e567bc…` 已凍結；前一階段 Mac／iPad final raw `BUILD SUCCEEDED` 仍不等於 artifact PASS。新 Mac raw plistlib preflight actual exit 1：3 份 `InfoPlist.strings` 是 UTF16LE bytes 但 XML 宣告 UTF8，builder plistlib count=1 漏列 `.strings`；failed ZIP 與 `qa-completion-navigation-root-mac-attempt1-failed.json` 保留，workerfix2 variant／signZIP 進行中。

fixed2 Mac `aecc…`／iPad `e288…` 成品已實際安裝。Mac delivery receipt：`qa-completion-a11y-navigation-mac-delivery.json`；GUI Listen Now→LibraryList→Small→selection 0→1→0→List→Listen Now、paused Original 根操作完成；Support SQLite 全表／欄／列 exact，receipt：`qa-completion-navigation-mac-sqlite-independent-20261006.json`。iPad delivery receipt `delivery-receipt-complete.json` 為 admin PASS（delivery scope）；獨立保存 receipt `cmv-navigation-independent-preservation-20261006.json` 回讀 SQLite 204／7／0、queue/base 25、current 13、history 5（除 revision 外 exact）、install／launch 0。

### 歷史 fixed2 UI pending checkpoint（已由最新 scoped receipts 更新）

iPad fixed2 MAX100／Larger ON 已實測，排序 menu 可開、批次列可垂直捲到底部；選取 1 後以 native Deselect 取消。曾有一次截圖座標誤開 Remove 確認，已 Cancel 且未移除，不能把首次點擊算成功。portrait／窄視窗與最終 restoration 仍待驗；v6 relay 已 live，VoiceOver 維持 scoped、非完整朗讀 PASS。formal approval 已核准但審查尚未啟動，使用量 0；整體維持 Review，不轉 Done。

追加小視窗診斷：root 從主畫面「曲庫」直接縮小到約 540pt，排除 MiniPlayer sheet 路徑後，仍看不到四個分頁；內容捲動與 All Tracks／返回可操作。已最小調整 `CompactRootView`，將底部播放器 inset 移到各個 NavigationStack，保留原生 tab bar 的 safe area；RootView SHA-256 `0e7ba5…22431`，與 LibraryViews `e567bc…708b4` 一同重新凍結建置。修補仍待實機驗證，不算窄窗 PASS。receipt：`qa-completion-stagemanager-scoped-observations-20261006.json`。

Mac binary `919679…72bcb` 的 ordinary runtime scope 為 PASS：ordinary 五欄縮圖、selection 0→1→0、track menu open→Cancel、List／Listen Now 還原、Main paused 0:00／6:25 originalSound 均已觀察；queue `1962`／current `59`／history `24` 除 revision 外全欄位相同，Support SQLite 精確保留 1,980 tracks／114 sources。receipt：`qa-completion-a11y-linear-mac-scoped-runtime-verdict.json`。水平 toolbar、portrait／narrow、VoiceOver、ReduceMotion、設定還原仍由 root 續測，不能升格為完整 A11y PASS。

iPad binary `9d123a641fdb2e8c1c1ef4a2cb74c24047c402d017bfaa2127d3f9f52851476c` 已完成 build，root preflight 僅為 `PASS_LOCAL_ARTIFACT_ONLY`；actual `devicectl install`／`launch` 均 exit 0。Support SQLite before／after 的所有 tables、columns、rows 均一致，精確保留 204 tracks／7 sources；original25 queue 除 revision 外所有欄位一致，`currentIndex=13`、`history=5`。證據 receipt：`final-ledger.json`、`scoped-verdict.json`、`queue-all-fields-comparison.json`、`sqlite-all-fields-comparison.json`。

root 已接回正常 HTTP IAB3／tab2 CUA。iPad 真實 Settings maxfont 100、portrait 單欄、selection 1→0、scroll 後完整 title／artist／album 與獨立 Play／menu 可見，menu opens→tap outside closes；這些目前只記為進行中的 iPad scoped GUI observations，等待 root 最終 GUI receipt。Larger Accessibility 已實際關閉、font 67% 已由 CUA 讀回（上一頁 raw 不作 slider 證明），最終 restoration verification 仍待完成。Reduce Motion OS 0→1→Main FX mode／Original／Done→OS 0 均已讀回，receipt：`qa-completion-a11y-linear-ipad-reduce-motion-scoped-verdict-20261006.json`，`PASS_SCOPED_REDUCE_MOTION_CONTROL_AND_RESTORE`。

VoiceOver 先前兩次 system overlay 嘗試均遭 foreground guard 拒絕的 receipt 保留為歷史；v6 actual toggle OFF 的 raw 0 仍不等於 VoiceOver 功能 PASS。Stage Manager 約 900pt 四 tabs、MusicLibrary／AllTracks／selection 1→0／TrackInfo Done 為 scoped；約 540pt 四 tabs 視覺消失（屬可捲動內容），目前僅有 SpringBoard source，診斷中不列 PASS；已實際 nativeWindow→Zoom restore MAX。LibraryViews 新修正 SHA `e567bc053b1cb45836659b046a2bbaed2131173a80e18e1a2ee9a86126f708b4` 的大字體 toolbar／batch 垂直 stack 雙平台 frozen build 進行中，尚未交付。先前 browser admin policy unavailable 僅屬歷史，不代表目前仍 blocked。formal approval 已核准，審查未開始，使用量 0（12k／seat 3k／tool 6／wall 20 min）；整體維持 Review，不轉 Done。

歷史 7cc scoped coverage 保留：controls／PiP 觀察回讀 reverb 52%、delay 262.6 ms、intensity 0、custom strength 76%，PiP clock 1:05→1:38，聽感 `UNKNOWN_CAPABILITY`；full3 natural video→terminal audio EOF 到 0:54／0:54，3 entries／base、current 2、history 2 與 occurrence IDs 保留；cold restart queue fields（除 revision）、IDs／history／base 保留，UI 0:00、0:54 total 且 paused。原25 safety restore 的 identity／process／stop／restore／readback／launch／after-support actual exit 全 0，stopped restore byte-identical，25／current13／history5 除 revision 外全欄位相同（53→55）。收據：`qa-completion-linear-ipad-effects-pip-observations.json`、`qa-completion-linear-ipad-natural-eof-verdict.json`、`qa-completion-linear-ipad-eof-cold-verdict.json`、`qa-completion-linear-ipad-original25-safety-restore-20261006-verdict.json`。

整體狀態仍為 Review：50k 整體 FAIL、容量 `TOOL_LIMITED`、聽感 `UNKNOWN`；network／AirPlay／Bluetooth 為 `USER_EXCLUDED`，Pro 鄰居 scope 不改判。VoiceOver、ReduceMotion、水平 toolbar、portrait／narrow 與 restoration 仍在測，勿宣稱全 PASS 或已 restore。

## 最新 iPad 線性候選事實（2026-10-05 10:13）

以下保留歷史 checkpoint；「待解鎖／尚未安裝」不代表現況。iPad 已解鎖、WDA ready，HTTP tab 接回且 CUA 已觸控 Main。linear same-source 114 candidate（binary SHA-256：`7cc5817c255cfacd1e104b51bfa57cf889ba1db025b64d067a275e3f333ca2b4`）已覆蓋安裝／launch；devicectl receipt outcome 為 success。數值 shell exit 未保存，記 **Unavailable**，不可補寫 exit 0。

`qa-completion-linear-ipad-delivery-root-readback.json` 顯示三份 DB file SHA 相同、204 tracks／7 sources／0 playlists；原25 queue 除 revision 外欄位全同（IDs、history、currentIndex 13、base、modes），revision 53→56。GUI 證據為 `qa-completion-linear-ipad-original25-postlaunch-ui.xml`、`.png`、`.json`，畫面 Play 0:00／5:14。

root 已 seed 自有 full3／current1；影片 clock 0:00→0:18→1:02→2:19，並在 2:19 暫停。custom、delay、reverb、intensity 0、wet PiP、EOF、accessibility 尚待驗，不能 PASS／完成。安裝前完整 backup 已保留。suffix guard 誤判另停止本輪自有 QA；`qa-completion-linear-ipad-delivery-command-ledger-correction.json` 已更正 App 身分，兩者資料未改，不能寫成「僅停止 Main」。QA cancel probe 已安裝並完成實機量測，150 ms 整體仍 FAIL，且未 promotion 到 Main；不可與新 Main 的 runtime 混用。

## iPad 停止狀態還原補記（2026-10-05 09:20）

在遙控失效／鎖定期間，CoreDevice 的資料讀寫仍可用。root 以 fresh app identity／exact executable／process guard，先備份測試佇列、只停止正式 Main，再寫回封存的原 25 項 queue；全部七步 exit 0，讀回整份檔案與原備份 byte-identical（entries/base=25、index13、history5）。此備份也與新 immutable envelope 的原25 entry相同。**PASS_SCOPED_STOPPED_FILE_ONLY**，尚未啟動、不宣稱畫面／paused／語意 post-launch 已驗；新版 iPad 尚未安裝。收據：`qa-completion-linear-wait-ipad-original25-verdict.json`。以下較早「最終還原未完成」已由此補記更新，但恢復服務後的新成品實機驗證及最後 post-launch 回讀仍待完成。

## 最新 Mac 驗收（2026-10-05 09:16；iPad 與正式審查仍待完成）

線性佇列修正版的同來源 114 檔與 focused source snapshot 一致，雙平台 Release／strict signing／架構／四份 raw plist／local qualification／ZIP 每檔 SHA、CRC 已由 root 獨立核對。第一版 Mac 三語檔的 UTF-16 bytes／UTF-8 XML 宣告不一致保留 FAIL_TOOL，另複製修正並重簽，未覆寫失敗成品。Mac binary `d1d4e9dedf0da8c6187b6e3119d20f23e7f32665df8a1ad1381930195322d5ac`；iPad binary `7cc5817c255cfacd1e104b51bfa57cf889ba1db025b64d067a275e3f333ca2b4`。iPad 尚未安裝，不列 iPad runtime PASS。

Mac 已安全備份並覆蓋桌面，冷啟動原 1962 項 queue 的 entries／baseEntries／currentIndex 59／history 24／modes／continuation **全部相同，包含 occurrence IDs**；1980 tracks、114 sources、playlist 的所有 DB 欄位一致。接著以自有三曲 cur1 影片從產品 Play 開始，暫停後原生 slider seek 至 172.958 秒，再續播至真實影片自然 EOF；自動接末首音訊，音訊亦自然播完，UI 保留三列，queue entries/base=3、index=2、原 IDs 與模式皆保留。再冷啟動仍 full3、index2、history 與 IDs 一致、0:00 暫停。這是 Mac GUI runtime，不是 mocked EOF，也不替代 iPad。

最後 Mac 已還原原 1962 項 queue，啟動後 ID／順序／位置／歷史／模式／continuation 全同，原曲 0:00 暫停與原音。1977 筆非本輪播放 fixture 的所有欄位一致，114 sources／playlist 亦全相同；三筆自有播放 fixture 的 play count／lastPlayedAt 允許本次播放變動。旁白、減少動態效果與設定頁面已還原。收據：`qa-completion-linear-mac-cold-restore-verdict.json`、`qa-completion-linear-mac-natural-eof-verdict.json`、`qa-completion-linear-mac-eof-cold-verdict.json`、`qa-completion-linear-mac-final-restore-verdict.json`。

iPad 自動化模式仍失敗且後續已自動鎖定，等待本人重啟／解鎖；原25備份安全、最終還原未完成。剩餘新成品 EOF、custom delay/reverb/零強度、wet PiP、完整 accessibility／Dynamic Type／Stage Manager 尚待驗。正式評論尚未開始，已核准預算完整保留。以下較早的續測狀態為歷史 checkpoint。

## 目前續測（2026-10-05；佇列補強與自動化恢復，尚未結案）

同來源修復版已完成 Mac／iPad 建置、簽章、本機 preflight 與實際覆蓋。曲庫全欄位核對：Mac 1980 筆／114 來源、iPad 204 筆／7 來源，metadata、排除、評分、最愛、歌單皆保留；Mac UI 1971 為原有 9 筆 excluded。iPad 原始 25 項佇列保留備份，當前是自有測試佇列，最終還原仍待執行。

Mac 自製 180 秒影片已驗音效切換、原音比較、自訂六參數、暫停／playing seek／standalone EOF，未重現低音回呼崩潰。iPad 已驗低音、人聲、電子、八場景、自訂部分參數、原音比較與暫停 seek；影片時鐘前進。原音 playing PiP 實際出現在主畫面，返回 App clock 為 2:38。完整 wet PiP、iPad delay／reverb／零強度及主觀音質仍未通過。逐項記錄：`qa-completion-fixed-main-runtime-observations.json`。

cold restore 從三項佇列中段影片自然播放至末首 audio EOF，實際保存與 UI 縮成一項；Mac cold restore 的 1962 項 track 順序、current 59／history 24 保留，但 occurrence IDs 全部重建。修正已補完整 UI route 與 occurrence identity，線性 helper 修正後，整組 focused reliability **8 tests／0 failure／exit 0** 已由 root 原始 log 與 source snapshot 核對；此為 callback scope，不能替代實機自然 EOF。交付審查又發現 helper 的反覆陣列移除為 O(n²)，已改成線性 ordinal pool 並重驗。新增測試最初錯誤假設 manual reorder 不改 base order，失敗已保留；修正此預期後仍驗證 duplicate occurrence identity。第一版 Mac build 成功但暫不交付；新同來源雙平台成品建置中，實機驗收仍待執行。

五萬首搜尋取消診斷版已獨立安裝並實際操作。冷單筆查詢 **3130.617 ms**，candidates await 約 **3097.224 ms**；暖單筆 **61.217／81.188 ms** 達 150 ms，暖中文 **162.895 ms**、英文歌手 **243.207 ms** 未達標。結果與原生畫面相符；取消 guard 跳過 stale downstream work，但 candidate await 仍完成。保持原本 AND／OR 查詢語意，**未 promotion 到正式 Main、不宣稱整體效能通過**。收據：`qa-completion-qa-cancel-probe-runtime-warm-final-verdict.json`。iPad 10 GiB 為 TOOL_LIMITED、建立檔數 0；Mac SMB 10 GiB 維持既有 scope PASS。

Mac 減少動態效果實際 off→on→off，音效面板開啟、音色切換、reset 與關閉可操作；只列 controls scope，不冒稱所有動畫停用。旁白實際啟動與首次提示已操作，但工具無法觀察語音／游標，字幕支援 App 亦 timeout，故 **TOOL_LIMITED**；系統旁白已還原關閉、字幕原設定未改。收據：`qa-completion-fixed-mac-accessibility-controls.json`。

iPad 仍解鎖時 WDA 結束；一次 guarded 重啟仍 exit 65、`Timed out while enabling automation mode`。relay 網頁可達，WDA port 拒絕連線，屬服務故障，不當作 App crash 或重新鎖定。已請使用者重啟並解鎖；在外部狀態改變前不盲目重試。稍後 lockState 已為 passcodeRequired=true，遙控失效後無法送達 keep-awake touch；仍需本人處理。剩餘 iPad accessibility／Dynamic Type／Stage Manager 與新成品 EOF 驗收需恢復服務。正式評論額度已核准、尚未 dispatch；原佇列還原與凍結證據後再審查，任務維持 Review。

## 最新實機補驗（2026-10-05 07:15）

QA v5 已安裝並實際操作，五萬首四個指定查詢的結果與原生畫面相符。queryStart→state publish 分別為冷啟動 3327.256 ms、尾端單筆 121.638 ms、中文 162.092 ms、英文歌手 300.851 ms；150 ms 僅尾端單筆通過。取消中的舊 generation 沒有發布舊結果，但仍完成 repository work，不宣稱快速取消或 compositor PASS。

iPad 10 GiB 容量工具回報 TOOL_LIMITED：Foundation preflight 可用 3.947 GiB，POSIX 可用 1.926 GiB，低於 14 GiB 保護門檻；測試檔數為零，無此輪容量檔需清理。Mac／SMB 10 GiB PASS_SCOPED 保留，兩者不可混用。收據：`qa-completion-qa5-capacity-root-verdict.json`。

影片背景回呼修復的 14 項 Core 測試、0 fail 已由 root 核對原始輸出。Mac 原生影片選擇器修復的第一輪建置失敗已保存，原因為 conditional compilation 與 SwiftUI modifier 連接，已最小修正並重建。新版實機影片音效、PiP 與最終交付仍待驗，正式評論尚未開始。

## 最新續測狀態（2026-10-05 06:47；影片音效崩潰正在修復）

本節取代下方「待解鎖」狀態。本輪仍在執行，尚未正式完成評論或結案。

- Mac v3 Main 已覆蓋桌面並實際啟動；1,972 筆曲目、113 來源與 14 個 metadata 欄位完全保留。cold restore 依既有規則移除一項預先 excluded occurrence，queue 1,963→1,962、history 25→24；剩餘順序、current、模式與 continuation 相同，不宣稱整份佇列逐位元不變。收據：`qa-completion-resume-independent-verification.json`。
- 原生 no-tap 四案與 bare-tap 三案均 ready／playing、時鐘前進；play-before-install 時序疑點未在 bare-tap 重現。這些結果不替代產品影片音效驗收。
- Mac 自製 180 秒影片實际原音 clock 1→9→21 秒，音效路由顯示可用；選擇低音增強後 **FAIL_CRASH**。崩潰堆疊定位到 `CMVVideoAudioEffectsRenderer.prepare` 的 AVAudioSourceNode callback，非主執行緒觸發 Swift MainActor executor assertion。修復與背景 wet-render 回歸正在進行，不把原 13 項主執行緒測試當作此缺陷已涵蓋。收據：`qa-completion-mac-video-bass-crash.ips`。
- Mac「開啟影片」未呈現選擇器；Root「加入音樂來源」正常匯入自製 Source-B 八檔。此匯入問題另行最小修復，新增的測試來源與原資料分別追蹤。
- iPad 已解鎖、WDA／relay 重啟；瀏覽器曾停在 data: 連線錯誤頁而被政策拒絕，經使用者手動重新開啟後以 CUA 接回，已送達實際 Listen Now 操作。原 25 項 queue 停止時整份備份相同；啟動後 entries／base／history／index／shuffle／repeat 語意全部相同，UI 顯示 Play（暫停）。收據：`qa-completion-original25-postlaunch-verdict.json`。
- 最新 QA v5 已做安裝前資料備份，安裝與 50k／容量回歸正在進行。影片修復版 Main 尚未建置／交付；正式評論仍未開始。

## 目前續測狀態（2026-10-05；新版成品已核對，實機待解鎖）

本節取代下方歷史候選的「最後還原／清理」描述；本輪仍在執行，尚未正式結案或完成評論。Pro 專項維持既有 Done。

- 主 App 曲庫目前為 204 tracks／7 sources；原始 183 筆 ID、九個 metadata 欄位、最愛與評分已由唯讀安裝前後比對確認保留。原始 25 項 queue 備份仍保留；本次續測目前使用三項自製 audio/video route，**最終 25 項語意還原尚未執行**。收據：`qa-completion-consolidated-data-preservation.json`。
- 主 App 已安裝 consolidated candidate，iPad binary SHA-256：`8db5a876088a1c9b267e3f136539daaa533c863aedab032599f0bf3ba2e5070d`。新版進度條的 cold disabled、準備後播放、播放中 native seek、暫停 seek／resume 與實際 raw drag 已取得有限 PASS；早期未送達／拖曳未命中的嘗試仍保留為 INCONCLUSIVE。收據：`qa-completion-progress-consolidated-verdict.json`。這個 binary 尚未包含正在實作的影片音效。
- 修正 QA 的 ScrollView 與背景量測後，實機五萬首 queryStart→state publish：冷啟動指定單筆 `3408.007833 ms`、暖查詢尾端單筆 `95.857292 ms`、中文 `349.09625 ms`、英文多 token `161.42975 ms`。只有尾端單筆達 150 ms，其他不宣稱通過；不把 state publish 當 compositor 完成。30 ms debounce 與 Unicode shortcut 已有焦點測試，最新 QA 實機回歸尚待執行。
- 10 GiB NAS 容量測試 **PASS_SCOPED（Mac／SMB NAS）**：十個各 1 GiB 自製 WAV，production `FileOfflineCacheStore` prefetch 與完整 checksum 符合生成資料；trim 前 Smart logical／POSIX allocated 皆為 `10,737,418,240 bytes`，降額後 9 GiB Smart＋1 GiB Pinned，十首皆能解析、Pinned verify 與 checksum 保留。wall time `3567.78 s`（約 59 分 28 秒）。SMB 的 Foundation allocated-size 值與 POSIX `stat.st_blocks` 不一致，實體配置以後者獨立核對。收據：`qa-completion-capacity-preallocated-10g-root-verdict.json`、`qa-completion-capacity-preallocated-10g-before-trim-stat.json`。這不是 iPad runtime 或全斷網測試。
- iPad 的容量 QA 工具建檔／解碼／SHA／配額 assertions 已修正；v4 安裝前發現三語 plist 格式損壞，保留 FAIL_TOOL 收據。v5 的 binary、簽章、四份 plist 與三語 QA 名稱由 root 複查通過，尚未安裝，不列 runtime PASS：`qa-completion-50k-capacity-v5-root-preflight.json`。
- 使用者已核准「影片也能套用音效」實作及測試。Core isolated realtime manual-rendering renderer 的 13 項 AudioEffectsTests、0 fail 已驗，來源 hash 與收據一致；每個 preset fresh PCM、非中性 custom、原音 bitwise dry、零強度、mono／interleaved、finite／格式／frame limit／lifecycle 與實際 wet render counter 均涵蓋。收據：`qa-completion-video-effects-core-focused.json`。
- App focused tests **9 PASS／0 fail／0 skip（macOS arm64）**，root 已從 xcresult 獨立讀回並核對六個 owned source hash。涵蓋原音比較與保存設定／queue、neutral custom、舊 snapshot 的 CAS 不清掉新 pending、舊 prepared token 不增加 wet counter、新代次實際處理 512-frame PCM。這是 production context 的焦點驗證，不冒稱真正 AVPlayer native callback、iPad 聽感或 PiP 已驗。
- 同來源 Main Release 成品已完成：114 個來源檔案與工作區逐檔 hash 相符，只含 12 個核准 overlays；iPad arm64 binary `6108b4c5090ac8c4e49983ca098fef1c8a4a454bda9d82e7c226096ba2d886ee`、Mac universal（arm64／x86_64）v3 binary `1d91f0edfc7110cccefd77682b8f75253b85a439ec4d6cf83834a0d128087bed`。root 獨立核對嚴格簽章、架構、raw plist 解析、ZIP 每檔 SHA／CRC 與真正 `qualify-app-store.sh`，兩端本機 qualification exit 0。Mac v2 的 UTF-16 bytes／UTF-8 XML 宣告不一致已在 v3 成品修正並重簽，保留 FAIL_TOOL 歷史。收據：`qa-completion-main-root-verification.json`、`qa-completion-main-root-preflight-v2-failure.json`。**尚未安裝這版 iPad、尚未覆蓋桌面 App，不列 UI／聽感／Distribution PASS。**
- frozen source、Core／App focused evidence、容量證據與 Mac 1972 筆資料基準已封存為 `cmv-video-source-focused-capacity-checkpoint-20261005.tar.gz`；199 個 archive entries 逐檔讀回與 manifest 相符。兩端 Main ZIP 另行封存並核對。
- 真正 AVPlayer native callback 補驗為 **INCONCLUSIVE_FAILED_PROBE**：root 從原始 xcresult 讀回 0 PASS／3 FAIL／0 skip，9 assertions 失敗；播放時間停在 0、狀態 pending／waiting，未取得 native prepare／process 或 wet render 成功證據。未完成 no-tap baseline 與 ready/error 診斷，因此不能判定僅是鎖定環境限制，也不能列影片 runtime PASS。compiled test source 已重建並符合當時 hash，diagnostic variant 另保留；production 三個相關檔案 hash 一致。收據：`qa-completion-video-effects-app-real-avplayer-root-readback.json`。
- iPad 目前 `passcodeRequired=true`；桌面 CUA 亦回報 Mac 鎖定、無法自動解鎖。兩端 UI 驗收需要使用者本人解鎖，本機建置與檔案驗證繼續。QA 專輯搜尋中斷不列產品 crash，原 QA process 仍存活且指定 CMV/Jetsam crash inventory 為空。新一輪實機操作及最終資料還原要待解鎖。
- 正式三位獨立 Luna＋不同仲裁的評論額度已核准，尚未 dispatch；先完成驗證並凍結內容定址 snapshot。全斷網、AirPlay／Bluetooth 依使用者指示排除。
- 曾嘗試在鎖定期間先回復原始 queue；讀取測試 queue 的第一步遇到 CoreDevice error 4000／裝置服務斷線，**尚未停止、寫入或啟動 Main App**。保持原備份與待還原狀態，不盲目重試；收據：`qa-completion-final-stopped-queue-verdict.json`。本輪四個 Main build roots 已回收 allocated `1,137,549,312 bytes`；native probe 自有 scratch／runner 已清理。自己的 WDA host 已 exit 65，relay 用 SIGINT 結束、exit 130，兩個 PID 均不存在；其他程序未碰。遙控服務需解鎖後重啟，不能沿用頁面舊快照。

## 歷史已驗結果（依各自候選限定）

| 範圍 | 判定 | 實際涵蓋與證據 |
| --- | --- | --- |
| 50k metadata 與 production repository | PASS（合成資料） | 50,000 個唯一 ID、來源 A/B/C、虛構歌手／專輯／albumArtist／genre、中文／日文／emoji、長文字、缺欄位、同名不同 ID、501 以後分頁；production `applyScan`、來源／歌手／專輯／genre／Unicode 查詢與升降排序均有收據：`fixture-validation.json`、`fixture-production-contract.json`。 |
| Production contract | PASS，18 contracts | 全量計數、來源與虛構 artist group/search、缺值、重複 title 唯一 ID、offset 501／526 與排序；JSON 是 production API 輸入證據，不把 JSON 自我比對冒稱 runtime PASS。 |
| Rust workspace／50k 搜尋 | PASS | workspace tests 34、fmt、all-targets test、clippy `-D warnings` exit 0；10 queries 平均 25.287 ms、最慢 25.854 ms、peak RSS 10,092,544 bytes。這是 in-memory Rust scope，不是 iPad UI、NAS I/O 或 150 ms gate：`search-candidate-revision-3-rust-validation.json`。既有超過 150 ms 的 FAIL 收據保留。 |
| 原創實體媒體與 embedded tags | PASS（13/13 playable） | 12 AAC m4a＋1 H.264/AAC MOV，含 180 秒 audio、30 秒 video；Faults 另隔離兩個壞檔。`fixture-embedded-tags-validation.json` 存在且記錄 AVFoundation 讀回 title／artist／album／genre／releaseDate 為 13/13；track/disc 為 0/13，是容器限制，不冒稱 embedded tags 完整。 |
| Source-A／Source-B production import | PASS（13 media） | Source-A 6 檔與 Source-B 7 檔實機／production 回讀通過；baseline 183 筆加 13 檔後為 196 tracks。Source-A accepted track/disc 缺值與 Source-B metadata 收據：`metadata-candidate-source-a-verdict.json`、`metadata-candidate-ipad-rescan-verdict.json`。 |
| Faults | PASS（可恢復錯誤） | `damaged.m4a` 被跳過、indexing continues；unsupported `.bin` 不入列。Faults 匯入後仍 196 tracks、來源 7、Faults 0 tracks、既有 metadata／queue 保留：`metadata-candidate-faults-verdict.json`。 |
| metadata preservation | PASS（讀回範圍） | 190 candidate 安裝前後與 baseline 183 的 9 個 metadata 欄位差異皆 0，source identity、playlist 0、favorite／rating baseline 保留；Faults 後 196／7 sources 亦保留：`metadata-candidate-install-preservation-verdict.json`、`metadata-candidate-faults-verdict.json`。 |
| v3 歌單／一般 queue／SmartDJ／分析／metadata Apply-Undo | PASS（歷史範圍） | v3 borderless reorder、normal queue、SmartDJ、單曲聲學分析、metadata apply/undo 各有獨立收據；代表已驗範圍，不宣稱新版 binary 全部重測。Undo 比較的是 183 ID 與 9 metadata 欄位，不是整個 DB byte identical。 |
| source loss／Pinned | PASS（網路仍開） | source 檔移出 root 後，pinned copy checksum 一致，新版冷啟動仍播放至 0:16→1:02；這是 source unavailable retention 測試，`networkDisabled=false`，不代表 airplane／全斷網：`metadata-candidate-offline-source-loss-verdict.json`、`resume-long-pin-checksum-verdict.json`。 |
| Smart cache／Pinned 邊界 | 設計已確認，容量壓測 Review | Smart 與 Pinned 使用獨立根目錄，`smartBudgetBytes` 為 10 GiB；既有 pin/checksum 通過，但未完成 10 GiB 實機容量壓測：`resume-long-pin-checksum-verdict.json`。 |
| 背景／PiP | 有限 PASS | 180 秒音訊背景播放與 paused PiP 進入／返回有 evidence；playing PiP、鎖定、長時間負載與完整 mixed EOF 維持 Review：`resume-long-background-verdict.json`、`resume-pip-paused-verdict.json`。 |
| Mac SMB NAS 50k | PASS（Mac SMB scope） | production `IncrementalScanner`＋SwiftData persistent repository：published／available 50,000、missing／issues 0、offset 501 為 25；scanner wall time `2064.009899020195 s`（約 34 分 24 秒），`/usr/bin/time -l` max RSS `509,034,496` bytes。這些是觀察值，不推測耗時原因：`nas-physical-main-verification.json`、`luna-nas-physical-50k.json`。 |
| NAS 13 檔與 source loss | PASS（Mac harness） | initial／unchanged／own fixture remove／`sourceWasReachable=false` 階段 exit 0，來源不可達時保留資料；不是 iPad FileProvider、150 ms UI 或完整斷網：`luna-nas-physical-13.json`、`luna-nas-physical-final.md`。 |

## 本輪修復

- Rust 搜尋：未命中先返回，減少配置，同時保留 Unicode contextual lowercase 與空白正規化；34 tests 與合成核心 benchmark 通過。
- 歌單 row：三個按鈕使用 `.borderless`，避免同列上下移、播放、移除一起觸發；v3 實機 DB 與未變動 queue 已驗。
- Scanner：AAC／MOV 的格式 metadata 原本漏讀，改用 commonKey 與 Apple 格式 identifiers；專輯歌手優先於作者 fallback，實媒體測試 2 PASS／0 skip，13 檔 iPad 匯入回讀通過。
- 混合佇列：末段音樂原本丟掉完整 route 卻保留舊 base order，存檔被拒而留下空快照；修正末段 route 與清理邊界，production transition／store load focused tests 2 PASS／0 skip，實機三項末曲與冷啟動保存通過。

## 歷史 mixed candidate 與實機 runtime

final mixed candidate source 有 113 files，tree SHA-256 為 `011828a6e361a8afe47af503dc7a39347acb338915b99cbc86a25ba8ade56c81`；只 overlay `Native/CMV/CMV/AppModel.swift` 與 `Native/CMV/CMVProTests/AppModelReliabilityTests.swift`。iPad／Mac／Simulator 三平台 Release/local qualification exit 0；iPad binary SHA-256 為 `ab5abe0feccd287ba8f7a6d2491af35196655781e67a911261489c8fd563fddd`。`metadata-mixed-candidate-scoped-review.md` 是 scoped review，不是 formal `critic_full`：`metadata-mixed-candidate-summary.json`、`metadata-mixed-candidate-source-overlay.json`。

`metadata-mixed-candidate-runtime-verdict.json`／`.md` 的 readonly 收據確認：

- 第一輪 3-route 的首段長音訊與末段 Dream/audio 自然接續都有 UI／queue evidence；中間檔名為 `natural-video.xml`，但實際內容是 Dream/audio，沒有宣稱第一輪中間影片視覺 PASS。
- 另一輪 video→audio 有實際影片 PNG/XML：`Video`、原創圖案、0:08／0:30、`Pause`、`Return to Moon Ring`／`Done`；接著末段 audio 0:53／0:54 paused 與 cold restart 0:00／0:54 均保留 full3 `entries/baseEntries`、`currentIndex=2`、history、occurrence membership 與 modes。
- 第一輪 terminal EOF 後的單曲 `entries/baseEntries=1`、`index=0` 是合法終點 snapshot；不能解讀為 EOF 後仍保留 full3。這部分留實機行為定義，不回填成 mixed full3 PASS。

manual-skip 僅作診斷：`metadata-mixed-candidate-skip-*` 顯示 Return Moon Ring 後影片約 0:28，Next 動作被 fresh XPath／座標 guard 拒絕；沒有 manual EOF race PASS；未送達的動作不認定為產品故障。遠端 Slider 的 `isSeeking` stale 仍是疑點，尚未完成人工 native 驗證，不改 production。

## Fixture 與公開界線

使用者合成曲庫位置為 `/Volumes/MyGame/music/CMV-Validation-20261004/`：Source-A／Source-B 實體媒體、Source-C metadata、Faults 隔離；50k 是 metadata records，不是 50,000 份音訊。rich JSON、profiles、README 是 fictional fixture 附件，不代表 App 新增 bio feature。NAS physical 50k 使用合法 tiny AAC，payload `80,100,000` bytes（約 80.1 MB）；與 50k metadata JSON 的大小／用途分開記錄。

原創 fixture 的 13 media、196 tracks、7 sources、Faults、fictional artist group/search、source-loss retention 均依各自 evidence 分層；來源 loss 測試網路仍開，不能補稱全斷網。Smart 10 GiB 與 Pinned 獨立，但沒有容量壓測。公開報告只放 evidence 檔名與必要 hash，不放私有帳戶、裝置、憑證或私人 clip。

## Review 與尚未完成範圍

保留 v3 reorder、normal queue、SmartDJ、analyze、metadata Apply/Undo 的既有代表性收據，不假稱最新 candidate 全重測。VoiceOver 完整語音品質、Stage Manager 窄窗全矩陣、鎖定、iPad 50k 連續輸入 150 ms、Distribution 與 formal critic review 仍未驗。完全斷網已依使用者最新指示標為 `USER_EXCLUDED`，不列待驗；AirPlay／Bluetooth 依使用者指示排除；Pro 交易由隔壁專項結案，本輪不重評。

最後只還原原始 queue JSON，沒有覆寫曲庫 DB。冷啟動回讀為 25 entries／25 baseEntries／history 5、index 13、shuffle false、repeat off、paused；曲目與 base／history 順序與原備份一致，occurrence UUID 與 revision 正常重建，不宣稱 byte-identical。196 首與 7 來源仍保留，原始 183 首九個 metadata 欄位、最愛與評分差異均為 0，playlist 0、Pinned 0；見 `metadata-mixed-candidate-final-preservation-verdict.json`。新增的合成媒體／來源保留，播放與分析統計依本輪操作保留。

本輪 build／test 暫存回收約 2.70 GB，已獨立核對來源與三端成品 ZIP 的 SHA／CRC 並保留。自己的 Python relay 正常結束、WDA host 以 SIGINT 結束，兩個已確認 PID 均不存在；沒有終止其他任務程序。來源及 iPad／Mac App 保留供檢查，Simulator ZIP、NAS fixtures、持久化測試 store 與所有 device evidence 保留；見 `metadata-mixed-candidate-build-cleanup.json`、`metadata-mixed-candidate-runtime-cleanup.json`。

Antigravity Bridge 已依使用者授權提供 NAS 諮詢；當時協作者缺少檔案／shell 能力，其建議不作 runtime 證據。實際數值均以本輪本機與裝置收據為準。MissionCenter 已同步，doctor pass（舊任務 Passport 為既有 warning）、status stale=false；八個非 Pro 任務維持 Review。

## 10-05 續測 checkpoint

使用者已核准正式 critic_full：3 位獨立 Luna＋1 位不同仲裁，總 12,000 tokens、每席跨所有輪次 3,000 tokens、每席 6 工具、整體 20 分鐘；測試後凍結 snapshot 才 dispatch。完全斷網為 USER_EXCLUDED。操作方式已寫入 [MissionCenter iPad runbook](../MissionCenter/ipad-testing-runbook.md)。10 GiB 實際容量、最新非 Pro 自動回歸與隔離五萬首搜尋 UI 正在續驗，尚不先記 PASS。

### 續測新增觀察（未結案）

- 實體 iPad 隔離 QA 回讀 SQLite＋WAL／SHM：50,000 tracks、quick_check=ok，初次 seed 9.502636 秒；不是 metric 常數自報。測試版改名為 CMV QA 50K。
- 實際搜尋第 502 筆指定名稱、第 49,999 筆、英文／中文虛構歌手與專輯。97 個 query generations 中，81 個取消 generation 未有 stale publish。7 筆完成的非空查詢為 249.351–3730.384 ms、median 366.421 ms，150 ms 未通過。queryStart 含 120 ms debounce，原 QA observer 在 MainActor 同步寫檔，尚需控制量測干擾。背景 observer 的第一版成品出現錯誤 UI surface，已保留失敗並回查，不計 PASS。見 `qa-completion-50k-database-count.json`、`qa-completion-50k-metrics-analysis.json`、`qa-completion-50k-batched-wrong-surface.*`。
- 前述 manual EOF 診斷已由兩次送達操作補強：30 秒影片在約 14 秒與 23 秒送達 Next，越過原影片 EOF 後新 audio 繼續播放，currentIndex=2、3 entries/baseEntries 保持。判定 PASS_SCOPED，不代表所有時序組合；見 `qa-completion-eof-manual-verdict.json`。
- 主人本人確認有聲音但進度條不跑，native Slider 與 raw drag 亦重現。已做最小 PlaybackProgressView 修正、Mac build 通過，新版 iPad 尚待實測。cold restored queue 未 prepare 的 seek 為另個問題，不併稱已修。
- 非 Pro 自動回歸：Core 99 項、0 fail、2 skip（另有相同 scanner hash 的焦點證據）；artwork/native audio 5、effects/preferences 5 通過。AppModel 兩個錯誤訊息 assertions 改為依語系 prefix，en／zh-Hant／ja 各 2 通過，正式錯誤行為未改。
- 真 AAC smart cache 壓力測試由 759,936 降至 390,001 bytes，Pinned checksum 保持。這是小容量行為測試；10 GiB 實際容量因本機空間不足未執行，不用 sparse 檔代替。
- Runbook 已補 selector、lockState 唯讀查詢、native Slider、QA 隔離與量測界線。WDA 中斷後已重啟自己的 session，保留收據，尚未最終清理。

## 2026-10-06 解鎖後增補（Review，未結案）

### QA2／Main／資料保存

QA2 production video driver 在 iPad13 的限定 session 為 `14.616 s`；13 modes 均完成事件核對，所有非 neutral wetCount 增加，seek／pause／resume／stop 通過，`stop 405→405`、`errors=0`。證據仍只涵蓋 production session，主觀聽感、完整 lease 與完整 PiP 矩陣維持 Review。

Main frozen binary `e288` 已完成 13 個 GUI mode label 回讀；Custom `76%／52%／262.6 ms` 原音返回比較成立，影片自動 EOF 到 terminal 約 `54 s`。PiP Original 已實機進入、Pause→Resume，HomePiP 兩張截圖顯示畫面／進度變化；Home→fullscreen 因 fresh guard 過期且圖像點擊無效，不能列 PASS，稍後自然 EOF 關閉。

Restore-original receipt `20261006T135119Z` actual exit `0`，25 entries／base25／current13／history5；所有非 revision 欄位 exact，原 queue hash 前綴為 `56a8657d…226`。允許差異限兩筆 track 的 `Z_OPT`、`playCount`、`lastPlayedAt`，另有 4 筆 CoreData history transaction/change rows 與 primary-key allocation counters；不能宣稱整個 SQL byte identical。

### 搜尋與取消

QA2 search runtime receipt 的四個暖樣本為 `QA-501-after-target 54.302 ms`、`Synthetic Track 50000 72.874 ms`、`星河 119.884 ms`、`Fictional Artist 03 134.315 ms`；共 `61 started／10 published／0 stale publication`。cold final query `3242.827 ms`、empty outlier `170.059 ms` 仍超標，沒有 p95／full-performance 或 Main promotion 結論。

QA3 cancellation build artifact 已完成本機 build/sign/ZIP 收據；local test 實際 `107 tests／2 skipped／0 failures`。1 ms cancellation test 不足以證明在第一批中點 deterministic cancellation；硬體仍需驗 cancellation stage、取消後 `loaded=false`／半成品清理及下一次完整查詢恢復，不能把它寫成 hardware PASS。

### 容量與下一步

使用者最新容量基準為 `30 GB`，supersedes 舊 `33 GB` 歷史報告；當時 simulator 已 Shutdown，root `simctl shutdown all` actual exit `0`。本輪已清理已完成工作 cache `365380 + 505688 KiB`，swap 仍增加，不宣稱可用空間回到 30 GB，也未終止其他任務程序。

後續維持 Review：root 以 QA3 硬體補驗取消 stage，重新量測 cold／empty／完整 query metrics，並以 fresh guard 重試 PiP Home→fullscreen、lease 與主觀聽感。cold 首次約 3.24 秒及 empty 單次 170.059 ms 尚未修復；本增補不改 source、checkpoint 或 iPad 狀態，也不執行 syncdoctor。

### 22:04 更新：QA3 硬體退步，QA4 待驗

QA3備份、安裝與啟動actual0，完整target查詢count1；六個舊request在candidate stage取消且未走end，但最新結果等待 **14368.014ms**，判定性能退步、不promotion Main。需把entry check移到enumerate前，QA4正建置。資料處理批次數未觀測，不宣稱physical mid-batch cancellation。

輸入流程改用UI清除鈕、重新聚焦、送完整文字後，中文／虛構歌手／尾端曲目恢復正確200／200／1，暖單樣本120.246／142.117／66.579ms；68started／12published／0stale。帶尾字的錯誤輸入樣本不算預期查詢成功。PiP後對post13基準只有兩個owned測試track播放統計及6筆新增CoreDatachange/transaction，既有history未變，原25非revision exact；Main204／7／0仍保留。新增391檔實機證據已封存並逐entry SHA讀回；MC doctor actual0/pass（legacy passport unknown），仍保持Review。


### 2026-10-06 22:50 最新續測（取代較早的 QA3／QA4 下一步，維持 Review）

QA4 原 unsigned 候選誤用 QA2 AppModel 基底，被根代理拒絕且未安裝。QA4b 保留 QA3 AppModel、121 來源檔僅 repository/tests 兩項差異；deterministic pre-cancel/recovery focused test 1 test／0 failure、unsigned build actual0。根代理完成 Development 簽章 strict/deep、五份 plist/privacy 及 ZIP 每檔 bytes 驗證。首次 QA 名稱改寫漏保留本地化 NSMotionUsageDescription；原成品保留，已另製逐鍵保留的成品（binary b1f1e4d4…9700、ZIP 73a5e842…442f），備份、同 QA bundle 補裝及啟動 actual0。Main e288/aecc 沒有 promotion。

QA4b 暖查詢：target72.727ms／中文109.128及122.753ms／虛構歌手140.992及141.594ms／50000末筆65.686ms；無結果58.870ms並顯示無符合曲目，清除後恢復200筆。原簽章包45started／16published／0stale；暖樣本都<=150ms，但沒有p95或完整50k硬體IDs/order結論。冷target4735.116ms，metadata補裝後冷末筆4691.073ms：QA3的14.368秒退步已改善，冷瓶頸仍待修；QA5真正500筆fetch分頁候選正在隔離處理，尚未實機驗收。

QA3實際捲動越過200邊界，generation69發布200→400，曲目00200/00201/00213可見、第二頁repository→publish64.672ms。不能把第一個queryStart到23分鐘後手動捲動的間隔當分頁延遲。

本機實測約7.3GiB可用，工作前30GB仍為使用者報告。唯一MediBuddy模擬器已Shutdown且保留。分身清除本次完成的241468KiB候選build cache；先前240548KiB及365380/505688KiB記錄保留。3224檔／487678713bytes證據已比對搬至NAS：原cleanup因權限actual1，2967剩餘檔再驗證0mismatch後只補本機owned舊目錄寫權、cleanup actual0；NAS與source/raw保留，舊路徑有效symlink。WDA/relay與他人程序持續運作。

PiP回全螢幕、full lease／slow NAS／meter／完整VoiceOver與iPad10GiB容量缺口照實保留；全斷網/AirPlay/Bluetooth依使用者排除，Pro由隔壁負責。正式council仍limited，沒有新增formal審查或Done宣告。checkpoint v14新增235檔封存且逐entry SHA讀回；不覆寫v13失敗或舊archives。本段的文件更新尚未另執行MC sync/doctor。


### 2026-10-06 22:54 使用者更新效能取捨

使用者表示五萬首首次載入即使等待約一分鐘也能接受。驗收重點改為初始化期間可操作、背景進度與取消，以及後續暖搜尋順暢；首次建立索引4–5秒不再當作必須壓到150ms的失敗。歷史QA3退步保留，暖搜尋150ms與資料完整性仍須依實測驗收。QA5只先審閱分頁安全性，不為cold擴大持久索引／prewarm重構；是否採用以必要性、正確性與回歸結果決定。
## 2026-10-06 23:40 續測 checkpoint（尚未完成交付）

使用者已接受五萬首首次索引約 4–5 秒，重點改為等待期間可操作、可取消、有進度及後續暖搜尋；QA5 真正 500 筆 fetch 分頁候選不採用，封存工程證據。QA4b 已測暖搜尋 58.870–141.594 ms，未宣稱 p95 或完整五萬筆 iPad UI IDs/order。

Main 搜尋整合候選核心回歸 actual exit 0：107 tests／2 skipped／0 failures。主代理獨立查核 historical manifest 114 檔、實際候選 116 檔：3 檔修改，另有兩份從現有 workspace 帶入而 frozen base 未含的 Rust test fixtures（loudness.tsv／reconciliation.tsv）。兩份 fixture bytes 與 workspace exact，既有 16 個 Rust 路徑 unchanged；Repo／Tests 與 QA4b exact，production AppModel 未混入 QA metrics／seed／timing hook。Root source receipt：`/tmp/cmv-search-main-integration-20261006/root-source-audit.json`。先前只說 114 檔涵蓋所有來源的描述已被此實際盤點取代；Mac／iPad 新成品尚未交付。

舊 Main e288 直向搜尋 `cobalt` 與日文歌手 `月島` 各找到正確 1 首，與唯讀 204 筆曲庫中 46 筆未排除曲目核對。橫向搜尋欄點擊未取得焦點，其他控制正常，原因待查；不宣稱 Artist 目錄文字篩選通過。旋轉回橫向會清空搜尋狀態。

PiP 第 3 次嘗試未確認進入；影片自然 EOF 到 terminal audio 可見，原 25 首佇列已還原（restore receipt `20261006T150419Z` actual 0，所有非 revision 欄位 exact）。一次 capture 與 restore 重疊，該 capture 不採為停止前狀態證明。主資料 204 tracks／7 sources／0 playlists 保留，差異只限兩首測試曲播放統計及 CoreData bookkeeping；完整 PiP 返回全螢幕仍待驗。
