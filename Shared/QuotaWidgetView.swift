import Charts
import SwiftUI

public struct QuotaWidgetView: View {
    public let snapshot: UsageSnapshot
    public let glassOpacity: Double
    public let usesParticles: Bool
    public let particleColor: ParticleColorSettings

    public init(
        snapshot: UsageSnapshot,
        glassOpacity: Double = WidgetGlassOpacity.defaultValue,
        usesParticles: Bool = false,
        particleColor: ParticleColorSettings = .defaultValue
    ) {
        self.snapshot = snapshot
        self.glassOpacity = WidgetGlassOpacity.clamped(glassOpacity)
        self.usesParticles = usesParticles
        self.particleColor = particleColor
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
                .overlay {
                    if usesParticles {
                        ParticleTipEmitter(
                            shape: .linear(Double(remaining) / 100),
                            color: particleColor
                        )
                        .frame(width: proxy.size.width, height: 24)
                    }
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
    public let usesParticles: Bool
    public let particleColor: ParticleColorSettings

    public init(
        snapshot: UsageSnapshot,
        glassOpacity: Double = WidgetGlassOpacity.defaultValue,
        usesParticles: Bool = false,
        particleColor: ParticleColorSettings = .defaultValue
    ) {
        self.snapshot = snapshot
        self.glassOpacity = WidgetGlassOpacity.clamped(glassOpacity)
        self.usesParticles = usesParticles
        self.particleColor = particleColor
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
                if usesParticles {
                    ParticleTipEmitter(
                        shape: .ring(Double(remaining) / 100),
                        color: particleColor
                    )
                }
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

struct WidgetSurface: View {
    let isLight: Bool
    let opacity: Double
    let accent: Color
    let usesParticles: Bool
    let particleColor: ParticleColorSettings

    init(
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
                ParticleGlassBorder(
                    isLight: isLight,
                    color: particleColor
                )
            }
        }
    }
}

private struct ParticleGlassBorder: View {
    let isLight: Bool
    let color: ParticleColorSettings

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            drawParticles(
                in: &context,
                size: size,
                time: Date.now.timeIntervalSinceReferenceDate
            )
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
                let inset = 3.6 + Double(lane) * 1.45
                let xUnit = signedPower(cos(angle), exponent: 0.36)
                let yUnit = signedPower(sin(angle), exponent: 0.36)
                let x = Double(center.x) + (Double(size.width) / 2 - inset) * xUnit
                let y = Double(center.y) + (Double(size.height) / 2 - inset) * yUnit

                let movingHighlight = max(0, cos(angle - phase))
                let highlight = pow(movingHighlight, 8)
                let diameter = 0.8 + Double((index + lane) % 4) * 0.18 + highlight * 0.9
                let opacity = min(1, (isLight ? 0.32 : 0.46)
                    + Double(lanes - lane) * 0.055
                    + highlight * 0.26)

                drawDot(in: &context, x: x, y: y, diameter: diameter, opacity: opacity)
            }
        }

        drawDetachedParticles(in: &context, size: size, phase: phase)

        let edge = RoundedRectangle(cornerRadius: 30, style: .continuous)
            .path(in: CGRect(origin: .zero, size: size).insetBy(dx: 2.2, dy: 2.2))
        context.stroke(
            edge,
            with: .color(color.swiftUIColor.opacity(isLight ? 0.14 : 0.2)),
            lineWidth: 1
        )
    }

    private func drawDetachedParticles(
        in context: inout GraphicsContext,
        size: CGSize,
        phase: Double
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let count = size.width < 220 ? 72 : 108

        for index in 0..<count {
            let progress = Double(index) / Double(count)
            let angle = progress * 2 * .pi
            let xUnit = signedPower(cos(angle), exponent: 0.36)
            let yUnit = signedPower(sin(angle), exponent: 0.36)
            let x = Double(center.x) + (Double(size.width) / 2 - 2.8) * xUnit
            let y = Double(center.y) + (Double(size.height) / 2 - 2.8) * yUnit
            guard index.isMultiple(of: 9) else { continue }

            let normal = normalized(
                dx: x - Double(center.x),
                dy: y - Double(center.y)
            )
            let life = ParticleMotion.unitPhase(phase / (2 * .pi) + progress * 1.7)
            let drift = 3.5 + life * 8
            let turbulence = sin(Double(index) * 2.17 + phase) * 0.7
            let detachedX = x + normal.dx * drift - normal.dy * turbulence
            let detachedY = y + normal.dy * drift + normal.dx * turbulence
            let opacity = (1 - life) * (isLight ? 0.38 : 0.58) * 0.72

            drawDot(
                in: &context,
                x: detachedX,
                y: detachedY,
                diameter: 0.75,
                opacity: opacity
            )
        }
    }

    private func drawDot(
        in context: inout GraphicsContext,
        x: Double,
        y: Double,
        diameter: Double,
        opacity: Double
    ) {
        let rect = CGRect(
            x: x - diameter / 2,
            y: y - diameter / 2,
            width: diameter,
            height: diameter
        )
        context.fill(
            Path(ellipseIn: rect),
            with: .color(color.swiftUIColor.opacity(max(0, min(1, opacity))))
        )
    }

    private func normalized(dx: Double, dy: Double) -> (dx: Double, dy: Double) {
        let length = max(0.001, hypot(dx, dy))
        return (dx / length, dy / length)
    }

    private func signedPower(_ value: Double, exponent: Double) -> Double {
        copysign(pow(abs(value), exponent), value)
    }
}

private enum ParticleTipShape {
    case linear(Double)
    case ring(Double)
}

private struct ParticleTipEmitter: View {
    let shape: ParticleTipShape
    let color: ParticleColorSettings

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            drawParticles(
                in: &context,
                size: size,
                time: Date.now.timeIntervalSinceReferenceDate
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawParticles(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let originAndDirection = originAndDirection(in: size)

        for index in 0..<12 {
            let life = ParticleMotion.unitPhase(time * 0.22 + Double(index) / 12)
            let drift = life * 10
            let turbulence = sin(Double(index) * 2.41 + time) * 2 * life
            let x = originAndDirection.origin.x
                + originAndDirection.direction.dx * drift
                - originAndDirection.direction.dy * turbulence
            let y = originAndDirection.origin.y
                + originAndDirection.direction.dy * drift
                + originAndDirection.direction.dx * turbulence
            let diameter = 0.8 + (1 - life) * 1.15
            let rect = CGRect(
                x: x - diameter / 2,
                y: y - diameter / 2,
                width: diameter,
                height: diameter
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(color.swiftUIColor.opacity(pow(1 - life, 1.7) * 0.72))
            )
        }
    }

    private func originAndDirection(
        in size: CGSize
    ) -> (origin: CGPoint, direction: CGVector) {
        switch shape {
        case .linear(let progress):
            return (
                CGPoint(
                    x: size.width * max(0, min(1, progress)),
                    y: size.height / 2
                ),
                CGVector(dx: 1, dy: 0)
            )
        case .ring(let progress):
            let angle = -.pi / 2 + 2 * .pi * max(0, min(1, progress))
            let radius = min(size.width, size.height) / 2 - 8
            return (
                CGPoint(
                    x: size.width / 2 + cos(angle) * radius,
                    y: size.height / 2 + sin(angle) * radius
                ),
                CGVector(
                    dx: cos(angle) * 0.82 - sin(angle) * 0.18,
                    dy: sin(angle) * 0.82 + cos(angle) * 0.18
                )
            )
        }
    }

}

private extension ParticleColorSettings {
    var swiftUIColor: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}
