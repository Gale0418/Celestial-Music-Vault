# 星穹私藏音樂庫 Celestial Music Vault（CMV）2.0｜App Store Connect metadata gate

更新：2026-10-03

這份文件是商店 metadata 的總覽與送審前核對表。三種語言的 canonical 欄位位於：

- [en-US canonical metadata](AppStoreMetadata/en-US.md)
- [zh-Hant canonical metadata](AppStoreMetadata/zh-Hant.md)
- [ja-JP canonical metadata](AppStoreMetadata/ja-JP.md)

欄位檔描述目前原生產品可由程式碼／既有文件支持的範圍。X14 的 Smart Playlist、歌詞與背景來源變更 watcher 是延後評估，不得寫入本版商店功能宣稱。

## 已核對的固定資料

- App 名稱：`星穹私藏音樂庫 Celestial Music Vault`
- 版本：`2.0`；目前版本號／build 以正式上傳前的 archive 與 App Store Connect 回讀為準
- Bundle ID：`com.windsheep.cmv`
- 類別：Music
- 支援平台：macOS 15+、iPadOS 18+
- 產品定位：本機／已掛載 NAS 的私人影音曲庫播放器；不含 CMV 帳號、雲端同步、廣告或第三方追蹤
- 公開 Privacy Policy URL：`https://github.com/Gale0418/Celestial-Music-Vault/blob/main/PRIVACY.md`
- 公開 Support URL：`https://github.com/Gale0418/Celestial-Music-Vault/blob/main/SUPPORT.md`
- URL 狀態：本輪工具匿名回讀結果為 HTTP 200；送審前再確認 URL 仍可讀
- 公開支援信箱：`coderb0418@gmail.com`
- 方案：免費下載＋一次性 CMV Pro non-consumable
- Pro 商品 ID：`com.windsheep.cmv.pro.v1`
- 台灣 storefront 價格：NT$150；商店文案不把這個單一地區價格寫成所有 storefront 的固定價格
- App icon：`Native/CMV/CMV/Assets.xcassets/AppIcon.appiconset/`；實際 archive 仍須重跑資格檢查

## 三語欄位驗證

三份 canonical 檔案均包含 Name、Subtitle、Keywords、Promotional text、Description、What’s New、Privacy URL、Support URL、支援信箱、版權欄位與 App Review notes。Name／Subtitle／Keywords／Promotional text 已以 Apple 常用上限 30／30／100／170 字元檢查；description 與 What’s New 均遠低於 4,000 字元上限。

本機欄位檢查結果：

- `en-US.md`：Name 21、Subtitle 29、Keywords 77、Promotional text 168 字元。
- `zh-Hant.md`：名稱 7、副標題 24、關鍵字 36、宣傳文字 87 字元。
- `ja-JP.md`：名前 21、サブタイトル 22、キーワード 47、プロモーションテキスト 87 字元。

上述是檔案內容與字數檢查，不是 App Store Connect 寫入或審核結果。

## 發布者仍須補入或確認的資料

這些欄位涉及法律責任、商店帳號或實際展示素材，不能由 repository 推定：

1. 版權欄位已沿用使用者授權的已上架 MediBuddy 公開權利人 `2026 Gale0418`，並寫入兩平台版本。
2. App Review contact 已沿用使用者授權的已上架 MediBuddy 審核資料，寫入兩平台且不要求登入；私人聯絡資料只留在 Apple 後台與本機私有 runtime 檔，三語公開文件保留 marker。
3. 年齡分級、版權聲明、出口合規與 App Store Connect privacy questionnaire。
4. 同一個已凍結 RC 產出的 Mac／iPad screenshots、preview video 與實機測試日期／平台。
5. `Native/ASSET_RIGHTS_LEDGER.md` 中仍為 Blocked 的 Review audio／video／cover 與商店截圖權利證據；icon 與主題素材已由使用者確認為本專案 Codex 創作，相關紀錄見 ASSET_PROVENANCE.md；素材必須能證明商業散布與修改範圍。
6. 正式 Distribution archive、embedded entitlements、Privacy Manifest 與 dSYM／binary 對應；canonical metadata 檔不取代該驗收。

## 文案邊界

可描述的目前功能包括：本機與已掛載 NAS 曲庫、搜尋、metadata 瀏覽、最愛、評分、一般歌單、基本佇列、音訊與相容影片播放、iPad 背景音訊／子母畫面、Mac 影片獨立視窗，以及 CMV Pro 的離線釘選、智慧預取、額外主題、本機聲學分析與 Smart DJ。正式上傳前仍須以同一 RC 的實機與 Pro Sandbox 證據確認。

