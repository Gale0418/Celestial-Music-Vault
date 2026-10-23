# iPad 實機驗收 Runbook

## 現行觸控操作規則

所有 GUI 輸入經 CUA 操作既有 `http://127.0.0.1:8766/` 遙控頁；shell 僅讀取 WDA 的 GET source／screenshot／activeAppInfo，與行政性的備份、安裝、啟動。下方歷史 POST 範例是舊機制說明，不是目前可直接從 shell 執行觸控的步驟。

每次送原生按鈕前先讀 fresh AX；非同步頁面顯示「點擊中」時，等待下一次狀態確認成功才接續。文字先在原生欄位聚焦，再填入遙控頁文字欄並送出；斷線後不能盲重送，必須先確認原生實際文字。截圖像素、裝置 point 與瀏覽器顯示座標分開處理；切橫直向後重新定位。保持 bundle／orientation／rect guards，不弱化防誤觸檢查。

AVControls 在播放中會 autohide；若 stale target 或畫面轉場使操作失敗，不得 blind retry。先以 persistent Moon pause 建立可重讀的穩定畫面，再重新 refresh／讀 fresh AX 與 rect，最後才進 fullscreen。helper `refresh` 不是實際 touch，也不算 keepalive PASS。

實機測試期間穿插實際觸控，目標30秒內、最長45秒；更新截圖、AX讀取與只啟用App不算有效防閒置輸入。WDA失聯時立即診斷程序與鎖定狀態，服務由其擁有聊天恢復，不能停掉他人的程序。重新連線確認 fresh native state 後才繼續；需使用者解鎖時集中說明實際原因。

2026-10-07 最新工程續測 checkpoint（QA e634／Main a40／PiP；維持 Review）

QA e634 fresh restore-check-3（08:17:23Z）initial SHA `fca94cba3082033648daaf5bcfd31355bd25346ac7605b3b14304f332042b44a`、restore SHA `83bc9673a117c4249b2fe21ee980926118e2eb986c4776a5e97b2a53dd96511a`；8 manifests 的 order／page／query／cancel／recover 均一致，50,000 IDs／250頁原序保持。根收據只公開檔名 `qa50k-new-guard-restore-root-verdict.json`，不將此 scoped restore readback 擴張為硬體全量效能 PASS。

Main a40 own SourceB 30s 暫停0:13、seek25%後實際0:06；先暫停的 Root 月環路徑 `0:28/3:00`→全螢幕 paused→SpringBoard 34、PiP 16% paused→native 回復全螢幕成功，Main 仍 `0:28/3:00`，放回月環顯示0:29（一秒展示差，不作 byte exact），Play至0:30後再次 pause 0:42，列為 `PASS_SCOPED_PIP_RETURN`。receipt `pip-return-addendum.json` SHA `8cf931a146eea38236fe33e76341ee6b9b0777a247bad6f53b805a9e1b483678`。先前 actively-playing PiP nativePause 遇 stale guard 失敗仍不算 PASS；`main-a40-pip180-fullscreen-paused` 意圖命名、實際 pause 失敗，明確排除。Main postPiP restore3 已完成，receipt `root-restore-verdict.json` SHA `252c48070c4717a837afcd1788479e0a217866e8c77fa831c85b7b75dbbeb014`：9 schema／columns／rows、preferences 9 values、queue 非revision exact（197→199，counts19／19／17／18），fresh GUI 原曲フリージア 0:00／5:34 paused。Main artwork 8a6 scoped runtime：iPad LibraryViews SHA `8a6fc21ef719289da9f73c3eac9cc52139fd8c8b12f5b7aa620ce6787fdf4a16`、iPad build SHA `70e7702d4426191a40f39af6951d5e0d19dd39f98540d7c07750f0c760fca509`、Video 維持 a40；parent-cover／album-center 與 artist-center 皆完成 physical detail-entry（507444），small-first physical 選1（499512），small-five 5、single-deselect 4、cancel-all 0；親讀 XML 與 assertion metadata SHA 後列為 `PASS_SCOPED_MAIN_ARTWORK_PARENT_ARTIST_SELECTION`。final Mac artifact root readback `root-independent-mac-parent-readback.json` 僅 PASS artifact only（binary `51985`／ZIP `8be0`），Desktop 行政交付已完成 delivery scoped PASS，primary root readback 檔名 `primary-root-delivery-readback.json`、`delivery-receipt.json` SHA `3e3a1b0a7e1c844b5e65d9e2ccad93412c7a322232c5cd5b7e1ea4220beaf184`；13 files／22 raw logs actual0、SHA／userdata 全源 exact、rollback 完整 ZIP 核 SHA；binary `51985`、no launch／no GUI，Mac GUI 仍 locked。保留 1980 tracks／114 sources／queue 1962／cur59／hist24／revision280。post-GUI limited data readback 已 PASS：公開收據檔名 `root-post-gui-primary-readback.json` 顯示主代理 9 tables 的 schema／columns／rows 含 WAL exact、queue 除 revision exact（201→203）、app-owned preferences 全 exact 但 `SKTransactionUpdatesLastChecked` 為 timestamp delta；`post-gui-verdict.json` 與 `post-gui-support／prefs copies` actual0。首次 UTF-8 comparison syntax exit1 保留，retry1 actual0；這不是所有 preferences bytes exact。a77 舊封存與 QA A/B baseline 未重現 Main finding 保留為歷史；未測欄位不填，真 NAS、iPad 10GiB、VoiceOver、人工聽測、actively-playing PiP pause 與 formal review 仍待驗，維持 Review。

Saturn iPad limited repair 已列 `PASS_SCOPED_IPAD_SATURN_SHADER_REPAIR`：new118 root handoff／source corrected；117 parent 每檔 SHA exact，原 Metal `6067` 保留，未改 Swift／metal。iPad artifact `66996`／ZIP `a874` raw build actual0，CompileMetal／MetalLink／strict codesign actual0，`default.metallib` 16,168 bytes 且含 `saturnScene`；Root install actual0、launch retry actual0。R2／GUI portrait-first、landscape、Library captures 均有 metadata SHA，single-card 1→cancel0 實機 PASS；`hardware/root-post-install-data-readback.json` 顯示 9 tables 含 WAL 的 schema／columns／rows exact、queue 非revision exact（209→211），preferences 除 StoreKit timestamp 外 exact，`titaniumEclipse` 仍選取。source／ZIP／簽章 readbacks 均為新 root。Mac artifact `9697`／ZIP `523c` deepstrict0、receipt `f3bd` exact；CUA 實際 launch，原星海晨光→Saturn·Pro→設定與聆聽 native screenshot 看見完整土星光環，列為 `PASS_SCOPED_MAC_SATURN_GUI`，並以 AX 確認還原星海晨光、回聆聽 paused 0:00。公開證據只列檔名 `root-desktop-readback.json`／`root-mac-gui-readback.json`；畫面為 tool output 目視，沒有 local PNG。iPad independent GUI `root-ipad-gui-readback.json` 亦 PASS；交付前後 data exact 不延伸為 GUI 後 DB exact。`verify-runtime-resource-inputs.py` guard 已驗 old117 negative1／new118+iPad positive0，缺 metal 或 image filename 會阻擋，external entitlements／codesign exact。CUA remote Errno61 中斷由另一 owner 診斷，已完成的 iPad Saturn 成果仍有效，不宣稱持續 keepalive。舊封存與非 Saturn PASS 歷史保留；正式 review 尚未 dispatch，維持 Review，不宣稱整體 Done。

Artwork candidate metadata receipt `artwork-runtime-candidate-verdict.json` SHA `be07dca35b7005fd4736225cf190fef370a550ffd3b37a4ee5b20b6a337c3b4d`：50,000 筆非 artwork 欄位 exact，僅 5 筆 `Z_OPT` 2→3；artwork PNG bytes／dimensions／IDs exact，history 已明列。這是資料保存與 artwork 操作 scoped evidence，不是 catalog negative 或 private album 通過。

CodeRabbit a40 僅審 `VideoExperienceView`，29 insert／6 delete，actual0；NDJSON 9 lines complete、0 issues，receipt `Root coderabbit-a40-root-readback.json`。這是工程 review，不是 formal council；AB 139 regular archive SHA `0c14718765897305a84ea40d6ddfd100f1777d8a467925ba91d5806ffd0cff44`、Root 138 entries SHA exact，cache cleanup 680188903 bytes；SMB free 顯示未變，不宣稱 Mac 30GB 恢復。

