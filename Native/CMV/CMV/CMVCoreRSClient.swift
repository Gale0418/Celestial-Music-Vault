import CMVCoreFFI
import Foundation

enum CMVCoreRSError: Error, Equatable, Sendable {
    case unsupportedABIVersion(UInt32)
    case invalidArgument
    case invalidPayload
    case reconciliationFailed
    case playbackPlanFailed
    case searchFailed
    case analysisFailed
    case rustPanic
    case unknownStatus(Int32)
    case malformedResponse
    case valueTooLarge
}

enum RustTrackAvailability: UInt8, Sendable {
    case available = 0
    case sourceOffline = 1
    case missing = 2
    case permissionRequired = 3
}

struct RustTrackSnapshot: Equatable, Sendable {
    let identifier: String
    let relativePath: String
    let fileSize: UInt64
    let modifiedAtMillis: Int64
    let title: String
    let availability: RustTrackAvailability
}

struct RustScannedFile: Equatable, Sendable {
    let identifier: String
    let relativePath: String
    let fileSize: UInt64
    let modifiedAtMillis: Int64
    let title: String
}

enum RustUpsertKind: UInt8, Sendable {
    case insert = 0
    case update = 1
}

struct RustTrackUpsert: Equatable, Sendable {
    let kind: RustUpsertKind
    let file: RustScannedFile
}

struct RustReconciliation: Equatable, Sendable {
    let upserts: [RustTrackUpsert]
    let missingIdentifiers: [String]
}

struct RustTimelineTrack: Equatable, Sendable {
    let sampleRateHz: UInt32
    let totalFrames: UInt64
    let startFrame: UInt64
    let replayGainDB: Double?
    let peak: Double?
}

struct RustPlaybackPlan: Equatable, Sendable {
    let currentStartFrame: UInt64
    let currentFrameCount: UInt64
    let nextStartEngineFrame: UInt64
    let currentGainLinear: Double
    let nextGainLinear: Double
}

struct RustSearchTrack: Equatable, Sendable {
    let identifier: String
    let title: String
    let artist: String
    let album: String
    let favorite: Bool
    let rating: UInt8
}

struct RustSearchResult: Equatable, Sendable {
    let identifier: String
    let score: UInt32
}

struct RustAnalysisFeatures: Equatable, Sendable {
    let version: UInt32
    let integratedLoudnessLUFS: Double
    let peak: Double
    let energy: Double
    let brightness: Double
    let bpm: Double?
    let musicalKey: UInt8?
}

struct RustDJTrack: Equatable, Sendable {
    let identifier: String
    let title: String
    let favorite: Bool
    let rating: UInt8
    let bpm: Double?
    let energy: Double
    let playCount: UInt32
    let skipCount: UInt32
}

struct RustDJSelection: Equatable, Sendable {
    let identifier: String
    let score: Double
    let reasons: [String]
}

struct RustCacheEvictionEntry: Equatable, Sendable {
    let identifier: String
    let sizeBytes: Int64
    let pinned: Bool
    let lastAccessOrder: UInt64
}

struct CMVCoreRSClient: Sendable {
    static let supportedABIVersion: UInt32 = 1

    func reconcile(
        existing: [RustTrackSnapshot],
        scanned: [RustScannedFile],
        sourceReachable: Bool
    ) throws -> RustReconciliation {
        let actualVersion = cmv_core_abi_version_v1()
        guard actualVersion == Self.supportedABIVersion else {
            throw CMVCoreRSError.unsupportedABIVersion(actualVersion)
        }

        let request = try RequestEncoder.encode(
            existing: existing,
            scanned: scanned,
            sourceReachable: sourceReachable
        )
        var output = CMVOwnedBufferV1(ptr: nil, len: 0)
        let status = request.withUnsafeBytes { bytes in
            cmv_core_reconcile_v1(
                bytes.bindMemory(to: UInt8.self).baseAddress,
                bytes.count,
                &output
            )
        }
        guard status == CMV_STATUS_OK_V1.rawValue else {
            throw Self.error(for: status)
        }
        defer { cmv_core_buffer_free_v1(output) }
        guard let pointer = output.ptr else {
            throw CMVCoreRSError.malformedResponse
        }
        var decoder = ResponseDecoder(
            bytes: UnsafeBufferPointer(start: pointer, count: output.len)
        )
        return try decoder.decode()
    }

