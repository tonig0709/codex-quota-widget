import Foundation

@main
struct WidgetProviderProbe {
    static func main() async {
        let environment = ProcessInfo.processInfo.environment
        guard let fiveHour = Int(environment["CODEX_QUOTA_EXPECT_FIVE_HOUR"] ?? ""),
              let weekly = Int(environment["CODEX_QUOTA_EXPECT_WEEKLY"] ?? ""),
              let dailyCount = Int(environment["CODEX_QUOTA_EXPECT_DAILY_COUNT"] ?? ""),
              let lastTokens = Int64(environment["CODEX_QUOTA_EXPECT_LAST_TOKENS"] ?? "")
        else { preconditionFailure("Widget provider probe is missing expected values") }

        let snapshot = await CodexQuotaProvider().loadSnapshot()
        precondition(snapshot.fiveHour?.usedPercent == fiveHour, "Widget provider returned stale 5h data")
        precondition(snapshot.weekly?.usedPercent == weekly, "Widget provider returned stale weekly data")
        precondition(snapshot.dailyUsage.count == dailyCount, "Widget provider returned incomplete trend data")
        precondition(snapshot.dailyUsage.last?.tokens == lastTokens, "Widget provider returned stale trend data")
        precondition(snapshot.email == nil && snapshot.plan == nil, "Widget provider received account identity")

        let fallback = UsageSnapshot(
            fiveHour: UsageWindow(usedPercent: 99, windowDurationMinutes: nil, resetsAt: nil),
            weekly: UsageWindow(usedPercent: 99, windowDurationMinutes: nil, resetsAt: nil)
        )
        let rejected = await SnapshotHTTPClient.load(
            from: SnapshotHTTPClient.endpoint.appendingPathComponent("not-snapshot"),
            fallback: fallback
        )
        precondition(rejected == fallback, "Widget client accepted a non-snapshot route")
        print("Widget provider probe passed.")
    }
}
