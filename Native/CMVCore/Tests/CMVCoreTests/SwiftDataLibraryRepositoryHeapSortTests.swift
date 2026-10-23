import Foundation
import XCTest
import SwiftData
import CMVDomain
import CMVLibrary

final class SwiftDataLibraryRepositoryHeapSortTests: XCTestCase {
    private let sourceID = UUID(uuidString: "D5DBD2D2-50C0-4E34-9BD5-500000000001")!

    private func makeContainer(inMemory: Bool = true, at url: URL? = nil) throws -> ModelContainer {
        let configuration = inMemory
            ? ModelConfiguration(isStoredInMemoryOnly: true)
            : ModelConfiguration(url: try XCTUnwrap(url))
        return try ModelContainer(
            for: MediaSourceRecord.self,
            TrackRecord.self,
            PlaylistRecord.self,
            configurations: configuration
        )
    }

    private func edgeFixture() -> [ScannedMediaFile] {
        (0..<80).map { index in
            let title: String
            switch index % 8 {
            case 0: title = "Same 2"
            case 1: title = "Same 10"
            case 2: title = "星河 4"
            case 3: title = "Track \(index)"
            case 4: title = "Alpha \(index % 3)"
            case 5: title = "Echo \(index % 4)"
            case 6: title = "Numeric 10"
            default: title = "Numeric 2"
            }
            return ScannedMediaFile(
                relativePath: "edge/track-\(index).flac",
                fileIdentifier: "edge-\(index)",
                fileSize: Int64(index + 1),
                modifiedAt: Date(timeIntervalSince1970: TimeInterval(index * 17)),
                title: title,
                artist: "Oracle Artist \(index % 7)",
                album: "Album \(index % 5)",
                albumArtist: index % 2 == 0 ? "Album Artist \(index % 3)" : "",
                genre: index % 3 == 0 ? nil : "Genre \(index % 4)",
                releaseDate: index % 4 == 0 ? nil : Date(timeIntervalSince1970: TimeInterval(index * 86_400)),
                trackNumber: index % 13,
                discNumber: index % 3,
                duration: Double(index) + 0.5
            )
        }
    }

    private func expectedPage(_ ids: [UUID], offset: Int, limit: Int) -> [UUID] {
        let safeOffset = min(max(0, offset), ids.count)
        return Array(ids.dropFirst(safeOffset).prefix(max(1, limit)))
    }

    func testPagedSortMatchesFullOracleAcrossAllSortsAndEdgeInputs() async throws {
        let repository = SwiftDataLibraryRepository(container: try makeContainer())
        try await repository.applyReconciliation(upserts: edgeFixture(), missingIdentifiers: [], sourceID: sourceID)

        let offsets = [0, 1, 79, 199, 2_000, Int.max, -1]
        let limits = [0, 1, 200, Int.max]
        for sort in LibraryTrackSort.allCases {
            for ascending in [true, false] {
                let oracle = try await repository.trackIDs(matching: "oracle", sort: sort, ascending: ascending)
                XCTAssertEqual(oracle.count, 80, "oracle count for \(sort) / \(ascending)")
                for offset in offsets {
                    let actual = try await repository.tracks(
                        matching: "oracle", sort: sort, ascending: ascending,
                        limit: 1, offset: offset, includeArtwork: false
                    ).map(\.id)
                    XCTAssertEqual(actual, expectedPage(oracle, offset: offset, limit: 1), "offset \(offset), \(sort), \(ascending)")
                }
                for limit in limits {
                    let actual = try await repository.tracks(
                        matching: "oracle", sort: sort, ascending: ascending,
                        limit: limit, offset: 0, includeArtwork: false
                    ).map(\.id)
                    XCTAssertEqual(actual, expectedPage(oracle, offset: 0, limit: limit), "limit \(limit), \(sort), \(ascending)")
                }
            }
        }

        for (query, sort, ascending) in [("Same", LibraryTrackSort.title, true), ("星河", .artist, false), ("Track 1", .title, true)] {
            let oracle = try await repository.trackIDs(matching: query, sort: sort, ascending: ascending)
            let actual = try await repository.tracks(
                matching: query, sort: sort, ascending: ascending,
                limit: 200, offset: 0, includeArtwork: false
            ).map(\.id)
            XCTAssertEqual(actual, oracle, "substring/CJK/natural order query \(query)")
        }

        let fresh = ScannedMediaFile(
            relativePath: "edge/track-0.flac", fileIdentifier: "edge-0", fileSize: 99,
            modifiedAt: Date(timeIntervalSince1970: 99_999), title: "Fresh Title",
            artist: "Oracle Artist fresh", album: "Fresh Album"
        )
        try await repository.applyReconciliation(upserts: [fresh], missingIdentifiers: [], sourceID: sourceID)
        let refreshed = try await repository.tracks(
            matching: "Fresh", sort: .title, ascending: true,
            limit: 10, offset: 0, includeArtwork: false
        )
        XCTAssertEqual(refreshed.map(\.fileIdentifier), ["edge-0"], "metadata update must refresh search index")
    }

    private struct PerformanceSample: Codable {
        let index: Int
        let query: String
        let sort: String
        let ascending: Bool
        let elapsedMs: Double
        let returnedCount: Int
    }

    func testReleasePersistentHeapSortWarm40Queries() async throws {
        let storeURL = URL(fileURLWithPath: "/tmp/cmv-final-performance-20261008/persistent-50k-fixture/default.store")
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            throw XCTSkip("test-owned persistent 50k fixture is not available")
        }
        let repository = SwiftDataLibraryRepository(container: try makeContainer(inMemory: false, at: storeURL))
        _ = try await repository.searchCandidates(matching: "heap-sort-warm-prime")
        var cases: [(String, LibraryTrackSort, Bool)] = []
        cases += (0..<10).map { ("Track \($0)", LibraryTrackSort.title, true) }
        cases += (0..<10).map { (String(format: "Artist %02d", $0), LibraryTrackSort.artist, false) }
        cases += (0..<10).map { (String(format: "Album %02d", $0), LibraryTrackSort.album, true) }
        cases += (0..<5).map { ("星河 \($0)", LibraryTrackSort.title, true) }
        cases += (0..<5).map { ("NoSuchHeapSortToken\($0)", LibraryTrackSort.title, true) }
        var samples: [PerformanceSample] = []
        samples.reserveCapacity(cases.count)
        for (index, item) in cases.enumerated() {
            let start = ContinuousClock.now
            let rows = try await repository.tracks(
                matching: item.0, sort: item.1, ascending: item.2,
                limit: 200, offset: 0, includeArtwork: false
            )
            let elapsed = start.duration(to: .now)
            let components = elapsed.components
            let elapsedMs = Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1_000_000_000_000_000
            samples.append(PerformanceSample(index: index, query: item.0, sort: item.1.rawValue, ascending: item.2, elapsedMs: elapsedMs, returnedCount: rows.count))
            XCTAssertLessThanOrEqual(rows.count, 200)
        }
        let outputURL = URL(fileURLWithPath: "/tmp/cmv-final-performance-20261008/heap-promotion-production-40-samples.json")
        let data = try JSONEncoder().encode(samples)
        try data.write(to: outputURL, options: .atomic)
        print("CMV_HEAP_PRODUCTION_40 samples=\(samples.count) path=\(outputURL.path)")
        XCTAssertEqual(samples.count, 40)
    }
}