    func planPlayback(
        engineSampleRateHz: UInt32,
        current: RustTimelineTrack,
        next: RustTimelineTrack
    ) throws -> RustPlaybackPlan {
        let actualVersion = cmv_core_abi_version_v1()
        guard actualVersion == Self.supportedABIVersion else {
            throw CMVCoreRSError.unsupportedABIVersion(actualVersion)
        }
        let request = PlaybackRequestEncoder.encode(
            engineSampleRateHz: engineSampleRateHz,
            current: current,
            next: next
        )
        var output = CMVOwnedBufferV1(ptr: nil, len: 0)
        let status = request.withUnsafeBytes { bytes in
            cmv_core_plan_playback_v1(
                bytes.bindMemory(to: UInt8.self).baseAddress,
                bytes.count,
                &output
            )
        }
        guard status == CMV_STATUS_OK_V1.rawValue else {
            throw Self.error(for: status)
        }
        defer { cmv_core_buffer_free_v1(output) }
        guard let pointer = output.ptr else {
            throw CMVCoreRSError.malformedResponse
        }
        var decoder = PlaybackResponseDecoder(
            bytes: UnsafeBufferPointer(start: pointer, count: output.len)
        )
        return try decoder.decode()
    }

    func search(
        query: String,
        tracks: [RustSearchTrack],
        limit: Int
    ) throws -> [RustSearchResult] {
        let actualVersion = cmv_core_abi_version_v1()
        guard actualVersion == Self.supportedABIVersion else {
            throw CMVCoreRSError.unsupportedABIVersion(actualVersion)
        }
        let request = try SearchRequestEncoder.encode(query: query, tracks: tracks, limit: limit)
        var output = CMVOwnedBufferV1(ptr: nil, len: 0)
        let status = request.withUnsafeBytes { bytes in
            cmv_core_search_v1(
                bytes.bindMemory(to: UInt8.self).baseAddress,
                bytes.count,
                &output
            )
        }
        guard status == CMV_STATUS_OK_V1.rawValue else {
            throw Self.error(for: status)
        }
        defer { cmv_core_buffer_free_v1(output) }
        guard let pointer = output.ptr else { throw CMVCoreRSError.malformedResponse }
        var decoder = SearchResponseDecoder(
            bytes: UnsafeBufferPointer(start: pointer, count: output.len)
        )
        return try decoder.decode()
    }

    func analyzePCM(samples: [Float], sampleRateHz: UInt32, channels: UInt16) throws -> RustAnalysisFeatures {
        try validateABIVersion()
        let request = try AnalysisRequestEncoder.encode(samples: samples, sampleRateHz: sampleRateHz, channels: channels)
        var output = CMVOwnedBufferV1(ptr: nil, len: 0)
        let status = request.withUnsafeBytes { bytes in
            cmv_core_analyze_pcm_v1(bytes.bindMemory(to: UInt8.self).baseAddress, bytes.count, &output)
        }
        guard status == CMV_STATUS_OK_V1.rawValue else { throw Self.error(for: status) }
        defer { cmv_core_buffer_free_v1(output) }
        guard let pointer = output.ptr else { throw CMVCoreRSError.malformedResponse }
        var decoder = AnalysisResponseDecoder(bytes: UnsafeBufferPointer(start: pointer, count: output.len))
        return try decoder.decode()
    }

    func makeDJ(tracks: [RustDJTrack], limit: Int) throws -> [RustDJSelection] {
        try validateABIVersion()
        var request = Data("CMV1".utf8)
        request.appendInteger(UInt16(1))
        try request.appendCount(limit)
        try request.appendCount(tracks.count)
        for track in tracks {
            try request.appendString(track.identifier)
            try request.appendString(track.title)
            request.append(track.favorite ? 1 : 0)
            request.append(track.rating)
            request.appendOptionalDouble(track.bpm)
            request.appendInteger(track.energy.bitPattern)
            request.appendInteger(track.playCount)
            request.appendInteger(track.skipCount)
        }
        var output = CMVOwnedBufferV1(ptr: nil, len: 0)
        let status = request.withUnsafeBytes { bytes in
            cmv_core_make_dj_v1(bytes.bindMemory(to: UInt8.self).baseAddress, bytes.count, &output)
        }
        guard status == CMV_STATUS_OK_V1.rawValue else { throw Self.error(for: status) }
        defer { cmv_core_buffer_free_v1(output) }
        guard let pointer = output.ptr else { throw CMVCoreRSError.malformedResponse }
        var decoder = DJResponseDecoder(bytes: UnsafeBufferPointer(start: pointer, count: output.len))
        return try decoder.decode()
    }

