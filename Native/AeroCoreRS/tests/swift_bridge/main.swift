import Foundation

let client = AeroCoreRSClient()
let result = try client.reconcile(
    existing: [
        RustTrackSnapshot(
            identifier: "stable",
            relativePath: "old/stable.flac",
            fileSize: 10,
            modifiedAtMillis: 100,
            title: "Old",
            availability: .available
        ),
        RustTrackSnapshot(
            identifier: "missing",
            relativePath: "missing.flac",
            fileSize: 20,
            modifiedAtMillis: 200,
            title: "Missing",
            availability: .available
        ),
    ],
    scanned: [
        RustScannedFile(
            identifier: "stable",
            relativePath: "new/stable.flac",
            fileSize: 11,
            modifiedAtMillis: 101,
            title: "New"
        ),
        RustScannedFile(
            identifier: "inserted",
            relativePath: "inserted.flac",
            fileSize: 30,
            modifiedAtMillis: 300,
            title: "Inserted"
        ),
    ],
    sourceReachable: true
)

precondition(result.upserts.map(\.file.identifier) == ["inserted", "stable"])
precondition(result.upserts.map(\.kind) == [.insert, .update])
precondition(result.missingIdentifiers == ["missing"])
print("Swift↔Rust ABI smoke passed")

let largeExisting = (0..<50_000).map { index in
    RustTrackSnapshot(
        identifier: "track-\(index)",
        relativePath: "Library/track-\(index).flac",
        fileSize: UInt64(index + 1),
        modifiedAtMillis: Int64(index),
        title: "Track \(index)",
        availability: .available
    )
}
let largeScanned = (0..<49_000).map { index in
    RustScannedFile(
        identifier: "track-\(index)",
        relativePath: "Library/track-\(index).flac",
        fileSize: UInt64(index + 1),
        modifiedAtMillis: Int64(index),
        title: "Track \(index)"
    )
}
let largeResult = try client.reconcile(
    existing: largeExisting,
    scanned: largeScanned,
    sourceReachable: true
)
precondition(largeResult.upserts.isEmpty)
precondition(largeResult.missingIdentifiers.count == 1_000)
precondition(largeResult.missingIdentifiers.first == "track-49000")
precondition(largeResult.missingIdentifiers.last == "track-49999")
print("Swift↔Rust 50k reconciliation passed")

let playbackPlan = try client.planPlayback(
    engineSampleRateHz: 48_000,
    current: RustTimelineTrack(
        sampleRateHz: 44_100,
        totalFrames: 441_000,
        startFrame: 44_100,
        replayGainDB: -6,
        peak: nil
    ),
    next: RustTimelineTrack(
        sampleRateHz: 48_000,
        totalFrames: 960_000,
        startFrame: 0,
        replayGainDB: 6,
        peak: 0.8
    )
)
precondition(playbackPlan.currentFrameCount == 396_900)
precondition(playbackPlan.nextStartEngineFrame == 432_000)
precondition(abs(playbackPlan.currentGainLinear - 0.501_187) < 0.000_001)
precondition(playbackPlan.nextGainLinear == 1.25)
print("Swift↔Rust playback plan passed")

let searchResults = try client.search(
    query: " moon ",
    tracks: [
        RustSearchTrack(identifier: "partial", title: "Moon Lane", artist: "A", album: "B", favorite: false, rating: 0),
        RustSearchTrack(identifier: "exact", title: "Moon", artist: "A", album: "B", favorite: true, rating: 5),
    ],
    limit: 10
)
precondition(searchResults.map(\.identifier) == ["exact", "partial"])
print("Swift↔Rust search ranking passed")

let searchFixture = largeExisting.prefix(500).map {
    RustSearchTrack(identifier: $0.identifier, title: $0.title, artist: "Fixture Artist",
                    album: "Fixture Album", favorite: false, rating: 0)
}
let searchStart = ContinuousClock.now
let largeSearchResults = try client.search(query: "Track 499", tracks: searchFixture, limit: 20)
let searchElapsed = searchStart.duration(to: .now)
precondition(largeSearchResults.first?.identifier == "track-499")
precondition(searchElapsed < .milliseconds(1_000))
print("Swift↔Rust paged search passed (elapsed: \(searchElapsed))")

let analysisSamples: [Float] = (0..<4_000).map { index in
    let phase = Double(index) / 4_000.0
    return Float(sin(phase * 2.0 * Double.pi * 440.0))
}
let analysis = try client.analyzePCM(samples: analysisSamples, sampleRateHz: 4_000, channels: 1)
precondition(analysis.version == 2)
precondition(analysis.peak > 0.99)
precondition(analysis.musicalKey == 9)
print("Swift↔Rust PCM analysis passed (versioned LUFS/BPM/key)")

let djResults = try client.makeDJ(tracks: [
    RustDJTrack(identifier: "skip", title: "跳過", favorite: false, rating: 0,
                bpm: nil, energy: 0.2, playCount: 0, skipCount: 10),
    RustDJTrack(identifier: "favorite", title: "收藏", favorite: true, rating: 5,
                bpm: 120, energy: 0.8, playCount: 0, skipCount: 0),
], limit: 2)
precondition(djResults.first?.identifier == "favorite")
precondition(djResults.first?.reasons.contains(where: { $0.contains("最愛") }) == true)
print("Swift↔Rust Smart DJ passed (ranked reasons)")

let evictionResults = try client.planEviction(entries: [
    RustCacheEvictionEntry(identifier: "pinned", sizeBytes: 100, pinned: true, lastAccessOrder: 0),
    RustCacheEvictionEntry(identifier: "old", sizeBytes: 20, pinned: false, lastAccessOrder: 1),
    RustCacheEvictionEntry(identifier: "new", sizeBytes: 20, pinned: false, lastAccessOrder: 2),
], budgetBytes: 100)
precondition(evictionResults == ["old", "new"])
print("Swift↔Rust cache eviction passed (pinned protected)")
