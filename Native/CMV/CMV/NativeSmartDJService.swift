import Foundation
import CMVDomain

/// Bridges the value-only Smart DJ scoring core. No audio, URLs or user data
/// leave the process; only compact track snapshots cross the Rust ABI.
struct NativeSmartDJService: SmartDJService {
    private let rust = CMVCoreRSClient()

    func makeQueue(from tracks: [Track], profiles: [UUID: AnalysisProfile],
                   history: [UUID: ListeningSignal], limit: Int) async -> [DJSelection] {
        let input = tracks.map { track in
            let profile = track.analysis ?? profiles[track.id]
            let signal = history[track.id] ?? ListeningSignal()
            return RustDJTrack(identifier: track.id.uuidString, title: track.title,
                               favorite: track.isFavorite, rating: UInt8(clamping: track.rating),
                               bpm: profile?.bpm, energy: profile?.energy ?? 0,
                               playCount: UInt32(clamping: signal.playCount),
                               skipCount: UInt32(clamping: signal.skipCount))
        }
        guard let selections = try? rust.makeDJ(tracks: input, limit: limit) else { return [] }
        let byID = Dictionary(tracks.map { ($0.id.uuidString, $0) },
                              uniquingKeysWith: { first, _ in first })
        return selections.compactMap { selection in
            guard let track = byID[selection.identifier] else { return nil }
            return DJSelection(track: track, score: selection.score, reasons: selection.reasons)
        }
    }
}
