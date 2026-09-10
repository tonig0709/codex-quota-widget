import SwiftUI

enum GlassSettingKeys {
    static let appearance = "glassAppearanceMode"
    static let opacity = "desktopPanelGlassOpacity"
    static let edgeStrength = "glassEdgeStrength"
    static let elasticity = "glassElasticity"
    static let cornerRadius = "glassCornerRadius"
    static let tone = "glassTone"
}

enum GlassAppearanceMode: String, CaseIterable, Identifiable {
    case automatic, dark, light

    var id: Self { self }
    var title: String {
        switch self {
        case .automatic: "自动"
        case .dark: "深色"
        case .light: "浅色"
        }
    }

    func isLight(in colorScheme: ColorScheme) -> Bool {
        switch self {
        case .automatic: colorScheme == .light
        case .dark: false
        case .light: true
        }
    }
}

enum GlassTone: String, CaseIterable, Identifiable {
    case cool, neutral, warm

    var id: Self { self }
    var title: String {
        switch self {
        case .cool: "冷"
        case .neutral: "中性"
        case .warm: "暖"
        }
    }
    var color: Color {
        switch self {
        case .cool: Color(red: 0.35, green: 0.58, blue: 1)
        case .neutral: .clear
        case .warm: Color(red: 1, green: 0.56, blue: 0.26)
        }
    }
}

private enum GlassPreset: String, CaseIterable, Identifiable {
    case clear, standard, vivid, custom

    var id: Self { self }
    var title: String {
        switch self {
        case .clear: "清透"
        case .standard: "标准"
        case .vivid: "鲜明"
        case .custom: "自定"
        }
    }
}

struct GlassSettingsView: View {
    let compact: Bool

    @AppStorage(GlassSettingKeys.appearance) private var appearanceRaw = GlassAppearanceMode.dark.rawValue
    @AppStorage(GlassSettingKeys.opacity) private var opacity = WidgetGlassOpacity.defaultValue
    @AppStorage(GlassSettingKeys.edgeStrength) private var edgeStrength = 0.55
    @AppStorage(GlassSettingKeys.elasticity) private var elasticity = 0.10
    @AppStorage(GlassSettingKeys.cornerRadius) private var cornerRadius = 30.0
    @AppStorage(GlassSettingKeys.tone) private var toneRaw = GlassTone.neutral.rawValue
    @State private var showsAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 14 : 18) {
            if !compact {
                Text("玻璃外观")
                    .font(.title3.weight(.semibold))
                Text("所有调整都会立即反映在预览与桌面面板中。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("预设", selection: preset) {
                ForEach(GlassPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                        .disabled(preset == .custom)
                }
            }
            .pickerStyle(.segmented)

            Picker("外观", selection: appearance) {
                ForEach(GlassAppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            slider("不透明度", value: $opacity, range: WidgetGlassOpacity.minimum...WidgetGlassOpacity.maximum, percent: true)
            slider("边缘强度", value: $edgeStrength, range: 0...1, percent: true)
            slider("弹性", value: $elasticity, range: 0...0.25, percent: true)

            DisclosureGroup("高级设置", isExpanded: $showsAdvanced) {
                VStack(alignment: .leading, spacing: 14) {
                    slider("圆角", value: $cornerRadius, range: 20...40, percent: false)

                    Picker("玻璃色调", selection: tone) {
                        ForEach(GlassTone.allCases) { tone in
                            Text(tone.title).tag(tone)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.top, 10)
            }

            Button("恢复默认值") { apply(.standard) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
    }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        percent: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                if percent {
                    Text(value.wrappedValue, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    Text(value.wrappedValue, format: .number.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Slider(value: value, in: range)
                .accessibilityLabel(title)
        }
    }

    private var appearance: Binding<GlassAppearanceMode> {
        Binding(
            get: { GlassAppearanceMode(rawValue: appearanceRaw) ?? .dark },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    private var tone: Binding<GlassTone> {
        Binding(
            get: { GlassTone(rawValue: toneRaw) ?? .neutral },
            set: { toneRaw = $0.rawValue }
        )
    }

    private var preset: Binding<GlassPreset> {
        Binding(
            get: {
                if matches(opacity: 0.35, edge: 0.42, elasticity: 0.06, radius: 30, tone: .neutral) { return .clear }
                if matches(opacity: 0.86, edge: 0.55, elasticity: 0.10, radius: 30, tone: .neutral) { return .standard }
                if matches(opacity: 0.72, edge: 0.9, elasticity: 0.18, radius: 32, tone: .cool) { return .vivid }
                return .custom
            },
            set: { apply($0) }
        )
    }

    private func matches(opacity expectedOpacity: Double, edge: Double, elasticity expectedElasticity: Double, radius: Double, tone: GlassTone) -> Bool {
        abs(opacity - expectedOpacity) < 0.005 &&
            abs(edgeStrength - edge) < 0.005 &&
            abs(elasticity - expectedElasticity) < 0.005 &&
            abs(cornerRadius - radius) < 0.005 &&
            toneRaw == tone.rawValue
    }

    private func apply(_ preset: GlassPreset) {
        switch preset {
        case .clear:
            opacity = 0.35
            edgeStrength = 0.42
            elasticity = 0.06
            cornerRadius = 30
            toneRaw = GlassTone.neutral.rawValue
        case .standard:
            opacity = 0.86
            edgeStrength = 0.55
            elasticity = 0.10
            cornerRadius = 30
            toneRaw = GlassTone.neutral.rawValue
        case .vivid:
            opacity = 0.72
            edgeStrength = 0.9
            elasticity = 0.18
            cornerRadius = 32
            toneRaw = GlassTone.cool.rawValue
        case .custom:
            break
        }
    }
}
