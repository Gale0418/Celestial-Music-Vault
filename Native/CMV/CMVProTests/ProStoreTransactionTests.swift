import XCTest
import StoreKit
import StoreKitTest
@testable import CMV

/// Runs the production ProStore against an isolated local product, without an Apple ID.
/// Keep these tests serial: SKTestSession controls one StoreKit environment per host.
@MainActor
final class ProStoreTransactionTests: XCTestCase {
    private let productID = "local.cmv.pro.test"

    private func makeSession() async throws -> SKTestSession {
#if CMV_STOREKIT_TEST_HOST
        let compileHostFlag = true
#else
        let compileHostFlag = false
#endif
        print("StoreKit diagnostic compileHostFlag=\(compileHostFlag)")
        let url = try XCTUnwrap(Bundle(for: Self.self).url(
            forResource: "CMVProLocal", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        let purchaseError = await session.simulatedError(forAPI: .purchase)
        print("StoreKit diagnostic purchaseErrorConfigured=\(purchaseError != nil)")
        XCTAssertNil(purchaseError, "StoreKit purchase error override survived resetToDefaultState")
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    private func readyStore(refreshAfterPropagation: Bool = true) async throws -> ProStore {
        let store = ProStore(productID: productID)
        await store.start()
        // An unavailable StoreKit service must fail, rather than pass a no-op purchase.
        XCTAssertTrue(store.canPurchase, "Local StoreKit product unavailable: \(store.message ?? "no message")")
        guard store.canPurchase else { throw TestFailure.productUnavailable }
        // clearTransactions() changes the StoreKit environment asynchronously.
        // Wait until currentEntitlements reflects that state before asserting a
        // fresh store is locked.
        try await waitForCurrentEntitlement(false)
        if refreshAfterPropagation { await store.refresh() }
        XCTAssertFalse(store.hasPro)
        return store
    }

    private struct EntitlementState {
        let count: Int
        let activeProductCount: Int
        let unverifiedCount: Int

        var hasProduct: Bool { activeProductCount > 0 }
    }

    private func readEntitlements() async -> EntitlementState {
        var count = 0
        var activeProductCount = 0
        var unverifiedCount = 0
        for await result in Transaction.currentEntitlements {
            count += 1
            switch result {
            case .verified(let transaction):
                guard transaction.productID == productID,
                      transaction.productType == .nonConsumable,
                      transaction.revocationDate == nil else { continue }
                activeProductCount += 1
            case .unverified:
                unverifiedCount += 1
            }
        }
        return EntitlementState(
            count: count,
            activeProductCount: activeProductCount,
            unverifiedCount: unverifiedCount
        )
    }

    private func waitForCurrentEntitlement(_ expected: Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while ContinuousClock.now < deadline {
            let state = await readEntitlements()
            if state.hasProduct == expected { return }
            try await Task.sleep(for: .milliseconds(250))
        }
        let state = await readEntitlements()
        XCTFail(
            "Timed out waiting for currentEntitlements: expected=\(expected), "
                + "count=\(state.count), activeProductCount=\(state.activeProductCount), "
                + "unverifiedCount=\(state.unverifiedCount)"
        )
    }

    private func waitForStoreState(_ store: ProStore, expected: Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while ContinuousClock.now < deadline {
            if store.hasPro == expected { return }
            try await Task.sleep(for: .milliseconds(250))
        }
#if DEBUG && CMV_STOREKIT_TEST_HOST
        let entitlementState = await readEntitlements()
        let diagnostics = store.storeKitTestDiagnostics
        print(
            "StoreKit diagnostic production listener: allUpdates=\(diagnostics.allUpdates) "
                + "matchingVerifiedNonConsumableUpdates=\(diagnostics.matchingVerifiedNonConsumableUpdates) "
                + "transactionOrderRejections=\(diagnostics.transactionOrderRejections) "
                + "listenerStarted=\(diagnostics.listenerStarted) "
                + "streamUpdates=\(diagnostics.streamUpdates) "
                + "listenerFinished=\(diagnostics.listenerFinished) "
                + "currentEntitlementsCount=\(entitlementState.count) "
                + "activeProductCount=\(entitlementState.activeProductCount) "
                + "unverifiedCount=\(entitlementState.unverifiedCount)"
        )
#endif
        XCTFail("Timed out waiting for ProStore state: expected=\(expected)")
        throw TestFailure.storeStateTimeout
    }

    private func diagnoseEntitlements(_ label: String) async {
        let state = await readEntitlements()
        print(
            "StoreKit diagnostic \(label): count=\(state.count) "
                + "activeProductCount=\(state.activeProductCount) "
                + "unverifiedCount=\(state.unverifiedCount)"
        )
    }

    private func waitForPendingAskToBuyTransaction(in session: SKTestSession) async throws -> SKTestTransaction {
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while ContinuousClock.now < deadline {
            let matches = session.allTransactions().filter { $0.productIdentifier == productID }
            if matches.count == 1,
               let transaction = matches.first,
               transaction.state == .deferred,
               transaction.pendingAskToBuyConfirmation {
                return transaction
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        let matches = session.allTransactions().filter { $0.productIdentifier == productID }
        XCTAssertEqual(matches.count, 1, "Expected exactly one Ask to Buy transaction for the local product")
        XCTAssertEqual(matches.first?.state, .deferred, "Expected the Ask to Buy transaction to be deferred")
        XCTAssertTrue(matches.first?.pendingAskToBuyConfirmation == true, "Expected Ask to Buy confirmation to remain pending")
        throw TestFailure.pendingTransactionMissing
    }

    private func waitForTransactionState(
        _ expected: SKPaymentTransactionState,
        in session: SKTestSession
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while ContinuousClock.now < deadline {
            let matches = session.allTransactions().filter { $0.productIdentifier == productID }
            if matches.count == 1,
               matches[0].state == expected,
               !matches[0].pendingAskToBuyConfirmation {
                return
            }
            try await Task.sleep(for: .milliseconds(250))
        }
        let matches = session.allTransactions().filter { $0.productIdentifier == productID }
        let states = matches.map { String(describing: $0.state) }.joined(separator: ",")
        XCTFail(
            "Timed out waiting for local transaction state: expected=\(expected), "
                + "productMatches=\(matches.count), states=\(states)"
        )
    }

    func testPurchaseRestartRestoreAndRefund() async throws {
        let session = try await makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = try await readyStore()
        await store.purchase()
        XCTAssertTrue(store.hasPro)
        XCTAssertEqual(store.operation, .idle)
        try await waitForCurrentEntitlement(true)
        await diagnoseEntitlements("after purchase")

        let restarted = ProStore(productID: productID)
        await restarted.start()
        // A fresh store may start before StoreKit has propagated the purchase.
        // Wait for the service state, then perform the same production refresh.
        try await waitForCurrentEntitlement(true)
        await restarted.refresh()
        XCTAssertTrue(restarted.hasPro, "A fresh store must read currentEntitlements after propagation")
        await restarted.restore()
        XCTAssertTrue(restarted.hasPro)
        XCTAssertEqual(restarted.operation, .idle)

        let transaction = try XCTUnwrap(
            session.allTransactions().first {
                $0.productIdentifier == productID
                    && ($0.state == .purchased || $0.state == .restored)
            }
        )
        try session.refundTransaction(identifier: transaction.identifier)
        // The refund is accepted synchronously, but currentEntitlements is
        // updated asynchronously by StoreKitTest.
        try await waitForCurrentEntitlement(false)
        await store.refresh()
        await restarted.refresh()
        XCTAssertFalse(store.hasPro)
        XCTAssertFalse(restarted.hasPro)
    }

    func testPendingApprovalArrivesThroughUpdates() async throws {
        let session = try await makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        session.askToBuyEnabled = true
        let store = try await readyStore()
        await store.purchase()
        XCTAssertFalse(store.hasPro)
        XCTAssertEqual(store.message, AppLanguage.localized("購買正在等待核准。"))
        let pending = try await waitForPendingAskToBuyTransaction(in: session)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        // approveAskToBuyTransaction is synchronous from the test API's point
        // of view; any resulting transaction update is observed asynchronously.
        try await waitForTransactionState(.purchased, in: session)
        // StoreKitTest approval and its signed StoreKit state propagate separately.
        // Observe the fixture only; never refresh or grant access on ProStore here.
        try await waitForCurrentEntitlement(true)
        let afterApproval = session.allTransactions().filter { $0.productIdentifier == productID }
        let states = afterApproval.map { String(describing: $0.state) }.joined(separator: ",")
        print("StoreKit diagnostic after approval: states=\(states) productMatches=\(afterApproval.count)")
        // Deliberately do not call refresh: this isolates whether approval
        // reaches the production Transaction.updates listener.
        try await waitForStoreState(store, expected: true)
#if DEBUG && CMV_STOREKIT_TEST_HOST
        XCTAssertGreaterThanOrEqual(store.storeKitTestDiagnostics.matchingVerifiedNonConsumableUpdates, 1)
#endif
    }

    /// Distinguishes StoreKitTest event delivery from CMV's transaction handling.
    /// This test intentionally creates no ProStore and has exactly one consumer.
    func testRawStoreKitPendingApprovalDelivery() async throws {
        let session = try await makeSession()
        session.askToBuyEnabled = true
        let probe = RawUpdatesProbe()
        let listener = Task {
            let updates = Transaction.updates
            probe.started = true
            for await result in updates {
                guard !Task.isCancelled else { return }
                probe.allUpdates += 1
                if case .verified(let transaction) = result,
                   transaction.productID == self.productID,
                   transaction.revocationDate == nil {
                    probe.matchingUpdates += 1
                    await transaction.finish()
                }
            }
        }
        defer {
            listener.cancel()
            session.clearTransactions()
            session.resetToDefaultState()
        }
        while !probe.started { await Task.yield() }
        try await waitForCurrentEntitlement(false)
        let products = try await Product.products(for: [productID])
        let product = try XCTUnwrap(products.first { $0.id == productID })
        let purchase = try await product.purchase()
        guard case .pending = purchase else {
            XCTFail("Raw StoreKit purchase did not enter pending state")
            return
        }
        let pending = try await waitForPendingAskToBuyTransaction(in: session)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        try await waitForTransactionState(.purchased, in: session)
        try await waitForCurrentEntitlement(true)
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while probe.matchingUpdates == 0 && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(250))
        }
        print("StoreKit diagnostic raw listener: allUpdates=\(probe.allUpdates) matchingUpdates=\(probe.matchingUpdates)")
        await diagnoseEntitlements("raw listener after approval")
        XCTAssertGreaterThanOrEqual(probe.matchingUpdates, 1,
                                    "StoreKitTest approved the purchase but did not deliver a verified update to the raw listener")
    }

    private final class RawUpdatesProbe {
        var started = false
        var allUpdates = 0
        var matchingUpdates = 0
    }

    /// Isolates the second refresh in the test setup from initial startup.
    func testPendingApprovalAfterSingleStartupRefresh() async throws {
        let session = try await makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        session.askToBuyEnabled = true
        let store = try await readyStore(refreshAfterPropagation: false)
        await store.purchase()
        XCTAssertFalse(store.hasPro)
        let pending = try await waitForPendingAskToBuyTransaction(in: session)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        try await waitForTransactionState(.purchased, in: session)
        // StoreKitTest approval and its signed StoreKit state propagate separately.
        // Observe the fixture only; never refresh or grant access on ProStore here.
        try await waitForCurrentEntitlement(true)
        try await waitForStoreState(store, expected: true)
#if DEBUG && CMV_STOREKIT_TEST_HOST
        XCTAssertGreaterThanOrEqual(store.storeKitTestDiagnostics.matchingVerifiedNonConsumableUpdates, 1)
#endif
    }

    /// Uses the production purchase wrapper with a single raw listener.
    /// No ProStore.start(): receiving this event cannot directly grant Pro.
    func testPendingApprovalRawListenerWithProductionPurchase() async throws {
        let session = try await makeSession()
        session.askToBuyEnabled = true
        let probe = RawUpdatesProbe()
        let listener = Task {
            let updates = Transaction.updates
            probe.started = true
            for await result in updates {
                guard !Task.isCancelled else { return }
                probe.allUpdates += 1
                if case .verified(let transaction) = result,
                   transaction.productID == self.productID,
                   transaction.revocationDate == nil {
                    probe.matchingUpdates += 1
                    await transaction.finish()
                }
            }
        }
        defer {
            listener.cancel()
            session.clearTransactions()
            session.resetToDefaultState()
        }
        while !probe.started { await Task.yield() }
        let store = ProStore(productID: productID)
        await store.refresh()
        guard store.canPurchase else { throw TestFailure.productUnavailable }
        await store.purchase()
        XCTAssertFalse(store.hasPro)
        let pending = try await waitForPendingAskToBuyTransaction(in: session)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        try await waitForTransactionState(.purchased, in: session)
        try await waitForCurrentEntitlement(true)
        let deadline = ContinuousClock.now.advanced(by: .seconds(30))
        while probe.matchingUpdates == 0 && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(250))
        }
        print("StoreKit diagnostic raw listener + production purchase: allUpdates=\(probe.allUpdates) matchingUpdates=\(probe.matchingUpdates)")
        XCTAssertGreaterThanOrEqual(probe.matchingUpdates, 1)
    }

    /// Uses the production listener with a direct, freshly loaded Product.
    func testPendingApprovalProductionListenerWithDirectPurchase() async throws {
        let session = try await makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        session.askToBuyEnabled = true
        let store = try await readyStore()
        let products = try await Product.products(for: [productID])
        let product = try XCTUnwrap(products.first { $0.id == productID })
        let result = try await product.purchase()
        guard case .pending = result else {
            XCTFail("Direct purchase did not enter pending state")
            return
        }
        let pending = try await waitForPendingAskToBuyTransaction(in: session)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        try await waitForTransactionState(.purchased, in: session)
        // StoreKitTest approval and its signed StoreKit state propagate separately.
        // Observe the fixture only; never refresh or grant access on ProStore here.
        try await waitForCurrentEntitlement(true)
        try await waitForStoreState(store, expected: true)
#if DEBUG && CMV_STOREKIT_TEST_HOST
        XCTAssertGreaterThanOrEqual(store.storeKitTestDiagnostics.streamUpdates, 1)
#endif
    }

    // Keep decline independent: an approval failure must not skip this
    // negative case. A declined Ask to Buy must never grant an entitlement.
    func testPendingDeclineDoesNotGrantAccess() async throws {
        let session = try await makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        session.askToBuyEnabled = true
        let store = try await readyStore()
        await store.purchase()
        XCTAssertFalse(store.hasPro)
        XCTAssertEqual(store.message, AppLanguage.localized("購買正在等待核准。"))
        let pending = try await waitForPendingAskToBuyTransaction(in: session)
        try session.declineAskToBuyTransaction(identifier: pending.identifier)
        let declined = try XCTUnwrap(session.allTransactions().first {
            $0.identifier == pending.identifier
        })
        XCTAssertFalse(declined.pendingAskToBuyConfirmation)
        XCTAssertFalse(declined.state == .purchased || declined.state == .restored)
        try await waitForCurrentEntitlement(false)
        XCTAssertFalse(store.hasPro)
        XCTAssertEqual(store.operation, .idle)
        await store.refresh()
        XCTAssertFalse(store.hasPro)
    }

    func testCancellationAndFailureDoNotGrantAccess() async throws {
        let session = try await makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = try await readyStore()
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        await store.purchase()
        XCTAssertFalse(store.hasPro)
        XCTAssertEqual(store.operation, .idle)
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: .purchase)
        await store.purchase()
        XCTAssertFalse(store.hasPro)
        XCTAssertEqual(store.operation, .idle)
        XCTAssertFalse(session.allTransactions().contains { $0.state == .purchased || $0.state == .restored })
    }

