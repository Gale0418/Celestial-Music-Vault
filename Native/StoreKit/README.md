# CMV Pro 本機 StoreKit 交易測試

`CMVProLocal.storekit` 只包含 `local.cmv.pro.test` 這個本機專用、一次性 `NonConsumable` 商品。它不是 App Store 正式商品，也不會使用 Apple ID 或真實付款。

## 在 App 畫面測試

1. 以 Xcode 開啟 `Native/CMV/CMV.xcodeproj`，選 `CMV-StoreKit-Local` Scheme。
2. 先選 iPad Simulator，按 Run；此 Scheme 的 Run 選項已連到 `CMVProLocal.storekit`，並只在 Debug 啟動時傳入本機商品 ID。
3. 在 App「設定 → CMV Pro」確認顯示測試價格，再測購買、恢復與權益變化。這是模擬交易，不需 Sandbox 帳號，也不會扣款。

一般 `CMV` Scheme、Release／Archive 與手動安裝後從主畫面啟動的實機 App **不會**自動使用這份本機設定。要在實機跑同一個本機情境，需以 Xcode 選本測試 Scheme 對已配對 iPad 按 Run；只用 `devicectl install`／`launch` 不會啟用 Xcode 的 StoreKit Configuration。此 Scheme 沿用原 App 的 bundle ID，實機 Run 可能覆蓋裝置上同 ID 的既有安裝；在確認備份或使用隔離 QA bundle ID 前不要直接執行。正式 Sandbox 測試另需 App Store Connect 已建立的商品與 Sandbox 測試帳號，不能用這個本機商品 ID 代替。

從 repository root 執行：

```sh
Native/StoreKit/run-cmv-pro-storekit-test.sh
```

runner 會在 `/private/tmp` 建立一次性 app host，直接編譯正式 `CMVDomain/ProAccess.swift` 權益政策與 `Native/CMV/CMV/ProStore.swift`，以 Apple `StoreKitTest.SKTestSession` 載入設定，並依序驗證：

- `Product.products` 可取得 `NonConsumable` 商品
- `ProStore.purchase()` 成功後授予 Pro
- 新的 `ProStore` 透過本機 `Transaction.currentEntitlements` 恢復（未關閉網路，不算離線冷啟動證據）
- `SKTestSession.refundTransaction` 後撤銷權益
- `askToBuyEnabled` 的 pending 與核准流程

只會由本 runner 呼叫 `session.clearTransactions()`；不要把正式商品 ID 放進這個設定檔。

若執行時看到 `SKTestSession Error saving configuration file: SKInternalErrorDomain Code=3`，或 `Product.products` 為空，代表目前 macOS/Xcode 執行環境沒有提供可用的 StoreKit 本機測試服務。這不是交易測試通過；請保留完整 stderr，需將同一測試邏輯接入 Xcode 啟動的測試 host；本 shell runner 本身不支援 simulator。這個後續 host 尚未驗收。

2026-09-24 驗證：`CMV-StoreKit-Local` 的 iPad Simulator Debug 建置通過；Xcode Run 選項可找到設定檔，啟動後程序含本機測試 ID，Xcode 的交易管理器列出 `CMV Pro Local Test Only`。模擬器 App 已進入設定頁，但尚未取得升級頁價格／購買完成的畫面證據。上述 shell runner 再跑仍回 `SKInternalErrorDomain Code=3` 與空商品集合，因此不能記為交易矩陣通過。

同日再次 Xcode Run 的建置／安裝完成，但 App 停留白色啟動畫面超過 60 秒；已停止該次執行。Xcode 交易管理器先前建立的一筆本機合成交易保留在模擬器供後續測試，不能把它視為 App 內購買成功或 Sandbox 驗收。另一專案 G.A.I 的本機 StoreKit 商品與 CMV 商品不同，其測試紀錄也不能充作 CMV 的購買證據。
