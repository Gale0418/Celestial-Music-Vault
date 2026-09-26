import SwiftUI
import CMVDomain

/// Applies only explicitly selected fields to the chosen library records.
/// Original media files and fields left unchecked are never changed.
struct BatchMetadataEditor: View {
    let selectionCount: Int
    let onSave: (TrackMetadataPatch) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var changesArtist = false
    @State private var changesAlbum = false
    @State private var changesAlbumArtist = false
    @State private var artist = ""
    @State private var album = ""
    @State private var albumArtist = ""

    private var canSave: Bool {
        (changesArtist || changesAlbum || changesAlbumArtist) &&
        (!changesArtist || !artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) &&
        (!changesAlbum || !album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) &&
        (!changesAlbumArtist || !albumArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

                Section("統一套用") {
                    fieldRow("歌手", isEnabled: $changesArtist, value: $artist)
                    fieldRow("專輯", isEnabled: $changesAlbum, value: $album)
                    fieldRow("專輯歌手", isEnabled: $changesAlbumArtist, value: $albumArtist)
                }
            }
            .navigationTitle("批次編輯歌曲資訊")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("套用變更") {
                        onSave(TrackMetadataPatch(
                            artist: changesArtist ? .set(artist.trimmingCharacters(in: .whitespacesAndNewlines)) : .unchanged,
                            album: changesAlbum ? .set(album.trimmingCharacters(in: .whitespacesAndNewlines)) : .unchanged,
                            albumArtist: changesAlbumArtist ? .set(albumArtist.trimmingCharacters(in: .whitespacesAndNewlines)) : .unchanged
                        ))
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .frame(maxWidth: 520, minHeight: 360)
    }

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
}
