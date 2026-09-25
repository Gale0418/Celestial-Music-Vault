import SwiftUI
import SwiftData
import CMVDomain

/// Keeps analysis progress and cancellation independent of Now Playing layout.
struct NowPlayingAnalysisButton: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.modelContext) private var context

    let track: Track

    @State private var task: Task<Void, Never>?
    @State private var generation = 0
    @State private var isAnalyzing = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button(AppLanguage.localized("分析這首音樂"), systemImage: "waveform.path") {
                    startAnalysis()
                }
                .buttonStyle(.bordered)
                .disabled(isAnalyzing)
                if isAnalyzing {
                    ProgressView()
                    Button(AppLanguage.localized("取消")) { cancelAnalysis(showMessage: true) }
                        .buttonStyle(.borderless)
                }
            }
            .frame(minHeight: 44)
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: track.id) { _, _ in
            cancelAnalysis()
            message = nil
        }
        .onDisappear { cancelAnalysis() }
    }

    private func startAnalysis() {
        guard appModel.requirePro(.smartDJ), !isAnalyzing else { return }
        generation &+= 1
        let requestGeneration = generation
        isAnalyzing = true
        message = nil
        task = Task { @MainActor in
            defer {
                if requestGeneration == generation {
                    isAnalyzing = false
                    task = nil
                }
            }
            do {
                let profile = try await appModel.analyzeTrack(track, context: context)
                guard requestGeneration == generation, !Task.isCancelled else { return }
                message = profile.bpm.map {
                    String(format: AppLanguage.localized("分析完成，節奏約 %.0f BPM。"), $0)
                } ?? AppLanguage.localized("音訊分析已完成。")
            } catch is CancellationError {
                if requestGeneration == generation {
                    message = AppLanguage.localized("已取消分析。")
                }
            } catch {
                if requestGeneration == generation {
                    message = String(format: AppLanguage.localized("音訊分析失敗：%@"),
                                     AppLanguage.localizedError(error))
                }
            }
        }
    }

    private func cancelAnalysis(showMessage: Bool = false) {
        generation &+= 1
        task?.cancel()
        task = nil
        isAnalyzing = false
        if showMessage { message = AppLanguage.localized("已取消分析。") }
    }
}
