import Foundation

/// CMV Pro 提供的付費能力。基本播放、佇列與使用者資料不屬於此集合。
public enum ProFeature: String, CaseIterable, Codable, Hashable, Sendable {
    case smartOfflineCache
    case advancedLibrary
    case additionalThemes
    case smartDJ
}

/// StoreKit 交易對權益狀態機的輸入。
///
/// `revision` 由交易邊界產生，必須單調遞增。這讓較早開始的 refresh
/// 在較新的 Transaction.updates 已經授權後，不能把權益覆蓋回免費狀態。
public enum ProAccessTransition: Equatable, Sendable {
    case verified(revision: UInt64)
    case pending(revision: UInt64)
    case failed(revision: UInt64)
    case revoked(revision: UInt64)

    public var revision: UInt64 {
        switch self {
        case let .verified(revision), let .pending(revision),
             let .failed(revision), let .revoked(revision):
            return revision
        }
    }
}

/// 可在 Domain 純測試的 Pro 權益狀態。
public struct ProAccessState: Equatable, Sendable {
    public private(set) var hasPro: Bool
    public private(set) var revision: UInt64

    public init(hasPro: Bool = false, revision: UInt64 = 0) {
        self.hasPro = hasPro
        self.revision = revision
    }

    /// 套用交易結果；回傳 `false` 代表輸入是過期或重複 revision。
    @discardableResult
    public mutating func apply(_ transition: ProAccessTransition) -> Bool {
        guard transition.revision > revision else { return false }
        revision = transition.revision

        switch transition {
        case .verified:
            hasPro = true
        case .revoked:
            hasPro = false
        case .pending, .failed:
            // 一次性 Pro 的取消、pending 或暫時錯誤不能抹掉既有的
            // 已驗證權益；下次 currentEntitlements 仍會重新核對。
            break
        }
        return true
    }

    public func allows(_ feature: ProFeature) -> Bool {
        _ = feature
        return hasPro
    }
}

public enum ProAccessPolicy {
    public static func allows(_ feature: ProFeature, hasPro: Bool) -> Bool {
        _ = feature
        return hasPro
    }
}

/// StoreKit 驗簽保證真實性，不保證 callback 到達順序。
/// 已退款的同一筆交易不能再次授權；重新購買必須是較新的交易。
public struct ProTransactionOrder: Sendable {
    private var latestSignedDate: Date?
    private var revokedTransactionIDs: Set<UInt64> = []
    private var latestWasRevoked = false

    public init() {}

    public mutating func accept(id: UInt64, signedDate: Date, revoked: Bool) -> Bool {
        if !revoked, revokedTransactionIDs.contains(id) { return false }
        if let latestSignedDate {
            guard signedDate >= latestSignedDate else { return false }
            // 同時間的衝突事件以撤銷優先，不把不確定事件當成新的授權。
            if signedDate == latestSignedDate, latestWasRevoked, !revoked { return false }
        }
        if revoked { revokedTransactionIDs.insert(id) }
        latestSignedDate = signedDate
        latestWasRevoked = revoked
        return true
    }
}