Main artwork 8a6 scoped runtime：iPad LibraryViews SHA `8a6fc21ef719289da9f73c3eac9cc52139fd8c8b12f5b7aa620ce6787fdf4a16`、iPad build SHA `70e7702d4426191a40f39af6951d5e0d19dd39f98540d7c07750f0c760fca509`、Video 維持 a40；parent-cover／album-center 與 artist-center 皆完成 physical detail-entry（507444），small-first physical 選1（499512），small-five 5、single-deselect 4、cancel-all 0；親讀 XML 與 assertion metadata SHA 後列為 `PASS_SCOPED_MAIN_ARTWORK_PARENT_ARTIST_SELECTION`。final Mac artifact root readback `root-independent-mac-parent-readback.json` 僅 PASS artifact only（binary `51985`／ZIP `8be0`），Desktop 行政交付已完成 delivery scoped PASS，primary root readback 檔名 `primary-root-delivery-readback.json`、`delivery-receipt.json` SHA `3e3a1b0a7e1c844b5e65d9e2ccad93412c7a322232c5cd5b7e1ea4220beaf184`；13 files／22 raw logs actual0、SHA／userdata 全源 exact、rollback 完整 ZIP 核 SHA；binary `51985`、no launch／no GUI，Mac GUI 仍 locked。保留 1980 tracks／114 sources／queue 1962／cur59／hist24／revision280。post-GUI limited data readback 已 PASS：公開收據檔名 `root-post-gui-primary-readback.json` 顯示主代理 9 tables 的 schema／columns／rows 含 WAL exact、queue 除 revision exact（201→203）、app-owned preferences 全 exact 但 `SKTransactionUpdatesLastChecked` 為 timestamp delta；`post-gui-verdict.json` 與 `post-gui-support／prefs copies` actual0。首次 UTF-8 comparison syntax exit1 保留，retry1 actual0；這不是所有 preferences bytes exact。a77 舊封存與 QA A/B baseline 未重現 Main finding 保留為歷史；未測欄位不填，真 NAS、iPad 10GiB、VoiceOver、人工聽測、actively-playing PiP pause 與 formal review 仍待驗，維持 Review。

2026-10-07 14:15 續測中的目前基準（取代舊資料還原指示，維持 Review）

使用者已交回 iPad 控制權；現在 Main 的權威備份為429曲／10來源／0歌單、收藏0，queue19／base19／current17／history18／revision197。保留 zh-Hant、crimsonNebula、bathroom／0.76，禁止還原歷史204曲／7來源／25項queue。完整 Support（含SQLite WAL）與preferences已備份，SHA清單位於 `.cmv-local-evidence/2026-10-07-final-runtime/runtime-baseline.json`。

本輪已實際操作直向四分頁中的設定、音效、聆聽、曲庫，浴室音效→對照原音→返回音效標籤成立，未播放／改queue。曲庫搜尋按鈕已開鍵盤；送文字時WDA服務拒絕連線，這次搜尋尚未驗成，已請服務擁有聊天恢復，不盲重送。工程Luna正在補硬體50k完整IDs／order／cancellation及慢速resolve／lease矩陣；這不是正式評論波次。

actual production video session host診斷exit0：seek／stop／wet baseline通過；自然EOF後timer58→89（一秒），非零level47→47。已安排最小terminal polling修正與EOF後seek／重播回歸，尚未通過修正版、尚未交付新版。Mac最終成品須包含arm64＋x86_64，iPad為arm64。正式新四席審查尚未啟動，完整人工朗讀／聽感及iPad10GiB條件項由另一聊天集中整理。全斷網／AirPlay／Bluetooth依使用者排除；工作前30GB僅本人回報，不能當本輪實測。

2026-10-07 01:53 最新權威 checkpoint（取代以下較早的 build pending／PiP return unknown；維持 Review）

最終 Main 為 source audit v8 的117檔，audit SHA 0da7c6296b1adba69caf722024a8512b7714b1b7860dd45f487bc38622b7bffa。Mac／iPad 最後 build actual0，strict/deep 簽章、五份 plist 所有鍵值、ZIP逐檔SHA／CRC與三張有效Sky素材非零尺寸均通過；兩端同Main bundle已安裝啟動。Mac binary 505021de01f4c52ff60ccfa0c07e5504881808bc5d90b0194586291a454e065e；iPad binary 6ba80bb96f7daa948af35b76e6bbe1f4b406584331fcb4e262d624c3b1fb3432。五個已驗程式檔已guarded promotion，workspace117來源SHA逐檔exact，未stage／commit／發布。

背景漏包修復已由兩端實際CUA畫面確認；使用者核准縮薄與透明，header44pt／左右20pt、opacity0.18，PlayerBar cover44／spacing2／padding6且控制44pt。右欄隱藏時搜尋clear X曾錯觸UpNext；最終將兩個面板按鈕並排左側，Mac日文搜尋5→清除200、iPad cobalt搜尋1→清除46，右欄仍Hidden，真觸控回歸通過。保留ReduceTransparency不透明分支。兩張不可達SkyEmeraldAurora／SkySaturnOrbit（201716bytes）先SHA exact备份再移除；SkyAmberDawn／SkyCrimsonNebula／SkyMilkyWayDepth仍打包，羊羊主題使用SheepStorybook，不刪其素材。

Mac最後交付前後9表全欄列exact，1980曲／114來源／0歌單，queue1962／cur59／hist24除revision277→280全同，amberDawn保存。iPad交付前後9表exact，204曲／7來源／0歌單、收藏0，原25／base25／cur13／hist5除revision73→76全同，使用者選的emeraldAurora保存。PiP4後另核對SQLite含WAL：僅兩首owned測試曲之playcount／lastPlayed／Z_OPT及CoreData記帳改動，非測試曲無新增／刪除／變更；原25除revision76→64全欄位相同。不能用相同DB main檔SHA忽略不同WAL。

PiP4實際 native minimize→Home→PiP返回全螢幕，返回前後1:02／3:00保持，Play後進度2:54；guarded original25還原actual0，fresh XML為會いたい、Play、Original、0:00／5:14。Home的foreground transition guard拒絕屬預期防護，screen-only重新觀察後才點返回，未弱化guard。首次portrait命名capture實際1180×820，不能當直向證據；先前slim版直向四tab證據保留，最後117版只記已觀察範圍。

Core107 tests／2 skipped／0 failures actual0；50k QA4b暖樣本58.870–141.594ms、45started／16published／0stale已驗，冷4.735／4.691秒依使用者接受；QA5未採用，不冒稱硬體全50k IDs/order或p95通過。影片13音效production session與seek／pause／resume／stop皆有限PASS，完整聽感／音訊路由／lease／slow NAS／meter與VoiceOver完整朗讀焦點仍UNKNOWN；iPad10GiB容量TOOL_LIMITED，全斷網／AirPlay／Bluetooth為USER_EXCLUDED。Pro由「Pro購買功能結案」獨立負責。

正式council沿用sealed limited紀錄；工程Luna核對不是formal closure，最後117來源尚無四席final-snapshot closure，不標Done或整體App Store ready。原超額仲裁與失敗收據保留。新證據將封存到main-final-background-cleanup-checkpoint-20261007.tar.gz；精確SHA與cleanup結果依旁附receipt／v16 checkpoint。


## 背景素材漏包防線（2026-10-07）

以完整目錄複製建置來源，包含 HEIC，不依固定副檔名清單或歷史114檔清單宣稱資源完整。逐一解析 Assets.xcassets 下 Contents.json 的 images[].filename，檢查相對素材實際存在、與 workspace SHA 相同。完成 build 後使用 assetutil --info 檢查 Assets.car 必須包含目前仍使用的 SkyAmberDawn、SkyCrimsonNebula、SkyMilkyWayDepth，且各圖 PixelWidth／PixelHeight 大於0；2026-10-07 使用者授權清理的 SkyEmeraldAurora／SkySaturnOrbit 必須不再打包。最初漏包修復的121來源包曾要求五張全部存在，該歷史 gate 不套用到精簡後117來源包。簽章驗證不能取代此檢查。

交付時維持同一 Main bundle；停止前後備份 Support／Preferences，確認所有資料表及 queue 除 revision 外相同、selectedTheme 保存。實機用目前主題看見背景後，再驗證縮薄透明工具列的控制與大字體；refresh 不算防鎖操作，必須穿插真正原生點擊。


2026-10-07 00:55 最新背景修復進行中：使用者回報 Mac／iPad 背景皆消失。root 已確認隔離來源五個 Sky imageset 只含 Contents.json，缺被引用的 HEIC；舊交付 Mac Assets.car 的 assetutil actual0 列出 7 個資產且沒有任何 Sky 背景。已從 workspace SHA exact 補回 5 張原圖，新增所有 imageset filename 引用存在性與 SHA 檢查。source audit v6 actual0，實際121檔＝歷史114＋2既有Rust fixtures＋5漏包背景；仍僅5個程式碼修改。使用者核准縮薄＋更透明已套入隔離候選：header 0.18、PlayerBar spacing2／padding6／cover44，44pt控制與 ReduceTransparency 不透明分支保留。兩端 incremental build 進行中，尚未交付背景修正版，不宣稱視覺通過。已交付前版兩端資料保存：Mac1980／114、iPad204／7及原25全表exact；新GUI月島／cobalt搜尋成功，一次語意中心重開焦點失敗保留。正式整體仍 Review。

