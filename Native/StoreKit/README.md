# CMV Pro 本機 StoreKit 交易測試

`CMVProLocal.storekit` 只包含 `local.cmv.pro.test` 這個本機專用、一次性 `NonConsumable` 商品。它不是 App Store 正式商品，也不會使用 Apple ID 或真實付款。

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