    func planEviction(entries: [RustCacheEvictionEntry], budgetBytes: Int64) throws -> [String] {
        guard budgetBytes >= 0, entries.allSatisfy({ $0.sizeBytes >= 0 }) else {
            throw CMVCoreRSError.invalidArgument
        }
        let actualVersion = cmv_core_abi_version_v1()
        guard actualVersion == Self.supportedABIVersion else {
            throw CMVCoreRSError.unsupportedABIVersion(actualVersion)
        }
        var request = Data("CMV1".utf8)
        request.appendInteger(UInt16(1))
        request.appendInteger(UInt64(budgetBytes))
        try request.appendCount(entries.count)
        for entry in entries {
            try request.appendString(entry.identifier)
            request.appendInteger(UInt64(entry.sizeBytes))
            request.append(entry.pinned ? 1 : 0)
            request.appendInteger(entry.lastAccessOrder)
        }
        var output = CMVOwnedBufferV1(ptr: nil, len: 0)
        let status = request.withUnsafeBytes { bytes in
            cmv_core_eviction_plan_v1(bytes.bindMemory(to: UInt8.self).baseAddress, bytes.count, &output)
        }
        guard status == CMV_STATUS_OK_V1.rawValue else { throw Self.error(for: status) }
        defer { cmv_core_buffer_free_v1(output) }
        guard let pointer = output.ptr else { throw CMVCoreRSError.malformedResponse }
        var decoder = CacheResponseDecoder(bytes: UnsafeBufferPointer(start: pointer, count: output.len))
        return try decoder.decode()
    }

    private static func error(for status: Int32) -> CMVCoreRSError {
        switch status {
        case 1: .invalidArgument
        case 2: .invalidPayload
        case 3: .reconciliationFailed
        case 4: .playbackPlanFailed
        case 5: .searchFailed
        case 6: .analysisFailed
        case 7: .unknownStatus(status)
        case 8: .unknownStatus(status)
        case 255: .rustPanic
        default: .unknownStatus(status)
        }
    }

    private func validateABIVersion() throws {
        let actualVersion = cmv_core_abi_version_v1()
        guard actualVersion == Self.supportedABIVersion else {
            throw CMVCoreRSError.unsupportedABIVersion(actualVersion)
        }
    }
}

private enum PlaybackRequestEncoder {
    static func encode(
        engineSampleRateHz: UInt32,
        current: RustTimelineTrack,
        next: RustTimelineTrack
    ) -> Data {
        var bytes = Data("CMV1".utf8)
        bytes.appendInteger(UInt16(1))
        bytes.appendInteger(engineSampleRateHz)
        bytes.appendTimelineTrack(current)
        bytes.appendTimelineTrack(next)
        return bytes
    }
}

private enum SearchRequestEncoder {
    static func encode(query: String, tracks: [RustSearchTrack], limit: Int) throws -> Data {
        var bytes = Data("CMV1".utf8)
        bytes.appendInteger(UInt16(1))
        try bytes.appendString(query)
        try bytes.appendCount(limit)
        try bytes.appendCount(tracks.count)
        for track in tracks {
            try bytes.appendString(track.identifier)
            try bytes.appendString(track.title)
            try bytes.appendString(track.artist)
            try bytes.appendString(track.album)
            bytes.append(track.favorite ? 1 : 0)
            bytes.append(track.rating)
        }
        return bytes
    }
}

private enum AnalysisRequestEncoder {
    static func encode(samples: [Float], sampleRateHz: UInt32, channels: UInt16) throws -> Data {
        guard channels > 0, samples.count <= Int(UInt32.max), samples.count % Int(channels) == 0 else {
            throw CMVCoreRSError.valueTooLarge
        }
        var bytes = Data("CMV1".utf8)
        bytes.appendInteger(UInt16(1))
        bytes.appendInteger(sampleRateHz)
        bytes.appendInteger(channels)
        bytes.appendInteger(UInt32(samples.count))
        for sample in samples { bytes.appendInteger(sample.bitPattern) }
        return bytes
    }
}

