import Foundation
import CMVDomain

public struct LocalSmartDJService: SmartDJService {
    public init() {}

    public func makeQueue(from tracks: [Track], profiles: [UUID: AnalysisProfile],
                          history: [UUID: ListeningSignal], limit: Int) async -> [DJSelection] {
        tracks.map { track in
            let profile = profiles[track.id]
            let signal = history[track.id] ?? ListeningSignal()
            var score = Double(track.rating) * 0.7 + (track.isFavorite ? 2.0 : 0)
            score += min(2.0, Double(signal.playCount) * 0.12)
            score -= min(4.0, Double(signal.skipCount) * 0.45)
            var reasons: [String] = []
            if track.isFavorite { reasons.append("你已加入最愛") }
            if track.rating >= 4 { reasons.append("評分很高") }
            if let bpm = profile?.bpm { reasons.append("節奏約 \(Int(bpm)) BPM") }
            if let key = profile?.musicalKey { reasons.append("調性為 \(key)") }
            if reasons.isEmpty {
                reasons.append(signal.playCount == 0 ? "尚未播放過" : "依聆聽習慣推薦")
            }
            return DJSelection(track: track, score: score, reasons: reasons)
        }
        .sorted { lhs, rhs in
            lhs.score == rhs.score ? lhs.track.title.localizedStandardCompare(rhs.track.title) == .orderedAscending : lhs.score > rhs.score
        }
        .prefix(max(0, limit))
        .map { $0 }
    }
}
