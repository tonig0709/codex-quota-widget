import Foundation
import WidgetKit

/// Repairs LaunchServices state left behind when Finder replaces the app
/// while an older WidgetKit extension process is still alive.
enum WidgetRepairService {
    private static let queue = DispatchQueue(label: "dev.codexquota.widget-repair")
    private static let extensionExecutable = "CodexQuotaWidgetExtension"
    private static let launchServicesTool = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    static func repair() {
        let appURL = Bundle.main.bundleURL
        let widgetURL = appURL
            .appendingPathComponent("Contents/PlugIns", isDirectory: true)
            .appendingPathComponent("CodexQuotaWidgetExtension.appex", isDirectory: true)

        queue.async {
            // A stale extension keeps the previous CFBundleVersion in memory.
            // WidgetKit then rejects the new archive and renders a black tile.
            run("/usr/bin/pkill", arguments: ["-TERM", "-x", extensionExecutable])
            run(launchServicesTool, arguments: ["-f", appURL.path])

            if FileManager.default.fileExists(atPath: widgetURL.path) {
                run("/usr/bin/pluginkit", arguments: ["-a", widgetURL.path])
            }

            DispatchQueue.main.async {
                WidgetCenter.shared.reloadAllTimelines()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
    }

    private static func run(_ executable: String, arguments: [String]) {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return }
        process.waitUntilExit()
    }
}
