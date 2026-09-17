import Foundation
import SwiftUI
import WidgetKit

struct CodexQuotaEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot
    let settings: GlassRenderSettings
}

struct CodexQuotaProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CodexQuotaEntry {
        let settings = GlassRenderSettings.standard
        var snapshot = UsageSnapshot.placeholder
        snapshot.appearance = settings.appearance
        return CodexQuotaEntry(date: .now, snapshot: snapshot, settings: settings)
    }

    func snapshot(for configuration: AppearanceV5ConfigurationIntent, in context: Context) async -> CodexQuotaEntry {
        var snapshot = context.isPreview ? UsageSnapshot.placeholder : SnapshotStore.load()
        let settings = effectiveSettings(snapshot: snapshot, configuration: configuration)
        snapshot.appearance = settings.appearance
        return CodexQuotaEntry(date: .now, snapshot: snapshot, settings: settings)
    }

    func timeline(for configuration: AppearanceV5ConfigurationIntent, in context: Context) async -> Timeline<CodexQuotaEntry> {
        let entry = await entry(for: configuration)
        // The app explicitly reloads both widget kinds on a data change. This
        // one-minute policy is the safe fallback if macOS coalesces that request.
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60)))
    }

    private func entry(for configuration: AppearanceV5ConfigurationIntent) async -> CodexQuotaEntry {
        var snapshot = await loadSnapshot()
        let settings = effectiveSettings(snapshot: snapshot, configuration: configuration)
        snapshot.appearance = settings.appearance
        return CodexQuotaEntry(date: .now, snapshot: snapshot, settings: settings)
    }

    private func effectiveSettings(snapshot: UsageSnapshot, configuration: AppearanceV5ConfigurationIntent) -> GlassRenderSettings {
        if let settings = snapshot.glassSettings { return settings.sanitized }
        return GlassRenderSettings(
            appearance: configuration.useLightAppearance ? .light : .dark,
            opacity: configuration.glassOpacity
        ).sanitized
    }

    func loadSnapshot() async -> UsageSnapshot {
        let snapshot = await SnapshotHTTPClient.load(fallback: SnapshotStore.load())
        SnapshotStore.save(snapshot)
        return snapshot
    }
}

struct SmallCodexQuotaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: SnapshotStore.smallWidgetKind, intent: AppearanceV5ConfigurationIntent.self, provider: CodexQuotaProvider()) { entry in
            QuotaRingWidgetView(snapshot: entry.snapshot, glassOpacity: entry.settings.opacity)
                .codexWidgetSurface(
                    settings: entry.settings,
                    accent: .green
                )
        }
        .configurationDisplayName("Codex Quota · 小型")
        .description("以双圆环显示 Codex 5h 与周额度剩余比例。")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct LargeCodexQuotaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: SnapshotStore.largeWidgetKind, intent: AppearanceV5ConfigurationIntent.self, provider: CodexQuotaProvider()) { entry in
            QuotaWidgetView(snapshot: entry.snapshot, glassOpacity: entry.settings.opacity)
                .codexWidgetSurface(
                    settings: entry.settings,
                    accent: .blue
                )
        }
        .configurationDisplayName("Codex Quota · 大型")
        .description("查看 Codex 5h、周额度与近七天 Token 用量。")
        .supportedFamilies([.systemExtraLarge])
        .contentMarginsDisabled()
    }
}

private extension View {
    func codexWidgetSurface(settings: GlassRenderSettings, accent: Color) -> some View {
        modifier(CodexWidgetSurfaceModifier(settings: settings.sanitized, accent: accent))
    }
}

