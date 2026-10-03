import Foundation
import StoreKit
import StoreKitTest

/// Standalone host keeps source-language messages deterministic; the app target
/// continues using its real AppLanguage implementation and string catalogue.
enum AppLanguage {
    @MainActor static func localized(_ key: String) -> String { key }
}

@main
@MainActor
struct CMVProStoreKitRunner {
    static let productID = "local.cmv.pro.test"

    static func main() async {
        do {
            guard let configURL = Bundle.main.url(forResource: "CMVProLocal", withExtension: "storekit") else {
                throw RunnerError("找不到隨 app bundle 打包的 CMVProLocal.storekit")
            }

            let session = try SKTestSession(contentsOf: configURL)
            session.disableDialogs = true
            session.clearTransactions()

            let products = try await Product.products(for: [productID])
            guard let product = products.first(where: { $0.id == productID }) else {
                throw RunnerError("Product.products 回傳空集合；請查看 SKTestSession/storekitd 的錯誤輸出")
            }
            guard product.type == .nonConsumable else {
                throw RunnerError("商品類型不是 nonConsumable：\(product.type)")
            }
            print("product: \(product.id), type=\(product.type), displayPrice=\(product.displayPrice)")

            let store = ProStore(productID: productID)
            await store.start()
            guard store.canPurchase else {
                throw RunnerError("ProStore 啟動後不可購買：message=\(store.message ?? "nil")")
            }

            await store.purchase()
            guard store.hasPro else {
                throw RunnerError("ProStore.purchase 未授予 Pro：message=\(store.message ?? "nil")")
            }
            print("purchase: hasPro=true, message=\(store.message ?? "nil")")

            let restored = ProStore(productID: productID)
            await restored.start()
            guard restored.hasPro else {
                throw RunnerError("currentEntitlements 未恢復已購 Pro")
            }
            await restored.restore()
            guard restored.hasPro else { throw RunnerError("restore 遺失已購權益") }
            print("restore/current entitlement: hasPro=true")

            if let transaction = session.allTransactions().first {
                try session.refundTransaction(identifier: transaction.identifier)
                try await Task.sleep(for: .milliseconds(300))
                await restored.refresh()
                guard !restored.hasPro else { throw RunnerError("refund 後仍持有 Pro") }
                print("refund: hasPro=false")
            } else {
                throw RunnerError("購買後沒有 SKTestTransaction，無法測試 refund")
            }

            session.clearTransactions()
            session.askToBuyEnabled = true
            let pendingStore = ProStore(productID: productID)
            await pendingStore.start()
            await pendingStore.purchase()
            guard !pendingStore.hasPro, pendingStore.message == "購買正在等待核准。" else {
                throw RunnerError("pending 情境未回傳預期訊息：\(pendingStore.message ?? "nil")")
            }
            print("pending: message=\(pendingStore.message ?? "nil")")
            if let pendingTransaction = session.allTransactions().first {
                try session.approveAskToBuyTransaction(identifier: pendingTransaction.identifier)
                try await Task.sleep(for: .milliseconds(300))
                await pendingStore.refresh()
                guard pendingStore.hasPro else { throw RunnerError("pending 核准後沒有 Pro") }
                print("approve pending: hasPro=true")
            } else {
                throw RunnerError("pending 沒有可核准交易")
            }

            print("StoreKit local transaction runner passed")
        } catch {
            FileHandle.standardError.write(Data("StoreKit local transaction runner failed: \(error)\n".utf8))
            Foundation.exit(1)
        }
    }

    struct RunnerError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
}
