import SwiftUI
import CMVDomain

/// Read-only Get Info surface. Optional source tags are shown as 未提供 so a
/// filesystem modification date is never mistaken for a release date.
struct TrackInfoView: View {
    let track: Track
    @Environment(\.dismiss) private var dismiss
    private var unavailableText: String { AppLanguage.localized("未提供") }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本資訊") {
                    infoRow("歌名", track.title)
                    infoRow("歌手", AppLanguage.localizedArtist(track.artist))
                    infoRow("專輯", AppLanguage.localizedAlbum(track.album))
                    infoRow("專輯歌手", track.albumArtist.isEmpty ? unavailableText : track.albumArtist)
                    infoRow("類型", track.genre?.isEmpty == false ? track.genre! : unavailableText)
                    infoRow("發行日期", track.releaseDate.map(Self.dateFormatter.string) ?? unavailableText)
                    infoRow("評分", track.rating > 0
                            ? String(format: AppLanguage.localized("%lld 顆星"), locale: AppLanguage.currentLocale, arguments: [Int64(track.rating)])
                            : unavailableText)
                }
                Section("檔案與曲目") {
                    infoRow("曲目編號", track.trackNumber.map(String.init) ?? unavailableText)
                    infoRow("唱片編號", track.discNumber.map(String.init) ?? unavailableText)
                    infoRow("播放時長", track.duration > 0 ? (Self.durationFormatter.string(from: track.duration) ?? unavailableText) : unavailableText)
                    infoRow("加入曲庫", track.addedAt.timeIntervalSince1970 > 0
                            ? Self.dateFormatter.string(from: track.addedAt) : unavailableText)
                    infoRow("檔案修改時間", Self.dateFormatter.string(from: track.modifiedAt))
                    infoRow("相對路徑", track.relativePath)
                }
            }
            .navigationTitle("歌曲資訊")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 420)
        .environment(\.locale, AppLanguage.currentLocale)
    }

    private func infoRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        LabeledContent(title, value: value)
    }

    private static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.currentLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}
