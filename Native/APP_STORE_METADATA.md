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

- `en-US.md`：Name 21、Subtitle 26、Keywords 77、Promotional text 145 字元。
- `zh-Hant.md`：名稱 7、副標題 13、關鍵字 36、宣傳文字 53 字元。
- `ja-JP.md`：名前 21、サブタイトル 10、キーワード 47、プロモーションテキスト 66 字元。

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
