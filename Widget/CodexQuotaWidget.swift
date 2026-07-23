import Foundation
import SwiftUI
import WidgetKit

struct CodexQuotaEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
    let glassOpacity: Double
}

struct CodexQuotaProvider: AppIntentTimelineProvider {
    private let snapshotURL = URL(string: "http://127.0.0.1:48193/snapshot")!

    func placeholder(in context: Context) -> CodexQuotaEntry {
        CodexQuotaEntry(date: .now, snapshot: .placeholder, glassOpacity: WidgetGlassOpacity.defaultValue)
    }

    func snapshot(for configuration: AppearanceV3ConfigurationIntent, in context: Context) async -> CodexQuotaEntry {
        if context.isPreview {
            return previewEntry(for: configuration)
        }
        return await entry(for: configuration)
    }

    func timeline(for configuration: AppearanceV3ConfigurationIntent, in context: Context) async -> Timeline<CodexQuotaEntry> {
        let entry = await entry(for: configuration)
        // The app explicitly reloads both widget kinds on a data change. This
        // one-minute policy is the safe fallback if macOS coalesces that request.
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60)))
    }

    private func previewEntry(for configuration: AppearanceV3ConfigurationIntent) -> CodexQuotaEntry {
        var snapshot = UsageSnapshot.placeholder
        snapshot.appearance = configuration.useLightAppearance ? .light : .dark
        return CodexQuotaEntry(date: .now, snapshot: snapshot, glassOpacity: WidgetGlassOpacity.clamped(configuration.glassOpacity))
    }

    private func entry(for configuration: AppearanceV3ConfigurationIntent) async -> CodexQuotaEntry {
        var snapshot = await loadSnapshot()
        snapshot.appearance = configuration.useLightAppearance ? .light : .dark
        return CodexQuotaEntry(date: .now, snapshot: snapshot, glassOpacity: WidgetGlassOpacity.clamped(configuration.glassOpacity))
    }

    private func loadSnapshot() async -> UsageSnapshot {
        var request = URLRequest(url: snapshotURL)
        request.timeoutInterval = 2
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let response = response as? HTTPURLResponse,
              response.statusCode == 200,
              response.mimeType == "application/json",
              let snapshot = try? JSONDecoder().decode(UsageSnapshot.self, from: data) else {
            return SnapshotStore.load()
        }
        SnapshotStore.save(snapshot)
        return snapshot
    }
}

struct SmallCodexQuotaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: SnapshotStore.smallWidgetKind, intent: AppearanceV3ConfigurationIntent.self, provider: CodexQuotaProvider()) { entry in
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
        .description("以圆环显示 Codex 周额度剩余比例。")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct LargeCodexQuotaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: SnapshotStore.largeWidgetKind, intent: AppearanceV3ConfigurationIntent.self, provider: CodexQuotaProvider()) { entry in
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
        .description("查看 Codex 周额度与近七天 Token 用量。")
        .supportedFamilies([.systemExtraLarge])
        .contentMarginsDisabled()
    }
}

@main
struct CodexQuotaWidgetBundle: WidgetBundle {
    var body: some Widget {
        SmallCodexQuotaWidget()
        LargeCodexQuotaWidget()
    }
}