    /// Separately verifies reconciliation after approval. A pass here is not
    /// evidence that the pending Transaction.updates acceptance test passed.
    func testPendingApprovalRefreshReconcilesVerifiedEntitlement() async throws {
        let session = try await makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        session.askToBuyEnabled = true
        let store = try await readyStore()
        await store.purchase()
        XCTAssertFalse(store.hasPro)
        let pending = try await waitForPendingAskToBuyTransaction(in: session)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        try await waitForTransactionState(.purchased, in: session)
        try await waitForCurrentEntitlement(true)
#if DEBUG && CMV_STOREKIT_TEST_HOST
        let before = store.storeKitTestDiagnostics
        print("StoreKit diagnostic before reconciliation: hasPro=\(store.hasPro) allUpdates=\(before.allUpdates)")
#endif
        await store.refresh()
        XCTAssertTrue(store.hasPro, "A verified approved entitlement must reconcile through production refresh")
        XCTAssertEqual(store.operation, .idle)
#if DEBUG && CMV_STOREKIT_TEST_HOST
        let after = store.storeKitTestDiagnostics
        print("StoreKit diagnostic after reconciliation: hasPro=\(store.hasPro) allUpdates=\(after.allUpdates)")
#endif
    }

    /// An off-device purchase probes the same production listener without the
    /// Ask to Buy approval path or a second transaction consumer.
    func testExternalPurchaseArrivesThroughUpdates() async throws {
        let session = try await makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = try await readyStore()
        // The deprecated synchronous API models an externally completed
        // transaction; this test observes whether it reaches updates.
        // The newer async overload tries to return a signed Transaction to
        // the caller; local macOS StoreKitTest cannot provide that JWS here,
        // so it fails before the production listener is exercised.
        try session.buyProduct(productIdentifier: productID)
        try await waitForCurrentEntitlement(true)
        try await waitForStoreState(store, expected: true)
    }

