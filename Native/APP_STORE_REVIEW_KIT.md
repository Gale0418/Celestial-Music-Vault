# CMV 2.0｜App Review Kit

## 2026-10-23 最新狀態

兩平台 2.0（1）已上傳且目前遭拒審；本輪準備 2.0（2）。iOS 需要明確 Pro 路徑；macOS 需要實際使用畫面及清楚的 Apple Music 用途說明。新版增加寬版側欄 Pro 快捷入口，保留原設定路徑；以原創示範媒體重新擷取實際畫面。系統媒體整合的三語用途說明不宣稱讀取 Apple Music 私人曲庫，完整 prompt 觸發條件仍未重現。四張新實機圖已完成：Mac 兩張 2880×1800、iPad 兩張 2360×1640，全部橫向；另兩張 image_gen 裝置 mockup 已完成並明確標示。13 吋 Simulator 橫向圖仍在補拍。final archive／export／upload／送審仍 pending，詳見 [本輪紀錄](REVIEW_FIXES_20261023.md)。

更新：2026-10-23

這是實機示範與審核回覆的操作清單。三語商店與 App Review Notes 的 canonical
來源位於 `Native/AppStoreMetadata/`，避免複製文案後產生不同版本。私人審核聯絡資料
只在 App Store Connect 與權限受限的執行階段資料中使用，不放進版本控制。

## 2026-10-08 歷史回讀（不代表最新狀態）

本節只保存當日回讀；最新狀態以上方 2026-10-23 為準。下方 2026-10-03 候選、工具失敗與未完成清單也屬歷史紀錄，不代表全部仍待驗。
CMV App Record已存在，兩平台2.0仍為PREPARE_FOR_SUBMISSION；截至本日最近一次ASC回讀，完整build列表0，兩平台三語截圖／preview集合均0。該次三語App Info與兩平台公開文案33欄回讀一致；本次文件更新未重新查詢或修改遠端。審核聯絡與版權已依主人授權沿用MediBuddy，不重建App Record或重填私人資料。

Pro技術可靠性已由AERO-MON30／PQ38完成驗收與正式評論；PiP、兩端整體聽感、iPad旁白及窄picker取消已由主人接受。50k約一分鐘等待接受，完整10GiB實填不需要；Mac旁白、全斷網及Bluetooth／AirPlay屬本輪USER_EXCLUDED。上述結果不取代同RC商店素材與剩餘功能矩陣，亦不把排除項寫成PASS。iPad已歸還並完成晚間續測，歌單／Smart DJ／播放中佇列與冷啟動、分析／移出計數均有分範圍封存。自訂七值冷啟動及原音對照通過，主人重開後已完成音效設定還原及獨立Luna複查；續測四EQ各冷啟動保存成功。測後九表與原佇列非revision exact、effects解析值exact但JSON key order使encoded bytes不同，StoreKit時間另變；歌曲維持暫停。

最新側欄計數修正版已封存四份Development／Distribution archive、IPA／PKG與六項qualification收據；兩平台Distribution archive及export皆通過App Store Distribution qualification，實際簽章Team與建置recipe一致。來源95項與四份dSYM UUID的對應見本機 ignored evidence：`../.cmv-local-evidence/2026-10-08-task-zero/sidebar-count-fixed-artifacts-01/manifest.json`（未納入版本控制），Team核對見本機 ignored evidence：`../.cmv-local-evidence/2026-10-08-task-zero/signing-team-readback-01/primary-team-readback.json`（未納入版本控制）。這些是成品與簽章資格證據；RC4仍Blocked，尚未upload／送審。

本次重新讀取並核對四份archive及封存source的Privacy Manifest，皆與目前來源逐byte一致（SHA-256 `11ed836c19e9b0e74170e70775025b7499b6cdc39b245b5a425ecb24d77c073a`）：tracking為false、collected data types為空；required-reason API宣告為FileTimestamp `3B52.1`、UserDefaults `CA92.1`、SystemBootTime `35F9.1`／`8FFB.1`。這是bundle宣告一致性驗證；遠端App Privacy「不收集資料」已有本日晚間解除登入後的瀏覽器fresh回讀，見下方收據；CLI未取得fresh問卷，也未將manifest內容當成完整執行期資料流審查。

