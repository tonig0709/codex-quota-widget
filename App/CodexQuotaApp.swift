import AppKit
import SwiftUI

@main
struct CodexQuotaApp: App {
    @StateObject private var server = CodexAppServer()

    init() {
        WidgetRepairService.repair()
    }

    var body: some Scene {
        WindowGroup {
            if WidgetRepairService.requiresInstalledCopy {
                InstallLocationView()
            } else {
                DashboardView(server: server)
            }
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Codex Quota", image: "CodexMark") {
            if WidgetRepairService.requiresInstalledCopy {
                Text("请从“应用程序”启动")
                Button("打开“应用程序”文件夹") { WidgetRepairService.revealApplicationsFolder() }
            } else {
                Text(menuSummary)
                Divider()
                Button("立即刷新") { server.refresh() }
                Button("修复桌面小组件") { WidgetRepairService.repair() }
                Button("打开面板") { NSApp.activate(ignoringOtherApps: true) }
            }
            Divider()
            Button("退出") { NSApp.terminate(nil) }
        }
    }

    private var menuSummary: String {
        guard let value = server.snapshot.weekly?.remainingPercent else { return "等待额度数据" }
        return "周额度剩余 \(value)%"
    }
}
