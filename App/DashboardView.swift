import SwiftUI

struct DashboardView: View {
    @ObservedObject var server: CodexAppServer

    var body: some View {
        VStack(spacing: 18) {
            QuotaWidgetView(snapshot: server.snapshot)
                .frame(width: 680, height: 300)

            HStack {
                Label(statusText, systemImage: statusIcon)
                    .foregroundStyle(statusColor)
                Spacer()
                Button("刷新") { server.refresh() }
                    .disabled(server.state == .connecting)
                if case .disconnected = server.state {
                    Button("连接 Codex") { server.connect() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 6)
        }
        .padding(24)
        .frame(minWidth: 730, minHeight: 380)
        .task { server.connect() }
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
