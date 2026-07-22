import Charts
import SwiftUI

public struct QuotaWidgetView: View {
    public let snapshot: UsageSnapshot
    public let glassOpacity: Double

    public init(snapshot: UsageSnapshot, glassOpacity: Double = WidgetGlassOpacity.defaultValue) {
        self.snapshot = snapshot
        self.glassOpacity = WidgetGlassOpacity.clamped(glassOpacity)
    }

    private var remaining: Int { snapshot.weekly?.remainingPercent ?? 0 }
    private var isLight: Bool { snapshot.resolvedAppearance == .light }
    private var primaryText: Color { isLight ? Color(red: 0.08, green: 0.1, blue: 0.14) : .white }
    private var secondaryText: Color { isLight ? .black.opacity(0.52) : .white.opacity(0.56) }
    private var trackColor: Color { isLight ? .black.opacity(0.09) : .white.opacity(0.14) }
    private var gridColor: Color { isLight ? .black.opacity(0.08) : .white.opacity(0.1) }
    private var chartColor: Color { isLight ? .indigo : Color(red: 0.32, green: 0.58, blue: 1) }
    private var quotaColor: Color {
        switch QuotaLevel(remainingPercent: remaining) {
        case .healthy: .green
        case .warning: .orange
        case .critical: .red
        }
    }

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
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("周额度")
                            .font(.headline.weight(.semibold))
                        Spacer()
                        Text("\(remaining)%")
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                            .tracking(-1.2)
                            .monospacedDigit()
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(trackColor)
                            Capsule()
                                .fill(quotaColor.gradient)
                                .frame(width: proxy.size.width * CGFloat(remaining) / 100)
                        }
                    }
                    .frame(height: 10)

                    Label(resetText, systemImage: "clock.arrow.circlepath")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(secondaryText)
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

    private var resetText: String {
        guard let date = snapshot.weekly?.resetsAt else { return "等待账户数据" }
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

    private var remaining: Int { snapshot.weekly?.remainingPercent ?? 0 }
    private var isLight: Bool { snapshot.resolvedAppearance == .light }
    private var primaryText: Color { isLight ? Color(red: 0.08, green: 0.1, blue: 0.14) : .white }
    private var trackColor: Color { isLight ? .black.opacity(0.09) : .white.opacity(0.14) }
    private var quotaColor: Color {
        switch QuotaLevel(remainingPercent: remaining) {
        case .healthy: .green
        case .warning: .orange
        case .critical: .red
        }
    }

    public var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle().stroke(trackColor, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(remaining) / 100)
                    .stroke(quotaColor.gradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image("CodexMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
            }
            .frame(width: 82, height: 82)

            Text("\(remaining)%")
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .tracking(-1.8)
                .monospacedDigit()
        }
        .padding(14)
        .foregroundStyle(primaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Codex 周额度剩余 \(remaining)%")
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
