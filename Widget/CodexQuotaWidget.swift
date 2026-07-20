import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct AppearanceV3ConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "显示设置"
    static var description = IntentDescription("选择此小组件的深浅色外观与玻璃不透明度。")

    @Parameter(title: "浅色外观", default: false)
    var useLightAppearance: Bool

    @Parameter(
        title: "玻璃不透明度",
        default: WidgetGlassOpacity.defaultValue,
        controlStyle: .slider,
        inclusiveRange: WidgetGlassOpacity.minimum...WidgetGlassOpacity.maximum
    )
    var glassOpacity: Double
}

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
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(5 * 60)))
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
                .containerBackground(for: .widget) { Color.clear }
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
                .containerBackground(for: .widget) { Color.clear }
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
