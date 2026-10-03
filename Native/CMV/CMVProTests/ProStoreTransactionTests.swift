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

    private func readyStore() async throws -> ProStore {
        let store = ProStore(productID: productID)
        await store.start()
        // An unavailable StoreKit service must fail, rather than pass a no-op purchase.
        XCTAssertTrue(store.canPurchase, "Local StoreKit product unavailable: \(store.message ?? "no message")")
        guard store.canPurchase else { throw TestFailure.productUnavailable }
        // clearTransactions() changes the StoreKit environment asynchronously.
        // Wait until currentEntitlements reflects that state before asserting a
        // fresh store is locked.
        try await waitForCurrentEntitlement(false)
        await store.refresh()
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
        let diagnostics = store.storeKitTestDiagnostics
        let entitlementState = await readEntitlements()
        print(
            "StoreKit diagnostic production listener: allUpdates=\(diagnostics.allUpdates) "
                + "matchingVerifiedNonConsumableUpdates=\(diagnostics.matchingVerifiedNonConsumableUpdates) "
                + "transactionOrderRejections=\(diagnostics.transactionOrderRejections) "
                + "currentEntitlementsCount=\(entitlementState.count) "
                + "activeProductCount=\(entitlementState.activeProductCount) "
                + "unverifiedCount=\(entitlementState.unverifiedCount)"
        )
#endif
        XCTFail("Timed out waiting for ProStore state: expected=\(expected)")
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

    func testPendingApprovalAndDecline() async throws {
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
        // of view, while the transaction update is delivered asynchronously.
        try await waitForTransactionState(.purchased, in: session)
        let afterApproval = session.allTransactions().filter { $0.productIdentifier == productID }
        let states = afterApproval.map { String(describing: $0.state) }.joined(separator: ",")
        print("StoreKit diagnostic after approval: states=\(states) productMatches=\(afterApproval.count)")
        // Deliberately do not call refresh: approval must arrive through the
        // production Transaction.updates listener.
        try await waitForStoreState(store, expected: true)

        session.clearTransactions()
        let declinedStore = try await readyStore()
        await declinedStore.purchase()
        let declined = try await waitForPendingAskToBuyTransaction(in: session)
        try session.declineAskToBuyTransaction(identifier: declined.identifier)
        try await waitForCurrentEntitlement(false)
        await declinedStore.refresh()
        XCTAssertFalse(declinedStore.hasPro)
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
        do {
            let transaction = try await session.buyProduct(identifier: productID)
            XCTAssertEqual(transaction.productID, productID)
        } catch {
            let failure = error as NSError
            print("StoreKit diagnostic external purchase error: domain=\(failure.domain) code=\(failure.code)")
            throw error
        }
        try await waitForCurrentEntitlement(true)
        try await waitForStoreState(store, expected: true)
    }

    private enum TestFailure: Error {
        case productUnavailable
        case pendingTransactionMissing
    }
}
