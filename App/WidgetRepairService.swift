import AppKit
import Foundation
import WidgetKit

/// Keeps the WidgetKit extension registered from the installed app, rather
/// than from a temporary App Translocation copy opened from a DMG or download.
enum WidgetRepairService {
    private struct Registration {
        let isEnabled: Bool
        let url: URL
        let build: Int?
    }

    private enum CleanupDecision {
        case proceed(staleWidgets: [URL])
        case newerBuildPresent
        case unavailable
    }

    private static let queue = DispatchQueue(label: "dev.codexquota.widget-repair")
    private static let extensionExecutable = "CodexQuotaWidgetExtension"
    private static let extensionIdentifier = "dev.codexquota.app.widget"
    private static let lastVerifiedBuildKey = "lastVerifiedWidgetBuild"
    private static let launchServicesTool = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    static var requiresInstalledCopy: Bool {
        let path = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true).path + "/"
        return !path.hasPrefix("/Applications/") && !path.hasPrefix(userApplications)
    }

    static func repair() {
        guard !requiresInstalledCopy else { return }

        let appURL = Bundle.main.bundleURL
        let widgetURL = appURL
            .appendingPathComponent("Contents/PlugIns", isDirectory: true)
            .appendingPathComponent("CodexQuotaWidgetExtension.appex", isDirectory: true)
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        guard let currentBuild = Int(build) else { return }

        queue.async {
            let registrationMissing = !isCurrentWidgetRegistered(at: widgetURL)
            let buildChanged = UserDefaults.standard.string(forKey: lastVerifiedBuildKey) != build

            if registrationMissing || buildChanged {
                switch registrationDecision(keeping: widgetURL, currentBuild: currentBuild) {
                case .unavailable:
                    return
                case .newerBuildPresent:
                    // Never mutate PlugInKit after detecting a newer build. On macOS 15,
                    // unregistering this older path can still displace the active entry
                    // because both extensions share the same bundle identifier.
                    return
                case let .proceed(staleWidgets):
                    // `pluginkit -r` is only safe after the complete registration set
                    // proves every other path is older than this installed app.
                    for staleWidget in staleWidgets {
                        run("/usr/bin/pluginkit", arguments: ["-r", staleWidget.path])
                    }
                }
                // A stale extension keeps a previous bundle version in memory.
                // WidgetKit then rejects the new archive or removes it from the gallery.
                run("/usr/bin/pkill", arguments: ["-TERM", "-x", extensionExecutable])
                run(launchServicesTool, arguments: ["-f", appURL.path])
                if FileManager.default.fileExists(atPath: widgetURL.path) {
                    run("/usr/bin/pluginkit", arguments: ["-a", widgetURL.path])
                    run("/usr/bin/pluginkit", arguments: ["-e", "use", "-i", extensionIdentifier])
                }
                if waitUntilCurrentWidgetIsRegistered(at: widgetURL) {
                    UserDefaults.standard.set(build, forKey: lastVerifiedBuildKey)
                }
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
        let currentURL = canonical(widgetURL)
        guard let registrations = registrations() else { return false }
        return registrations.count == 1 &&
            registrations[0].isEnabled &&
            registrations[0].url == currentURL
    }

    private static func waitUntilCurrentWidgetIsRegistered(at widgetURL: URL) -> Bool {
        for _ in 0..<20 {
            if isCurrentWidgetRegistered(at: widgetURL) { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    private static func registrationDecision(keeping widgetURL: URL, currentBuild: Int) -> CleanupDecision {
        let currentURL = canonical(widgetURL)
        guard let registrations = registrations() else { return .unavailable }
        let stale = registrations.filter { $0.url != currentURL }
        for registration in stale {
            if let build = registration.build {
                if build > currentBuild { return .newerBuildPresent }
            } else if FileManager.default.fileExists(atPath: registration.url.path) {
                return .unavailable
            }
        }
        return .proceed(staleWidgets: stale.map(\.url))
    }

    private static func registrations() -> [Registration]? {
        guard let output = output("/usr/bin/pluginkit", arguments: ["-m", "-A", "-v", "-i", extensionIdentifier]) else {
            return nil
        }
        var parsed: [Registration] = []
        for line in output.split(separator: "\n") where line.contains(extensionIdentifier) {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 4 else { return nil }
            let identityField = fields[0].trimmingCharacters(in: .whitespaces)
            guard let marker = identityField.first, marker == "+" || marker == "-" else { return nil }
            let identity = identityField.dropFirst().trimmingCharacters(in: .whitespaces)
            guard identity.hasPrefix(extensionIdentifier + "(") else { return nil }

            let path = fields[3].trimmingCharacters(in: .whitespaces)
            guard path.hasPrefix("/"),
                  path.hasSuffix("/Contents/PlugIns/CodexQuotaWidgetExtension.appex")
            else { return nil }
            let url = canonical(URL(fileURLWithPath: path))
            parsed.append(Registration(isEnabled: marker == "+", url: url, build: buildNumber(at: url)))
        }
        let summaryCounts = output.split(separator: "\n").compactMap { line -> Int? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("("), trimmed.contains(" plug-in") else { return nil }
            return Int(trimmed.dropFirst().prefix(while: { $0.isNumber }))
        }
        guard summaryCounts.count == 1, summaryCounts[0] == parsed.count else { return nil }
        return parsed
    }

    private static func buildNumber(at widgetURL: URL) -> Int? {
        let plistURL = widgetURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let value = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = value as? [String: Any]
        else { return nil }
        return buildNumber(dictionary["CFBundleVersion"])
    }

    private static func buildNumber(_ value: Any?) -> Int? {
        if let build = value as? String { return Int(build) }
        if let build = value as? NSNumber { return build.intValue }
        return nil
    }

    private static func canonical(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }

    private static func output(_ executable: String, arguments: [String]) -> String? {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return nil }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
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
