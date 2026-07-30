import AppIntents
import WidgetKit

enum WidgetVisualTheme: String, AppEnum {
    case classic
    case particle

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "视觉主题")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .classic: "经典 Liquid Glass",
        .particle: "动态粒子"
    ]
}

/// Kept in both the app and widget targets so WidgetKit can resolve saved
/// configurations after LaunchServices refreshes the containing app.
struct AppearanceV3ConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "显示设置"
    static var description = IntentDescription("选择视觉主题、深浅色外观、玻璃不透明度与粒子颜色。")

    @Parameter(title: "视觉主题", default: .classic)
    var visualTheme: WidgetVisualTheme

    @Parameter(title: "浅色外观", default: false)
    var useLightAppearance: Bool

    @Parameter(
        title: "玻璃不透明度",
        default: 0.86,
        controlStyle: .slider,
        inclusiveRange: (lowerBound: 0.35, upperBound: 1.0)
    )
    var glassOpacity: Double

    @Parameter(
        title: "粒子色相",
        description: "仅动态粒子主题生效",
        default: 0.69,
        controlStyle: .slider,
        inclusiveRange: (lowerBound: 0.0, upperBound: 1.0)
    )
    var particleHue: Double

    @Parameter(
        title: "粒子饱和度",
        description: "仅动态粒子主题生效",
        default: 0.82,
        controlStyle: .slider,
        inclusiveRange: (lowerBound: 0.0, upperBound: 1.0)
    )
    var particleSaturation: Double

    @Parameter(
        title: "粒子亮度",
        description: "仅动态粒子主题生效",
        default: 0.96,
        controlStyle: .slider,
        inclusiveRange: (lowerBound: 0.2, upperBound: 1.0)
    )
    var particleBrightness: Double
}
