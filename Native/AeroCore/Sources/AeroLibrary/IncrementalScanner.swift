import Foundation
import AVFoundation
import AeroDomain

private actor ScannedFileCollector {
    private var files: [ScannedMediaFile] = []

    func append(_ batch: [ScannedMediaFile]) { files.append(contentsOf: batch) }
    func value() -> [ScannedMediaFile] { files }
}

private struct ExtractedMetadata: Sendable {
    var mediaKind: MediaKind
    var title: String
    var artist: String
    var album: String
    var albumArtist: String
    var artworkData: Data?
    var trackNumber: Int?
    var discNumber: Int?
    var duration: TimeInterval
    var replayGainDB: Double?
}

public enum MediaScanError: LocalizedError, Equatable, Sendable {
    case unreadableFile(path: String)
    case unsupportedFile(path: String)

    public var errorDescription: String? {
        switch self {
        case .unreadableFile(let path):
            "無法讀取媒體檔案「\(path)」，已略過此檔案，其餘索引會繼續。請確認檔案完整且來源仍可存取。"
        case .unsupportedFile(let path):
            "不支援媒體檔案「\(path)」的播放格式，已略過此檔案，其餘索引會繼續。"
        }
    }
}

public actor IncrementalScanner {
    private static let supportedExtensions: Set<String> = ["mp3", "aac", "m4a", "alac", "flac", "wav", "aiff", "aif", "mp4", "mov", "m4v"]
    private var cancelled = false

    public init() {}

    public func cancel() { cancelled = true }

    public func scan(
        url root: URL,
        batchSize: Int = 400,
        accessAlreadyGranted: Bool = false,
        onBatch: @escaping @Sendable ([ScannedMediaFile]) async throws -> Void,
        onProgress: @escaping @Sendable (ScanProgress) async -> Void,
        onIssue: @escaping @Sendable (MediaScanError) async -> Void = { _ in }
    ) async throws {
        if cancelled {
            cancelled = false
            throw CancellationError()
        }
        defer { cancelled = false }
        let canAccess = accessAlreadyGranted || root.startAccessingSecurityScopedResource()
        guard canAccess else { throw MediaSourceAccessError.accessDenied }
        defer {
            if !accessAlreadyGranted { root.stopAccessingSecurityScopedResource() }
        }

        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .fileResourceIdentifierKey, .isHiddenKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
                                                               options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        let effectiveBatchSize = max(1, batchSize)
        var batch: [ScannedMediaFile] = []
        batch.reserveCapacity(effectiveBatchSize)
        var processed = 0
        while let url = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            if cancelled { throw CancellationError() }
            guard Self.supportedExtensions.contains(url.pathExtension.lowercased()) else { continue }
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true else { continue }
            processed += 1
            let relative = String(url.path.dropFirst(root.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let identifier = values.fileResourceIdentifier.map { String(describing: $0) } ?? relative
            let metadata: ExtractedMetadata
            do {
                metadata = try await Self.extractMetadata(from: url, fallbackTitle: url.deletingPathExtension().lastPathComponent)
            } catch let issue as MediaScanError {
                // A single damaged file must not invalidate an otherwise
                // usable source. Keep scanning and let the app surface the
                // actionable filename to the user.
                await onIssue(issue)
                continue
            } catch {
                await onIssue(.unreadableFile(path: url.lastPathComponent))
                continue
            }
            batch.append(ScannedMediaFile(relativePath: relative, fileIdentifier: identifier,
                                          fileSize: Int64(values.fileSize ?? 0),
                                          modifiedAt: values.contentModificationDate ?? .distantPast,
                                          title: metadata.title, artist: metadata.artist,
                                          album: metadata.album, albumArtist: metadata.albumArtist,
                                          artworkData: metadata.artworkData,
                                          trackNumber: metadata.trackNumber, discNumber: metadata.discNumber,
                                          duration: metadata.duration, replayGainDB: metadata.replayGainDB,
                                          mediaKind: metadata.mediaKind))
            if batch.count == effectiveBatchSize {
                try await onBatch(batch)
                batch.removeAll(keepingCapacity: true)
            }
            if processed == 1 || processed.isMultiple(of: 128) {
                await onProgress(ScanProgress(discovered: processed, processed: processed, currentPath: relative))
            }
        }
        if !batch.isEmpty { try await onBatch(batch) }
        await onProgress(ScanProgress(discovered: processed, processed: processed, currentPath: ""))
    }

    public func scan(
        url root: URL,
        accessAlreadyGranted: Bool = false,
        onProgress: @escaping @Sendable (ScanProgress) async -> Void,
        onIssue: @escaping @Sendable (MediaScanError) async -> Void = { _ in }
    ) async throws -> [ScannedMediaFile] {
        let collector = ScannedFileCollector()
        try await scan(
            url: root,
            accessAlreadyGranted: accessAlreadyGranted,
            onBatch: { await collector.append($0) },
            onProgress: onProgress,
            onIssue: onIssue
        )
        return await collector.value()
    }

    private static func extractMetadata(from url: URL, fallbackTitle: String) async throws -> ExtractedMetadata {
        let asset = AVURLAsset(url: url)
        let tracks: [AVAssetTrack]
        do {
            tracks = try await asset.load(.tracks)
        } catch {
            throw MediaScanError.unreadableFile(path: url.lastPathComponent)
        }
        guard !tracks.isEmpty else {
            throw MediaScanError.unreadableFile(path: url.lastPathComponent)
        }
        let isPlayable: Bool
        do {
            isPlayable = try await asset.load(.isPlayable)
        } catch {
            throw MediaScanError.unreadableFile(path: url.lastPathComponent)
        }
        guard isPlayable else {
            throw MediaScanError.unsupportedFile(path: url.lastPathComponent)
        }
        let hasVideo = tracks.contains { $0.mediaType == .video }
        let hasAudio = tracks.contains { $0.mediaType == .audio }
        guard hasVideo || hasAudio else {
            throw MediaScanError.unsupportedFile(path: url.lastPathComponent)
        }
        var result = ExtractedMetadata(mediaKind: hasVideo ? .video : .audio,
                                       title: fallbackTitle, artist: "未知歌手", album: "未知專輯",
                                       albumArtist: "", artworkData: nil, trackNumber: nil,
                                       discNumber: nil, duration: 0, replayGainDB: nil)
        let commonMetadata = (try? await asset.load(.commonMetadata)) ?? []
        let formatMetadata = (try? await asset.load(.metadata)) ?? []
        let metadata = commonMetadata + formatMetadata
        var textValues: [String] = []
        for item in metadata {
            guard let value = try? await item.load(.stringValue), !value.isEmpty else { continue }
            textValues.append(value)
            switch item.identifier {
            case AVMetadataIdentifier.commonIdentifierTitle: result.title = value
            case AVMetadataIdentifier.commonIdentifierArtist: result.artist = value
            case AVMetadataIdentifier.commonIdentifierAlbumName: result.album = value
            case AVMetadataIdentifier.commonIdentifierAuthor where result.albumArtist.isEmpty:
                result.albumArtist = value
            default: break
            }
            let identifier = item.identifier?.rawValue ?? ""
            if identifier.lowercased().contains("track") {
                result.trackNumber = AudioMetadataParser.integerTag(from: identifier, value: value) ?? result.trackNumber
            } else if identifier.lowercased().contains("disc") {
                result.discNumber = AudioMetadataParser.integerTag(from: identifier, value: value) ?? result.discNumber
            }
        }
        result.replayGainDB = AudioMetadataParser.replayGainDB(from: textValues)
        if let artworkItem = metadata.first(where: { $0.identifier == AVMetadataIdentifier.commonIdentifierArtwork }),
           let loadedData = try? await artworkItem.load(.dataValue),
           loadedData.count <= 20 * 1_024 * 1_024 {
            result.artworkData = loadedData
        }
        if let duration = try? await asset.load(.duration), duration.seconds.isFinite, duration.seconds > 0 {
            result.duration = duration.seconds
        } else if let file = try? AVAudioFile(forReading: url), file.processingFormat.sampleRate > 0 {
            result.duration = Double(file.length) / file.processingFormat.sampleRate
        }
        return result
    }
}
