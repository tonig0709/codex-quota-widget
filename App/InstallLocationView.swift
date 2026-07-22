import SwiftUI

struct InstallLocationView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.blue)
            Text("请从“应用程序”启动")
                .font(.title2.weight(.semibold))
            Text("Codex Quota 正在从下载文件或磁盘映像的临时副本运行。macOS 无法可靠地将该副本的小组件显示在组件库中。请将 App 拖到“应用程序”，再从那里打开。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("打开“应用程序”文件夹") {
                    WidgetRepairService.revealApplicationsFolder()
                }
                .buttonStyle(.borderedProminent)
                Button("退出") { NSApp.terminate(nil) }
            }
        }
        .padding(32)
        .frame(width: 460)
    }
}
