import SwiftUI
import CMVThemes

private func cmvLocalizedFormat(_ key: String, arguments: CVarArg...) -> String {
    let preference = UserDefaults.standard.string(forKey: AppLanguage.preferenceKey) ?? "system"
    return String(
        format: AppLanguage.localized(key),
        locale: AppLanguage.locale(for: preference),
        arguments: arguments
    )
}

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
    var localizedTitleKey: String? = nil
    var localizedTitleArgument: String? = nil
    var detail: String?
    let startedAt: Date

    var displayTitle: String {
        guard let localizedTitleKey else { return title }
        guard let localizedTitleArgument else { return AppLanguage.localized(localizedTitleKey) }
        return String(format: AppLanguage.localized(localizedTitleKey), localizedTitleArgument)
    }
}

struct BackgroundActivityRail: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

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
                    Text(activity.displayTitle)
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
                if appModel.queuedScanCount > 0 || appModel.additionalBackgroundActivityCount > 0 {
                    Text(pendingWorkLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(reduceTransparency ? AnyShapeStyle(theme.surface) : AnyShapeStyle(.regularMaterial))
            .overlay(alignment: .top) { Divider() }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(activity))
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func accessibilityLabel(_ activity: BackgroundActivity) -> String {
        return [activity.displayTitle, activity.detail, pendingWorkLabel.isEmpty ? nil : pendingWorkLabel]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "，")
    }

    private var pendingWorkLabel: String {
        let queued = appModel.queuedScanCount
        let other = appModel.additionalBackgroundActivityCount
        if queued > 0, other > 0 {
            return cmvLocalizedFormat("待索引 %lld 個來源 · 其他工作 %lld 項",
                                      arguments: Int64(queued), Int64(other))
        }
        if queued > 0 {
            return cmvLocalizedFormat("待索引 %lld 個來源", arguments: Int64(queued))
        }
        if other > 0 {
            return cmvLocalizedFormat("其他工作 %lld 項", arguments: Int64(other))
        }
        return ""
    }
}

struct BackgroundActivityToast: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if let activity = appModel.primaryBackgroundActivity {
            HStack(spacing: 9) {
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.primary)
                Image(systemName: activity.kind.symbol)
                    .foregroundStyle(theme.primary)
                Text(activity.displayTitle)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                if let detail = activity.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(
                reduceTransparency ? AnyShapeStyle(theme.surface) : AnyShapeStyle(.regularMaterial),
                in: Capsule()
            )
            .overlay(Capsule().stroke(theme.primary.opacity(0.28), lineWidth: 1))
            .shadow(color: .black.opacity(0.24), radius: 10, y: 4)
            .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel([activity.displayTitle, activity.detail].compactMap { $0 }.joined(separator: "，"))
        }
    }
}

struct ErrorStatusBanner: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.cmvTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if let message = appModel.errorMessage {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("關閉", systemImage: "xmark") { appModel.errorMessage = nil }
                    .labelStyle(.iconOnly)
                    .frame(width: 44, height: 44)
                    .accessibilityHint("關閉這則狀態訊息")
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .background(reduceTransparency ? AnyShapeStyle(theme.surface) : AnyShapeStyle(.regularMaterial))
            .overlay(alignment: .bottom) { Divider() }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(cmvLocalizedFormat("錯誤：%@", arguments: message))
        }
    }
}
