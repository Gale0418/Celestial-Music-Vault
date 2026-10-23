# CMV 發行帳號唯讀盤點

## 2026-10-23 最新覆核

iOS／macOS 的 2.0（1）已於 10 月 9 日成功上傳並提交；10 月 23 日直接從 App Store Connect 核對，兩平台目前為 **REJECTED**，不是尚無 build 的草稿。iOS 有 App 與 Pro IAP 兩個提交項目；Pro IAP version 為 READY_FOR_REVIEW，仍掛在同一份拒審提交。macOS 拒審點為實際操作截圖及 Apple Music 用途說明；iOS 要求提供 Pro 操作路徑。準備中的修正版為 2.0（2），尚未重新上傳或送審。下方 10 月 3／8 日紀錄皆為歷史時點，不能當作目前狀態；詳見 [本輪修復紀錄](REVIEW_FIXES_20261023.md)。

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

## 2026-10-08 任務清零唯讀回讀

App Record已存在。完整版本列表只有iOS/macOS 2.0草稿（PREPARE_FOR_SUBMISSION），完整uploaded build列表0，沒有目前可用VALID Build。兩平台三語localization與Support URL已存在，但六組截圖/preview集合均為0。MediBuddy審核聯絡及版權先前已依授權沿用，不需再次建立帳號或App Record；其他產品公開版本不能當作CMV已上架。證據：`.cmv-local-evidence/2026-10-08-task-zero/initial-reconciliation/`。

補充：同帳號 GAI 與 MediBuddy 版本列表均有 READY_FOR_SALE 歷史版本；CMV `com.windsheep.cmv` 目前回讀沒有此狀態。這項結果只涵蓋目前帳號及此 App Record，不排除其他名稱、Bundle ID 或帳號的歷史版本。三語 App Info 與兩平台版本公開文案共33欄已再次逐欄核對一致；初次比較器漏列7個 URL 標籤，已另存修正收據，沒有變更遠端資料。
