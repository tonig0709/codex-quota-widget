import Charts
import SwiftUI

public struct QuotaWidgetView: View {
    public let snapshot: UsageSnapshot
    public let glassOpacity: Double

    public init(snapshot: UsageSnapshot, glassOpacity: Double = WidgetGlassOpacity.defaultValue) {
        self.snapshot = snapshot
        self.glassOpacity = WidgetGlassOpacity.clamped(glassOpacity)
    }

    private var isLight: Bool { snapshot.resolvedAppearance == .light }
    private var primaryText: Color { isLight ? Color(red: 0.08, green: 0.1, blue: 0.14) : .white }
    private var secondaryText: Color { isLight ? .black.opacity(0.52) : .white.opacity(0.56) }
    private var trackColor: Color { isLight ? .black.opacity(0.09) : .white.opacity(0.14) }
    private var gridColor: Color { isLight ? .black.opacity(0.08) : .white.opacity(0.1) }
    private var chartColor: Color { isLight ? .indigo : Color(red: 0.32, green: 0.58, blue: 1) }

    public var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                Image("CodexMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
                Text("Codex")
                    .font(.title2.weight(.semibold))
                    .tracking(-0.4)
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("已同步")
                    Text(snapshot.updatedAt, style: .time)
                        .monospacedDigit()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(trackColor, in: Capsule())
            }

            HStack(alignment: .bottom, spacing: 30) {
                VStack(alignment: .leading, spacing: 14) {
                    quotaSection(title: "5h额度", window: snapshot.fiveHour)
                    quotaSection(title: "周额度", window: snapshot.weekly)
                }
                .frame(maxWidth: 244)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("近 7 天趋势").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("单位 M").font(.caption2).foregroundStyle(secondaryText)
                    }
                    Chart(snapshot.dailyUsage) { point in
                        BarMark(
                            x: .value("日期", shortDate(point.startDate)),
                            y: .value("Tokens (M)", point.millions)
                        )
                        .foregroundStyle(chartColor.gradient)
                        .cornerRadius(3)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 7)) {
                            AxisValueLabel().foregroundStyle(secondaryText)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine().foregroundStyle(gridColor)
                            AxisValueLabel().foregroundStyle(secondaryText)
                        }
                    }
                    .accessibilityLabel("近七天 Codex Token 用量")
                }
            }
        }
        .padding(22)
        .foregroundStyle(primaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func quotaSection(title: String, window: UsageWindow?) -> some View {
        let remaining = window?.remainingPercent ?? 0
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Spacer()
                Text("\(remaining)%")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .tracking(-1.1)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(trackColor)
                    Capsule()
                        .fill(quotaColor(for: remaining).gradient)
                        .frame(width: proxy.size.width * CGFloat(remaining) / 100)
                }
            }
            .frame(height: 9)

            Label(resetText(for: window), systemImage: "clock.arrow.circlepath")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(secondaryText)
        }
    }

    private func quotaColor(for remaining: Int) -> Color {
        switch QuotaLevel(remainingPercent: remaining) {
        case .healthy: .green
        case .warning: .orange
        case .critical: .red
        }
    }

    private func resetText(for window: UsageWindow?) -> String {
        guard let date = window?.resetsAt else { return "等待账户数据" }
        return "\(date.formatted(date: .numeric, time: .shortened)) 重置"
    }

    private func shortDate(_ value: String) -> String {
        String(value.suffix(5)).replacingOccurrences(of: "-", with: "/")
    }
}

public struct QuotaRingWidgetView: View {
    public let snapshot: UsageSnapshot
    public let glassOpacity: Double

    public init(snapshot: UsageSnapshot, glassOpacity: Double = WidgetGlassOpacity.defaultValue) {
        self.snapshot = snapshot
        self.glassOpacity = WidgetGlassOpacity.clamped(glassOpacity)
    }

    private var isLight: Bool { snapshot.resolvedAppearance == .light }
    private var primaryText: Color { isLight ? Color(red: 0.08, green: 0.1, blue: 0.14) : .white }
    private var trackColor: Color { isLight ? .black.opacity(0.09) : .white.opacity(0.14) }