private enum RequestEncoder {
    static func encode(
        existing: [RustTrackSnapshot],
        scanned: [RustScannedFile],
        sourceReachable: Bool
    ) throws -> Data {
        var bytes = Data("CMV1".utf8)
        bytes.appendInteger(UInt16(1))
        bytes.append(sourceReachable ? 1 : 0)
        try bytes.appendCount(existing.count)
        try bytes.appendCount(scanned.count)
        for track in existing {
            try bytes.appendString(track.identifier)
            try bytes.appendString(track.relativePath)
            bytes.appendInteger(track.fileSize)
            bytes.appendInteger(UInt64(bitPattern: track.modifiedAtMillis))
            try bytes.appendString(track.title)
            bytes.append(track.availability.rawValue)
        }
        for file in scanned {
            try bytes.appendScannedFile(file)
        }
        return bytes
    }
}

private struct ResponseDecoder {
    private let bytes: UnsafeBufferPointer<UInt8>
    private var offset = 0

    init(bytes: UnsafeBufferPointer<UInt8>) {
        self.bytes = bytes
    }

    mutating func decode() throws -> RustReconciliation {
        guard try take(count: 4).elementsEqual("CMV1".utf8),
              try readInteger(as: UInt16.self) == 1 else {
            throw CMVCoreRSError.malformedResponse
        }
        let upsertCount = try readCount()
        var upserts: [RustTrackUpsert] = []
        upserts.reserveCapacity(upsertCount)
        for _ in 0..<upsertCount {
            guard let kind = RustUpsertKind(rawValue: try readInteger(as: UInt8.self)) else {
                throw CMVCoreRSError.malformedResponse
            }
            upserts.append(RustTrackUpsert(kind: kind, file: try readScannedFile()))
        }
        let missingCount = try readCount()
        var missing: [String] = []
        missing.reserveCapacity(missingCount)
        for _ in 0..<missingCount {
            missing.append(try readString())
        }
        guard offset == bytes.count else {
            throw CMVCoreRSError.malformedResponse
        }
        return RustReconciliation(upserts: upserts, missingIdentifiers: missing)
    }

    private mutating func readScannedFile() throws -> RustScannedFile {
        RustScannedFile(
            identifier: try readString(),
            relativePath: try readString(),
            fileSize: try readInteger(as: UInt64.self),
            modifiedAtMillis: Int64(bitPattern: try readInteger(as: UInt64.self)),
            title: try readString()
        )
    }

    private mutating func readCount() throws -> Int {
        Int(try readInteger(as: UInt32.self))
    }

    private mutating func readString() throws -> String {
        let count = try readCount()
        let data = Data(try take(count: count))
        guard let value = String(data: data, encoding: .utf8) else {
            throw CMVCoreRSError.malformedResponse
        }
        return value
    }

    private mutating func readInteger<T: FixedWidthInteger>(as: T.Type) throws -> T {
        let slice = try take(count: MemoryLayout<T>.size)
        return slice.enumerated().reduce(into: T.zero) { result, element in
            result |= T(element.element) << T(element.offset * 8)
        }
    }

    private mutating func take(count: Int) throws -> Slice<UnsafeBufferPointer<UInt8>> {
        guard count >= 0, offset <= bytes.count, count <= bytes.count - offset else {
            throw CMVCoreRSError.malformedResponse
        }
        let start = offset
        offset += count
        return bytes[start..<offset]
    }
}

private struct PlaybackResponseDecoder {
    private let bytes: UnsafeBufferPointer<UInt8>
    private var offset = 0

    init(bytes: UnsafeBufferPointer<UInt8>) {
        self.bytes = bytes
    }

    mutating func decode() throws -> RustPlaybackPlan {
        guard try take(count: 4).elementsEqual("CMV1".utf8),
              try readInteger(as: UInt16.self) == 1 else {
            throw CMVCoreRSError.malformedResponse
        }
        let result = RustPlaybackPlan(
            currentStartFrame: try readInteger(as: UInt64.self),
            currentFrameCount: try readInteger(as: UInt64.self),
            nextStartEngineFrame: try readInteger(as: UInt64.self),
            currentGainLinear: Double(bitPattern: try readInteger(as: UInt64.self)),
            nextGainLinear: Double(bitPattern: try readInteger(as: UInt64.self))
        )
        guard offset == bytes.count else {
            throw CMVCoreRSError.malformedResponse
        }
        return result
    }

    private mutating func readInteger<T: FixedWidthInteger>(as: T.Type) throws -> T {
        let slice = try take(count: MemoryLayout<T>.size)
        return slice.enumerated().reduce(into: T.zero) { result, element in
            result |= T(element.element) << T(element.offset * 8)
        }
    }