2026-10-07 00:17 最新更新準備：整條上下工具列採20pt左右留白／明確滿寬；舊版e288外框本來已滿寬，這次調整內側留白一致。新版搜尋hit-test與版面尚待實機，不能以build判PASS。same-bundle更新前guarded stop／Support與Preferences read-from／relaunch actual0，SQLite integrity ok，204／7／0、queue25／cur13／hist5，與既有原25 queue SHA相同。先備份再安裝，UI input仍僅CUA；建置期間用已觀察的原生曲庫／歌手／專輯控制持續實際切換，網頁refresh不能代替觸控防鎖。

2026-10-06 20:48 本機準備完成：隔離 QA artifact2（flag-only影片診斷）actual build／sign／strict均0，raw5plist與ZIP逐檔bytes／CRC回讀通過，binary `b902805c…f96c`／ZIP `b0a0c6fd…cbb7`；11MB合成fixture SHAe227…b1c已確認在Bundle，driver SHAeffc…055c。未部署、未跑iPad，不能列硬體PASS。artifact1專用原probe量50k搜尋，artifact2專用全13 mode實際tap／timer／seek／pause／resume／stop診斷；共享Main與Pro來源及資料均未變更。等待本人重啟／解鎖，優先完成Main原25 postlaunch回讀，再backup QA50k namespace後部署。

2026-10-06 20:38 最新裝置狀態：WDA 自有 recovery 一度 ready=true，建立控制 session 時 runner 被 signal kill，actual xcodebuild exit65／relay startup exit1；原服務42968先前已不存在，未終止其他任務程序。停止 Main 後原25 queue 已逐位元回讀 exact（SHA919079…df5），後續 launch 因 Locked actual exit1，故僅 PASS_STOPPED_ORIGINAL25_BYTES，不列 postlaunch PASS，也未重驗目前音效偏好。已請本人重開 iPad 並解鎖，未再盲重啟。新版50k QA artifact1 binary7caba8…ba61／ZIP0eb7b0…fd38，本地 root source119SHA／raw5plist／strictsign0／ZIPCRC PASS，尚未部署、性能尚未實測；artifact2加入flag-only影片完整session診斷，獨立建置續行。工程Bridge片段評論由trajectory實際DONE＋兩marker核對，接受13count guard／duration tolerance強化，巢狀函式宣告順序編譯錯說法以hostactualcompile0反證；它不替代正式council。

2026-10-06 20:14 追加 Mac host 真 production VideoPlaybackSession 診斷：`root-final-receipt.json` SHA `216b4498…6120`，實際 compile/run exit0、15.488秒；13 presets逐個supported／processed／clock advancing，12非原音要求各自wet counter增加（custom設定含reverb52/delay262.6/bass3）；seek／pause／resume／stop通過，停止前後Timer412／412、errors0。完整class／observer與frozen114對照只計數器/accessors，CMVCore sources逐檔exact。這是Mac host有限診斷，不代替iPad13模式GUI、聽感、iOS音訊session或歷史0/3 XCTest。舊5.248秒guard不足與root第一輪readiness太早exit3均保留。自有Swift scratch已清理。

2026-10-06 20:12 最新補驗：postcouncil 字體已由 raw XML 確認 Larger OFF 0／Slider 67%；native Cancel 關閉曾誤開的 Remove 確認，未執行 Remove。postcouncil 唯讀 Support 全表／欄／列與 post-rapid baseline 相同、204 tracks／7 sources／0 playlists，queue 原25除revision全同；不把誤點算 Deselect 成功。隨後僅安装已封存 owned3 影片 fixture，進行13模式GUI補驗，WDA已回 Connection refused；目前queue fixture仍待後續還原，不能引用先前paused原25圖當目前狀態。服務診斷進行中；未送達觸控不算通過或防鎖。隔離50k效能候選已讀回8份rawlog SHA與Swift正規化相同／Rust production無差異，106 Swift／25 Rust及新增20,005筆test通過；仍待同probe iPad≤150ms，未promotion。正式council維持limited／Review。

### 2026-10-06 v6 遙控接續（目前入口）

本段是目前唯一權威摘要：fixed2 成品 e288／aecc 已雙安裝；post-rapid root 唯讀核對為 queue 除 revision 外 exact 25／base25／current13／history5，SQLite 不列全欄列 exact，204 tracks／7 sources／0 playlists 保持，僅 3-track playcount／lastPlayed／Z_OPT 與 CoreData history／bookkeeping 改動。Mac actual GUI 只記 scoped：Listen Now→LibraryList→Small→selection 0→1→0→List→Listen Now、paused Original；iPad actual GUI 只記 scoped：fontmax toolbar reachability、narrow four-tab navigation、native Zoom MAX 與 Main paused 0:00／5:14 Original，字體還原已由 postcouncil raw readback 確認 OFF0／67%，範圍證據見本頁最新補驗。圖像評論指出 scrolled BatchEdit title 位於 nav 下；最新 100% 實機微調捲動 counter image 中，原 Batch Edit Info 與 Deselect 均完整可見，最後 1 call 的獨立 visual 僅部分反證永久不可達，root／arbiter 不先定性為全域 defect 或 PASS。正式審查為 limited，chair record receipt `AERO-PQ41-cmv-final-20261006-13b10557bc0a.json`；3blind flow／visual／failure 各累積 6，原 arbiter 9／6 超額回合 `INADMISSIBLE` 保留為歷史。使用者已核准 replacement 3k／6 calls／10 min 取代 arbiter 累積 4 calls，但 token usage 未實際計數，不宣稱 exact quota compliance；review reports 已封存。D raw fixed2 install success 並 continuation launch success。維持 Review（非 Done）；performance FAIL、capacity `TOOL_LIMITED`、full VoiceOver／full wet／slow NAS 仍未知。

fixed2 後的最新 iPad scoped receipts：`qa-completion-navigation-ipad-fontmax-scoped-verdict-20261006.json` 為 `PASS_SCOPED_FONTMAX_TOOLBAR_REACHABILITY`（landscape Sort menu、selection 0→1→0、批次列垂直捲到底部）；`qa-completion-navigation-ipad-narrow-scoped-verdict-20261006.json` 為 `PASS_SCOPED_NARROW_FOUR_TAB_NAVIGATION`（Listen→Playlist→Settings→Library、AllTracks push/back、MiniPlayer sheet open／向下 dismiss、四 tabs 恢復）。narrow 僅有 SpringBoard XML，不是完整 accessibility focus PASS。

### 歷史 pre-final data-after-GUI checkpoint（已由最新 scoped receipts 更新）

font restore raw `qa-completion-navigation-ipad-font-restored-20261006.xml` 讀回 LargerSwitch 0、unnamed Slider 67%；window native Zoom 回 MAX，Main restored `qa-completion-navigation-ipad-restored-main-20261006.png`／`.xml` 回讀 paused 0:00／5:14 Original。當時 data-after-GUI 仍在唯讀核對、formal 審查尚未開始；該段保留為歷史，不覆寫目前 council 3 份 sealed review 進行中的狀態。已知 50k performance FAIL、capacity `TOOL_LIMITED`、AVPlayer probe `UNKNOWN`，維持 Review。

e288 rapid EOF receipt `qa-completion-navigation-ipad-rapid-eof-scoped-verdict-20261006.json` 是有限 near-EOF queue-selection scoped PASS，不代表 exhaustive subsecond race、慢 NAS／meter full matrix 或 listening PASS。post-rapid `final-receipt.json` 的 queue 除 revision 外 exact 25／base25／current13／history5；SQLite 完整 204／7／0 保持，但不列全欄列 exact，僅 3-track playcount／lastPlayed／Z_OPT 與 CoreData history／bookkeeping 改動，屬允許差異且不代表資料遺失。`product-tap-pipeline-receipt.json` 是 standalone partial diagnostic，13 是 wet buffers 而非 13 presets，final item unknown；歷史 0／3 probe failure 保留。正式審查 chair record 為 limited，reports 已封存；3blind flow／visual／failure 各 6，原 arbiter 9／6 超額為 `INADMISSIBLE`，replacement 3k／6 calls／10 min 已核准但 token usage 未實際計數，維持 Review。

remote PNG 是靜態快照；收到後必須先 refresh，再以新畫面重新讀取 rect／orientation／bundle guard，不能以 `waitFor` 盲循環等待 PNG 自行更新，也不能沿用舊 rect。

