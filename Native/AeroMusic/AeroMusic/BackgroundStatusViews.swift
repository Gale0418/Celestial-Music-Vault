import SwiftUI
import AeroThemes

enum BackgroundActivityKind: Sendable {
    case scanning
    case library
    case playback
    case cache
    case analysis

    var symbol: String {
        switch self {
        case .scanning: "externaldrive.badge.magnifyingglass"
        case .library: "music.note.list"
        case .playback: "waveform"
        case .cache: "arrow.down.circle"
        case .analysis: "sparkles"
        }
    }

    var priority: Int {
        switch self {
        case .playback: 50
        case .scanning: 40
        case .cache, .analysis: 30
        case .library: 10
        }
    }
}

struct BackgroundActivity: Identifiable, Sendable {
    let id: UUID
    let kind: BackgroundActivityKind
    let title: String
    var detail: String?
    let startedAt: Date
}

struct BackgroundActivityRail: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.aeroTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let activity = appModel.primaryBackgroundActivity {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.primary)
                    .accessibilityHidden(true)
                Image(systemName: activity.kind.symbol)
                    .foregroundStyle(theme.primary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(activity.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    if let detail = activity.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if appModel.additionalBackgroundActivityCount > 0 {
                    Text("另有 \(appModel.additionalBackgroundActivityCount) 項")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(.regularMaterial)
            .overlay(alignment: .top) { Divider() }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(activity))
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func accessibilityLabel(_ activity: BackgroundActivity) -> String {
        let other = appModel.additionalBackgroundActivityCount
        return [activity.title, activity.detail, other > 0 ? "另有 \(other) 項背景工作" : nil]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "，")
    }
}

struct ErrorStatusBanner: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        if let message = appModel.errorMessage {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.callout)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("關閉", systemImage: "xmark") { appModel.errorMessage = nil }
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
                    .accessibilityHint("關閉這則狀態訊息")
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .background(.regularMaterial)
            .overlay(alignment: .bottom) { Divider() }
            .accessibilityElement(children: .contain)
        }
    }
}
