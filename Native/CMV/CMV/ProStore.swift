import Foundation
import Observation
import StoreKit
import CMVDomain

/// CMV 一次性 Pro 的 StoreKit 2 狀態與操作入口。
///
/// 商品 ID 來自 `CMVProProductID` Info.plist；初始化時傳入 `productID` 可供
/// Preview、測試或不同環境注入。沒有有效商品 ID 時不會虛構商品或授予權益。
@MainActor
@Observable
public final class ProStore {
    public enum Operation: Equatable, Sendable {
        case idle
        case purchasing
        case restoring
    }

    private enum EntitlementRead {
        case verified
        case absent
        case unavailable
    }

    public private(set) var hasPro = false
    public private(set) var isChecking = false
    public private(set) var displayPrice: String?
    public private(set) var operation: Operation = .idle
    public var message: String? {
        messageKey.map(AppLanguage.localized)
    }

    public var isConfigured: Bool { productID != nil }
    public var canPurchase: Bool {
        operation == .idle && !isChecking && product != nil && productID != nil
    }

    private let productID: String?
    private var product: Product?
    @ObservationIgnored
    nonisolated(unsafe) private var updatesTask: Task<Void, Never>?
    private var didStart = false
    private var accessState = ProAccessState()
    private var transactionOrder = ProTransactionOrder()
    private var messageKey: String?
    private var revision: UInt64 = 0
    private var refreshGeneration: UInt64 = 0

    public init(productID: String? = nil) {
        let injected = Self.validProductID(productID)
        if let injected {
            self.productID = injected
        } else {
            #if DEBUG
            // Only the dedicated Xcode StoreKit scheme sets this launch variable.
            // Keep the shipped Info.plist product ID independent of local fixtures.
            let localTestID = Self.validProductID(
                ProcessInfo.processInfo.environment["CMV_LOCAL_STOREKIT_PRODUCT_ID"])
            #else
            let localTestID: String? = nil
            #endif
            let configured = Bundle.main.object(forInfoDictionaryKey: "CMVProProductID") as? String
            self.productID = localTestID ?? Self.validProductID(configured)
        }
    }

    private static func validProductID(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              !(value.hasPrefix("$(") && value.hasSuffix(")")) else {
            return nil
        }
        return value
    }

    nonisolated deinit {
        updatesTask?.cancel()
    }

    /// 啟動長存的 Transaction.updates listener，並從本地 currentEntitlements
    /// 讀取現有權益。currentEntitlements 不需要網路即可讀取已同步交易。
    public func start() async {
        guard !didStart else {
            await refresh()
            return
        }
        didStart = true
        startTransactionListener()
        await refresh()
    }

    /// 重新讀取 StoreKit currentEntitlements；不呼叫 AppStore.sync。
    public func refresh() async {
        guard operation == .idle else { return }
        _ = await refreshStore()
    }

    private func refreshStore() async -> EntitlementRead {
        guard !isChecking else { return .unavailable }
        guard let productID else {
            displayPrice = nil
            messageKey = "目前尚未開放 Pro 購買，免費功能可照常使用。"
            return .unavailable
        }

        isChecking = true
        messageKey = nil
        let generation = refreshGeneration
        var foundVerifiedEntitlement = false
        var completedEntitlementRead = true
        var entitlementReadReliable = true
        var verifiedTransactions: [Transaction] = []

        // 先讀本地 currentEntitlements。它不需要先查商品網路，故離線啟動
        // 時也能立即恢復已驗證的 Pro；商品價格稍後再獨立載入。
        for await result in Transaction.currentEntitlements {
            guard !Task.isCancelled else {
                completedEntitlementRead = false
                break
            }
            guard generation == refreshGeneration else {
                completedEntitlementRead = false
                break
            }
            switch result {
            case let .verified(transaction):
                guard transaction.productID == productID,
                      transaction.productType == .nonConsumable else { continue }
                guard transactionOrder.accept(id: transaction.id, signedDate: transaction.signedDate,
                                              revoked: transaction.revocationDate != nil) else {
                    // A stale cached transaction is not evidence that the newer entitlement vanished.
                    entitlementReadReliable = false
                    continue
                }
                if transaction.revocationDate == nil { foundVerifiedEntitlement = true }
                verifiedTransactions.append(transaction)
            case let .unverified(transaction, _):
                if transaction.productID == productID {
                    // 驗證失敗不能授權；若已有本地 verified Pro，也不能因
                    // 暫時驗證錯誤把它抹掉。
                    entitlementReadReliable = false
                }
            }
        }

        guard completedEntitlementRead, !Task.isCancelled else {
            isChecking = false
            // A newer verified Transaction.updates event can legitimately
            // supersede this interrupted iteration. Report its current state
            // instead of claiming that the restored access is unknown.
            return generation != refreshGeneration && hasPro ? .verified : .unavailable
        }

        // 新 transaction 若在 currentEntitlements 等待期間抵達，快照已過時，
        // 不得提交「沒有 entitlement」的結果。
        let canCommitSnapshot = generation == refreshGeneration && entitlementReadReliable
        if canCommitSnapshot {
            applyEntitlementSnapshot(foundVerifiedEntitlement)
        }
        let snapshotGeneration = refreshGeneration

        // 權益快照已交付給狀態機後再 finish；若 refresh 已過時或被取消，
        // 這批 transaction 不算已交付，交由下一次核對或 updates 處理。
        if canCommitSnapshot {
            for transaction in verifiedTransactions {
                await transaction.finish()
            }
        }

        var loadedProduct: Product?

        do {
            loadedProduct = try await Product.products(for: [productID]).first
        } catch {
            // 商品查詢失敗不代表已購買的權益失效；currentEntitlements 仍會
            // 繼續嘗試，價格則暫時保持 nil。
            messageKey = "目前無法載入 Pro 商品資訊。"
        }

        if let loadedProduct, loadedProduct.type == .nonConsumable {
            product = loadedProduct
            displayPrice = loadedProduct.displayPrice
        } else {
            product = nil
            displayPrice = nil
            if message == nil {
                messageKey = "目前無法購買 Pro。"
            }
        }

        isChecking = false
        // Transaction.updates may arrive while finishing transactions or
        // loading the product. Never report a superseded snapshot as the
        // outcome of this restore attempt.
        if refreshGeneration != snapshotGeneration {
            return hasPro ? .verified : .unavailable
        }
        guard canCommitSnapshot else {
            // A verified update may have arrived during entitlement iteration.
            return generation != refreshGeneration && hasPro ? .verified : .unavailable
        }
        return foundVerifiedEntitlement ? .verified : .absent
    }