    public var body: some View {
        HStack(spacing: 12) {
            quotaRing(title: "5h", window: snapshot.fiveHour)
            quotaRing(title: "周", window: snapshot.weekly)
        }
        .padding(12)
        .foregroundStyle(primaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func quotaRing(title: String, window: UsageWindow?) -> some View {
        let remaining = window?.remainingPercent ?? 0
        return VStack(spacing: 7) {
            ZStack {
                Circle().stroke(trackColor, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(remaining) / 100)
                    .stroke(quotaColor(for: remaining).gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image("CodexMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
            }
            .frame(width: 58, height: 58)

            Text("\(title) \(remaining)%")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Codex \(title)额度剩余 \(remaining)%")
    }

    private func quotaColor(for remaining: Int) -> Color {
        switch QuotaLevel(remainingPercent: remaining) {
        case .healthy: .green
        case .warning: .orange
        case .critical: .red
        }
    }
}

public struct LiquidGlassSurface: View {
    let isLight: Bool
    let opacity: Double
    let accent: Color

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var resolvedOpacity: Double { reduceTransparency ? 1 : WidgetGlassOpacity.clamped(opacity) }

    public init(isLight: Bool, opacity: Double, accent: Color) {
        self.isLight = isLight
        self.opacity = opacity
        self.accent = accent
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(surfaceFill)
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(outerBorder, lineWidth: 0.8)
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .inset(by: 1)
                            .strokeBorder(innerBorder, lineWidth: 0.5)
                    }
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(isLight ? 0.66 : 0.18))
                    .frame(height: 0.75)
                    .padding(.horizontal, 36)
                    .padding(.top, 1)
            }
    }

    private var surfaceFill: Color {
        if isLight {
            return Color(red: 0.93, green: 0.96, blue: 1).opacity(resolvedOpacity)
        }
        return .black.opacity(resolvedOpacity)
    }

    private var outerBorder: Color {
        isLight ? .white.opacity(0.9) : .white.opacity(0.22)
    }

    private var innerBorder: Color {
        isLight ? accent.opacity(0.16) : .white.opacity(0.08)
    }
}

public struct WidgetSurface: View {
    let isLight: Bool
    let opacity: Double
    let accent: Color
    let usesParticles: Bool
    let particleColor: ParticleColorSettings

    public init(
        isLight: Bool,
        opacity: Double,
        accent: Color,
        usesParticles: Bool = false,
        particleColor: ParticleColorSettings = .defaultValue
    ) {
        self.isLight = isLight
        self.opacity = opacity
        self.accent = accent
        self.usesParticles = usesParticles
        self.particleColor = particleColor
    }

    public var body: some View {
        ZStack {
            LiquidGlassSurface(isLight: isLight, opacity: opacity, accent: accent)
            if usesParticles {
                ParticleGlassBorder(isLight: isLight, color: particleColor)
            }
        }
    }
}

private struct ParticleGlassBorder: View {
    let isLight: Bool
    let color: ParticleColorSettings

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color {
        Color(
            hue: color.hue,
            saturation: color.saturation,
            brightness: color.brightness
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { timeline in
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                drawParticles(
                    in: &context,
                    size: size,
                    time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawParticles(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let phase = time * (2 * .pi / 5.6)
        let particleCount = size.width < 220 ? 84 : 132
        let lanes = 4

        for lane in 0..<lanes {
            for index in 0..<particleCount {
                let progress = Double(index) / Double(particleCount)
                let angle = progress * 2 * .pi
                let wave = sin(angle * 3 + phase) * 1.15 + sin(angle * 7 - phase * 0.72) * 0.45
                let inset = 3.6 + Double(lane) * 1.45 - wave
                let xUnit = signedPower(cos(angle), exponent: 0.36)
                let yUnit = signedPower(sin(angle), exponent: 0.36)
                var x = Double(center.x) + (Double(size.width) / 2 - inset) * xUnit
                let y = Double(center.y) + (Double(size.height) / 2 - inset) * yUnit

                let shedding = x > Double(size.width) * 0.82 && index.isMultiple(of: 13)
                if shedding {
                    x += (sin(phase + Double(index)) + 1) * 3.2
                }

                let movingHighlight = max(0, cos(angle - phase))
                let highlight = pow(movingHighlight, 8)
                let diameter = 0.8 + Double((index + lane) % 4) * 0.18 + highlight * 0.9
                let opacity = min(1, (isLight ? 0.32 : 0.46)
                    + Double(lanes - lane) * 0.055
                    + highlight * 0.34)

                let rect = CGRect(
                    x: x - diameter / 2,
                    y: y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                context.fill(Path(ellipseIn: rect), with: .color(accent.opacity(opacity)))
            }
        }

        let edge = RoundedRectangle(cornerRadius: 30, style: .continuous)
            .path(in: CGRect(origin: .zero, size: size).insetBy(dx: 2.2, dy: 2.2))
        context.stroke(
            edge,
            with: .color(accent.opacity(isLight ? 0.14 : 0.2)),
            lineWidth: 1
        )
    }

    private func signedPower(_ value: Double, exponent: Double) -> Double {
        copysign(pow(abs(value), exponent), value)
    }
}
