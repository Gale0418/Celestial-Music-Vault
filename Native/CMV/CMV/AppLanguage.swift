import Foundation
import CMVLibrary
import CMVPlayback

enum AppLanguage {
    static let preferenceKey = "cmv.appLanguage"
    static var currentLanguage: String {
        identifier(for: UserDefaults.standard.string(forKey: preferenceKey) ?? "system")
    }
    static var currentLocale: Locale { Locale(identifier: currentLanguage) }

    static func formattedCount(_ count: Int) -> String {
        count.formatted(.number.locale(currentLocale))
    }

    static func locale(for preference: String, preferredLanguages: [String] = Locale.preferredLanguages) -> Locale {
        Locale(identifier: identifier(for: preference, preferredLanguages: preferredLanguages))
    }

    static func localized(_ key: String) -> String {
        let language = currentLanguage
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// Localizes only the scanner's known fallback metadata values.
    /// Real metadata, including whitespace and other legacy values, is preserved.
    static func localizedArtist(_ value: String) -> String {
        localizedMetadata(value, fallback: "未知歌手")
    }

    static func localizedAlbum(_ value: String) -> String {
        localizedMetadata(value, fallback: "未知專輯")
    }

    /// Catalog keys combine album and artist; keep the stored key untouched.
    static func localizedAlbumGroup(_ key: String) -> String {
        var display = key
        let unknownAlbumPrefix = "未知專輯 · "
        let unknownArtistSuffix = " · 未知歌手"
        if display.hasPrefix(unknownAlbumPrefix) {
            display.replaceSubrange(display.startIndex..<display.index(display.startIndex, offsetBy: "未知專輯".count),
                                    with: localized("未知專輯"))
        }
        if display.hasSuffix(unknownArtistSuffix) {
            display.replaceSubrange(display.index(display.endIndex, offsetBy: -"未知歌手".count)..<display.endIndex,
                                    with: localized("未知歌手"))
        }
        return display
    }

    private static func localizedMetadata(_ value: String, fallback: String) -> String {
        value.isEmpty || value == fallback ? localized(fallback) : value
    }

    static func localizedError(_ error: Error) -> String {
        if let access = error as? MediaSourceAccessError {
            switch access {
            case .staleBookmark: return localized("音樂來源授權已過期，請重新選擇資料夾。")
            case .accessDenied: return localized("無法存取音樂來源。")
            }
        }
        if let playback = error as? NativePlaybackError {
            switch playback {
            case .unresolvedTrack: return localized("找不到歌曲檔案，請重新連接音樂來源。")
            case .invalidAudioFormat: return localized("歌曲的取樣格式無法播放。")
            case .unsupportedFrameCount: return localized("歌曲長度超出目前播放管線可處理的範圍。")
            }
        }
        if let scan = error as? MediaScanError {
            switch scan {
            case .unreadableFile(let path):
                return String(format: localized("無法讀取媒體檔案「%@」，已略過此檔案，其餘索引會繼續。請確認檔案完整且來源仍可存取。"), path)
            case .unsupportedFile(let path):
                return String(format: localized("不支援媒體檔案「%@」的播放格式，已略過此檔案，其餘索引會繼續。"), path)
            }
        }
        return error.localizedDescription
    }

    private static func identifier(for preference: String, preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        switch preference {
        case "en", "zh-Hant", "ja":
            return preference
        default:
            for language in preferredLanguages.map({ $0.lowercased() }) {
                if language.hasPrefix("zh") { return "zh-Hant" }
                if language.hasPrefix("ja") { return "ja" }
                if language.hasPrefix("en") { return "en" }
            }
            return "en"
        }
    }
}
