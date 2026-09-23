import XCTest
@testable import CMVDomain

final class ProAccessTests: XCTestCase {
    func testVerifiedTransitionGrantsEveryProFeature() {
        var state = ProAccessState()

        XCTAssertTrue(state.apply(.verified(revision: 1)))
        XCTAssertTrue(state.hasPro)
        for feature in ProFeature.allCases {
            XCTAssertTrue(state.allows(feature))
            XCTAssertTrue(ProAccessPolicy.allows(feature, hasPro: state.hasPro))
        }
    }

    func testPendingAndFailedTransitionsPreserveExistingEntitlement() {
        var state = ProAccessState(hasPro: true, revision: 2)

        XCTAssertTrue(state.apply(.pending(revision: 3)))
        XCTAssertTrue(state.hasPro)
        XCTAssertTrue(state.apply(.failed(revision: 4)))
        XCTAssertTrue(state.hasPro)
    }

    func testRevocationRemovesOnlyProAccess() {
        var state = ProAccessState(hasPro: true, revision: 5)

        XCTAssertTrue(state.apply(.revoked(revision: 6)))
        XCTAssertFalse(state.hasPro)
        XCTAssertFalse(state.allows(.smartDJ))
    }

    func testStaleTransitionCannotOverwriteNewerVerifiedState() {
        var state = ProAccessState()

        XCTAssertTrue(state.apply(.verified(revision: 10)))
        XCTAssertFalse(state.apply(.revoked(revision: 9)))
        XCTAssertTrue(state.hasPro)
        XCTAssertEqual(state.revision, 10)
    }

    func testFreeStateAllowsNoProFeature() {
        let state = ProAccessState()

        for feature in ProFeature.allCases {
            XCTAssertFalse(state.allows(feature))
        }
    }

    func testRevocationRejectsDelayedSuccessForSameTransaction() {
        var order = ProTransactionOrder()
        let revokedAt = Date(timeIntervalSince1970: 20)
        XCTAssertTrue(order.accept(id: 1, signedDate: revokedAt, revoked: true))
        XCTAssertFalse(order.accept(id: 1, signedDate: Date(timeIntervalSince1970: 10), revoked: false))
        XCTAssertFalse(order.accept(id: 1, signedDate: Date(timeIntervalSince1970: 30), revoked: false))
    }

    func testNewPurchaseCanGrantAndOlderRevocationCannotOverwriteIt() {
        var order = ProTransactionOrder()
        XCTAssertTrue(order.accept(id: 1, signedDate: Date(timeIntervalSince1970: 20), revoked: true))
        XCTAssertTrue(order.accept(id: 2, signedDate: Date(timeIntervalSince1970: 30), revoked: false))
        XCTAssertFalse(order.accept(id: 1, signedDate: Date(timeIntervalSince1970: 20), revoked: true))
    }

    func testEqualTimestampPrefersRevocation() {
        var order = ProTransactionOrder()
        let time = Date(timeIntervalSince1970: 20)
        XCTAssertTrue(order.accept(id: 1, signedDate: time, revoked: false))
        XCTAssertTrue(order.accept(id: 1, signedDate: time, revoked: true))
        XCTAssertFalse(order.accept(id: 2, signedDate: time, revoked: false))
    }
}