不可描述為本版已提供的功能：獨立最近播放 preset、可保存規則 Smart Playlist、歌詞服務、背景檔案 watcher、即時自動重掃、雲端同步或串流音樂內容。X14 評估可結案不等於這些延後功能已實作。

截圖與 preview 只能使用自有或明確授權的音訊、影片、封面、字體與插圖；不得使用商業專輯封面、串流服務畫面、YouTube／VTuber 影片或權利不明的私人媒體。Mac 與 iPad 素材必須來自同一已凍結 CMV RC，不混用舊 bundle、臨時 `/tmp` 截圖或不同主題狀態。

App 介面已有 `en`／`zh-Hant`／`ja` 字串資源，但商店頁的三語輸入、截圖、權利資料與 Review notes 仍須在 App Store Connect 逐欄建立並由發布者核對。canonical 檔案是可審閱來源，不是遠端商店已寫入的證據。

## App Privacy 對照

程式會在裝置本機保存使用者授權資料夾的 security-scoped bookmark、相對路徑／檔案識別、媒體 metadata／封面、歌單、最愛、評分、播放／跳歌紀錄、BPM／調性／響度分析、主題偏好與離線快取。這些資料不傳給開發者或第三方，因此可依實際 build 與 Privacy Manifest 填寫「不收集」；公開隱私政策仍須清楚說明本機處理、刪除方式與 NAS 連線模型。CMV 不做 SMB 登入、LAN 掃描、雲端同步、廣告、追蹤或第三方分析。

## Review／提交核對順序

1. 發布者確認法律權利人、Review contact、年齡分級、出口合規與素材授權。
2. 由同一凍結 RC 產出雙平台 archive、screenshots、preview 與 Review media，核對功能文案不含 X14 延後項目。
3. 在 App Store Connect 建立三語 metadata、Privacy questionnaire 與一次性 Pro 商品資料；價格以各 storefront 顯示為準。
4. 以正式 archive 做 upload validation，再用 TestFlight／Sandbox 核對購買、恢復、離線與核心播放路徑。
5. 保存遠端回讀、處理狀態與 Review notes 證據；Waiting for Review／In Review 不等於已上架。

本文件與三語 canonical 檔案不保存 Apple ID、API key、憑證、NAS 帳密或私人媒體。

## 2026-10-03 App Store Connect 草稿寫入與回讀

本輪已將三語 app-info 與兩平台 2.0 version metadata 寫入 App Store Connect。每組三個 locales 全數成功，逐欄回讀共 33 欄與 canonical 一致，0 mismatches。首次上架版本不接受 What’s New，CLI 明確回報後省略該欄；檔案保留內容供日後版本使用，不把它當成本次已寫入。公開 Support／Privacy URL 已填入。審核聯絡與版權欄位依使用者明確授權沿用已上架 MediBuddy 資料；私人姓名、電話與帳號不進 repository。

年齡問卷按現存功能與原創 App 素材填寫 NONE／false；CMV 無內建網頁瀏覽、內容廣泛分享、社群、聊天或廣告。本機使用者選取媒體不等於 App 的內容廣泛散布，採 Apple [age ratings 定義](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/) 的 User-Generated Content 範圍判讀。尚未宣稱問卷的最終審核結果、Build 上傳或正式送審完成。

## 2026-10-03 最新送審證據與限制

- 解鎖後最後 source 的 iPad Debug install／launch 成功；binary SHA-256 `f7f9105e356d249183248d7a5d73a8ca173c29aab69ebcfe4161d31724ea2786` 與 final source manifest 相符。25 首原創 fixture、Track Info English、release `Not Available` 與多選 2 項 UI 通過；enqueue 為 Unknown，重複 future remove、重排與 terminate／restore 未驗證。
- 同一最後 source 的 Mac 原創 MOV 僅完成單一 fixture 路徑：Play→Pause 約 1.133872027 秒，月環與 standalone native player 間切換保持 paused，EOF 後 Not Playing／empty，清除本次影片後曲庫 1,969。這不能支撐 mixed media race、PiP 或聽感認證宣稱。
- App Store Connect Content Rights 已保存 `DOES_NOT_USE_THIRD_PARTY_CONTENT`，主要類別為 Music；主人確認 App 不提供內建歌曲、影片或圖片。CMV 的產品範圍是 local user-authorized media；此選項不等於所有私人音樂均已有商業散布授權，個別 rights forms 仍須完成。
- Marquee overflow scope 已進入 source 修正，Marquee card／PlayerBar 已實作，新的雙平台 build 正在建立。先前 final Distribution archive／qualification 只代表舊 source candidate，不能當作最新 source 的 qualification；正式上傳前需重建並重新回讀。
- 節目級聲學比較摘要已整理於 [ACOUSTIC_REFERENCE_QA_20261003.md](ACOUSTIC_REFERENCE_QA_20261003.md)，但 programme matrix 尚未完成；Sandbox、screenshots、無剪輯 preview、rights forms 與 formal critic budget 仍是未完成項目。

