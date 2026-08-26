import AppKit
import CoreGraphics
import SwiftUI

struct DesktopGlassPanelView: View {
    static let windowID = "desktop-glass-panel"

    @ObservedObject var server: CodexAppServer
    @AppStorage("desktopPanelUseLightAppearance") private var useLightAppearance = false
    @AppStorage("desktopPanelGlassOpacity") private var glassOpacity = WidgetGlassOpacity.defaultValue
    @State private var showsControls = false
    @Environment(\.dismissWindow) private var dismissWindow

    private var panelSnapshot: UsageSnapshot {
        var value = server.snapshot
        value.appearance = useLightAppearance ? .light : .dark
        return value
    }

    var body: some View {
        QuotaWidgetView(snapshot: panelSnapshot, glassOpacity: glassOpacity)
            .frame(width: 680, height: 300)
            .background {
                DesktopGlassSurface(
                    isLight: useLightAppearance,
                    opacity: glassOpacity,
                    accent: .blue
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showsControls.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(useLightAppearance ? .black.opacity(0.62) : .white.opacity(0.72))
                .background(.thinMaterial, in: Circle())
                .padding(12)
                .help("调整桌面玻璃面板")
                .popover(isPresented: $showsControls, arrowEdge: .bottom) {
                    controls
                }
            }
            .background(DesktopPanelWindowConfigurator())
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("桌面玻璃面板")
                .font(.headline)

            Picker("外观", selection: $useLightAppearance) {
                Text("深色").tag(false)
                Text("浅色").tag(true)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("玻璃不透明度")
                    Spacer()
                    Text(glassOpacity, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: $glassOpacity,
                    in: WidgetGlassOpacity.minimum...WidgetGlassOpacity.maximum
                )
                .accessibilityLabel("玻璃不透明度")
                .accessibilityValue(glassOpacity.formatted(.percent.precision(.fractionLength(0))))
            }

            HStack {
                Button("立即刷新") { server.refresh() }
                Spacer()
                Button("关闭面板") {
                    dismissWindow(id: Self.windowID)
                }
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}

private struct DesktopGlassSurface: View {
    let isLight: Bool
    let opacity: Double
    let accent: Color

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var resolvedOpacity: Double {
        reduceTransparency ? 1 : WidgetGlassOpacity.clamped(opacity)
    }

    private var filmOpacity: Double {
        if isLight {
            return 0.12 + WidgetGlassOpacity.normalized(resolvedOpacity) * 0.68
        }
        return WidgetGlassOpacity.darkFilmOpacity(resolvedOpacity)
    }

    var body: some View {
        DesktopVisualEffectView(isLight: isLight)
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill((isLight ? Color.white : Color.black).opacity(filmOpacity))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(isLight ? .white.opacity(0.78) : .white.opacity(0.24), lineWidth: 0.8)
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .inset(by: 1)
                            .strokeBorder(isLight ? accent.opacity(0.18) : .white.opacity(0.09), lineWidth: 0.5)
                    }
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(isLight ? 0.7 : 0.2))
                    .frame(height: 0.75)
                    .padding(.horizontal, 36)
                    .padding(.top, 1)
            }
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
