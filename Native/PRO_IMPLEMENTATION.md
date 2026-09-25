# CMV Pro 實作與驗收紀錄

日期：2026-09-08；任務：AERO-MON30（In Progress）。

這份紀錄描述可編譯的施工切片與 2026-09-26 的商店設定，不是 App Store 已可販售的聲明。
正式商品已建立、商務協議已核對且審核截圖已上傳，但沙盒驗收仍待完成；上市全文仍以
[商業草案](MONETIZATION_DRAFT.md) 的完整功能情境為準。

## 已採用的邊界

- StoreKit 2 負責 Apple 簽章交易；Swift Domain 放共用權益狀態與功能政策。
  不加入購買伺服器、追蹤 SDK 或 Rust StoreKit 包裝。
- 啟動先讀裝置上的 `Transaction.currentEntitlements`；商品價格查詢失敗
  不能直接等同沒有購買。只接受指定 ID 的 verified non-consumable。
- `Transaction.updates` 監聽延遲核准、其他購買與撤銷；購買／恢復操作互斥。
  尚未核准、取消或暫時錯誤不清除已驗證權益；舊快照不能覆蓋新交易。
- `AppStore.sync()` 只由「恢復購買」明確觸發。價格來自 `Product.displayPrice`。
- Info.plist 的 `CMVProProductID` 接 `CMV_PRO_PRODUCT_ID` build setting，
  Debug／Release 均指向已由 Apple API 回讀的 `com.windsheep.cmv.pro.v1`。
  商店回傳錯誤類型或無商品時不能購買；本機 StoreKit fixture 仍使用獨立測試 ID。

## 2026-09-26 商店設定

- App Store Connect App ID `6815468050`：`com.windsheep.cmv`，iOS＋macOS 同一紀錄，主要語言繁體中文。
- App 本體台灣價格為免費；現有 175 個地區已設可用，但 App 尚未發佈。
- Pro 商品 ID `com.windsheep.cmv.pro.v1`、商品資源 ID `6815468483`：
  `NON_CONSUMABLE`，台灣原定價 NT$290；2026-09-26 依使用者決定改為 NT$150，
  `asc iap pricing summary` 已回讀 `TWD 150`。繁中與英文購買名稱／描述已回讀。
  現有 175 個地區設可用；沒有啟用不可撤銷的家庭共享。
- 商品的真實 iPad 升級頁截圖已上傳（資源 ID `3d8c1597-c3fd-46e1-8411-9264d81e913e`，
  `assetDeliveryState=COMPLETE`），狀態已由 `MISSING_METADATA` 變為 `READY_TO_SUBMIT`；
  尚未送審，仍需 StoreKit Sandbox 測試。App Store Connect 商務頁已唯讀確認免費／付費協議有效、
  收款與稅務狀態已完成；上述狀態仍不代表可以購買或已提交審核。
  本地留存 [iPad 升級頁截圖](StoreKit/evidence/pro-review-20260926-ipad.png)。

## 實際操作分界

| 操作 | 本次行為 |
| --- | --- |
| 本機／NAS 基本播放、既有快取播放 | 免費；不因退款刪除使用者的檔案 |
| 搜尋、基本歌單、收藏評分、加入／清除日常佇列 | 免費 |
| 新離線釘選、背景智慧預取 | Pro；動作層檢查，逐首預取前再檢查 |
| 取消離線釘選 | 免費；同曲操作防重入 |
| 銀河月夜、星海晨光 | 免費主題；既有免費主題偏好相容保留 |
| 新選用綿羊幻想鄉、木星深空站 | Pro；已選主題保留，不在啟動或退款時重寫偏好 |
| 聲學分析、Smart DJ 產生 | 動作層 Pro 檢查；Smart DJ 推薦／播放與現在收聽分析入口已接入，實機、離線與大型曲庫驗收仍由 AERO-SD4 承接 |
| 進階批次編輯 | 政策已保留 feature；未實作的工具不以空按鈕假裝完成 |

升級頁由設定與付費操作進入，使用原生 sheet、可捲動內容、固定底部購買／恢復操作、系統字級與明確完成鍵。
目前頁面列出此切片可用的離線／主題利益與 Smart DJ 推薦；聲學分析與進階整理全部完成後，
再依實際 RC 增補。完成或關閉升級頁不會改變目前播放與曲庫。

## 跨領域檢查

