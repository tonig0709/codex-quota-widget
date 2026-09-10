import AppKit
import CoreGraphics
import SwiftUI

struct DesktopGlassPanelView: View {
    static let windowID = "desktop-glass-panel"

    @ObservedObject var server: CodexAppServer
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(GlassSettingKeys.appearance) private var appearanceRaw = GlassAppearanceMode.dark.rawValue
    @AppStorage(GlassSettingKeys.opacity) private var glassOpacity = WidgetGlassOpacity.defaultValue
    @AppStorage(GlassSettingKeys.edgeStrength) private var edgeStrength = 0.55
    @AppStorage(GlassSettingKeys.elasticity) private var elasticity = 0.10
    @AppStorage(GlassSettingKeys.cornerRadius) private var cornerRadius = 30.0
    @AppStorage(GlassSettingKeys.tone) private var toneRaw = GlassTone.neutral.rawValue
    @State private var showsControls = false
    @State private var hoverVector = CGSize.zero
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismissWindow) private var dismissWindow

    private var panelSnapshot: UsageSnapshot {
        var value = server.snapshot
        value.appearance = isLight ? .light : .dark
        return value
    }

    var body: some View {
        QuotaWidgetView(snapshot: panelSnapshot, glassOpacity: glassOpacity)
            .frame(width: 680, height: 300)
            .background {
                DesktopGlassSurface(
                    isLight: isLight,
                    opacity: glassOpacity,
                    accent: .blue,
                    cornerRadius: cornerRadius,
                    edgeStrength: edgeStrength,
                    tone: glassTone.color,
                    elasticity: elasticity,
                    hoverVector: hoverVector,
                    isHovering: isHovering
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: CGFloat(cornerRadius), style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showsControls.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isLight ? .black.opacity(0.62) : .white.opacity(0.72))
                .background(.thinMaterial, in: Circle())
                .padding(12)
                .help("调整桌面玻璃面板")
                .popover(isPresented: $showsControls, arrowEdge: .bottom) {
                    controls
                }
            }
            .onContinuousHover(perform: updateHover)
            .background(DesktopPanelWindowConfigurator())
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("桌面玻璃面板")
                .font(.headline)

            GlassSettingsView(compact: true)

            HStack {
                Button("立即刷新") { server.refresh() }
                Spacer()
                Button("关闭面板") {
                    dismissWindow(id: Self.windowID)
                }
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private var appearanceMode: GlassAppearanceMode {
        GlassAppearanceMode(rawValue: appearanceRaw) ?? .dark
    }

    private var glassTone: GlassTone {
        GlassTone(rawValue: toneRaw) ?? .neutral
    }

    private var isLight: Bool {
        appearanceMode.isLight(in: colorScheme)
    }

    private func updateHover(_ phase: ContinuousHoverPhase) {
        switch phase {
        case .active(let location):
            isHovering = true
            hoverVector = CGSize(
                width: min(1, max(-1, location.x / 340 - 1)),
                height: min(1, max(-1, location.y / 150 - 1))
            )
        case .ended:
            isHovering = false
            if reduceMotion {
                hoverVector = .zero
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 1)) {
                    hoverVector = .zero
                }
            }
        }
    }
}

private struct DesktopGlassSurface: View {
    let isLight: Bool
    let opacity: Double
    let accent: Color
    let cornerRadius: Double
    let edgeStrength: Double
    let tone: Color
    let elasticity: Double
    let hoverVector: CGSize
    let isHovering: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var resolvedOpacity: Double {
        reduceTransparency ? 1 : WidgetGlassOpacity.clamped(opacity)
    }

    private var filmOpacity: Double {
        if isLight {
            return 0.12 + WidgetGlassOpacity.normalized(resolvedOpacity) * 0.68
        }
        return WidgetGlassOpacity.darkFilmOpacity(resolvedOpacity)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CGFloat(cornerRadius), style: .continuous)
    }

    private var filmColor: Color {
        (isLight ? Color.white : Color.black).opacity(filmOpacity)
    }

    private var outerBorder: Color {
        isLight
            ? .white.opacity(0.48 + edgeStrength * 0.42)
            : .white.opacity(0.12 + edgeStrength * 0.22)
    }

    private var innerBorder: Color {
        isLight ? accent.opacity(0.18) : .white.opacity(0.09)
    }

    private var borderWidth: CGFloat {
        CGFloat(0.65 + edgeStrength * 0.45)
    }

    private var highlightOpacity: Double {
        (isLight ? 0.46 : 0.1) + edgeStrength * 0.24
    }

    private var highlightCenter: UnitPoint {
        UnitPoint(
            x: min(1, max(0, 0.5 + hoverVector.width * 0.5)),
            y: min(1, max(0, 0.5 + hoverVector.height * 0.5))
        )
    }

    private var motionStrength: CGFloat {
        reduceMotion ? 0 : CGFloat(min(0.25, max(0, elasticity)))
    }

    private var directionalHighlight: some View {
        shape
            .strokeBorder(
                RadialGradient(
                    colors: [.white.opacity(isLight ? 0.92 : 0.56), .clear],
                    center: highlightCenter,
                    startRadius: 0,
                    endRadius: 180
                ),
                lineWidth: CGFloat(1.2 + edgeStrength * 1.8)
            )
            .opacity(isHovering ? 1 : 0)
            .animation(.easeOut(duration: 0.16), value: isHovering)
    }

    var body: some View {
        DesktopVisualEffectView(isLight: isLight)
            .overlay { shape.fill(filmColor) }
            .overlay { shape.fill(tone.opacity(0.025 + edgeStrength * 0.055)) }
            .overlay {
                shape
                    .strokeBorder(outerBorder, lineWidth: borderWidth)
                    .overlay {
                        shape.inset(by: 1)
                            .strokeBorder(innerBorder, lineWidth: 0.5)
                    }
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(highlightOpacity))
                    .frame(height: 0.75)
                    .padding(.horizontal, 36)
                    .padding(.top, 1)
            }
            .overlay { directionalHighlight }
            .scaleEffect(
                x: 1 + abs(hoverVector.width) * motionStrength * 0.02,
                y: 1 + abs(hoverVector.height) * motionStrength * 0.02
            )
            .offset(
                x: hoverVector.width * motionStrength * 8,
                y: hoverVector.height * motionStrength * 6
            )
    }
}

private struct DesktopVisualEffectView: NSViewRepresentable {
    let isLight: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.appearance = NSAppearance(named: isLight ? .aqua : .darkAqua)
    }
}

private struct DesktopPanelWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { configure(view.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }
}
