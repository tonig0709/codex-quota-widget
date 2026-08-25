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
precondition(WidgetGlassOpacity.normalized(WidgetGlassOpacity.minimum) == 0)
precondition(WidgetGlassOpacity.normalized(WidgetGlassOpacity.maximum) == 1)
precondition(WidgetGlassOpacity.darkFilmOpacity(WidgetGlassOpacity.minimum) == 0.08)
precondition(WidgetGlassOpacity.darkFilmOpacity(WidgetGlassOpacity.maximum) == 0.94)
precondition(WidgetGlassOpacity.darkFilmOpacity(0.5) < WidgetGlassOpacity.darkFilmOpacity(0.86))
precondition(UsageSnapshot.placeholder.resolvedAppearance == .dark)
precondition(SnapshotStore.smallWidgetKind == "dev.codexquota.widget.small.v5")
precondition(SnapshotStore.largeWidgetKind == "dev.codexquota.widget.large.v5")
precondition(SnapshotHTTPClient.endpoint.absoluteString == "http://127.0.0.1:48193/snapshot")

#if canImport(AppKit)
@MainActor
func render<V: View>(_ view: V, width: CGFloat, height: CGFloat) -> NSBitmapImageRep {
    let renderer = ImageRenderer(content: view.frame(width: width, height: height))
    renderer.scale = 1
    guard let image = renderer.nsImage,
          let data = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: data)
    else { preconditionFailure("Widget render produced no image") }
    return bitmap
}

@MainActor
func changedPixels(_ lhs: NSBitmapImageRep, _ rhs: NSBitmapImageRep, in region: CGRect) -> Int {
    let xRange = max(0, Int(CGFloat(lhs.pixelsWide) * region.minX))..<min(lhs.pixelsWide, Int(CGFloat(lhs.pixelsWide) * region.maxX))
    let yRange = max(0, Int(CGFloat(lhs.pixelsHigh) * region.minY))..<min(lhs.pixelsHigh, Int(CGFloat(lhs.pixelsHigh) * region.maxY))
    var count = 0
    for y in yRange {
        for x in xRange {
            guard let left = lhs.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                  let right = rhs.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
            else { continue }
            let difference = abs(left.redComponent - right.redComponent) +
                abs(left.greenComponent - right.greenComponent) +
                abs(left.blueComponent - right.blueComponent) +
                abs(left.alphaComponent - right.alphaComponent)
            if difference > 0.12 { count += 1 }
        }
    }
    return count
}

@MainActor
func contrastPixelCounts(_ bitmap: NSBitmapImageRep, in region: CGRect) -> (dark: Int, bright: Int, total: Int) {
    let xRange = max(0, Int(CGFloat(bitmap.pixelsWide) * region.minX))..<min(bitmap.pixelsWide, Int(CGFloat(bitmap.pixelsWide) * region.maxX))
    let yRange = max(0, Int(CGFloat(bitmap.pixelsHigh) * region.minY))..<min(bitmap.pixelsHigh, Int(CGFloat(bitmap.pixelsHigh) * region.maxY))
    var dark = 0
    var bright = 0
    var total = 0
    for y in yRange {
        for x in xRange {
            guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                  color.alphaComponent > 0.1
            else { continue }
            let luminance = color.redComponent * 0.2126 +
                color.greenComponent * 0.7152 +
                color.blueComponent * 0.0722
            total += 1
            if luminance < 0.6 { dark += 1 }
            if luminance > 0.6 { bright += 1 }
        }
    }
    return (dark, bright, total)
}

@MainActor
func hasReadableContrast(_ bitmap: NSBitmapImageRep, in region: CGRect) -> Bool {
    let counts = contrastPixelCounts(bitmap, in: region)
    let minorityFloor = max(8, counts.total / 1_000)
    return counts.total > 0 &&
        min(counts.dark, counts.bright) > minorityFloor &&
        max(counts.dark, counts.bright) > counts.total / 5
}