    func testVerifiedAccessSurvivesProductNetworkFailureOnRestart() async throws {
        let session = try await makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let purchased = try await readyStore()
        await purchased.purchase()
        XCTAssertTrue(purchased.hasPro)
        try await waitForCurrentEntitlement(true)
        try await session.setSimulatedError(
            .generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        let restarted = ProStore(productID: productID)
        await restarted.start()
        XCTAssertTrue(restarted.hasPro, "Verified cached access must survive a product network error")
        XCTAssertFalse(restarted.canPurchase)
        XCTAssertNil(restarted.displayPrice)
        XCTAssertEqual(restarted.operation, .idle)
    }

    func testRestoreNetworkFailurePreservesVerifiedAccess() async throws {
        let session = try await makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = try await readyStore()
        await store.purchase()
        XCTAssertTrue(store.hasPro)
        try await session.setSimulatedError(
            .generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync)
        await store.restore()
        XCTAssertTrue(store.hasPro)
        XCTAssertEqual(store.operation, .idle)
        XCTAssertEqual(store.message, AppLanguage.localized("恢復購買失敗，請稍後再試。"))
    }

    func testUnverifiedPurchaseDoesNotGrantAccess() async throws {
        let session = try await makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = try await readyStore()
        try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
        await store.purchase()
        XCTAssertFalse(store.hasPro)
        XCTAssertEqual(store.operation, .idle)
        XCTAssertEqual(store.message, AppLanguage.localized("Pro 交易驗證失敗，未啟用權益。"))
    }

    func testUnverifiedRefreshPreservesPreviousVerifiedAccess() async throws {
        let session = try await makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = try await readyStore()
        await store.purchase()
        XCTAssertTrue(store.hasPro)
        try await waitForCurrentEntitlement(true)
        try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
        await store.refresh()
        XCTAssertTrue(store.hasPro, "A verification failure must not erase previously verified access")
    }

    func testMissingProductCannotPurchaseOrGrantAccess() async throws {
        let session = try await makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = ProStore(productID: "local.cmv.missing.product")
        await store.start()
        XCTAssertFalse(store.canPurchase)
        XCTAssertFalse(store.hasPro)
        await store.purchase()
        XCTAssertFalse(store.hasPro)
        XCTAssertEqual(store.operation, .idle)
        XCTAssertTrue(session.allTransactions().isEmpty)
    }

    func testRefundRevokesAccessThroughUpdates() async throws {
        let session = try await makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = try await readyStore()
        await store.purchase()
        XCTAssertTrue(store.hasPro)
        try await waitForCurrentEntitlement(true)
        let purchased = try XCTUnwrap(session.allTransactions().first {
            $0.productIdentifier == productID && $0.state == .purchased
        })
        try session.refundTransaction(identifier: purchased.identifier)
        try await waitForCurrentEntitlement(false)
        try await waitForStoreState(store, expected: false)
#if DEBUG && CMV_STOREKIT_TEST_HOST
        XCTAssertGreaterThanOrEqual(store.storeKitTestDiagnostics.matchingVerifiedNonConsumableUpdates, 1)
#endif
    }

    func testConcurrentPurchaseAndRestoreDoNotDuplicateTransactions() async throws {
        let session = try await makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let store = try await readyStore()
        let first = Task { await store.purchase() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while store.operation == .idle && ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertEqual(store.operation, .purchasing, "The first purchase must be in flight for this test")
        await store.purchase()
        await store.restore()
        await first.value
        XCTAssertTrue(store.hasPro)
        XCTAssertEqual(store.operation, .idle)
        let transactions = session.allTransactions().filter { $0.productIdentifier == productID }
        XCTAssertEqual(transactions.count, 1, "Repeated actions must not create a second transaction")
    }

    private enum TestFailure: Error {
        case productUnavailable
        case pendingTransactionMissing
        case storeStateTimeout
    }
}
