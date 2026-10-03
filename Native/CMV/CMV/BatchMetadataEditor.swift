import SwiftUI
import CMVDomain
import CMVLibrary

/// Applies only explicitly selected fields to the chosen library records.
/// Original media files and fields left unchecked are never changed.
struct BatchMetadataEditor: View {
    let selectionIDs: [UUID]
    let selectionCount: Int
    let onSave: (TrackMetadataPatch) -> Void

    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var changesTitle = false
    @State private var changesArtist = false
    @State private var changesAlbum = false
    @State private var changesAlbumArtist = false
    @State private var changesGenre = false
    @State private var changesTrackNumber = false
    @State private var changesDiscNumber = false
    @State private var changesReleaseDate = false
    @State private var title = ""
    @State private var artist = ""
    @State private var album = ""
    @State private var albumArtist = ""
    @State private var genre = ""
    @State private var trackNumber = ""
    @State private var discNumber = ""
    @State private var releaseDate = Date()
    @State private var showingPreview = false
    @State private var isPreviewing = false
    @State private var isSubmitting = false
    @State private var previewRows: [MetadataPreview] = []
    @State private var previewError: String?
    private var unavailableText: String { AppLanguage.localized("未提供") }

    private var canSave: Bool {
        (changesTitle || changesArtist || changesAlbum || changesAlbumArtist || changesGenre ||
         changesTrackNumber || changesDiscNumber || changesReleaseDate) &&
        (!changesTitle || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) &&
        (!changesArtist || !artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) &&
        (!changesAlbum || !album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) &&
        (!changesAlbumArtist || !albumArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        && (!changesGenre || !genre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        && (!changesTrackNumber || Int(trackNumber) != nil && Int(trackNumber)! >= 0)
        && (!changesDiscNumber || Int(discNumber) != nil && Int(discNumber)! >= 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("只修改勾選的欄位；原始音樂檔不會變動。")
                        .foregroundStyle(.secondary)
                } header: {
                    Text(String(format: AppLanguage.localized("批次編輯 %lld 首歌曲"),
                                locale: AppLanguage.currentLocale,
                                arguments: [Int64(selectionCount)]))
                }
                if let previewError {
                    Section {
                        Label(previewError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                Section("統一套用") {
                    fieldRow("歌名", isEnabled: $changesTitle, value: $title)
                    fieldRow("歌手", isEnabled: $changesArtist, value: $artist)
                    fieldRow("專輯", isEnabled: $changesAlbum, value: $album)
                    fieldRow("專輯歌手", isEnabled: $changesAlbumArtist, value: $albumArtist)
                    fieldRow("類型", isEnabled: $changesGenre, value: $genre)
                    numberFieldRow("曲目編號", isEnabled: $changesTrackNumber, value: $trackNumber)
                    numberFieldRow("唱片編號", isEnabled: $changesDiscNumber, value: $discNumber)
                    Toggle("發行日期", isOn: $changesReleaseDate)
                    if changesReleaseDate { DatePicker("日期", selection: $releaseDate, displayedComponents: .date) }
                }
            }
            .navigationTitle("批次編輯歌曲資訊")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("套用變更") {
                        requestPreview()
                    }
                    .disabled(!canSave || isPreviewing || isSubmitting)
                }
            }
            .confirmationDialog("確認批次變更？", isPresented: $showingPreview, titleVisibility: .visible) {
                Button("確認套用") {
                    guard !isSubmitting else { return }
                    isSubmitting = true
                    onSave(makePatch())
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text(previewMessage)
            }
        }
        .frame(maxWidth: 520, minHeight: 360)
        .environment(\.locale, AppLanguage.currentLocale)
    }

    private var previewMessage: String {
        let header = String(format: AppLanguage.localized("預覽 %lld 首歌曲（顯示前 %lld 首）；確認後才會寫入曲庫。原始檔案不會變動。"),
                            locale: AppLanguage.currentLocale,
                            arguments: [Int64(selectionCount), Int64(previewRows.count)])
        guard !previewRows.isEmpty else { return header }
        let lines = previewRows.map { row in
            let changes = metadataChanges(before: row.before, after: row.after)
            let title = row.before.title.isEmpty ? unavailableText : row.before.title
            return "• \(title)：\(changes.joined(separator: "、"))"
        }
        return ([header] + lines).joined(separator: "\n")
    }

    private func requestPreview() {
        guard !isPreviewing, !isSubmitting else { return }
        isPreviewing = true
        previewError = nil
        previewRows = []
        let previewIDs = Array(selectionIDs.prefix(10))
        Task { @MainActor in
            defer { isPreviewing = false }
            do {
                let repository = SwiftDataLibraryRepository(container: context.container)
                previewRows = try await repository.previewMetadata(for: previewIDs, with: makePatch())
                guard !previewRows.isEmpty || selectionCount == 0 else {
                    throw LibraryRepositoryError.trackNotFound(previewIDs.first ?? UUID())
                }
                showingPreview = true
            } catch {
                let message = String(format: AppLanguage.localized("無法預覽歌曲資訊：%@"),
                                     locale: AppLanguage.currentLocale,
                                     arguments: [error.localizedDescription])
                previewError = message
                appModel.errorMessage = message
            }
        }
    }

    private func makePatch() -> TrackMetadataPatch {
        TrackMetadataPatch(
            title: changesTitle ? .set(title.trimmingCharacters(in: .whitespacesAndNewlines)) : .unchanged,
            artist: changesArtist ? .set(artist.trimmingCharacters(in: .whitespacesAndNewlines)) : .unchanged,
            album: changesAlbum ? .set(album.trimmingCharacters(in: .whitespacesAndNewlines)) : .unchanged,
            albumArtist: changesAlbumArtist ? .set(albumArtist.trimmingCharacters(in: .whitespacesAndNewlines)) : .unchanged,
            genre: changesGenre ? .set(genre.trimmingCharacters(in: .whitespacesAndNewlines)) : .unchanged,
            releaseDate: changesReleaseDate ? .set(releaseDate) : .unchanged,
            trackNumber: changesTrackNumber ? .set(Int(trackNumber)!) : .unchanged,
            discNumber: changesDiscNumber ? .set(Int(discNumber)!) : .unchanged
        )
    }

    private func metadataChanges(before: TrackMetadataSnapshot, after: TrackMetadataSnapshot) -> [String] {
        var changes: [String] = []
        if before.title != after.title { changes.append(change("歌名", before.title, after.title)) }
        if before.artist != after.artist { changes.append(change("歌手", before.artist, after.artist)) }
        if before.album != after.album { changes.append(change("專輯", before.album, after.album)) }
        if before.albumArtist != after.albumArtist { changes.append(change("專輯歌手", before.albumArtist, after.albumArtist)) }
        if before.genre != after.genre { changes.append(change("類型", before.genre ?? unavailableText, after.genre ?? unavailableText)) }
        if before.releaseDate != after.releaseDate {
            changes.append(change("發行日期", before.releaseDate.map(Self.previewDateFormatter.string) ?? unavailableText,
                                 after.releaseDate.map(Self.previewDateFormatter.string) ?? unavailableText))
        }
        if before.trackNumber != after.trackNumber { changes.append(change("曲目編號", before.trackNumber.map(String.init) ?? unavailableText, after.trackNumber.map(String.init) ?? unavailableText)) }
        if before.discNumber != after.discNumber { changes.append(change("唱片編號", before.discNumber.map(String.init) ?? unavailableText, after.discNumber.map(String.init) ?? unavailableText)) }
        return changes.isEmpty ? [AppLanguage.localized("沒有差異")] : changes
    }

    private func change(_ label: String, _ before: String, _ after: String) -> String {
        "\(AppLanguage.localized(label))：\(before) → \(after)"
    }

    private static let previewDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private func fieldRow(_ title: LocalizedStringKey, isEnabled: Binding<Bool>,
                          value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: isEnabled)
            if isEnabled.wrappedValue {
                TextField(title, text: value)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .frame(minHeight: 44)
    }

    private func numberFieldRow(_ title: LocalizedStringKey, isEnabled: Binding<Bool>, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: isEnabled)
            if isEnabled.wrappedValue {
                TextField(title, text: value).textFieldStyle(.roundedBorder)
            }
        }
        .frame(minHeight: 44)
    }
}
