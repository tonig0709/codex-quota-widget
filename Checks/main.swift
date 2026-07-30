import CodexQuotaCore
import Foundation

let rateData = Data(#"{"id":3,"result":{"rateLimits":{"primary":{"usedPercent":20,"windowDurationMins":300},"secondary":{"usedPercent":28,"windowDurationMins":10080,"resetsAt":1800000000}}}}"#.utf8)
let rateLimits = try AppServerParser.rateLimitWindows(from: AppServerParser.object(from: rateData))
let weekly = rateLimits.weekly
precondition(rateLimits.fiveHour?.remainingPercent == 80)
precondition(rateLimits.fiveHour?.windowDurationMinutes == 300)
precondition(weekly.remainingPercent == 72)
precondition(weekly.windowDurationMinutes == 10_080)

let weeklyOnlyData = Data(#"{"id":3,"result":{"rateLimits":{"secondary":{"usedPercent":28,"windowDurationMins":10080}}}}"#.utf8)
let weeklyOnly = try AppServerParser.rateLimitWindows(from: AppServerParser.object(from: weeklyOnlyData))
precondition(weeklyOnly.fiveHour == nil)

let usageData = Data(#"{"id":4,"result":{"summary":{},"dailyUsageBuckets":[{"startDate":"2026-07-17","tokens":12500000}]}}"#.utf8)
let usage = try AppServerParser.dailyUsage(from: AppServerParser.object(from: usageData))
precondition(usage == [DailyUsage(startDate: "2026-07-17", tokens: 12_500_000)])

precondition(QuotaLevel(remainingPercent: 60) == .healthy)
precondition(QuotaLevel(remainingPercent: 30) == .warning)
precondition(QuotaLevel(remainingPercent: 29) == .critical)
precondition(WidgetGlassOpacity.clamped(0) == WidgetGlassOpacity.minimum)
precondition(WidgetGlassOpacity.clamped(2) == WidgetGlassOpacity.maximum)
precondition(WidgetGlassOpacity.clamped(0.7) == 0.7)
precondition(ParticleColorSettings(hue: -1, saturation: 2, brightness: 0).hue == 0)
precondition(ParticleColorSettings(hue: -1, saturation: 2, brightness: 0).saturation == 1)
precondition(ParticleColorSettings(hue: -1, saturation: 2, brightness: 0).brightness == 0.2)
precondition(UsageSnapshot.placeholder.resolvedAppearance == .dark)
precondition(SnapshotStore.smallWidgetKind == "dev.codexquota.widget.small.v3")
precondition(SnapshotStore.largeWidgetKind == "dev.codexquota.widget.large.v3")

print("Quota parser and threshold checks passed.")
