import Foundation
import CMVDomain

public struct LocalSmartDJService: SmartDJService {
    public init() {}

    public func makeQueue(from tracks: [Track], profiles: [UUID: AnalysisProfile],
                          history: [UUID: ListeningSignal], limit: Int) async throws -> [DJSelection] {
        tracks.map { track in
            let profile = track.analysis ?? profiles[track.id]
            let signal = history[track.id] ?? ListeningSignal()
            let rating = min(5, max(0, track.rating))
            let playCount = max(0, signal.playCount)
            let skipCount = max(0, signal.skipCount)
            let bpm = profile?.bpm.flatMap { value in
                value.isFinite && (20...400).contains(value) ? value : nil
            }
            var score = Double(rating) * 0.7 + (track.isFavorite ? 2.0 : 0)
            score += min(2.0, Double(playCount) * 0.12)
            score -= min(4.0, Double(skipCount) * 0.45)
            var reasons: [String] = []
            if track.isFavorite { reasons.append("你已加入最愛") }
            if rating >= 4 { reasons.append("評分很高") }
            if let bpm { reasons.append("節奏約 \(Int(bpm.rounded())) BPM") }
            if let key = profile?.musicalKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
                reasons.append("調性為 \(key)")
            }
            if reasons.isEmpty {
                reasons.append(playCount == 0 ? "尚未播放過" : "依聆聽習慣推薦")
            }
            return DJSelection(track: track, score: score, reasons: reasons)
        }
        .sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            let titleOrder = lhs.track.title.localizedStandardCompare(rhs.track.title)
            if titleOrder != .orderedSame { return titleOrder == .orderedAscending }
            return lhs.track.id.uuidString < rhs.track.id.uuidString
        }
        .prefix(max(0, limit))
        .map { $0 }
    }
}
