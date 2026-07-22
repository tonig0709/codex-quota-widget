import AppKit
import Foundation
import WidgetKit

/// Keeps the WidgetKit extension registered from the installed app, rather
/// than from a temporary App Translocation copy opened from a DMG or download.
enum WidgetRepairService {
    private static let queue = DispatchQueue(label: "dev.codexquota.widget-repair")
    private static let extensionExecutable = "CodexQuotaWidgetExtension"
    private static let extensionIdentifier = "dev.codexquota.app.widget"
    private static let lastVerifiedBuildKey = "lastVerifiedWidgetBuild"
    private static let launchServicesTool = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    static var requiresInstalledCopy: Bool {
        Bundle.main.bundleURL.path.contains("/AppTranslocation/") ||
        Bundle.main.bundleURL.path.hasPrefix("/Volumes/")
    }

    static func repair() {
        guard !requiresInstalledCopy else { return }

        let appURL = Bundle.main.bundleURL
        let widgetURL = appURL
            .appendingPathComponent("Contents/PlugIns", isDirectory: true)
            .appendingPathComponent("CodexQuotaWidgetExtension.appex", isDirectory: true)
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""

        queue.async {
            let registrationMissing = !isCurrentWidgetRegistered(at: widgetURL)
            let buildChanged = UserDefaults.standard.string(forKey: lastVerifiedBuildKey) != build

            if registrationMissing || buildChanged {
                // A stale extension keeps a previous bundle version in memory.
                // WidgetKit then rejects the new archive or removes it from the gallery.
                run("/usr/bin/pkill", arguments: ["-TERM", "-x", extensionExecutable])
                run(launchServicesTool, arguments: ["-f", appURL.path])
                if FileManager.default.fileExists(atPath: widgetURL.path) {
                    run("/usr/bin/pluginkit", arguments: ["-a", widgetURL.path])
                }
                UserDefaults.standard.set(build, forKey: lastVerifiedBuildKey)
            }

            DispatchQueue.main.async {
                WidgetCenter.shared.reloadAllTimelines()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
    }

    static func revealApplicationsFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications", isDirectory: true))
    }

    private static func isCurrentWidgetRegistered(at widgetURL: URL) -> Bool {
        let output = output("/usr/bin/pluginkit", arguments: ["-m", "-A", "-D", "-i", extensionIdentifier])
        return output.contains(widgetURL.path)
    }

    private static func output(_ executable: String, arguments: [String]) -> String {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return "" }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return "" }
        process.waitUntilExit()
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
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