目前服務使用 `ipad_remote_v6.py`；Python SHA-256 `ac205aba89006867361a941905a9f2f29e8bc259946103e76c95c2b5e301c1c2`，同名 HTML SHA-256 `e1da5e2b33cd376e4ba7528564c20f4c9672c8d2c9baa221fb1eb1d5d0e2e1ba`。v5 保留為歷史入口，所有 guards 延續。default-off checkbox 的 VoiceOver 雙點模式只將 image tap 切為 WDA `doubleTap`；root mocks py／node exit 0，CUA 實際 doubleTap Library→Listen 並回讀 paused 0:00／5:14。

VoiceOver fresh Settings 的綠色 ON→Use VoiceOver→Main 單點 Library、雙點 Listen→Settings 綠色 ON→actual toggle OFF，source `Switch` value 0。綠色 ON 僅是 visual，ON source 只有 Cell；不可編造 value 1、完整焦點或朗讀 PASS，維持 `UNKNOWN_CAPABILITY`。OFF 有精確 raw 0。公開 receipt 僅列檔名：`qa-completion-v6-voiceover-on-readback-20261006.xml`、`qa-completion-v6-voiceover-on-after-main-20261006.xml`、`qa-completion-v6-voiceover-main-doubletap-listen-20261006.xml`、`qa-completion-v6-voiceover-restored-off-20261006.xml`，各自 `.png`／`.json` 亦保留。

### 歷史 build pending checkpoint（已由 fixed2 更新）

Source114 新 manifest `339650…348d`、RootView `0e7…`／LibraryViews `e567bc…` 已凍結；Mac／iPad final raw `BUILD SUCCEEDED`，仍未交付，不能寫 artifact PASS。新 Mac raw plistlib preflight actual exit 1：3 份 `InfoPlist.strings` 為 UTF16LE bytes 但 XML 宣告 UTF8，builder plistlib count=1 漏列 `.strings`；failed ZIP 與 `qa-completion-navigation-root-mac-attempt1-failed.json` 保留，workerfix2 variant／signZIP 進行中。formal approval 已授權，審查未開始，使用量 0，維持 Review。

fixed2 Mac `aecc…`／iPad `e288…` 已實際安裝。公開 receipt 僅列檔名：Mac `qa-completion-a11y-navigation-mac-delivery.json`、`qa-completion-navigation-mac-sqlite-independent-20261006.json`；iPad `delivery-receipt-complete.json`（admin PASS，delivery scope）與 `cmv-navigation-independent-preservation-20261006.json`（SQLite 204／7／0、queue/base25、current13、history5 除 revision exact、install／launch 0）。Mac GUI 根操作 Listen Now→LibraryList→Small→selection 0→1→0→List→Listen Now、paused Original 已完成。

### 歷史 fixed2 UI pending checkpoint（已由最新 scoped receipts 更新）

iPad fixed2 MAX100／Larger ON 下排序 menu 可開、批次列可垂直捲到底部，選取 1 後用 native Deselect 取消；一次截圖座標誤開 Remove 確認，Cancel 未移除，不能把首次點擊當成功。portrait／窄視窗／最終 restoration 尚待驗；v6 relay live，VoiceOver 維持 scoped、非完整朗讀 PASS。formal approval 已核准但審查尚未啟動，使用量 0，維持 Review。

### 2026-10-06 v5 遙控接續（歷史入口）

歷史服務曾使用 `ipad_remote_v5.py`／同名 sibling HTML；Python SHA-256 `38ae89dd3eeac9b09ee3a6e0234f2c5cae8025f397007e65ae9d8f0b601b2403`，HTML SHA-256 `8b235678977d69c5acd25e9eb0abfa19324bd49c484c8297242d8518731a3a7d`。下方 v4 記錄保留為更早歷史。

「僅更新截圖」會清空舊的原生控制項，並以截圖前後一致的前景 App 身分建立獨立的影像觸控保護；圖片載入完成後才可送觸控。需要原生按鈕時先「更新畫面」，等「已連線」。轉場若回報前景改變，等轉場完成後重新更新，不重送舊 target，也不移除保護。原生查找完成、送出 input 前仍再次核對前景。

實際 CUA 已確認 Main 音樂庫／正在聆聽切換與音效面板開啟、Done 關閉；OS 切換時的前景不一致會拒絕 stale screenshot。這僅是遙控可用與保護的範圍驗證。旁白首次提示、雙點手勢、朗讀與焦點順序仍須獨立驗證，不能由一般點擊通過推定。

### 2026-10-06 v4 歷史入口與視窗限制

此段歷史執行的 `ipad_remote_v4.py` 使用 `Path(__file__).with_suffix(".html")`，實際 sibling 是 `ipad_remote_v4.html`，SHA-256 `2ea1c93ee19da54d532a8a2bed07223e361f2411caf4e1399522dbcfbcea93ed`；下述 `ipad_remote.html` 是歷史 helper，不可混成目前服務來源。

「僅更新截圖」沒有更新 bundle guard 或原生按鈕。跨前景後先完整更新，等「已連線」再操作；頁面先取 screenshot、再取 XML，轉場中的兩者可能不是同一瞬間。截圖若仍是動畫，轉場結束後再更新截圖，不能沿用另一個前景的 native target。

舞台管理員可由 fresh screenshot 的右下角把手拖到較小視窗，再用 fresh 原生「視窗控制項目」→「縮放」還原最大視窗。視窗內 native rect 可能相對 App 視窗；SpringBoard source orientation 也可能與 screenshot 不同。使用已核對 label／rect 的 native action，或最新 fullscreen screenshot 座標，不套用上一個視窗的 rect。窄窗只讀到 SpringBoard 標籤時，視覺觀察不等於完整 CMV 操作 PASS。

旁白首次提示曾切到系統 overlay，但 helper XML 仍指向 Settings，foreground guard 因此拒絕輸入。拒絕不算有效雙點，不移除 guard；`qa-completion-a11y-linear-ipad-voiceover-tool-limit-20261006.json` 記 TOOL_LIMITED，後續已讀回旁白關閉，聲音、焦點順序及 CMV 旁白導航仍未通過。

用途：在同一台實體 iPad 上執行 CMV 的可追溯驗收。公開文件只用 `<DEVICE_ID>`、`<USB_UDID>`、`<WDA_HOST>` 與私有 receipt 檔名，不寫帳號、profile、完整 device identifier 或 user clip。主人已授權本輪 iPad 測試與復原；既有授權持續有效。

歷史 helper entry：`ipad_remote.html`（舊 receipt 所用來源）；此段描述 v4 歷史 relay；目前入口以頂端 v5 記錄為準。`capture.py`、`seed_queue.py` 與歷史 relay source 同在既有 evidence 根目錄；新測試使用新 tag，不覆寫或刪除既有 R/evidence。若執行的 relay Python 是 v4，仍須核對它讀取的 sibling HTML 與本輪 receipt。

## 0. 操作規則

- 同一台 iPad 的獨占是排程協調，不是每一步重新請主人批准。跨 chat 以 `send_message` 交接才需要主人授權；本輪既有授權不重問。passcode、配對與未知敏感權限仍由主人本人處理。
- 第一次連線先做 CoreDevice discovery；不沿用舊 CoreDevice UUID、USB UDID、WDA session、xctestrun 或 PID。
- shell／`exec` 可做唯讀 discovery、`devicectl` install／process／copy JSON、GET source／screenshot、receipt 整理；不可用 shell POST tap／drag／keys。所有 UI input 必須走 `cua_repl`。`devicectl copy to` 僅限已授權 queue fixture seed／restore，不作一般 AppData 修改。
- 先等 busy 結束，再 fresh AX；只在需要視覺或座標時取 screenshot，不強制每一步同時保存兩者。native target 必須 fresh selector（已驗證的 `predicate string` 可降低 XPath 延遲）、bundle guard、orientation guard，且 WDA rect 與 AX frame 各邊誤差 ≤±2 points。
- Build、簽章、單張 screenshot 或單一 log 都不能單獨構成測試 PASS；持久狀態須另有 queue／DB／檔案回讀。
- WDA lost 或 link interruption 時，先保存錯誤與唯讀狀態，再重建自己的 session／proxy；本輪主人已授權測試，不需另問，但不可盲目重試，也不可終止他人程序。
- 若主人要求長時間播放，以約 30 秒為目標，最遲每 45 秒由 cua_repl 做一次已知不改狀態的實際 touch；不得建立背景 keep-awake automation。未獲長測授權時不自動 touch；screenshot／AX polling／refresh 不算 touch。
- `getAXState` 取得的 helper 畫面是 cached snapshot，不代表新的時鐘；要判讀新狀態必須先刷新，再取 fresh AX。`refresh` 本身不是 keep-awake 的實際觸控。
- 非同步點擊回傳後先等待「已連線」狀態，再取 fresh AX；Playwright provider 有短 deadline 時，即使診斷畫面可見也不要重送同一個 action。
- 每次原生 Slider 動作後都重新 `deriveFreshIndex`；不要沿用動作前的 index 或舊 queue snapshot。
- 只有 actual touch 才能 keep-awake；`refresh`、screenshot 或 AX polling 都不算 actual touch。