Antigravity Gemini 完成唯讀架構挑戰，請求 `cmv-pro-architecture-20260908-02`，
conversation `c7905386-ec4f-4fdb-a2f4-bfc450b4e0af`，沒有工具寫入。
採納離線權益、退款後清理入口、進行中播放不中斷與 VoiceOver 路徑檢查；
不採納「退款後限制使用者既有快取播放」的建議。

## 研究來源與授權

- [Apple currentEntitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements)：
  non-consumable 現有權益；退款／撤銷不在序列中。
- [Apple AppStore.sync](https://developer.apple.com/documentation/storekit/appstore/sync())：
  明確恢復時強制同步，日常讀取不需要每次要求同步。
- [Apple StoreKit 本機測試](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-in-xcode)：
  正式商品建立前仍可配置本機測試交易。
- GitHub prior art：`BaidetskyiYurii/StoreKitGiftApp` 的
  `dc55af8efd9c084bf3aebaf0dc42ba3413835f8d`。僅核對 `.storekit`
  NonConsumable 的機器欄位與 scheme 引用格式；未見 LICENSE，未複製其程式、
  圖片或文案，也未加入依賴。
- Chrome 存取 Apple 網站遭 browser security policy verification unavailable 阻擋；
  沒有繞過該限制。上述官方內容已在此前以 web／公開 Markdown 文件核對。

## 發行前仍需完成

1. 商品已備齊審核截圖與台灣定價；待功能驗收後才決定何時提交審核。
2. 驗證 iOS 與 macOS 對同一 non-consumable 商品的實際購買／恢復權益。
3. 兩平台本機 StoreKit 與 Sandbox：購買、重複點選、取消、待核准、核准更新、
   無商品、驗簽失敗、退款／撤銷、恢復、已購離線冷啟動。
4. 實際 VoiceOver／Dynamic Type、使用者資料保留與免費播放回歸。
5. SD4／I13 等功能完成後更新升級頁，並與 App Store 商品描述核對。

本機 StoreKit fixture 的 `local.cmv.pro.test` 與金額 `1.00` 僅供測試，
不可拿來代替正式商品或 Sandbox 驗收。

## 本次可核對的驗證證據

- 完整 Swift package 測試 **48 tests／0 failures**，包含 8 個 Pro policy／交易順序測試。
  已保存 [測試輸出](StoreKit/evidence/swift-tests-20260908.txt) 與
  [來源 SHA-256](StoreKit/evidence/validation-20260908.json)。
- `ProStore.swift` 最後修正的 Swift 6／macOS 15 獨立型別檢查通過。
- 加入交易身分／簽署時間防護後，最後版本 **Mac Debug／iPad Simulator Debug
  皆編譯成功（exit 0）**；這不是 Distribution／實機驗收。
- Mac 使用獨立 bundle ID `local.cmv.pro.qa` 與空白曲庫：設定入口、未配置商品
  的 disabled 購買、恢復錯誤、完成返回、選用 Pro 主題的升級入口均已操作確認。
  最後版本 Mac Debug 編譯 exit 0、隔離 App strict ad-hoc 簽章驗證通過；
  截圖 `.impeccable/review/pro-macos.png` 已更新為最後文案，Escape 返回設定通過。
- StoreKit standalone runner 已編譯成功，但 host 回 `SKInternalErrorDomain Code=3`，
  `Product.products=[]`，runner 正確 exit 1。它未通過交易驗收。
  XCTest app host 的另一次嘗試停在建置服務階段，亦未抵達交易測試。
- 本機磁碟滿（I/O code 28）中斷過測試與增量建置；完整 Swift tests 在回收本次
  已完成的暫存後成功。新建 iPad QA simulator 已關閉與刪除；未清理使用者
  既有模擬器或其他任務資源。共享磁碟 DerivedData 另遇工具錯誤，因此最終
  Xcode 建置改回本機逐平台執行。
- 2026-09-08 時 iPad UI 尚未到達升級頁；2026-09-26 已由模擬器走到 Smart DJ／Pro
  並核對購買與恢復按鈕。正式 Sandbox、已購離線冷啟動與完整無障礙矩陣仍未完成。
- 未向 CodeRabbit 上傳本次程式；使用獨立 Luna 審查，不能稱為 CodeRabbit 通過。
  首輪確認的舊購買結果蓋掉退款競態已修正並加回歸測試；Luna 複查判定 resolved，未發現新的明顯高影響錯誤。