@MainActor
func checkRender<Content: View, Background: View>(
    _ content: Content,
    on background: Background,
    width: CGFloat,
    height: CGFloat,
    label: String,
    regions: [(String, CGRect)]
) {
    // Native Glass is resolved by the desktop compositor, not ImageRenderer.
    // A deterministic wallpaper keeps this headless test faithful to the real
    // widget stack while still comparing content against the same glass layer.
    let wallpaper = LinearGradient(
        colors: [Color(red: 0.18, green: 0.42, blue: 0.62), Color(red: 0.52, green: 0.24, blue: 0.18)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    let baseline = render(ZStack { wallpaper; background }, width: width, height: height)
    let rendered = render(ZStack { wallpaper; background; content }, width: width, height: height)

    var visiblePixels = 0
    for y in 0..<rendered.pixelsHigh {
        for x in 0..<rendered.pixelsWide {
            guard let color = rendered.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
            if color.alphaComponent > 0.1 { visiblePixels += 1 }
        }
    }

    let pixelCount = rendered.pixelsWide * rendered.pixelsHigh
    let fullFrame = CGRect(x: 0, y: 0, width: 1, height: 1)
    precondition(visiblePixels > pixelCount * 9 / 10, "\(label) is blank or transparent")
    precondition(changedPixels(rendered, baseline, in: fullFrame) > pixelCount / 300, "\(label) content is indistinguishable from its glass background")
    precondition(hasReadableContrast(rendered, in: fullFrame), "\(label) is a solid or all-black surface")
    precondition(changedPixels(baseline, baseline, in: fullFrame) == 0, "render difference detector has a false positive")
    for (name, region) in regions {
        let regionPixels = Int(CGFloat(pixelCount) * region.width * region.height)
        precondition(changedPixels(rendered, baseline, in: region) > regionPixels / 500, "\(label) lacks visible \(name) content")
        precondition(hasReadableContrast(rendered, in: region), "\(label) lacks readable \(name) contrast")
    }
}

await MainActor.run {
    let emptyDark = UsageSnapshot(appearance: .dark)
    let boundary = UsageSnapshot(
        fiveHour: UsageWindow(usedPercent: 40, windowDurationMinutes: 300, resetsAt: nil),
        weekly: UsageWindow(usedPercent: 71, windowDurationMinutes: 10_080, resetsAt: nil),
        dailyUsage: (1...7).map { DailyUsage(startDate: "2099-01-0\($0)", tokens: Int64($0 * 1_000_000)) },
        appearance: .dark
    )
    var boundaryLight = boundary
    boundaryLight.appearance = .light
    let smallRegions = [
        ("left quota ring", CGRect(x: 0.04, y: 0.05, width: 0.44, height: 0.9)),
        ("right quota ring", CGRect(x: 0.52, y: 0.05, width: 0.44, height: 0.9))
    ]
    let largeRegions = [
        ("quota area", CGRect(x: 0.04, y: 0.08, width: 0.42, height: 0.7)),
        ("trend area", CGRect(x: 0.5, y: 0.08, width: 0.46, height: 0.7))
    ]

    let appearances = [
        (name: "dark", snapshot: emptyDark, isLight: false),
        (name: "light", snapshot: boundaryLight, isLight: true)
    ]
    let opacities = [
        (name: "minimum", value: WidgetGlassOpacity.minimum),
        (name: "maximum", value: WidgetGlassOpacity.maximum)
    ]

    for appearance in appearances {
        for opacity in opacities {
            checkRender(
                QuotaRingWidgetView(snapshot: appearance.snapshot, glassOpacity: opacity.value),
                on: LiquidGlassSurface(isLight: appearance.isLight, opacity: opacity.value, accent: .green),
                width: 164,
                height: 164,
                label: "small \(appearance.name) \(opacity.name)-opacity widget",
                regions: smallRegions
            )
            checkRender(
                QuotaWidgetView(snapshot: appearance.snapshot, glassOpacity: opacity.value),
                on: LiquidGlassSurface(isLight: appearance.isLight, opacity: opacity.value, accent: .blue),
                width: 704,
                height: 344,
                label: "large \(appearance.name) \(opacity.name)-opacity widget",
                regions: largeRegions
            )
        }
    }

    let solidSmall = render(
        ZStack {
            LiquidGlassSurface(isLight: false, opacity: WidgetGlassOpacity.minimum, accent: .green)
            Color.black
        },
        width: 164,
        height: 164
    )
    let solidLarge = render(
        ZStack {
            LiquidGlassSurface(isLight: false, opacity: WidgetGlassOpacity.minimum, accent: .blue)
            Color.black
        },
        width: 704,
        height: 344
    )
    let fullFrame = CGRect(x: 0, y: 0, width: 1, height: 1)
    precondition(!hasReadableContrast(solidSmall, in: fullFrame), "solid-black small-widget negative control passed")
    precondition(!hasReadableContrast(solidLarge, in: fullFrame), "solid-black large-widget negative control passed")

    let warmWallpaper = LinearGradient(colors: [.orange, .brown], startPoint: .top, endPoint: .bottom)
    let coolWallpaper = LinearGradient(colors: [.cyan, .indigo], startPoint: .top, endPoint: .bottom)
    let minimumWarm = render(
        ZStack { warmWallpaper; LiquidGlassSurface(isLight: false, opacity: WidgetGlassOpacity.minimum, accent: .blue) },
        width: 704,
        height: 344
    )
    let minimumCool = render(
        ZStack { coolWallpaper; LiquidGlassSurface(isLight: false, opacity: WidgetGlassOpacity.minimum, accent: .blue) },
        width: 704,
        height: 344
    )
    let maximumWarm = render(
        ZStack { warmWallpaper; LiquidGlassSurface(isLight: false, opacity: WidgetGlassOpacity.maximum, accent: .blue) },
        width: 704,
        height: 344
    )
    let maximumCool = render(
        ZStack { coolWallpaper; LiquidGlassSurface(isLight: false, opacity: WidgetGlassOpacity.maximum, accent: .blue) },
        width: 704,
        height: 344
    )
    let minimumInfluence = changedPixels(minimumWarm, minimumCool, in: fullFrame)
    let maximumInfluence = changedPixels(maximumWarm, maximumCool, in: fullFrame)
    precondition(minimumInfluence > maximumInfluence, "minimum dark glass does not reveal more wallpaper than maximum glass")
}
#endif

print("Quota parser, thresholds, and widget renders passed.")