## 1. CoreDevice discovery

```sh
xcrun devicectl list devices
xcrun devicectl device info details --device <DEVICE_ID> \
  --json-output .cmv-local-evidence/2026-10-04-remaining-validation/<tag>-device-details.json
xcrun devicectl device info processes --device <DEVICE_ID> \
  --json-output .cmv-local-evidence/2026-10-04-remaining-validation/<tag>-processes.json
xcrun devicectl device info lockState --device <DEVICE_ID>
```

核對 paired、transport、booted、Developer Mode、DDI、lock state、orientation 與 display size。需要本人解鎖或配對時停下交給主人；不記錄敏感值到公開文件。

CoreDevice discovery 的 UUID 與 USB `iproxy` 所需 UDID 不是同一欄位。這輪預設是區網 WDA `8100` 加本機 helper `8766` bridge；若真的走 USB，另以 discovery 查得的 `<USB_UDID>` 和未衝突 port：

```sh
iproxy 8766 8100 <USB_UDID>
```

WDA 若直接可由區網到達，使用當次 `<WDA_HOST>:8100`；不要把舊位址寫死。

## 2. WDA、xctestrun 與 CUA entrypoint

既有區網 WDA／helper 範例：

```sh
python3 .cmv-local-evidence/2026-10-04-remaining-validation/ipad_remote_v4.py \
  --wda http://<WDA_HOST>:8100 --port 8766
```

若使用 USB proxy，`--wda http://127.0.0.1:8766`，helper server 改用另一個未衝突的本機 port。不要安裝新 dependency。

需要既有 XCTest 時，以 `rg --files` 限定目前 DerivedData／archive 的 WDA build 輸出，再讀實際檔案；不假定 Xcode 版本或 xctestrun 檔名：

```sh
rg --files <CURRENT_DERIVED_DATA_OR_ARCHIVE_ROOT> | rg '/[^/]+\.xctestrun$'
plutil -p <DISCOVERED_XCTESTRUN>
xcodebuild test-without-building \
  -xctestrun <DISCOVERED_XCTESTRUN> \
  -destination 'id=<DEVICE_ID>'
```

確認 test bundle、架構、destination、candidate source／binary 相符；不符就記錄 blocked／NeedsRebase。

第一次 CUA 呼叫已知 entrypoint 優先用 `getTab`：

```javascript
let tab = await cua.getTab({url: "http://127.0.0.1:8766"});
```

若 tab 不存在才依當次環境建立／選擇瀏覽器；不必每次先做全 surface inventory。shell 可 GET `/source`、`/screen.png` 或執行唯讀 `capture.py <tag>`；不要從 shell 呼叫 helper 的 input POST endpoints。

## 3. UI 操作與座標

每個操作 loop：

1. 等 busy 消失，重新抓 fresh AX；確認前景 bundle 是本次明確目標：正式版 `com.windsheep.cmv`，或隔離的 `com.windsheep.cmv.qa50k`（顯示名稱 `CMV QA 50K`）。不得只憑同名圖示識別。
2. 以 fresh AX 找必要的 `type/name/label/frame`；只需要視覺確認或座標映射時才取 screenshot。
3. 由 cua_repl 點擊；不可重送 stale element、舊座標或舊 orientation。
4. 等 transition，再 fresh AX 讀取語意欄位（label、value、進度、按鈕狀態）並保存 tag。

預期 display points 是 portrait `820×1180`、landscape `1180×820`；retina screenshot 是 `1640×2360` 或 `2360×1640`，scale 2。旋轉後重新讀 AX，不能套用舊 frame。

約 30 秒的 skip／next／pause race 要在**同一個 cua_repl 呼叫**內做語意批次：fresh AX → action → bounded wait → fresh AX，再做下一個 action，避免 model round-trip 讓 input 太晚送達。每次仍執行 bundle／orientation／rect guards。

### 產品影片按鈕與 MissionCenter closeout 分開

`Native/CMV/CMV/RootView.swift:146–178` 的 production 行為如下：

- `Return to Moon Ring`（source 的「放回月環」）只把 presentation mode 設為 `.moonPortal` 並關閉 sheet，保留目前影片進度／播放狀態。
- 產品 `Done`（source 的「完成」）會關閉 sheet、呼叫 `stopVideoPlayback()`、清除 video window；這是**明確停止影片並清 queue** 的產品動作。
- 因此測試 mixed route 要保留播放時使用 Return；要驗證產品 stop／清 queue 才點 Done。畫面出現 Done 或 Return 不能單獨算測試完成。

MissionCenter 的 `Done` 是文件 closeout 狀態，只有 required 操作、fresh AX、持久化回讀與 receipts 都完成後才使用；它和產品影片的 Done 完全不同。產品 Return 也不是 MissionCenter closeout。

## 4. Queue fixture lifecycle

### 4.1 Backup 與 readonly 回讀

先保存當次 CMV process JSON，再以 `devicectl device copy from` 讀回整個 `Library/Application Support`。這是 read-from device；不要把 shell copy 當一般 AppData write。support root 必須保留 `default.store`、`default.store-wal`、`default.store-shm` 與 queue JSON。

本地分析先複製到自己 `/tmp`，用 SQLite URI `mode=ro` 與 `PRAGMA query_only=ON`；不要 `VACUUM`、checkpoint、migration 或寫入。比較欄位包括 track IDs、metadata 9 欄、source identity/status/bookmark、playlist、favorite/rating、Pinned files 與 queue。完成後只清自己的 `/tmp`，不刪 R/support/evidence。

### 4.2 Stop／seed／launch／restore

queue fixture seed 是本輪已授權的裝置操作，可使用 shell 的 `devicectl process` 與 JSON copy；UI input 仍只能 CUA：

```sh
xcrun devicectl device info processes --device <DEVICE_ID> \
  --json-output <TAG>-processes.json
xcrun devicectl device process terminate --device <DEVICE_ID> --pid <CMV_PID> \
  --json-output <TAG>-stop.json
xcrun devicectl device copy to --device <DEVICE_ID> \
  --source <QUEUE_JSON> \
  --destination 'Library/Application Support/CMV/playback-queue-v1.json' \
  --domain-type appDataContainer --domain-identifier com.windsheep.cmv \
  --json-output <TAG>-seed.json
xcrun devicectl device process launch --device <DEVICE_ID> \
  --json-output <TAG>-launch.json com.windsheep.cmv
```

launch options 要在 bundle 之前列明，實際命令保留於 receipt；不要依賴目前前景 App。seed 前驗證 version、entries/baseEntries、currentIndex、unique occurrence IDs、history membership；只停止自己 CMV PID。

原始 25-entry queue 復原時比對 track／base order、history、index 13、shuffle false、repeat off、entries/base well-formed 與 occurrence membership。重新序列化允許 occurrence UUID／revision 改變，不要求 JSON byte-identical。復原後 fresh AX／screenshot 確認 paused，再 copy queue JSON 回讀；queue PASS 不能由 build 或畫面取代。

每個 fixture 結束都復原原始 queue，除非主人明確指定保留變更；交接前保存 restore copy、process、launch 與 app state receipts。

## 5. 斷網範圍與失聯

本輪「完全斷網」是 `USER_EXCLUDED`，不建立 Airplane Mode 操作步驟，也不把它列為 blocked／待驗。已驗 source-loss（原檔移出 source root、Wi‑Fi 仍開、pin 可播放）只能標 source unavailable／cache fallback，不能延伸成 full offline；引用 `metadata-candidate-offline-source-loss-verdict.json`。

WDA lost／CoreDevice link interruption 時：保存錯誤與最後成功 tag，唯讀重查 device details／processes／lock state；必要時重建自己的 WDA session／proxy並重做 fresh AX。不要盲重試、不要 kill 他人。恢復失聯不改變本輪 `USER_EXCLUDED` 的斷網判定。

## 6. 驗收與收尾

每項 receipt 記錄日期、tag、candidate/source hash、實際 argv、exit code、裝置 scope、AX／視覺 evidence、持久化 copy／SQLite 結果、限制與下一步。PASS 必須有實際操作與可追溯結果。

收尾確認：原始 queue／必要 AppData 已復原；own helper、proxy、Python worker 已停止；R/evidence 保留；只清本輪 own `/tmp`。產品影片的 Done／Return 與 MissionCenter closeout Done 分開記錄：產品 Done 代表 stopVideoPlayback／清 queue，Return 代表保留進度回月環，MissionCenter Done 代表文件與驗收閉環。