Mac最新實機的佇列／metadata／排序／Smart DJ、EQ四preset、custom七值冷啟動，以及86字長標題尾端與自然返回已有分範圍證據，詳[累積測試總帳](../MissionCenter/tested-coverage-ledger-20261008.md)。Reduce Motion授權待答、iPad剩餘矩陣及同RC截圖／連續影片仍未完成；主人已撤除原評論預算hard stop；正式四席最新共同快照仍待實際執行，代理名額限制尚未解除，不宣稱正式收斂。

本機資料流靜態對照已補本機 ignored evidence：`../.cmv-local-evidence/2026-10-08-task-zero/privacy-source-readback-01/primary-source-readback.json`（未納入版本控制）：12個主要來源檔逐byte對應最新成品封存source；SwiftData曲庫、Application Support的queue／Pinned、Caches的Smart manifest及UserDefaults為裝置內保存；分析由AVAudioFile取得PCM後呼叫Rust FFI，購買使用Apple StoreKit。Swift／Rust production來源的指定網路API／函式關鍵字搜尋未見相符項目；這項有限靜態檢查不代表封包擷取或所有系統／provider外傳路徑已驗。

[本機隱私政策](../PRIVACY.md)已補Mac明確確認後「將實體檔案移至垃圾桶」的例外，與一般從曲庫移除區分；公開政策仍為10-03版本，本機10-08修訂尚待公開同步，未改遠端URL／問卷。

稍早ASC API重新完整分頁回讀兩平台2.0皆PREPARE_FOR_SUBMISSION、uploaded builds0。該時點隱私問卷fresh查詢受登入阻擋（後續瀏覽器已解除，見下一段）：CLI無cached web session，Chrome也顯示Apple帳號登入表單；已保留頁籤請主人自行登入，未輸入憑證／未修改問卷。見本機 ignored evidence：`../.cmv-local-evidence/2026-10-08-task-zero/asc-privacy-current-readback-01/primary-readback.json`（未納入版本控制）。截圖集合與文案未在本次重新查詢。

晚間主人重新登入後，Apple App隱私頁直接顯示已發佈「不收集資料」、資料類型「不會從這個App收集資料」，政策URL與canonical一致，見本機 ignored evidence：`../.cmv-local-evidence/2026-10-08-task-zero/asc-privacy-unlocked-readback-01/primary-readback.json`（未納入版本控制）。iPad後續已再次解鎖，晚間實測與還原切片詳累積總帳；重開後偏好還原與四EQ保存已分範圍驗證，不再沿用較早的自動鎖定或重開等待阻塞。正式評論已獲主人續授權並取消原預算hard stop，仍需實際四席報告；原中止歷史保留。本機政策修訂仍待公開同步。

參照GAI與MediBuddy既有審核文件的七類說明，CMV可沿用結構及已授權聯絡資料；產品能力、隱私與附件須由CMV自己的證據支持：

| 審核資訊 | CMV對應內容／來源 | 仍需補齊 |
| --- | --- | --- |
| 實機影片 | 依下方shot list使用原創ReviewMedia；不引用其他App影片 | 同RC雙平台連續影片、檔名與附件 |
| 裝置與系統 | 最低macOS15／iPadOS18；實際測試環境填入canonical Notes的runtime欄位 | 錄影當下平台、OS、版本／build與日期；不填私人裝置ID |
| 用途與對象 | 本機／已掛載NAS的私人影音曲庫播放器；不附帶影音目錄 | 以最終RC核對商店功能宣稱 |
| 存取與設定 | 免費核心無登入；Settings→Music Sources→Add Music Source，或側欄Add Music；Pro一次買斷／Restore Purchases | 同RC確認入口與完整操作矩陣 |
| 外部服務與工具 | 不提供SMB登入、LAN探索或雲端AI；NAS由Finder／Files先掛載；購買使用Apple StoreKit | 最新archive與來源Manifest一致已核；最終RC及遠端問卷／資料流對照仍待 |
| 地區與語言 | 介面及商店文案為en-US／zh-Hant／ja；台灣Pro價格證據不推論其他storefront價格 | 上傳前回讀實際可售地區與商品狀態 |
| 特殊領域與內容權利 | 影音播放器；不提供醫療／金融等專業服務。示範用原創PCM／MOV／PNG，權利見ReviewMedia與ASSET_RIGHTS_LEDGER | 同RC商店截圖內素材逐項對照與最終聲明 |