    private mutating func take(count: Int) throws -> Slice<UnsafeBufferPointer<UInt8>> {
        guard count >= 0, offset <= bytes.count, count <= bytes.count - offset else {
            throw CMVCoreRSError.malformedResponse
        }
        let start = offset
        offset += count
        return bytes[start..<offset]
    }
}

private struct SearchResponseDecoder {
    private let bytes: UnsafeBufferPointer<UInt8>
    private var offset = 0

    init(bytes: UnsafeBufferPointer<UInt8>) { self.bytes = bytes }

    mutating func decode() throws -> [RustSearchResult] {
        guard try take(count: 4).elementsEqual("CMV1".utf8),
              try readInteger(as: UInt16.self) == 1 else {
            throw CMVCoreRSError.malformedResponse
        }
        let count = Int(try readInteger(as: UInt32.self))
        var results: [RustSearchResult] = []
        results.reserveCapacity(count)
        for _ in 0..<count {
            results.append(RustSearchResult(
                identifier: try readString(),
                score: try readInteger(as: UInt32.self)
            ))
        }
        guard offset == bytes.count else { throw CMVCoreRSError.malformedResponse }
        return results
    }

    private mutating func readString() throws -> String {
        let count = Int(try readInteger(as: UInt32.self))
        let data = Data(try take(count: count))
        guard let value = String(data: data, encoding: .utf8) else {
            throw CMVCoreRSError.malformedResponse
        }
        return value
    }

    private mutating func readInteger<T: FixedWidthInteger>(as: T.Type) throws -> T {
        let slice = try take(count: MemoryLayout<T>.size)
        return slice.enumerated().reduce(into: T.zero) { result, element in
            result |= T(element.element) << T(element.offset * 8)
        }
    }

    private mutating func take(count: Int) throws -> Slice<UnsafeBufferPointer<UInt8>> {
        guard count >= 0, offset <= bytes.count, count <= bytes.count - offset else {
            throw CMVCoreRSError.malformedResponse
        }
        let start = offset
        offset += count
        return bytes[start..<offset]
    }
}

private struct AnalysisResponseDecoder {
    private let bytes: UnsafeBufferPointer<UInt8>
    private var offset = 0

    init(bytes: UnsafeBufferPointer<UInt8>) { self.bytes = bytes }

    mutating func decode() throws -> RustAnalysisFeatures {
        guard try take(count: 4).elementsEqual("CMV1".utf8),
              try readInteger(as: UInt16.self) == 1 else { throw CMVCoreRSError.malformedResponse }
        let result = RustAnalysisFeatures(
            version: try readInteger(as: UInt32.self),
            integratedLoudnessLUFS: Double(bitPattern: try readInteger(as: UInt64.self)),
            peak: Double(bitPattern: try readInteger(as: UInt64.self)),
            energy: Double(bitPattern: try readInteger(as: UInt64.self)),
            brightness: Double(bitPattern: try readInteger(as: UInt64.self)),
            bpm: try readOptionalDouble(),
            musicalKey: try readOptionalByte()
        )
        guard offset == bytes.count else { throw CMVCoreRSError.malformedResponse }
        return result
    }

    private mutating func readOptionalDouble() throws -> Double? {
        switch try readInteger(as: UInt8.self) {
        case 0: return nil
        case 1: return Double(bitPattern: try readInteger(as: UInt64.self))
        default: throw CMVCoreRSError.malformedResponse
        }
    }

    private mutating func readOptionalByte() throws -> UInt8? {
        switch try readInteger(as: UInt8.self) {
        case 0: return nil
        case 1: return try readInteger(as: UInt8.self)
        default: throw CMVCoreRSError.malformedResponse
        }
    }

    private mutating func readInteger<T: FixedWidthInteger>(as: T.Type) throws -> T {
        let slice = try take(count: MemoryLayout<T>.size)
        return slice.enumerated().reduce(into: T.zero) { result, element in
            result |= T(element.element) << T(element.offset * 8)
        }
    }

    private mutating func take(count: Int) throws -> Slice<UnsafeBufferPointer<UInt8>> {
        guard count >= 0, offset <= bytes.count, count <= bytes.count - offset else { throw CMVCoreRSError.malformedResponse }
        let start = offset; offset += count
        return bytes[start..<offset]
    }
}

private struct DJResponseDecoder {
    private let bytes: UnsafeBufferPointer<UInt8>
    private var offset = 0

    init(bytes: UnsafeBufferPointer<UInt8>) { self.bytes = bytes }

