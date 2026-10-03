import CoreGraphics
import ImageIO
import XCTest
@testable import CMV

final class ArtworkThumbnailCacheTests: XCTestCase {
    func testSameContentAndSizeReusesDecodedImage() async throws {
        let cache = ArtworkThumbnailCache(totalCostLimit: 32 * 1_024 * 1_024, countLimit: 128)
        let data = try makePNG(red: 1, green: 0, blue: 0)

        let firstImage = try await cache.image(for: data, maximumPixelSize: 16)
        let secondImage = try await cache.image(for: data, maximumPixelSize: 16)
        let first = try XCTUnwrap(firstImage)
        let second = try XCTUnwrap(secondImage)

        XCTAssertTrue(first === second)
    }

    func testChangedContentAndSizeNeverReuseWrongImage() async throws {
        let cache = ArtworkThumbnailCache()
        let red = try makePNG(red: 1, green: 0, blue: 0)
        let blue = try makePNG(red: 0, green: 0, blue: 1)

        let redSmallImage = try await cache.image(for: red, maximumPixelSize: 8)
        let blueSmallImage = try await cache.image(for: blue, maximumPixelSize: 8)
        let redLargeImage = try await cache.image(for: red, maximumPixelSize: 16)
        let redSmall = try XCTUnwrap(redSmallImage)
        let blueSmall = try XCTUnwrap(blueSmallImage)
        let redLarge = try XCTUnwrap(redLargeImage)

        XCTAssertFalse(redSmall === blueSmall)
        XCTAssertFalse(redSmall === redLarge)
    }

    func testCancelledRequestDoesNotReturnAnImage() async throws {
        let cache = ArtworkThumbnailCache()
        let data = try makePNG(red: 0, green: 1, blue: 0)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await cache.image(for: data, maximumPixelSize: 16)
        }

        do {
            _ = try await task.value
            XCTFail("取消的縮圖請求不應完成")
        } catch is CancellationError {
            // Expected.
        }
        let loaded = try await cache.image(for: data, maximumPixelSize: 16)
        XCTAssertNotNil(loaded)
    }

    private func makePNG(red: CGFloat, green: CGFloat, blue: CGFloat) throws -> Data {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 32,
            height: 32,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        let image = try XCTUnwrap(context.makeImage())
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
            output,
            "public.png" as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "ArtworkThumbnailCacheTests", code: 1)
        }
        return output as Data
    }
}
