import AppKit
import Combine
import Foundation
import Network
import WidgetKit

private final class SnapshotServer {
    static let port: NWEndpoint.Port = 48_193

    private let queue = DispatchQueue(label: "dev.codexquota.snapshot")
    private var listener: NWListener?

    func start() {
        guard listener == nil else { return }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: Self.port)
        guard let listener = try? NWListener(using: parameters) else { return }
        listener.newConnectionHandler = { [queue] connection in
            connection.start(queue: queue)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4_096) { data, _, _, _ in
                let request = data.flatMap { String(data: $0, encoding: .utf8) }
                let valid = request?.hasPrefix("GET /snapshot HTTP/1.") == true
                var snapshot = SnapshotStore.load()
                snapshot.email = nil
                snapshot.plan = nil
                let body = valid ? ((try? JSONEncoder().encode(snapshot)) ?? Data()) : Data()
                let status = valid ? "200 OK" : "404 Not Found"
                var response = Data("HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
                response.append(body)
                connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }
}

@MainActor
final class CodexAppServer: ObservableObject {
    enum State: Equatable {
        case disconnected
        case connecting
        case signingIn
        case connected(String?)
        case failed(String)
    }

    @Published private(set) var state: State = .disconnected
    @Published private(set) var snapshot = SnapshotStore.load()

    private var process: Process?
    private var input: FileHandle?
    private var outputBuffer = Data()
    private var refreshTimer: Timer?
    private let snapshotServer = SnapshotServer()

    init() {
        snapshotServer.start()
    }

    func connect() {
        guard process == nil else { refresh() ; return }
        guard let executable = findCodex() else {
            state = .failed("未找到 Codex CLI。请先安装 Codex 或 ChatGPT for Mac。")
            return
        }

        state = .connecting
        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server"]
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] task in
            Task { @MainActor in
                self?.process = nil
                self?.input = nil
                if task.terminationStatus != 0 {
                    self?.state = .failed("Codex app-server 已退出（\(task.terminationStatus)）")
                }
            }
        }

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor in self?.consume(data) }
        }

        do {
            try process.run()
            self.process = process
            input = stdin.fileHandleForWriting
            send(method: "initialize", id: 0, params: [
                "clientInfo": [
                    "name": "codex_quota_widget",
                    "title": "Codex Quota Widget",
                    "version": "0.2.0"
                ]
            ])
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func disconnect() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        input?.closeFile()
        process?.terminate()
        process = nil
        input = nil
        state = .disconnected
    }

    func refresh() {
        guard process != nil else { connect(); return }
        send(method: "account/rateLimits/read", id: 3)
        send(method: "account/usage/read", id: 4)
    }

    func setAppearance(_ appearance: WidgetAppearance) {
        guard snapshot.resolvedAppearance != appearance else { return }
        snapshot.appearance = appearance
        persist()
    }

    private func consume(_ data: Data) {
        outputBuffer.append(data)
        while let newline = outputBuffer.firstIndex(of: 0x0A) {
            let line = outputBuffer[..<newline]
            outputBuffer.removeSubrange(...newline)
            guard !line.isEmpty else { continue }
            let payload = Data(line)
            handle(payload)
        }
    }

    private func handle(_ data: Data) {
        guard let object = try? AppServerParser.object(from: data) else { return }

        if let method = object["method"] as? String {
            if method == "account/login/completed" {
                let success = (object["params"] as? [String: Any])?["success"] as? Bool ?? false
                success ? requestAccount() : (state = .failed("Codex 登录未完成"))
            } else if method == "account/rateLimits/updated" {
                refresh()
            } else if method == "account/updated" {
                requestAccount()
            }
            return
        }

        guard let id = (object["id"] as? NSNumber)?.intValue else { return }
        switch id {
        case 0:
            send(method: "initialized")
            requestAccount()
        case 1:
            handleAccount(object)
        case 2:
            if let url = AppServerParser.authURL(from: object) {
                state = .signingIn
                NSWorkspace.shared.open(url)
            }
        case 3:
            if let weekly = try? AppServerParser.weeklyWindow(from: object) {
                snapshot.weekly = weekly
                persist()
            }
        case 4:
            if let usage = try? AppServerParser.dailyUsage(from: object) {
                snapshot.dailyUsage = usage
                persist()
            }
        default:
            break
        }
    }

    private func requestAccount() {
        send(method: "account/read", id: 1, params: ["refreshToken": false])
    }

    private func handleAccount(_ object: [String: Any]) {
        guard let account = try? AppServerParser.account(from: object) else {
            state = .failed("无法读取 Codex 账户")
            return
        }
        if account.isLoggedIn {
            snapshot.email = account.email
            snapshot.plan = account.plan
            state = .connected(account.email)
            persist()
            refresh()
        } else {
            state = .signingIn
            send(method: "account/login/start", id: 2, params: [
                "type": "chatgpt",
                "useHostedLoginSuccessPage": true,
                "appBrand": "codex"
            ])
        }
    }

    private func persist() {
        snapshot.updatedAt = .now
        SnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: SnapshotStore.widgetKind)
    }

    private func send(method: String, id: Int? = nil, params: [String: Any]? = nil) {
        var message: [String: Any] = ["method": method]
        if let id { message["id"] = id }
        if let params { message["params"] = params }
        guard var data = try? JSONSerialization.data(withJSONObject: message) else { return }
        data.append(0x0A)
        do { try input?.write(contentsOf: data) }
        catch { state = .failed(error.localizedDescription) }
    }

    private func findCodex() -> URL? {
        let environment = ProcessInfo.processInfo.environment["CODEX_BINARY"]
        let paths = [
            environment,
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ].compactMap { $0 }
        return paths.first(where: FileManager.default.isExecutableFile(atPath:)).map(URL.init(fileURLWithPath:))
    }
}
