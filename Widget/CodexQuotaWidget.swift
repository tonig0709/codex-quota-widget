import Foundation
import SwiftUI
import WidgetKit

struct CodexQuotaEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
}

struct CodexQuotaProvider: TimelineProvider {
    private let snapshotURL = URL(string: "http://127.0.0.1:48193/snapshot")!

    func placeholder(in context: Context) -> CodexQuotaEntry {
        CodexQuotaEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CodexQuotaEntry) -> Void) {
        load { completion(CodexQuotaEntry(date: .now, snapshot: $0)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CodexQuotaEntry>) -> Void) {
        load { snapshot in
            let entry = CodexQuotaEntry(date: .now, snapshot: snapshot)
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
        }
    }

    private func load(completion: @escaping (UsageSnapshot) -> Void) {
        var request = URLRequest(url: snapshotURL)
        request.timeoutInterval = 2
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data, let snapshot = try? JSONDecoder().decode(UsageSnapshot.self, from: data) else {
                completion(SnapshotStore.load())
                return
            }
            SnapshotStore.save(snapshot)
            completion(snapshot)
        }.resume()
    }
}

struct CodexQuotaWidget: Widget {
    let kind = "dev.codexquota.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CodexQuotaProvider()) { entry in
            QuotaWidgetView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Codex Quota")
        .description("查看 Codex 周额度与近七天 Token 用量。")
        .supportedFamilies([.systemExtraLarge])
        .contentMarginsDisabled()
    }
}

@main
struct CodexQuotaWidgetBundle: WidgetBundle {
    var body: some Widget { CodexQuotaWidget() }
}
