import Foundation
import CMVDomain

public enum MediaSourceAccessError: LocalizedError, Equatable {
    case staleBookmark
    case accessDenied
    public var errorDescription: String? {
        switch self {
        case .staleBookmark: "音樂來源授權已過期，請重新選擇資料夾。"
        case .accessDenied: "無法存取音樂來源。"
        }
    }
}

public struct MediaSourceResolution: Sendable {
    public let url: URL
    /// Bookmark 仍可使用但已標記 stale 時，提供可持久化的新 bookmark。
    public let refreshedBookmark: Data?

    public init(url: URL, refreshedBookmark: Data? = nil) {
        self.url = url
        self.refreshedBookmark = refreshedBookmark
    }
}

public final class SecurityScopedResourceLease: @unchecked Sendable {
    public let url: URL
    private let ownsAccess: Bool

    fileprivate init(url: URL) throws {
        self.url = url
        ownsAccess = url.startAccessingSecurityScopedResource()
        guard ownsAccess else { throw MediaSourceAccessError.accessDenied }
    }

    deinit {
        if ownsAccess { url.stopAccessingSecurityScopedResource() }
    }
}

public actor SourceAccessCoordinator {
    public init() {}

    public func lease(for url: URL) throws -> SecurityScopedResourceLease {
        try SecurityScopedResourceLease(url: url)
    }
}

public struct SecurityScopedMediaSourceProvider: MediaSourceProvider {
    public init() {}

    public func makeBookmark(for url: URL) throws -> Data {
        // System picker URLs carry the sandbox extension on the original URL.
        // Acquire it here as well as at higher-level call sites so every
        // bookmark minting path (including reauthorization) is self-contained.
        let ownsAccess = url.startAccessingSecurityScopedResource()
        defer { if ownsAccess { url.stopAccessingSecurityScopedResource() } }
        #if os(macOS)
        let options: URL.BookmarkCreationOptions = [.withSecurityScope]
        #else
        // iOS does not expose `.withSecurityScope`; the document picker URL
        // already carries its scoped entitlement and `.minimalBookmark` is
        // the supported persistent representation.
        let options: URL.BookmarkCreationOptions = [.minimalBookmark]
        #endif
        return try url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    public func resolve(bookmark: Data) throws -> URL {
        let resolution = try resolveWithRefresh(bookmark: bookmark)
        guard resolution.refreshedBookmark == nil else { throw MediaSourceAccessError.staleBookmark }
        return resolution.url
    }

    /// 解析來源並在 Apple 仍能存取 stale bookmark 時立即重建 bookmark。
    /// 呼叫端應在同一個持久化交易中保存 `refreshedBookmark`。
    public func resolveWithRefresh(bookmark: Data) throws -> MediaSourceResolution {
        var stale = false
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        let url = try URL(resolvingBookmarkData: bookmark, options: options, relativeTo: nil, bookmarkDataIsStale: &stale)
        guard stale else { return MediaSourceResolution(url: url) }
        #if os(macOS)
        let bookmarkOptions: URL.BookmarkCreationOptions = [.withSecurityScope]
        #else
        let bookmarkOptions: URL.BookmarkCreationOptions = [.minimalBookmark]
        #endif
        // Recreating a stale security-scoped bookmark without first consuming
        // the resolved URL's sandbox extension can fail even though resolution
        // itself succeeded. Keep this balanced and local to the refresh path.
        let ownsAccess = url.startAccessingSecurityScopedResource()
        defer { if ownsAccess { url.stopAccessingSecurityScopedResource() } }
        guard let refreshed = try? url.bookmarkData(
            options: bookmarkOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            throw MediaSourceAccessError.staleBookmark
        }
        return MediaSourceResolution(url: url, refreshedBookmark: refreshed)
    }

    public func status(for bookmark: Data) async -> MediaSourceStatus {
        do {
            let url = try resolveWithRefresh(bookmark: bookmark).url
            guard url.startAccessingSecurityScopedResource() else { return .permissionRequired }
            defer { url.stopAccessingSecurityScopedResource() }
            return FileManager.default.isReadableFile(atPath: url.path) ? .available : .offline
        } catch {
            return .permissionRequired
        }
    }
}