    mutating func decode() throws -> [RustDJSelection] {
        guard try take(count: 4).elementsEqual("CMV1".utf8),
              try readInteger(as: UInt16.self) == 1 else { throw CMVCoreRSError.malformedResponse }
        let count = Int(try readInteger(as: UInt32.self))
        var result: [RustDJSelection] = []
        result.reserveCapacity(count)
        for _ in 0..<count {
            let identifier = try readString()
            let score = Double(bitPattern: try readInteger(as: UInt64.self))
            let reasonCount = Int(try readInteger(as: UInt32.self))
            var reasons: [String] = []
            reasons.reserveCapacity(reasonCount)
            for _ in 0..<reasonCount { reasons.append(try readString()) }
            result.append(RustDJSelection(identifier: identifier, score: score, reasons: reasons))
        }
        guard offset == bytes.count else { throw CMVCoreRSError.malformedResponse }
        return result
    }

    private mutating func readString() throws -> String {
        let count = Int(try readInteger(as: UInt32.self))
        let data = Data(try take(count: count))
        guard let value = String(data: data, encoding: .utf8) else { throw CMVCoreRSError.malformedResponse }
        return value
    }

    private mutating func readInteger<T: FixedWidthInteger>(as: T.Type) throws -> T {
        let slice = try take(count: MemoryLayout<T>.size)
        return slice.enumerated().reduce(into: T.zero) { result, element in
            result |= T(element.element) << T(element.offset * 8)
        }
    }

    private mutating func take(count: Int) throws -> Slice<UnsafeBufferPointer<UInt8>> {
        guard count >= 0, offset <= bytes.count, count <= bytes.count - offset else { throw CMVCoreRSError.malformedResponse }
        let start = offset; offset += count
        return bytes[start..<offset]
    }
}

private struct CacheResponseDecoder {
    private let bytes: UnsafeBufferPointer<UInt8>
    private var offset = 0

    init(bytes: UnsafeBufferPointer<UInt8>) { self.bytes = bytes }

    mutating func decode() throws -> [String] {
        guard try take(count: 4).elementsEqual("CMV1".utf8),
              try readInteger(as: UInt16.self) == 1 else { throw CMVCoreRSError.malformedResponse }
        let count = Int(try readInteger(as: UInt32.self))
        var result: [String] = []
        result.reserveCapacity(count)
        for _ in 0..<count { result.append(try readString()) }
        guard offset == bytes.count else { throw CMVCoreRSError.malformedResponse }
        return result
    }

    private mutating func readString() throws -> String {
        let count = Int(try readInteger(as: UInt32.self))
        let data = Data(try take(count: count))
        guard let value = String(data: data, encoding: .utf8) else { throw CMVCoreRSError.malformedResponse }
        return value
    }

    private mutating func readInteger<T: FixedWidthInteger>(as: T.Type) throws -> T {
        let slice = try take(count: MemoryLayout<T>.size)
        return slice.enumerated().reduce(into: T.zero) { result, element in
            result |= T(element.element) << T(element.offset * 8)
        }
    }

    private mutating func take(count: Int) throws -> Slice<UnsafeBufferPointer<UInt8>> {
        guard count >= 0, offset <= bytes.count, count <= bytes.count - offset else { throw CMVCoreRSError.malformedResponse }
        let start = offset; offset += count
        return bytes[start..<offset]
    }
}

private extension Data {
    mutating func appendInteger<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendCount(_ count: Int) throws {
        guard let value = UInt32(exactly: count) else {
            throw CMVCoreRSError.valueTooLarge
        }
        appendInteger(value)
    }

    mutating func appendString(_ value: String) throws {
        let utf8 = Data(value.utf8)
        try appendCount(utf8.count)
        append(utf8)
    }

    mutating func appendScannedFile(_ file: RustScannedFile) throws {
        try appendString(file.identifier)
        try appendString(file.relativePath)
        appendInteger(file.fileSize)
        appendInteger(UInt64(bitPattern: file.modifiedAtMillis))
        try appendString(file.title)
    }

    mutating func appendOptionalDouble(_ value: Double?) {
        guard let value else {
            append(0)
            return
        }
        append(1)
        appendInteger(value.bitPattern)
    }

    mutating func appendTimelineTrack(_ track: RustTimelineTrack) {
        appendInteger(track.sampleRateHz)
        appendInteger(track.totalFrames)
        appendInteger(track.startFrame)
        appendOptionalDouble(track.replayGainDB)
        appendOptionalDouble(track.peak)
    }
}
