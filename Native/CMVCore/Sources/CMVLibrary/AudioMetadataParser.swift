import Foundation

/// Parses explicit text tags that AVFoundation exposes as generic metadata
/// comments. Arbitrary comments are never treated as playback gain.
public enum AudioMetadataParser {
    public static func releaseDate(from value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        for format in ["yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd", "yyyy"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    public static func replayGainDB(from values: [String]) -> Double? {
        for value in values {
            let uppercased = value.uppercased()
            let isReplayGain = uppercased.hasPrefix("REPLAYGAIN_TRACK_GAIN=")
            let isR128 = uppercased.hasPrefix("R128_TRACK_GAIN=")
            guard isReplayGain || isR128,
                  let separator = value.firstIndex(of: "=") else { continue }
            let rawNumber = value[value.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let number = firstDouble(in: rawNumber), number.isFinite else { continue }
            let decibels: Double
            if isR128 && !rawNumber.lowercased().contains("db") {
                // R128 tags may be stored as signed Q7.8 fixed-point gain.
                decibels = number / 256
            } else {
                decibels = number
            }
            guard (-60...24).contains(decibels) else { continue }
            return decibels
        }
        return nil
    }

    public static func integerTag(from identifier: String, value: String) -> Int? {
        let key = identifier.lowercased()
        guard key.contains("tracknumber") || key.contains("track_number") || key.contains("trck") ||
                key.contains("discnumber") || key.contains("disc_number") || key.contains("tpos") ||
                key.contains("trkn") else { return nil }
        let digits = value.prefix { $0.isNumber }
        return Int(digits)
    }

    private static func firstDouble(in value: String) -> Double? {
        let token = value.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "," }).first
        return token.flatMap { Double($0.replacingOccurrences(of: "dB", with: "", options: .caseInsensitive)) }
    }
}
