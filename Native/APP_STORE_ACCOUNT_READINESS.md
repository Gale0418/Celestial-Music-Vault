# CMV 發行帳號唯讀盤點

核對日期：2026-10-03。此盤點只確認可繼續準備發行，不代表 RC、正式簽章、上傳或送審已通過。

| 項目 | 結果 | 來源與限制 |
| --- | --- | --- |
| App Record | Ready | Apple API 回讀 App ID `6815468050`、Bundle ID `com.windsheep.cmv`、主要語言 `zh-Hant`。 |
| iOS／macOS 版本 | Ready | 兩平台 2.0 為 Prepare for Submission；三語 metadata 已寫入並逐欄回讀。尚無本輪 VALID Build。 |
| API／瀏覽器登入 | Ready | 已能以既有 Keychain API 認證讀寫 CMV 草稿；Chrome 的 App Store Connect 登入可讀商務頁。未新增帳號權限。 |
| 免費 App 協議 | Ready | 商務頁顯示有效，期限至 2027-08-02；只讀取，未接受新合約。 |
| 付費 App 協議 | Ready | 商務頁顯示有效，期限至 2027-08-02；只讀取，未接受新合約。 |
| 銀行／稅務 | Ready | 商務頁銀行狀態使用中，台灣及美國稅表已完成。不公開銀行、地址、稅務或個人聯絡細節。 |
| 歐盟 DSA | Ready | 商務頁顯示通過審查。不將此狀態推論為其他地區法規皆已完成。 |
| 最終隱私聲明 | Ready | 「不收集資料」草稿已核對；使用者已同意法律確認並發佈，Apple 後台顯示已發佈。 |
| RC／Distribution／實機／Sandbox | Blocked | 由 AERO-RC4、SG4、DV4、MON30 分別驗證，不能由帳號盤點取代。 |

本機執行階段保存 Apple API 回讀與商務頁畫面；含帳號資訊的證據存於 Git 忽略目錄，公開文件只保留狀態及日期。讀取與登入成功不能保證未來認證不會到期；上傳前應再確認當時的權限和合約狀態。
