import Foundation
import SwiftUI
import WidgetKit

struct CodexQuotaEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
    let glassOpacity: Double
}

struct CodexQuotaProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CodexQuotaEntry {
        CodexQuotaEntry(date: .now, snapshot: .placeholder, glassOpacity: WidgetGlassOpacity.defaultValue)
    }

    func snapshot(for configuration: AppearanceV5ConfigurationIntent, in context: Context) async -> CodexQuotaEntry {
        var snapshot = context.isPreview ? UsageSnapshot.placeholder : SnapshotStore.load()
        snapshot.appearance = configuration.useLightAppearance ? .light : .dark
        return CodexQuotaEntry(date: .now, snapshot: snapshot, glassOpacity: WidgetGlassOpacity.clamped(configuration.glassOpacity))
    }

    func timeline(for configuration: AppearanceV5ConfigurationIntent, in context: Context) async -> Timeline<CodexQuotaEntry> {
        let entry = await entry(for: configuration)
        // The app explicitly reloads both widget kinds on a data change. This
        // one-minute policy is the safe fallback if macOS coalesces that request.
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60)))
    }

    private func entry(for configuration: AppearanceV5ConfigurationIntent) async -> CodexQuotaEntry {
        var snapshot = await loadSnapshot()
        snapshot.appearance = configuration.useLightAppearance ? .light : .dark
        return CodexQuotaEntry(date: .now, snapshot: snapshot, glassOpacity: WidgetGlassOpacity.clamped(configuration.glassOpacity))
    }

    func loadSnapshot() async -> UsageSnapshot {
        let snapshot = await SnapshotHTTPClient.load(fallback: SnapshotStore.load())
        SnapshotStore.save(snapshot)
        return snapshot
    }
}

struct SmallCodexQuotaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: SnapshotStore.smallWidgetKind, intent: AppearanceV5ConfigurationIntent.self, provider: CodexQuotaProvider()) { entry in
            QuotaRingWidgetView(snapshot: entry.snapshot, glassOpacity: entry.glassOpacity)
                .codexWidgetSurface(
                    isLight: entry.snapshot.resolvedAppearance == .light,
                    opacity: entry.glassOpacity,
                    accent: .green
                )
        }
        .configurationDisplayName("Codex Quota · 小型")
        .description("以双圆环显示 Codex 5h 与周额度剩余比例。")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct LargeCodexQuotaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: SnapshotStore.largeWidgetKind, intent: AppearanceV5ConfigurationIntent.self, provider: CodexQuotaProvider()) { entry in
            QuotaWidgetView(snapshot: entry.snapshot, glassOpacity: entry.glassOpacity)
                .codexWidgetSurface(
                    isLight: entry.snapshot.resolvedAppearance == .light,
                    opacity: entry.glassOpacity,
                    accent: .blue
                )
        }
        .configurationDisplayName("Codex Quota · 大型")
        .description("查看 Codex 5h、周额度与近七天 Token 用量。")
        .supportedFamilies([.systemExtraLarge])
        .contentMarginsDisabled()
    }
}

private extension View {
    func codexWidgetSurface(isLight: Bool, opacity: Double, accent: Color) -> some View {
        modifier(CodexWidgetSurfaceModifier(isLight: isLight, opacity: opacity, accent: accent))
    }
}

private struct CodexWidgetSurfaceModifier: ViewModifier {
    let isLight: Bool
    let opacity: Double
    let accent: Color

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if isLight {
            content.containerBackground(for: .widget) {
                LiquidGlassSurface(isLight: true, opacity: opacity, accent: accent)
            }
        } else {
#if compiler(>=6.2)
            if #available(macOS 26.0, *) {
                let resolvedOpacity = reduceTransparency ? 1 : WidgetGlassOpacity.clamped(opacity)
                let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

                content
                    .background {
                        shape.fill(.black.opacity(WidgetGlassOpacity.darkFilmOpacity(resolvedOpacity)))
                    }
                    .glassEffect(
                        .clear.tint(.black.opacity(WidgetGlassOpacity.darkGlassTintOpacity(resolvedOpacity))),
                        in: shape
                    )
                    .overlay {
                        shape
                            .strokeBorder(.white.opacity(0.22), lineWidth: 0.8)
                            .overlay {
                                shape.inset(by: 1)
                                    .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                            }
                    }
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.18))
                            .frame(height: 0.75)
                            .padding(.horizontal, 36)
                            .padding(.top, 1)
                    }
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                content.containerBackground(for: .widget) {
                    LiquidGlassSurface(isLight: false, opacity: opacity, accent: accent)
                }
            }
#else
            content.containerBackground(for: .widget) {
                LiquidGlassSurface(isLight: false, opacity: opacity, accent: accent)
            }
#endif
        }
    }
}

#if !CODEX_QUOTA_PROVIDER_PROBE
@main
@MainActor
struct CodexQuotaWidgetBundle: WidgetBundle {
    var body: some Widget {
        SmallCodexQuotaWidget()
        LargeCodexQuotaWidget()
    }
}
#endif