現行任務與接受範圍見MissionCenter/tasks.md、closeout-checkpoint-20261008.md；原創fixture下載與SHA仍沿用下方記錄，待實際附件完成後再填入Review Notes。尚未upload／送審。

## Release identity

- App：星穹私藏音樂庫 Celestial Music Vault
- Bundle ID：`com.windsheep.cmv`
- Version／build：`2.0`／`2`（本輪準備中的 build；上傳前仍以遠端安全 build number 為準）
- Platforms：macOS 15+、iPadOS 18+
- Primary language：Traditional Chinese (`zh-Hant`)
- Review contact：使用者已授權沿用已上架 MediBuddy 的審核聯絡資料；兩平台已填入。

## App Review Notes 來源

使用 `AppStoreMetadata/en-US.md` 的 App Review notes；繁中與日文亦有對應檔案。
2026-10-03 已將 Notes 寫入 iOS／macOS 2.0；免費功能不要求登入，
Pro 使用 Apple App Review Sandbox。首次上架不接受 What’s New 欄位，
該內容保留於 canonical 檔供日後更新使用。

以下測試流程供影片與人工驗收使用；目前已具備可公開下載的原創 fixture 與有限 iPad 操作證據，仍不能取代完整雙平台實機／Sandbox 證據。

## 2026-10-03 目前可重現證據