## 最新 checkpoint｜2026-10-03

- ASC Draft 已完成 15／15 目標欄位 exact readback，24／24 保護欄位保持原字；三語 canonical 的 subtitle、promotional text、description、What’s New 已完成 Gemini 文案整合，但首發 What’s New 未 live 寫入。
- 初版 Marquee candidate 的 Mac 佈局曾真實失敗，後以 `onGeometryChange`、positive-width guard 與 fixed container 修正；Mac Debug binary `e913939…`／ad-hoc test source `440bda…` 的限定驗收為 PASS：Medium 全文與 Small metadata 可往返讀取，short title／Not Playing 靜態狀態與完整 AX labels 已核對。Reduce Motion、完整 VoiceOver 與性能仍未驗。
- 新 Distribution 修正版仍在建置；Marquee source 變更前的 qualification 只屬舊 candidate，不能代表最新 source。
- 同一 Mac Debug source 的原創 Cobalt 加入兩次後保留兩個 occurrences；移除第二個 future occurrence 後剩一個 paused current、progress 0；quit／relaunch 還原一個 paused current，最後 Clear own queue 後曲庫仍為 1,969。iPad 第一 candidate 雖 install 成功，但 launch 遇 Locked、未取得新的 WDA 證據，解鎖待處理。Sandbox、pending tests、critics、screens／demo 與完整雙平台矩陣仍未完成。

### 最新 final-candidate checkpoint

- 最新 `marquee-layout-final` candidate 與 67 項 compile inputs 相符；Mac Release universal archive／qualification／package 簽章、iOS archive／export／IPA qualification、iPad Debug compile／codesign 通過。仍是 candidate，非 formal RC，尚未 upload。
- Mac Desktop Release 覆蓋成功；ad-hoc test binary `8bee1cc9b062c9b099dbded1aab55f63a60026e075af92de3ff31bfe595b59ad` 啟動後 library 1,969、empty queue、short title 靜態狀態與 long metadata 往返可讀，限定 PASS；不代表完整 AX／VoiceOver、Reduce Motion 或性能 benchmark。
- iPad 最新 source install 遇 CoreDevice 4000 disconnected，未 launch／未取得 WDA。fresh device available 後曾有 `passcodeRequired=true`、`unlockedSinceBoot=true`，後者只表示曾解鎖，不代表目前 unlocked；已再詢問使用者解鎖，無 build 等待，狀態為 ToolLimited。Sandbox、pending tests、critics、screens／demo 與完整雙平台矩陣仍未完成。

#### 解鎖後最新實機驗收

- Fresh 解鎖後 latest Debug binary SHA `1f973a2c67ac28d74c62f86864dfeafce512c5a284805079ee302cd628368545` ；裝置即時 `passcodeRequired=false`；install／launch success，短案例耗時 58 秒／總上限 170 秒。25 首曲目與 portrait 5 欄 cover 均在各自 card 內，限定 visual PASS；raw nested video AX image width 230 仍存在，不代表完整 AX bounds PASS。
- Marquee 完整 AX label 與 frame movement 有證據；完整 cycle、獨立 short case、Reduce Motion、VoiceOver、性能未驗。Up Next 為 Synced／25 total，Play 可見且 paused，本輪沒有 queue mutation 或播放。
- owned WDA DELETE HTTP 200；host port 不可連，SIGINT 後診斷停滯，僅終止本次自有 controller，相關程序已消失。私人曲庫封面與 raw receipts 排除公開；先前 install／launch failure 保留為歷史紀錄。Sandbox、pending tests、critics、screens／demo 與完整雙平台矩陣仍未完成。
