import Foundation

public enum WidgetAppearance: String, Codable, CaseIterable, Identifiable, Sendable {
    case dark, light

    public var id: Self { self }
    public var title: String { self == .dark ? "深色" : "浅色" }
}

public struct UsageWindow: Codable, Equatable, Sendable {
    public var usedPercent: Int
    public var windowDurationMinutes: Int?
    public var resetsAt: Date?

    public var remainingPercent: Int { max(0, min(100, 100 - usedPercent)) }

    public init(usedPercent: Int, windowDurationMinutes: Int?, resetsAt: Date?) {
        self.usedPercent = usedPercent
        self.windowDurationMinutes = windowDurationMinutes
        self.resetsAt = resetsAt
    }
}

public struct DailyUsage: Codable, Equatable, Identifiable, Sendable {
    public var id: String { startDate }
    public let startDate: String
    public let tokens: Int64

    public init(startDate: String, tokens: Int64) {
        self.startDate = startDate
        self.tokens = tokens
    }

    public var millions: Double { Double(tokens) / 1_000_000 }
}

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public var weekly: UsageWindow?
    public var dailyUsage: [DailyUsage]
    public var email: String?
    public var plan: String?
    public var appearance: WidgetAppearance?
    public var updatedAt: Date

    public init(
        weekly: UsageWindow? = nil,
        dailyUsage: [DailyUsage] = [],
        email: String? = nil,
        plan: String? = nil,
        appearance: WidgetAppearance = .dark,
        updatedAt: Date = .now
    ) {
        self.weekly = weekly
        self.dailyUsage = dailyUsage
        self.email = email
        self.plan = plan
        self.appearance = appearance
        self.updatedAt = updatedAt
    }

    public var resolvedAppearance: WidgetAppearance { appearance ?? .dark }

    public static let placeholder = UsageSnapshot(
        weekly: UsageWindow(usedPercent: 28, windowDurationMinutes: 10_080, resetsAt: nil),
        dailyUsage: [
            .init(startDate: "Mon", tokens: 12_000_000),
            .init(startDate: "Tue", tokens: 27_000_000),
            .init(startDate: "Wed", tokens: 54_000_000),
            .init(startDate: "Thu", tokens: 21_000_000),
            .init(startDate: "Fri", tokens: 34_000_000),
            .init(startDate: "Sat", tokens: 10_000_000),
            .init(startDate: "Sun", tokens: 13_000_000)
        ]
    )
}

public enum QuotaLevel: Equatable, Sendable {
    case healthy, warning, critical

    public init(remainingPercent: Int) {
        if remainingPercent >= 60 { self = .healthy }
        else if remainingPercent >= 30 { self = .warning }
        else { self = .critical }
    }
}

public enum SnapshotStore {
    public static let smallWidgetKind = "dev.codexquota.widget.small.v3"
    public static let largeWidgetKind = "dev.codexquota.widget.large.v3"
    private static let key = "usageSnapshot"

    public static func load(defaults: UserDefaults = sharedDefaults) -> UsageSnapshot {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(UsageSnapshot.self, from: data)
        else { return .placeholder }
        return value
    }

    public static func save(_ snapshot: UsageSnapshot, defaults: UserDefaults = sharedDefaults) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    public static var sharedDefaults: UserDefaults {
        .standard
    }
}
