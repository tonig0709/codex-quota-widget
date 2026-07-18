import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct AppearanceConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "显示设置"

    @Parameter(title: "浅色外观", default: false)
    var useLightAppearance: Bool
}

struct CodexQuotaEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
}

struct CodexQuotaProvider: AppIntentTimelineProvider {
    private let snapshotURL = URL(string: "http://127.0.0.1:48193/snapshot")!

    func placeholder(in context: Context) -> CodexQuotaEntry {
        CodexQuotaEntry(date: .now, snapshot: .placeholder)
    }

    func snapshot(for configuration: AppearanceConfigurationIntent, in context: Context) async -> CodexQuotaEntry {
        await entry(for: configuration)
    }

    func timeline(for configuration: AppearanceConfigurationIntent, in context: Context) async -> Timeline<CodexQuotaEntry> {
        let entry = await entry(for: configuration)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(5 * 60)))
    }

    private func entry(for configuration: AppearanceConfigurationIntent) async -> CodexQuotaEntry {
        var snapshot = await loadSnapshot()
        snapshot.appearance = configuration.useLightAppearance ? .light : .dark
        return CodexQuotaEntry(date: .now, snapshot: snapshot)
    }

    private func loadSnapshot() async -> UsageSnapshot {
        var request = URLRequest(url: snapshotURL)
        request.timeoutInterval = 1
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

struct CodexQuotaWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: CodexQuotaEntry

    var body: some View {
        Group {
            if family == .systemSmall {
                QuotaRingWidgetView(snapshot: entry.snapshot)
            } else {
                QuotaWidgetView(snapshot: entry.snapshot)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct CodexQuotaWidget: Widget {
    let kind = SnapshotStore.widgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: AppearanceConfigurationIntent.self, provider: CodexQuotaProvider()) { entry in
            CodexQuotaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Codex Quota")
        .description("查看 Codex 周额度与近七天 Token 用量。")
        .supportedFamilies([.systemSmall, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

@main
struct CodexQuotaWidgetBundle: WidgetBundle {
    var body: some Widget { CodexQuotaWidget() }
}