- 原創 Review fixture 已公開於 [cmv-review-fixtures-20261003](https://github.com/Gale0418/Celestial-Music-Vault/releases/tag/cmv-review-fixtures-20261003)，ZIP SHA-256 為
  `e3b766ec3a828fc8d11e8ac90b1468a5cea5e8f8ba600a79184aa39e68bf72d6`。素材來源、格式與權利說明仍以 `Native/ReviewMedia/README.md` 及 manifest 為準。
- iPad 已實際下載並在 Files 解壓，AddMusic 來源由 20 首增至 25 首；空佇列 Add → Play 的進度為 0。佇列
  `[Amber, Cobalt, Amber]` 移除未播放的 Cobalt 後為 `[Amber, Amber]`，目前曲目與進度不變；這只證明指定的未播放 Cobalt 路徑，不代表可移除指定的重複 Amber。
- 最新 iPad final source 已在解鎖後 install／launch 成功，binary SHA 與 final source manifest 相符；25 首原創 fixture、Track Info 英文與 release `Not Available`、多選 2 項 UI 通過。enqueue 結果 Unknown，重複 future remove、重排與 terminate／restore 未驗證。先前 install failure 保留於歷史 notes，不以舊 limited QA 代替此次 delivery。
- 多選、重排、本版強制終止後還原、完整雙平台無剪輯影片、Split View／PiP 與 Sandbox 仍未完整驗收。WDA runner 本輪 `Test crashed with signal kill.`、host exit 65 後已離開；session DELETE 因 service unavailable 未確認，cleanup receipt 未見 owned host 存活。根因未知，不稱為 CMV crash；私有畫面／XML／裝置資訊只留在 ignored runtime 證據。
- 先前 distribution source manifest 與 Mac Release／iOS Distribution candidate qualification 仍可追溯，但 Marquee overflow source 修正後正在建立新的雙平台 build；舊 candidate 不代表最新 source qualification，尚未 upload，不等於最終 RC 或送審完成。
- 最後 Mac desktop 覆蓋版以同 source 驗證四首原創 Cobalt／Violet／Amber／Silver；current Violet 為 index 1，真正 restore、Play／progress 0、曲庫 1,969 且沒有自動播放。這是限定 Mac 路徑證據，不取代完整佇列矩陣。
- 同一最後 source 的 Mac 原創 MOV 路徑已有限通過：Play→Pause 約 1.133872027 秒，月環→standalone native player 約 1.1291 秒且保持 paused，Return to Moon 後時間未改變；EOF 後 Not Playing／empty，清除本次原創影片後曲庫 1,969。這只證明單一 fixture 路徑，不代表 mixed media race、PiP 或聽感認證。
- App Store Connect Content Rights 已保存 `DOES_NOT_USE_THIRD_PARTY_CONTENT`，主要類別為 Music；產品不內建歌曲、影片或圖片，範圍是 local user-authorized media。這是商店選項與產品範圍證據，不等於所有私人音樂已有可散布授權；rights forms 仍待完成。
- 四首本專案原創 WAV 與 pinned BS1770 的獨立比較均在 ±0.1 LU 內，最大絕對差 0.000324。這只是 fixture-level loudness 比較，不代表 EBU 認證、全 genre 覆蓋或完整 release gate。

## 2026-10-09 商店素材拍攝準備（歷史）

最新來源重新核對 95/95 bytes 與 SHA 一致，Mac Desktop 執行檔仍符合
`sidebar-count-fixed-artifacts-01` 的 Development 成品，版本為 2.0（1）；六份既有
原創媒體 SHA 也全部符合 canonical manifest。沒有本次產品來源漂移或必須重建的證據。
三份準備證據封存於 `.cmv-local-evidence/2026-10-09-task-zero/store-capture-preflight-01/`，
manifest SHA 為 `78e2fda96c8cf390ac3e4ff801d948ccb2a7166ceba2ffcc2cdc13fb8341c820`。

[拍攝清單](ReviewMedia/store-capture-plan.json)定義兩平台、三語與五種畫面，共 30 個
截圖位置，逐張需保存尺寸、版本、runtime SHA、來源 SHA、原創媒體 SHA 與人工畫面檢視。
依 [Apple 現行規格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)，
Mac 使用指定 16:10 尺寸；iPad 必填 13 吋級別（2064×2752 或 2048×2732，亦接受橫向）。
目前實機鏡像尺寸不能代替該必填級別。可先拍同候選素材並標暫定，最終 RC4 鎖定與
來源一致後才升格；來源若變更，重拍受影響的畫面。

這是 2026-10-09 的拍攝準備驗證；當時實際截圖 0、連續影片未錄製、未上傳，沒有取代 RC4、實機矩陣或
正式四席核准。審核用無剪輯操作影片與商店 App Preview 分開處理，不混稱已完成。

## 2026-10-23 素材進度

- 四張新實機截圖已完成：Mac 兩張 2880×1800、iPad 兩張 2360×1640，全部為橫向。
- 兩張 image_gen 裝置 mockup 已完成，並在素材紀錄中標示為 mockup，不當成實機擷取。
- 13 吋 Simulator 橫向圖仍在補拍；final archive／export／upload／遠端回讀及送審仍 pending。

## 審核操作流程

1. 在 Settings → Music Sources → Add Music Source，或由側欄選擇 Add Music，透過系統 picker 選取有權使用的資料夾。
2. NAS 先由 Finder／Files 掛載；CMV 不要求或保存 NAS 帳密。
3. 確認背景索引進度與 Music Library，測試音訊播放、搜尋、最愛、評分、歌單與佇列。
4. 選取有權使用的相容影片，驗證 Mac 獨立視窗與 iPad 子母畫面。
5. 強制終止並重新開啟，驗證來源授權保留且不會自動開始播放。
6. 用 Apple Sandbox 帳號驗證一次性 Pro 購買、還原與權益；再測試離線釘選、
   智慧預取、本機分析、Smart DJ 與 Pro 主題。單元測試不取代此項實機證據。

免費功能不要求帳密；Pro 由 Apple Sandbox 驗證。原創素材產生器與權利說明見
`Native/ReviewMedia/README.md`；上述公開 fixture 可供重現有限流程，但不等同於完整
雙平台無剪輯示範影片或 Sandbox 驗收，未完成項目不得宣稱完成。

## 無剪輯實機影片 shot list

每個平台各錄一段連續影片，不剪接、不遮住系統提示：

1. 顯示 App 版本與平台。
2. 以系統 picker 加入 rights-cleared 本機資料夾。
3. 顯示背景索引進度、歌曲列表與立即播放。
4. 展示 queue、評分、最愛、歌單、shuffle／repeat、背景／鎖屏控制。
5. 斷開來源後顯示曲庫仍保留、離線釘選仍可播放，再重新授權。
6. iPad 額外展示 Files provider、Split View、背景播放與 PiP；Mac 額外展示影片
   utility window 與回到月環。

## MediBuddy 2.1 經驗的處理規則

- 若 Apple 要的是操作方法、測試環境或影片，先補完整 Review Notes／影片並在
  Resolution Center 回覆；沒有程式缺陷證據時不要盲目重建 build。
- `Waiting for Review`／`In Review` 只代表等待或審核中，不等於完成。
- 若 Apple 指出實際 crash、缺功能或 metadata 與 binary 不一致，才建立修復任務、
  重跑相同 gate 並決定是否上傳新 build。

## 最新 checkpoint｜2026-10-03

- ASC Draft 15／15 目標欄位 exact、24／24 保護欄位 exact；三語四個 canonical 欄位已完成 Gemini 整合，首發 What’s New 未寫入 live Draft。
- 初版 Marquee candidate 的 Mac 佈局曾真實失敗，後以 `onGeometryChange`、positive-width guard 與 fixed container 修正；Debug binary `e913939…`／ad-hoc source `440bda…` 的限定驗收 PASS：Medium 全文、Small metadata 往返可讀，short title／Not Playing 靜態狀態與完整 AX labels 通過。Reduce Motion、完整 VoiceOver 與性能未驗。
- 新 Distribution 修正版仍在建置；舊 qualification 不能代表最新 source。Mac 同 source 已驗證 Cobalt 兩 occurrences → 移除第二個 future 後一個 paused current／progress 0 → quit／relaunch 還原一個 paused current；Clear own queue 後曲庫維持 1,969。
- iPad 第一 candidate install 成功但 launch 仍 Locked，沒有新的 WDA 證據，解鎖待處理。Sandbox、pending tests、critics、screens／demo 與完整雙平台矩陣仍未完成。

### 最新 final-candidate checkpoint

- 最新 `marquee-layout-final` candidate 與 67 項 compile inputs 相符；Mac Release universal archive／qualification／package 簽章、iOS archive／export／IPA qualification、iPad Debug compile／codesign 均通過。這不是 formal RC，尚未 upload。
- Mac Desktop Release 覆蓋成功；ad-hoc test binary `8bee1cc9b062c9b099dbded1aab55f63a60026e075af92de3ff31bfe595b59ad` 啟動後曲庫 1,969、空佇列、short title 靜態狀態與 long metadata 往返可讀，限於此路徑 PASS；完整 AX／VoiceOver、Reduce Motion、性能 benchmark 未驗。
- iPad 最新 source install 遇 CoreDevice 4000 disconnected，未 launch／未取得 WDA。後續狀態曾回報 `passcodeRequired=true`、`unlockedSinceBoot=true`；後者不代表目前 unlocked。已再次請使用者解鎖，無 build 等待，暫列 ToolLimited。其餘 Sandbox、pending tests、critics、screens／demo 與完整矩陣仍未完成。

#### 解鎖後最新實機驗收

- Fresh 解鎖後 latest Debug binary SHA `1f973a2c67ac28d74c62f86864dfeafce512c5a284805079ee302cd628368545` ；裝置即時 `passcodeRequired=false`；install／launch success，短案例耗時 58 秒／總上限 170 秒。25 首曲目與 portrait 5 欄 cover 均留在各自 card 內，限定 visual PASS；raw nested video AX image width 230 仍在，未宣稱完整 AX bounds PASS。
- Marquee 完整 AX labels 與 frame movement 有證據，但完整 cycle、獨立 short case、Reduce Motion、VoiceOver、性能未驗。Up Next 為 Synced／25 total，Play 可見且 paused；沒有 queue mutation 或播放。
- owned WDA DELETE HTTP 200；host port 不可連，SIGINT 後診斷停滯，僅終止本次自有 controller，相關程序已消失。私人曲庫封面與 raw receipts 不公開；先前 CoreDevice／Locked 失敗保留為歷史紀錄。其餘 Sandbox、pending tests、critics、screens／demo 與完整矩陣仍未完成。

## 送審前狀態

2026-10-03 completion council 已完成三席獨立盲評及第四席仲裁，結論 blocked。已補最後 Release 桌面同曲兩筆正常重啟、暫停及進度 0 的完整 AX；qualification 另保存三次 exact Distribution 2.0(1) 指令與產物綁定收據。仍欠完整宣稱功能的同版驗收、Pro pending／Sandbox 與無障礙等 coverage，沒有最終獨立收斂複查，未 upload／送審。評論工具 27／24 次超額已記錄；raw 稿件與私人曲庫證據排除 Git。

- [x] Privacy Policy URL 公開可讀。
- [x] Support URL 與公開客服聯絡方式已建立。
- [x] 審核聯絡資料依使用者授權沿用已上架 App，已填入兩平台。
- [x] Review Notes 已填入正確 iOS 與 macOS 2.0 version。
- [x] 原創 fixture 的公開下載位置、SHA-256 與有限 iPad Files／佇列證據已記錄。
- [x] 前一輪 source 的 Mac／iOS candidate archive、signed package 與 IPA qualification 已記錄；Marquee source 變更後需重建，尚未 upload。
- [x] 最後 source 的 iPad install／launch 與限定 QA 結果已記錄；enqueue、重排、restore 等未知項目仍保留未完成。
- [x] Mac candidate 的 queue restore／no-autoplay 限定證據已記錄。
- [x] Mac 原創 MOV 單一路徑與 App Store Connect Content Rights 選項已記錄；不等於完整影片矩陣或所有私人媒體授權。
- [ ] Mac／iPad 完整 Review media 與雙平台無剪輯影片已驗收。
- [x] App Privacy「不收集資料」已核對；使用者同意後發佈，Apple 後台顯示已發佈。
- [ ] 最終 RC／Distribution archive／Sandbox 與實機矩陣已完成。
- [ ] 最終公開差異已檢查無私人帳號、憑證或 NAS 帳密。

### 2026-10-08T23:30:12.622956+08:00 iPad metadata/sort delta

2026-10-08 iPad 八欄 metadata 與六欄十二方向首頁切片完成，11 payload manifest 20d70670aaad6cf4ae83f0bd5500c41dc3c3231dce8baebf796528810ce7decb。preview未寫入/only2八欄/其餘618不變/undo620八欄 exact；Song Info 八欄及時長/加入日期直接可見，當日default日期不冒日曆編輯。sort每組前12對205真實資料 strict exact，末頁/跨分頁/時長評分distinct仍待。測後9表全欄列/queue268→271非revision/effects encoded/全部prefs exact，GUI原19首0:00paused。誤點兩首owned離線釘選新增2失敗0，cache不冒還原。WDA host04意外exit65，host05 existing product/test timeout NO與relay06恢复，未重build或重裝CMV。Mac當次剩8,245,516KiB，不冒30GB目前空間。任務原狀態保留，未上傳/送審。
