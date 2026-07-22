import SwiftUI

@main
struct CodexQuotaApp: App {
    @StateObject private var server = CodexAppServer()

    init() {
        WidgetRepairService.repair()
    }

    var body: some Scene {
        WindowGroup {
            DashboardView(server: server)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Codex Quota", image: "CodexMark") {
            Text(menuSummary)
            Divider()
            Button("立即刷新") { server.refresh() }
            Button("修复桌面小组件") { WidgetRepairService.repair() }
            Button("打开面板") { NSApp.activate(ignoringOtherApps: true) }
            Divider()
            Button("退出") { NSApp.terminate(nil) }
        }
    }

    private var menuSummary: String {
        guard let value = server.snapshot.weekly?.remainingPercent else { return "等待额度数据" }
        return "周额度剩余 \(value)%"
    }
}