private struct CodexWidgetSurfaceModifier: ViewModifier {
    let settings: GlassRenderSettings
    let accent: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if settings.appearance == .light {
            content.containerBackground(for: .widget) {
                LiquidGlassSurface(
                    isLight: true,
                    opacity: settings.opacity,
                    accent: accent,
                    cornerRadius: settings.cornerRadius,
                    edgeStrength: settings.edgeStrength,
                    tone: toneColor,
                    dispersion: settings.dispersion,
                    elasticity: settings.elasticity,
                    displacement: settings.displacement,
                    blurAmount: settings.blurAmount,
                    saturation: settings.saturation,
                    refractionMode: settings.refractionMode
                )
            }
        } else {
            content.containerBackground(for: .widget) {
                WidgetTransparentDarkSurface(settings: settings, accent: accent)
            }
        }
    }

    private var toneColor: Color {
        switch settings.tone {
        case "cool": Color(red: 0.35, green: 0.58, blue: 1)
        case "warm": Color(red: 1, green: 0.56, blue: 0.26)
        default: .clear
        }
    }
}

private struct WidgetTransparentDarkSurface: View {
    let settings: GlassRenderSettings
    let accent: Color

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let resolvedOpacity = reduceTransparency ? 1 : settings.opacity
        let shape = RoundedRectangle(cornerRadius: CGFloat(settings.cornerRadius), style: .continuous)
        let tone: Color = switch settings.tone {
        case "cool": Color(red: 0.35, green: 0.58, blue: 1)
        case "warm": Color(red: 1, green: 0.56, blue: 0.26)
        default: .clear
        }

        shape
            .fill(.black.opacity(WidgetGlassOpacity.darkFilmOpacity(resolvedOpacity)))
            .overlay { shape.fill(.black.opacity(settings.blurAmount * 0.10)) }
            .overlay { shape.fill(tone.opacity((0.02 + settings.edgeStrength * 0.04) * settings.saturation)) }
            .overlay {
                shape
                    .strokeBorder(
                        .white.opacity(0.12 + settings.edgeStrength * 0.22),
                        lineWidth: 0.65 + settings.edgeStrength * 0.75 + settings.displacement * 1.25
                    )
                    .overlay {
                        shape.inset(by: 0.8 + settings.displacement * 1.8)
                            .strokeBorder(.white.opacity(0.07 + settings.displacement * 0.07), lineWidth: 0.4 + settings.displacement * 0.9)
                    }
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(0.18))
                    .frame(height: 0.75)
                    .padding(.horizontal, 36)
                    .padding(.top, 1)
            }
            .overlay { staticRefraction(shape: shape) }
            .overlay {
                let offset = CGFloat(settings.dispersion * 3)
                ZStack {
                    shape.strokeBorder(.red.opacity(settings.dispersion * 0.18), lineWidth: 0.65).offset(x: -offset)
                    shape.strokeBorder(.cyan.opacity(settings.dispersion * 0.18), lineWidth: 0.65).offset(x: offset)
                }
            }
    }

    @ViewBuilder
    private func staticRefraction(shape: RoundedRectangle) -> some View {
        switch settings.refractionMode {
        case .standard:
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.08 + settings.displacement * 0.26), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.8 + settings.displacement * 1.8 + settings.elasticity * 0.8
            )
        case .polar:
            shape.strokeBorder(
                AngularGradient(colors: [.white.opacity(0.12 + settings.displacement * 0.32), .clear, accent.opacity(0.08 * settings.saturation), .clear], center: .center),
                lineWidth: 1 + settings.displacement * 2.4 + settings.elasticity * 0.8
            )
        case .prominent:
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.18 + settings.displacement * 0.38), accent.opacity(0.08 * settings.saturation), .clear], startPoint: .top, endPoint: .bottom),
                lineWidth: 1.4 + settings.displacement * 3.2 + settings.elasticity * 0.8
            )
        }
    }
}

#if !CODEX_QUOTA_PROVIDER_PROBE
@main
@MainActor
struct CodexQuotaWidgetBundle: WidgetBundle {
    var body: some Widget {
        SmallCodexQuotaWidget()
        LargeCodexQuotaWidget()
    }
}
#endif
