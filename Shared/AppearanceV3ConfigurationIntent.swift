import AppIntents
import WidgetKit

/// Kept in both the app and widget targets so WidgetKit can resolve saved
/// configurations after LaunchServices refreshes the containing app.
struct AppearanceV3ConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "显示设置"
    static var description = IntentDescription("选择视觉主题、深浅色外观、玻璃不透明度与粒子颜色。")

    @Parameter(title: "粒子主题", default: false)
    var useParticleTheme: Bool

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