```text
日期／task tag：<TAG>
CoreDevice／WDA／xctestrun receipts：<PRIVATE_RECEIPTS>
Candidate／source／binary：<PRIVATE_RECEIPTS>
UI：cua_repl、fresh AX；screenshot 僅視覺／座標需要
Queue／Application Support：backup、seed、restore、WAL/SHM readonly：<PRIVATE_RECEIPTS>
結果：PASS|LIMITED|REVIEW|USER_EXCLUDED
產品影片動作：Done(stop/clear queue)|Return to Moon Ring(preserve)
MissionCenter closeout：Done|未完成
Cleanup：只清 own worker／tmp；其他程序未觸碰
```

## 2026-10-05 補充實測教訓

- `lockState` 是唯讀查詢；`passcodeRequired: true` 時需要主人本人解鎖。`unlockedSinceBoot` 並不保證當下未鎖，兩欄須一起看。
- 遙控頁的 input 是非同步；「操作中／讀取畫面中」時，控制項可能仍顯示上次快照。等操作結束後取得 fresh AX 才判斷結果，不把中途文字或 WDA 往返時間當 App 搜尋耗時。
- v3 的 `iPad Slider 25%／50%／75%` 控制項會重新驗證 native Slider 並走 `adjustToNormalizedSliderPosition`；UI 輸入仍由 cua_repl 點擊這些控制項。保留 raw drag 與 native Slider 兩種實測，核對播放時秒數持續增加。
- 50K QA 使用獨立 bundle／SwiftData／queue／cache。只寫 QA 的虛構資料，結束後保存 metrics／SQLite 回讀再移除 QA；正式曲庫維持原資料。實體回讀已確認 50,000 筆，不能用 metric 的常數代替資料庫計數。
- 查詢從 queryStart 到 resultsPublished 包含 120 ms debounce；layoutMarker 是 SwiftUI onAppear，沒有證明 compositor 已顯示。同步 MainActor metrics 寫入有 observer overhead，須揭露且在效能不過門檻時另行控制。

- v4 建立不指定 tested bundle 的 WDA session，讓 foreground 自動偵測。實測在 Stage Manager／PiP 時，指定 CMV 的 tested session 可能偏好仍回報 foreground 的 CMV，漏掉實際系統設定前景；不得把這種 source 當 Home／PiP 返回證明。v4 的 bundle／rect input guard 持續保留，切到系统後先 fresh AX。
- Queue seed helper 以 `devicectl device info apps --bundle-id com.windsheep.cmv` 取得 fresh `apps[0].url`；正式 CMV executable 必須精確組成 `apps[0].url + '/CMV'`，不得以 suffix `/CMV.app/CMV` 代替。再以正式 bundle guard 與 exact executable PID 比對；QA 可能有同名 executable，不能只靠路徑或顯示名稱識別。
### 本輪磁碟與返回 App 補記

- 系統磁碟空間不足時先查 `simctl list devices --json`、模擬器 dataPathSize、已完成的本輪 DerivedData 與 `sysctl vm.swapusage`。只刪已確認本輪建立且測完的模擬器；先封存 QA store、metrics 與 inventory。其他專案的 Shutdown 裝置不代表可任意刪除。
- 本次已封存並刪除 QA iPad 模擬器，資料約 2.1 GiB；另回收已完成 QA 中間物約 691 MiB，可用空間回到約 3.2 GiB。單一 build 依序執行，避免平行編譯加重記憶體壓力。
- 不帶 bundleId 建立 WDA session 可避免 testedApp 前景偏好，但 `/wda/apps/activate` 仍需指定正式 CMV bundle。兩者用途不同。缺少 activate bundle 曾使返回按鈕 HTTP 500，已修正。
- PiP 控制會自動隱藏。strict fresh element guard 拒絕後，動作未送達，不記產品 FAIL，也不記 PASS。可另測 App 返回再按 Return to Moon Ring，並確認同曲進度繼續；這不能取代系統「回復全螢幕」按鈕的驗證。

### 原生控制項與 QA 工具檢查

- 點擊或設定 Slider 前，helper 必須重新 GET 原生 element 的 `enabled`，只有 `true` 才送 input；網頁上的 25／50／75% 按鈕也必須依原生 disabled 狀態停用。不能用測試工具繞過產品尚未準備完成的 Slider。
- helper input handler 是非同步：點擊返回不表示裝置動作已完成。等「已連線 · 點擊畫面即可觸控 iPad」再讀 fresh AX；短 timeout 後先查狀態，不盲目重送。
- 合併 production source 到 QA App 後，另驗 QA-only instrumentation 仍存在：queryStart、repositoryStart／End、resultsPublished。只有 seedReady 的 metrics 檔不能用來報搜尋耗時；layoutMarker 是 onAppear，不能冒稱 compositor 時間。
- QA root 的 `.songs` 畫面須和正式版一致，用 `ScrollView { TrackListView() }`。直接把大量 LazyVStack 放進 NavigationStack 會讓結果跑到負座標；這是 harness 缺陷，必須修好後重測，不能計正式 App PASS／FAIL。
- NAS 小檔 evidence 寫入變慢時，可先寫本機本輪專用暫存，收尾再封存至私有 evidence 根目錄並核對 SHA-256；封存完成前不清理暫存。

### 容量與影片音效續測

- 大容量 QA 工具安裝前先查實際建檔流程：`FileHandle(forWritingTo:)` 不會建立不存在的檔案。先以小檔解碼探針確認 WAV 形狀，再執行裝置容量測試；build 通過不代表 runtime 已驗。
- 分開記錄 media bytes、manifest／checksum overhead 與實體配置。SMB 上 Foundation allocated-size 可能與 POSIX `stat.st_blocks * 512` 不一致，必須保留兩者觀察，不能用邏輯大小或 sparse 檔假稱實際配置。
- 容量 PASS 應包含實際總量、source→cache checksum 一致、降額後媒體量、Pinned checksum／大小保留、失敗或取消時的階段收據，以及只清理本輪資料的證據。
- 影片音效驗證須區分「設定選取」「格式已準備」「實際 wet DSP render」。原音／強度零不應增加 wet render 計數；每個 preset 的 Core 測試都重填同一份原始 PCM，避免上一個效果的輸出使下一個效果假通過。
- plist 除 `plutil -lint`，還要直接解析原始 bytes；本輪 Mac 語系 XML 的 UTF-16 BOM 與 UTF-8 宣告不一致被 Apple lint 接受，標準解析器卻拒絕。修正後重簽、再核對 ZIP 逐檔 hash，不把舊 binary hash 沿用為新成品。
- 長時間編譯／讀碼不能取代 iPad 的真實觸控。解鎖後每 45–60 秒穿插已觀察、可逆的實際操作；若又出現 passcodeRequired，保留中斷狀態並等待本人解鎖，不把黑畫面或 Springboard 當 App crash。
- Mac 桌面 CUA 若回報系統鎖定／自動解鎖不可用，也要由本人解鎖。此時本機 build、簽章、檔案與收據檢查可繼續；沒有讀到桌面 App 的 fresh AX／畫面，不能宣稱 Mac UI 回歸或啟動通過。
- native AVPlayer probe 若停在 pending／waiting、time 0，先做相同資產的 no-tap baseline，讀 ready/error／waiting reason；只知道系統鎖定不能推論所有失敗都是環境限制。本輪三個案例失敗收據保留為 INCONCLUSIVE_FAILED_PROBE。
- `devicectl --json-output` 的命令結果檔必須和 `copy from --destination` 的 payload 檔分開，避免工具 metadata 覆寫讀回 queue。CoreDevice 服務斷線時先保留失敗階段，不重送未判明的 mutation。

## 2026-10-05 續測操作補充

- CUA 若拒絕 data: 連線錯誤頁，先確認本輪 relay 的 loopback LISTEN；由使用者手動重新開啟原 HTTP 頁面，inventory 回到 HTTP 後再綁定。不可用新 browser 或 shell UI 操作繞過政策。
- 遙控 tab 每輪 markHandoff()。點擊回傳「操作中」只代表送出；原生畫面更新且狀態已連線，才算送達。
- backspace 取代受游標位置影響會留下尾字。搜尋先原生清除、核對 empty，再聚焦並送出文字；欄位與 telemetry query 不符保留 INCONCLUSIVE。
- 舊 candidate 曾重建 occurrenceID；最新線性 candidate 須另比對完整 entries／base／history 與原 occurrenceID，只有 revision 可變。新版 iPad 原25與 Mac 原1962已實讀 IDs 保留；另看 paused UI，不把歷史行為沿用為新版預期。
- 本輪試驗曾誤用 suffix guard；已由 sealed command ledger correction 查證並記錄。誤判時停止的是自有 QA PID 21860，正式 Main 為 PID 21922，兩者資料均未改；不得把結果寫成僅停止 Main。

### 2026-10-05 fixed-build checkpoint（未結案）

