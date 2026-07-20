import CodexQuotaCore
import Foundation

let rateData = Data(#"{"id":3,"result":{"rateLimits":{"primary":{"usedPercent":20,"windowDurationMins":300},"secondary":{"usedPercent":28,"windowDurationMins":10080,"resetsAt":1800000000}}}}"#.utf8)
let weekly = try AppServerParser.weeklyWindow(from: AppServerParser.object(from: rateData))
precondition(weekly.remainingPercent == 72)
precondition(weekly.windowDurationMinutes == 10_080)

let usageData = Data(#"{"id":4,"result":{"summary":{},"dailyUsageBuckets":[{"startDate":"2026-07-17","tokens":12500000}]}}"#.utf8)
let usage = try AppServerParser.dailyUsage(from: AppServerParser.object(from: usageData))
precondition(usage == [DailyUsage(startDate: "2026-07-17", tokens: 12_500_000)])

precondition(QuotaLevel(remainingPercent: 60) == .healthy)
precondition(QuotaLevel(remainingPercent: 30) == .warning)
precondition(QuotaLevel(remainingPercent: 29) == .critical)
precondition(WidgetGlassOpacity.clamped(0) == WidgetGlassOpacity.minimum)
precondition(WidgetGlassOpacity.clamped(2) == WidgetGlassOpacity.maximum)
precondition(WidgetGlassOpacity.clamped(0.7) == 0.7)
precondition(UsageSnapshot.placeholder.resolvedAppearance == .dark)
precondition(SnapshotStore.smallWidgetKind == "dev.codexquota.widget.small.v3")
precondition(SnapshotStore.largeWidgetKind == "dev.codexquota.widget.large.v3")

print("Quota parser and threshold checks passed.")
