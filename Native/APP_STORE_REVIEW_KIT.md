# CMV 2.0｜App Review Kit

更新：2026-10-03

這是實機示範與審核回覆的操作清單。三語商店與 App Review Notes 的 canonical
來源位於 `Native/AppStoreMetadata/`，避免複製文案後產生不同版本。私人審核聯絡資料
只在 App Store Connect 與權限受限的執行階段資料中使用，不放進版本控制。

## Release identity

- App：星穹私藏音樂庫 Celestial Music Vault
- Bundle ID：`com.windsheep.cmv`
- Version／build：`2.0`／`1`（上傳前以遠端安全 build number 為準）
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