- `qa-completion-video-fixed-main-summary-retry1.json` 的 scope 只有 frozen source 與本機 Mac／iPad artifacts，verdict 是 `PASS_SCOPED`；iPad fixed binary SHA-256 為 `a600cdd28142ef1cbb786aace7d0c7c5ef5edefd0c90b4544f89e9c8bbf2731c`，Mac universal binary 為 `5fcd23ccf8232a55e64f8a741017f98a562a389ce640eea5e9463634aa281f3f`。兩端 runtime 尚在測，不能由此摘要標 PASS 或 Done。
- root preflight 的 sign／architecture／qualification 均為 exit `0`；source readback 為 114 files、`workspaceMismatches=0`。這些是候選與來源驗證，不取代實機 runtime。
- preservation 的唯讀回讀為 iPad 7 sources／204 tracks before-after 相同，停止前 25-entry queue raw SHA 相同；Mac 114 sources／1980 tracks 與原始 metadata 保持。其 scope 仍是 preservation evidence，不是整體 closeout。
- cold `idx1` 的 natural video→audio EOF 實際回讀由 3-entry fixture 收斂到 `entries=1`、`baseEntries=1`、`currentIndex=0`；這個 actual `3→1` 是尚待修正的缺陷，不能記為 PASS。
- QA5 search verdict 是 `PARTIAL_PASS_PERFORMANCE_FAIL`；capacity root verdict 是 `TOOL_LIMITED`（可用空間低於 14 GiB 門檻，未建立測試檔）。QA cancel probe 的 binary SHA-256 `211213340e5e2f95ddaf02219e653beef5b73aa23c08c8de76afd49c690ef9ee` 僅有 root preflight、`runtimeTested=false`，未安裝，不能併入 fixed runtime 結果。
- 本 checkpoint 狀態固定為 `REVIEW`；MissionCenter closeout 尚未完成。

## 自動化模式故障的辨識（2026-10-05 補記）

若 helper 可達但 WDA 8100 為 connection refused，先保存自有 xcodebuild 的 exit／raw log 與當次 CoreDevice lockState。這輪曾在 `passcodeRequired=false` 時出現 `Timed out while enabling automation mode`，一次 guarded 重啟仍 exit 65。這不是瀏覽器政策頁或 App crash，也不能一直要求重新解鎖。保留失敗、請本人重新啟動並解鎖 iPad，再以新 result bundle／tag 重建自己的 WDA；未有外部狀態改變前不反覆 restart。不終止系統 testmanagerd、其他任務的 runner 或使用者程序。

## 2026-10-06：分頁政策失敗與還原待辦（歷史記錄）

當時 tab inventory 找到使用者重新開啟的遙控分頁，但 `getTab`／`getAXState` 回報 `admin-enforced policy could not be verified` 並拒絕存取。這與 WDA connection refused、裝置鎖定分開記錄；當次 WDA ready、locked false。不得改用 shell POST 觸控、其他瀏覽器或較低層 UI 輸入繞過政策；重新開頁與人工解鎖本身都不是觸控成功的證據。此為歷史事件，不能寫成目前仍 blocked。

原25佇列以 fresh exact App executable guard 停止、還原並冷啟動；numeric command exits 全0，停止回讀 byte-identical，啟動後除 revision 外所有欄位相同。GUI 仍待驗，不能以 administrative receipt 取代。

接回控制後優先還原本輪設定：iPad「更大的輔助使用字級」原為關閉，一般字級滑桿原67%；最後實測為開啟與100%。Main 音效原為原音，最後測試為自訂；尚未還原。旁白原關閉，Stage Manager 原開啟與 landscape 原尺寸，保留偏好。每次變更後用實際 Settings／App 畫面讀回，穿插真實觸控；單純刷新／AX讀取無法防止自動鎖定。

## 2026-10-06 CUA 續測補充（進行中）

- root 已接回正常 HTTP IAB3／tab2。真實 Settings maxfont 100、Main Library 單欄、selection 1→0、scroll 後完整 title／artist／album 與獨立 Play／menu 可見，menu opens→tap outside closes；這些只記為 scoped observations，待 root 最終 GUI receipt。水平 toolbar、portrait／narrow、VoiceOver、ReduceMotion 與 restoration 仍在測，不能宣稱全 PASS 或已 restore。
- helper 若出現兩個相同 label／rect 的按鈕，先確認確實是同 label／rect，再採 `exact role first`；summary 用 `getByText` 取得原生 iPad 操作控制，不把它當 `rolebutton`。
- 流程必須是 fresh image → native input → fresh readback。`await` 的短 timeout 不代表 input 失敗；先 refresh 讀回結果，未確認前不可重送同一個 input。
- 約 30 秒長操作、最遲 45 秒內以實際 CUA touch 維持喚醒；AX、`refresh`、`activate`、orientation 變更單獨都不保證防止自動鎖定。共享 WDA 屬其他 chat 的所有程序均不可終止；只可清理本輪自己建立且已完成的 worker／proxy。
- formal approval 已核准，審查未開始，使用量 0（12k／seat、3k／seat、每席 tool 6、wall 20 min）。50k 整體為 FAIL、容量為 `TOOL_LIMITED`、聽感為 `UNKNOWN`；network／AirPlay／Bluetooth 為 `USER_EXCLUDED`，Pro 鄰居 scope 不改判。


## QA 自動影片診斷的接續方式（2026-10-06，成品已備妥，硬體尚待驗）

先確認本人重啟並解鎖後的 fresh lockState、WDA ready 及原生觸控成功。原25已在停止 Main 時逐位元還原；前次 launch 因 Locked exit1，必須只做 launch-only continuation，再讀回全部非 revision 欄位與 Original 音效，不能重播要求三首 fixture 的 restore precondition。

先備份 QA50K namespace 的固定 tmp root 與既有 metrics／SQLite，確認原資料數量，再安裝已通過本地簽章／raw5plist／ZIP 檢查的 QA 成品。artifact1 用既有 cancel-probe 量同樣冷／暖四個 queries；保留完整 count、fresh 第一頁與 query→publish，暖150ms門檻尚未實測。artifact2 加入選擇性的影片診斷啟動參數：

```sh
xcrun devicectl device process launch \
  --device <DEVICE_ID> --terminate-existing \
  --json-output <OWN_LAUNCH_RECEIPT_JSON> \
  com.windsheep.cmv.qa50k -- --qa-video-full-session
```

CLI options 置於 bundle 前；所有 args／actual exit／CoreDevice JSON 都保存。無 flag 時仍走原來的 seed／搜尋流程；有 flag 才先執行 production VideoPlaybackSession、真1/30 Timer與合成180秒本機影片的13-mode診斷，將 `qa-video-full-session.json` 寫到 QA root。診斷期間暫時設定 `isIdleTimerDisabled`，defer 恢復原值並清除自有 callbacks／player、還原音訊category／mode／options；它不能算成實際遙控觸控。正常 GUI 測試仍穿插 fresh/native guard 實際操作，目標30秒內、上限45秒。

JSON 必須 fresh，schema／bundleID／模式數13／各模式 supported、processed、時間前進、非原音 wet counter增量／actual AVPlayer seek／pause-resume／停止前後timer相同／errors0均逐一核對。缺fixture、setup失敗、沒有輸出、deadline或任何INCONCLUSIVE都保留，不能由建置成功升格硬體PASS。這份診斷不代替主觀聽感、影片畫面／PiP同步、完整Main音訊lease或慢NAS矩陣。

WDA connection refused時先診斷runner與lockState；本次一次ready後signal kill／exit65已保留，需外部重開機狀態改變後才嘗試新runner。不能把`passcodeRequired:false`當成永久保持畫面醒著，也不能用舊PNG判定目前前景。全部完成後返回Main，讀回原25／Original／paused與資料保存，再封存新實機證據。

## 接回後實機補驗（2026-10-06）

新 WDA／v6 relay ready 後已實際 CUA 觸控。隔離 QA2 全13模式 production session 14.616秒、errors0、stop405→405通過。Main全部13模式由明確選單逐項讀回；Next Sound僅輪替八種scene，不能當all13。自訂原音對照／返回保留76%／52%／262.6ms，影片自然EOF到末首audio，完整3首佇列／base／current2／history2保持。

fresh guard曾拒絕Done及locator未匹配，先refresh核對不盲重送，失敗保留。原25再還原並launch／readback0，GUI Original／paused0:00／5:14；資料204tracks／7sources／0playlists，差異僅兩個自有測試track播放計數／時間／Z_OPT及CoreData記帳，不宣稱全表完全相同。PiP追加回歸再用同一sealed3fixture，結束仍需還原25。

新增cancellation候選Core107／2skipped／0fail actual0，非Main來源；1ms測試不能單獨證明已處理首批，需QA3硬體stage證據。用SMB自有scratch隔離建置，避免Mac低空間，不使用I/O error的既有共享HFS volume。

