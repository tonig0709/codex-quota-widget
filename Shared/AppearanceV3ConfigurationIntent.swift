import AppIntents
import WidgetKit

/// Kept in both the app and widget targets so WidgetKit can resolve saved
/// configurations after LaunchServices refreshes the containing app.
struct AppearanceV3ConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "显示设置"
    static var description = IntentDescription("选择此小组件的深浅色外观与玻璃不透明度。")

    @Parameter(title: "浅色外观", default: false)
    var useLightAppearance: Bool

    @Parameter(
        title: "玻璃不透明度",
        default: 0.86,
        controlStyle: .slider,
        inclusiveRange: (lowerBound: 0.35, upperBound: 1.0)
    )
    var glassOpacity: Double
}
