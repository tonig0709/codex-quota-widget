import SwiftUI

struct DashboardView: View {
    @ObservedObject var server: CodexAppServer

    var body: some View {
        VStack(spacing: 20) {
            QuotaWidgetView(snapshot: server.snapshot)
                .frame(width: 680, height: 300)
                .background {
                    LiquidGlassSurface(
                        isLight: server.snapshot.resolvedAppearance == .light,
                        opacity: WidgetGlassOpacity.defaultValue,
                        accent: .blue
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            HStack(spacing: 12) {
                Label(statusText, systemImage: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.callout.weight(.medium))
                Spacer()

                Picker("外观", selection: appearance) {
                    ForEach(WidgetAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 132)

                Button("修复小组件") { WidgetRepairService.repair() }
                    .help("重新登记并刷新桌面小组件")
                Button("刷新") { server.refresh() }
                    .disabled(server.state == .connecting)
                if case .disconnected = server.state {
                    Button("连接 Codex") { server.connect() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(24)
        .frame(minWidth: 730, minHeight: 400)
        .task { server.connect() }
    }

    private var appearance: Binding<WidgetAppearance> {
        Binding(
            get: { server.snapshot.resolvedAppearance },
            set: { server.setAppearance($0) }
        )
    }

    private var statusText: String {
        switch server.state {
        case .disconnected: "尚未连接"
        case .connecting: "正在连接 Codex…"
        case .signingIn: "请在浏览器完成登录"
        case .connected(let email): email.map { "已连接 · \($0)" } ?? "已连接"
        case .failed(let message): message
        }
    }

    private var statusIcon: String {
        switch server.state {
        case .connected: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        default: "circle.dotted"
        }
    }

    private var statusColor: Color {
        switch server.state {
        case .connected: .green
        case .failed: .red
        default: .secondary
        }
    }
}