    public func purchase() async {
        guard operation == .idle else {
            messageKey = "已有 Pro 操作正在進行。"
            return
        }
        guard !isChecking else {
            messageKey = "正在檢查 Pro 狀態，請稍後再試。"
            return
        }
        guard let productID else {
            messageKey = "目前尚未開放 Pro 購買，免費功能可照常使用。"
            return
        }
        guard let product else {
            messageKey = "目前無法載入 Pro 商品資訊。"
            return
        }
        guard product.id == productID else {
            messageKey = "Pro 商品設定不一致，暫時無法購買。"
            return
        }

        operation = .purchasing
        messageKey = nil
        defer { operation = .idle }

        do {
            switch try await product.purchase() {
            case let .success(.verified(transaction)):
                guard transaction.productID == productID,
                      transaction.productType == .nonConsumable else {
                    messageKey = "收到未預期的 Pro 商品。"
                    return
                }
                let wasRevoked = transaction.revocationDate != nil
                applyVerified(transaction, source: .purchase)
                await transaction.finish()
                if !wasRevoked, hasPro { messageKey = "Pro 已啟用。" }
            case .success(.unverified(_, _)):
                messageKey = "Pro 交易驗證失敗，未啟用權益。"
            case .userCancelled:
                messageKey = "已取消購買。"
            case .pending:
                messageKey = "購買正在等待核准。"
            @unknown default:
                messageKey = "購買未完成。"
            }
        } catch {
            // 取消、pending 或錯誤都不會清除既有 verified Pro。
            messageKey = "購買失敗，請稍後再試。"
        }
    }

    /// 明確的恢復按鈕才會呼叫 AppStore.sync；一般 refresh 絕不主動同步。
    public func restore() async {
        guard operation == .idle else {
            messageKey = "已有 Pro 操作正在進行。"
            return
        }
        guard !isChecking else {
            messageKey = "正在檢查 Pro 狀態，請稍後再試。"
            return
        }
        guard productID != nil else {
            messageKey = "目前無法恢復 Pro 購買，請稍後再試。"
            return
        }

        operation = .restoring
        messageKey = nil
        defer { operation = .idle }

        do {
            try await AppStore.sync()
            switch await refreshStore() {
            case .verified where hasPro:
                messageKey = "Pro 購買已確認。"
            case .absent where !hasPro:
                messageKey = "找不到可恢復的 Pro 購買。"
            default:
                messageKey = "目前無法確認 Pro 購買，請稍後再試。"
            }
        } catch {
            // 恢復失敗不可抹掉既有本地已驗證權益。
            messageKey = "恢復購買失敗，請稍後再試。"
        }
    }

    private func startTransactionListener() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.receive(transactionResult: result)
            }
        }
    }

    private func receive(transactionResult: VerificationResult<Transaction>) async {
        guard let productID,
              case let .verified(transaction) = transactionResult,
              transaction.productID == productID,
              transaction.productType == .nonConsumable else {
            // 未驗證交易不能授權，也不能 finish 以免掩蓋驗證問題。
            return
        }

        applyVerified(transaction, source: .update)
        await transaction.finish()
    }

    private enum VerificationSource {
        case refresh
        case purchase
        case update
    }

    private func applyVerified(_ transaction: Transaction, source: VerificationSource) {
        guard transactionOrder.accept(id: transaction.id, signedDate: transaction.signedDate,
                                      revoked: transaction.revocationDate != nil) else { return }
        if transaction.revocationDate != nil {
            applyTransition(.revoked(revision: nextRevision()))
            messageKey = "Pro 權益已撤銷。"
            return
        }

        applyTransition(.verified(revision: nextRevision()))
        if case .update = source {
            messageKey = "Pro 已啟用。"
        }
    }

    private func applyEntitlementSnapshot(_ hasPro: Bool) {
        let transition: ProAccessTransition = hasPro
            ? .verified(revision: nextRevision())
            : .revoked(revision: nextRevision())
        applyTransition(transition)
    }

    private func nextRevision() -> UInt64 {
        revision &+= 1
        refreshGeneration = revision
        return revision
    }

    private func applyTransition(_ transition: ProAccessTransition) {
        guard accessState.apply(transition) else { return }
        hasPro = accessState.hasPro
    }
}
