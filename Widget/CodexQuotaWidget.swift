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

    func snapshot(for configuration: AppearanceV4ConfigurationIntent, in context: Context) async -> CodexQuotaEntry {
        var snapshot = context.isPreview ? UsageSnapshot.placeholder : SnapshotStore.load()
        snapshot.appearance = configuration.useLightAppearance ? .light : .dark
        return CodexQuotaEntry(date: .now, snapshot: snapshot, glassOpacity: WidgetGlassOpacity.clamped(configuration.glassOpacity))
    }

    func timeline(for configuration: AppearanceV4ConfigurationIntent, in context: Context) async -> Timeline<CodexQuotaEntry> {
        let entry = await entry(for: configuration)
        // The app explicitly reloads both widget kinds on a data change. This
        // one-minute policy is the safe fallback if macOS coalesces that request.
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60)))
    }

    private func entry(for configuration: AppearanceV4ConfigurationIntent) async -> CodexQuotaEntry {
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
        AppIntentConfiguration(kind: SnapshotStore.smallWidgetKind, intent: AppearanceV4ConfigurationIntent.self, provider: CodexQuotaProvider()) { entry in
            QuotaRingWidgetView(snapshot: entry.snapshot, glassOpacity: entry.glassOpacity)
                .containerBackground(for: .widget) {
                    LiquidGlassSurface(
                        isLight: entry.snapshot.resolvedAppearance == .light,
                        opacity: entry.glassOpacity,
                        accent: .green
                    )
                }
        }
        .configurationDisplayName("Codex Quota · 小型")
        .description("以双圆环显示 Codex 5h 与周额度剩余比例。")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct LargeCodexQuotaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: SnapshotStore.largeWidgetKind, intent: AppearanceV4ConfigurationIntent.self, provider: CodexQuotaProvider()) { entry in
            QuotaWidgetView(snapshot: entry.snapshot, glassOpacity: entry.glassOpacity)
                .containerBackground(for: .widget) {
                    LiquidGlassSurface(
                        isLight: entry.snapshot.resolvedAppearance == .light,
                        opacity: entry.glassOpacity,
                        accent: .blue
                    )
                }
        }
        .configurationDisplayName("Codex Quota · 大型")
        .description("查看 Codex 5h、周额度与近七天 Token 用量。")
        .supportedFamilies([.systemExtraLarge])
        .contentMarginsDisabled()
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
