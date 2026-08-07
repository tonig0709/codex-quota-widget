import CodexQuotaCore
import Foundation
#if canImport(AppKit)
import AppKit
import SwiftUI
#endif

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
precondition(UsageSnapshot.placeholder.resolvedAppearance == .dark)
precondition(SnapshotStore.smallWidgetKind == "dev.codexquota.widget.small.v3")
precondition(SnapshotStore.largeWidgetKind == "dev.codexquota.widget.large.v3")

#if canImport(AppKit)
@MainActor
func checkRender<V: View>(_ view: V, width: CGFloat, height: CGFloat, isLight: Bool) {
    let renderer = ImageRenderer(content: view.frame(width: width, height: height))
    renderer.scale = 1
    guard let image = renderer.nsImage,
          let data = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: data)
    else { preconditionFailure("Widget render produced no image") }

    var visiblePixels = 0
    var foregroundPixels = 0
    for y in 0..<bitmap.pixelsHigh {
        for x in 0..<bitmap.pixelsWide {
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
            if color.alphaComponent > 0.1 { visiblePixels += 1 }
            let high = max(color.redComponent, color.greenComponent, color.blueComponent)
            let low = min(color.redComponent, color.greenComponent, color.blueComponent)
            if isLight ? low < 0.55 : high > 0.45 { foregroundPixels += 1 }
        }
    }

    let pixelCount = bitmap.pixelsWide * bitmap.pixelsHigh
    precondition(visiblePixels > pixelCount * 9 / 10, "Widget render is blank or transparent")
    precondition(foregroundPixels > pixelCount / 200, "Widget render is a solid surface with no visible content")
}

MainActor.assumeIsolated {
    var dark = UsageSnapshot.placeholder
    dark.appearance = .dark
    var light = UsageSnapshot.placeholder
    light.appearance = .light

    checkRender(
        ZStack {
            LiquidGlassSurface(isLight: false, opacity: 0.86, accent: .green)
            QuotaRingWidgetView(snapshot: dark)
        },
        width: 164,
        height: 164,
        isLight: false
    )
    checkRender(
        ZStack {
            LiquidGlassSurface(isLight: true, opacity: 0.86, accent: .green)
            QuotaRingWidgetView(snapshot: light)
        },
        width: 164,
        height: 164,
        isLight: true
    )
    checkRender(
        ZStack {
            LiquidGlassSurface(isLight: false, opacity: 0.86, accent: .blue)
            QuotaWidgetView(snapshot: dark)
        },
        width: 704,
        height: 344,
        isLight: false
    )
    checkRender(
        ZStack {
            LiquidGlassSurface(isLight: true, opacity: 0.86, accent: .blue)
            QuotaWidgetView(snapshot: light)
        },
        width: 704,
        height: 344,
        isLight: true
    )
}
#endif

print("Quota parser, thresholds, and widget renders passed.")