## 本輪容量基準與暫存清理（2026-10-06）

2026-10-06 21:08 容量基準更正：使用者確認本次開工前可用空間為33GB（本人回報，非本輪工具量測）。當次df約1.34GiB，swap使用9480.50MiB，不能把整體差額歸因於本輪檔案。已確認無編譯程序占用，且QA2成品binary／ZIP雜湊與封存一致後，僅清理本輪完成的QA DerivedData／cargo-target合計365380KiB；df可用1403236→1743912KiB，約1.66GiB。原始碼、成品、失敗紀錄與證據保留，其他專案模擬器及系統swap未動。

## 2026-10-06 post-unlock continuation（Review）

QA2 production driver 已在 iPad13 完成限定 session：13 modes、總耗時 `14.616 s`、非 neutral wetCount 全部增加、seek／pause／resume／stop 通過，`stop 405→405`、`errors=0`。這只覆蓋 production driver 事件與計時，仍須分開驗主觀聽感、完整 lease 與 PiP。

Main frozen `e288` 已逐一回讀 13 個 GUI mode label；Custom 實測保留 `76%／52%／262.6 ms`，完成原音返回比較，影片自然 EOF 到 terminal 約 `54 s`。PiP Original 實機進入、Pause→Resume、HomePiP 兩張截圖顯示畫面與進度變化；Home 回全螢幕時 fresh guard 已過期，圖像點擊無效，這一步不得記 PASS，PiP 隨後自然 EOF 關閉。

Restore-original receipt `20261006T135119Z` actual `0`：25／base25／current13／history5，非 revision 欄位 exact（原 queue hash 前綴 `56a8657d…226`）；播放統計與 CoreData history bookkeeping 差異照 receipt 記錄。QA3 cancellation build artifact 已交付 root，local `107 tests／2 skipped／0 failures`；1 ms 測試不能代替 deterministic mid-build cancellation，需在硬體補驗 cancellation stage、取消後 loaded 狀態與下一次完整查詢恢復。

QA2 search warm samples 為 `54.302／72.874／119.884／134.315 ms`，`61 started／10 published／0 stale`；cold `3242.827 ms` 與 empty `170.059 ms` 仍是未解問題。下一步沿用 QA namespace 量測 cold/empty/full query stage 與 fresh guard 下 PiP fullscreen return／lease／subjective listening；未達條件前保持 Review，不標 Done。容量基準採使用者最新 `30 GB`，舊 `33 GB` 僅歷史，root shutdown-all actual `0` 與既有 cache 清理不代表空間已恢復。

## 搜尋輸入與 QA3 退步紀錄（2026-10-06 22:00）

v6 的「取代欄位文字」是送入退格鍵，僅刪游標前方文字；游標在中間會留下尾字。因此驗證流程改為：fresh 截圖點搜尋欄清除鈕 → 等操作完成並確認空白 → 重新聚焦欄位 → 等完成 → 使用「送出文字」→ 回讀完整欄位及 metrics.query。頁面 busy 時下一個按鈕會被略過，不能把點擊呼叫成功當成輸入送達。清除與聚焦後都要確認狀態再送文字。錯誤送入 `Synthetic Track 50000-target`／`星河-target` 的紀錄保留，不算預期搜尋測試通過。

QA3 同 QA namespace 已備份、安裝、啟動 actual0；候選入口缺少取消檢查，六個已取消請求各支付 enumerate 初始化成本，最新 target 正確 count1 但 query→publish **14368.014 ms**，較 QA2 退步，禁止 promotion。六個 requestID 只有 candidates.start/cancelled，沒有 end；不宣稱已處理實體首批。完整中文查詢恢復為候選12500／首頁200、120.246ms單樣本。QA4 正在補昂貴讀取前的 entry cancellation check，仍待建置與硬體驗收。


### 2026-10-06 22:50 截圖刷新與交接補充

CUA getScreenshot讀取遙控頁目前顯示的影像，不會自行要求iPad重拍。送文字時頁面可能在搜尋完成前就更新一次；metrics已發布而頁面仍顯示舊列時，先按「更新畫面」、確認連線完成，再查看截圖與原生controls。唯讀WDA source/screenshot與devicectl metrics可作獨立證據，不能代替實際觸控防鎖。

waitFor偶爾回傳selector deadline而診斷顯示visible；此時讀新AX/截圖，確認busy是否已完成及哪個輸入確實送達，從尚未送出的步驟接續，不盲目重送整组字串。

QA成品改CFBundleDisplayName時必須parse並保留原plist所有其他keys，尤其各語系NSMotionUsageDescription；不得以display-onlydict取代。重簽後驗證strict/deep、UTF-8/plist/privacy、ZIP逐檔bytes，same-bundle install前先備份QA namespace。Main與QA資料分開，原25佇列還原收據持續保留。
### 2026-10-06 23:40｜搜尋輸入焦點與旋轉續測

每次送文字前，先看實際 iPad 畫面確認搜尋已展開且鍵盤出現。直向的搜尋放大鏡可展開輸入欄；清除按鈕可能連搜尋模式一起關閉，清除後須重新點放大鏡並確認焦點，不能直接再送文字。`Return` 不足以證明字串已送入：必須從原生 SearchField.value 與結果數驗證。e288 舊 Main 直向 `cobalt`／`月島` 各為 1 首，且與唯讀曲庫 metadata 相符。由直向切回橫向會重新建立頁面並清空搜尋條件，未改動歌曲或佇列。

橫向 e288 搜尋欄目前重現「可見但點擊後未取得焦點」，其他導覽與頂部佇列按鈕正常；暫記 scoped finding，頂部控制列與 NavigationStack 搜尋工具列同位置的遮擋原因尚未確認，不能當作歌手篩選通過。證據：`/tmp/cmv-video-presets-ipad-20261006/gui-root-resume/main-wide-artist-search-no-focus.xml`。所有觸控仍由 CUA 經既有 guarded relay 送出，不修改 foreground／orientation／frame guards。

## 2026-10-07 16:15｜Main signed candidate fresh touch checkpoint（Review）

本 checkpoint 只補操作與判讀規則，不改 production／relay。Main signed iPad 已 install／launch `actual=0`（PID `23690`）；Main portrait 820×1180 小縮圖的第一、第二格曾出現 native element click 無狀態變化，而 fresh screenshot 中心點第一格可變更；QA 同 view 另有成功對照。這是尚未定位的 scoped finding，不得直接定性為產品 hit-test bug，也不能把 QA 成功借給 Main。

### Fresh AX／element／座標 fallback

1. 每次操作前先取 fresh screenshot 與 AX，核對前景 bundle、orientation、螢幕尺寸，以及目標的 exact `type`、`name`／`label`、`frame`、enabled 狀態；保存當次 raw。`getAXState` cached snapshot、舊 XML、上一個 orientation 的 rect 都不能當新 target。
2. 對 exact label／role 的 native element 只送一次 guarded click，等待狀態回讀後再判定；回傳成功但 selection／value 未變時，保存 failure raw，重新 fresh AX／screenshot，不重送同一個 stale element。
3. 若仍需判斷觸控命中，使用 fresh screenshot 的目前 frame 中心座標做一次 guarded coordinate probe，記錄螢幕 point、pixel／point scale、orientation、before／after screenshot 與 AX。coordinate probe 是診斷 fallback，不是繞過 bundle／orientation／rect guards 的一般入口。
4. 工具回報 element click 無效時，先把它記為「action returned but state unchanged」；只有 fresh center probe 也在同一個 frame 重現，才可建立可重現的 UI finding。第一格曾成功的中心點不能推論第二格，第二格需另取 fresh rect／center 測量。
5. 選取工具列出現後，內容列可能由 `y=152` 移到 `y=206`；這是版面狀態改變，必須重讀 frame，不能把兩個座標當成同一 frame 的 hit-test 證據。

### 搜尋、readback 與 performance 分離

- `14-replace` 送字串前，先 fresh screenshot 點清除控制，確認原生 SearchField 空值；重新聚焦後才送完整字串，最後核對 SearchField.value、結果數與 query metrics。游標位於中間造成的 `-target` 或尾綴殘留要保留 raw，不能誤判為查詢通過。
- Support／Preferences／queue 的資料回讀另存 receipt；query latency、publish／stale count、timer／wet counter 另存 performance/runtime receipt。任何一類 readback exact 都不能替代另一類性能或 UI 操作證據。
- 2026-10-07 16:15 基準：Main 429／10／0、queue19，9 表 exact、queue 非 revision exact、revision `197→199`；QA 50k／250 pages／8 queries 與舊代次 guard 僅是 scoped receipt。新 restore 仍在獨立讀取，未完成前維持 Review；Mac GUI 鎖定、完整 VO／聽感／slow NAS 亦維持未驗。
