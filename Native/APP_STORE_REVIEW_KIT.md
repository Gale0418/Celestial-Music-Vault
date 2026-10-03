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

以下測試流程供影片與人工驗收使用，不能取代尚未完成的實機／Sandbox 證據。

## 審核操作流程

1. 在 Settings → Music Sources → Add Music Source，或由側欄選擇 Add Music，透過系統 picker 選取有權使用的資料夾。
2. NAS 先由 Finder／Files 掛載；CMV 不要求或保存 NAS 帳密。
3. 確認背景索引進度與 Music Library，測試音訊播放、搜尋、最愛、評分、歌單與佇列。
4. 選取有權使用的相容影片，驗證 Mac 獨立視窗與 iPad 子母畫面。
5. 強制終止並重新開啟，驗證來源授權保留且不會自動開始播放。
6. 用 Apple Sandbox 帳號驗證一次性 Pro 購買、還原與權益；再測試離線釘選、
   智慧預取、本機分析、Smart DJ 與 Pro 主題。單元測試不取代此項實機證據。

免費功能不要求帳密；Pro 由 Apple Sandbox 驗證。原創素材產生器與權利說明見
`Native/ReviewMedia/README.md`；實際可下載媒體、測試裝置／OS 與無剪輯示範影片
必須在完成後補進 Notes，尚未提供的項目不得宣稱完成。

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

## 送審前狀態

- [x] Privacy Policy URL 公開可讀。
- [x] Support URL 與公開客服聯絡方式已建立。
- [x] 審核聯絡資料依使用者授權沿用已上架 App，已填入兩平台。
- [x] Review Notes 已填入正確 iOS 與 macOS 2.0 version。
- [ ] Mac／iPad 完整 Review media、可下載位置與無剪輯影片已驗收。
- [x] App Privacy「不收集資料」已核對；使用者同意後發佈，Apple 後台顯示已發佈。
- [ ] 最終 RC／Distribution archive／Sandbox 與實機矩陣已完成。
- [ ] 最終公開差異已檢查無私人帳號、憑證或 NAS 帳密。
