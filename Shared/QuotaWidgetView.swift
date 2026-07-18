import Charts
import SwiftUI

public struct QuotaWidgetView: View {
    public let snapshot: UsageSnapshot

    public init(snapshot: UsageSnapshot) { self.snapshot = snapshot }

    private var remaining: Int { snapshot.weekly?.remainingPercent ?? 0 }
    private var level: QuotaLevel { QuotaLevel(remainingPercent: remaining) }
    private var quotaColor: Color {
        switch level {
        case .healthy: .green
        case .warning: .orange
        case .critical: .red
        }
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 10) {
                    Image("CodexMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .accessibilityHidden(true)
                    Text("Codex")
                        .font(.title2.weight(.semibold))
                }
                Spacer()
                Text(snapshot.updatedAt, style: .time)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 28) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Week").font(.title3.weight(.semibold))
                        Spacer()
                        Text("\(remaining)%")
                            .font(.system(size: 38, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.16))
                            Capsule()
                                .fill(quotaColor.gradient)
                                .frame(width: proxy.size.width * CGFloat(remaining) / 100)
                        }
                    }
                    .frame(height: 11)
                    Text(resetText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 240)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("近 7 天趋势").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("单位 M").font(.caption2).foregroundStyle(.secondary)
                    }
                    Chart(snapshot.dailyUsage) { point in
                        BarMark(
                            x: .value("日期", shortDate(point.startDate)),
                            y: .value("Tokens (M)", point.millions)
                        )
                        .foregroundStyle(.blue.gradient)
                        .cornerRadius(2)
                    }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 7)) }
                    .chartYAxis { AxisMarks(position: .leading) }
                    .accessibilityLabel("近七天 Codex Token 用量")
                }
            }
        }
        .padding(22)
        .foregroundStyle(.white)
        .background {
            LinearGradient(
                colors: [.black.opacity(0.76), .blue.opacity(0.2), .black.opacity(0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var resetText: String {
        guard let date = snapshot.weekly?.resetsAt else { return "等待账户数据" }
        return "↻ \(date.formatted(date: .numeric, time: .shortened)) 重置"
    }

    private func shortDate(_ value: String) -> String {
        String(value.suffix(5)).replacingOccurrences(of: "-", with: "/")
    }
}
