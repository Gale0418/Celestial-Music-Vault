import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

/// Actor-isolated, policy-bounded cache for decoded audio artwork.
///
/// The cache key contains the artwork content digest and requested pixel size,
/// so changed artwork or a different grid size cannot reuse a stale image. The
/// compressed source bytes are not retained; the cache cost covers decoded
/// pixels only.
actor ArtworkThumbnailCache {
    static let shared = ArtworkThumbnailCache()

    private let cache: NSCache<NSString, CGImage>

    init(totalCostLimit: Int = 32 * 1_024 * 1_024, countLimit: Int = 128) {
        cache = NSCache<NSString, CGImage>()
        cache.totalCostLimit = max(0, totalCostLimit)
        cache.countLimit = max(0, countLimit)
    }

    func image(for data: Data, maximumPixelSize: Int) throws -> CGImage? {
        try Task.checkCancellation()
        guard maximumPixelSize > 0, !data.isEmpty else { return nil }

        let key = Self.cacheKey(for: data, maximumPixelSize: maximumPixelSize)
        if let cached = cache.object(forKey: key) { return cached }

        try Task.checkCancellation()
        let decoded = Self.decode(data: data, maximumPixelSize: maximumPixelSize)
        try Task.checkCancellation()
        guard let decoded else { return nil }

        let pixelCost = decoded.bytesPerRow.multipliedReportingOverflow(by: decoded.height)
        let cost = pixelCost.overflow ? Int.max : pixelCost.partialValue
        cache.setObject(decoded, forKey: key, cost: cost)
        return decoded
    }

    private static func cacheKey(for data: Data, maximumPixelSize: Int) -> NSString {
        let digest = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        return "\(digest)-\(maximumPixelSize)" as NSString
    }

    private static func decode(data: Data, maximumPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}
