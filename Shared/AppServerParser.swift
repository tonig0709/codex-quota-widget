import Foundation

public enum AppServerParserError: Error, Equatable {
    case invalidEnvelope
    case missingRateLimits
}

public struct AccountInfo: Equatable, Sendable {
    public let email: String?
    public let plan: String?
    public let isLoggedIn: Bool
}

public enum AppServerParser {
    public static func object(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppServerParserError.invalidEnvelope
        }
        return object
    }

    public static func account(from object: [String: Any]) throws -> AccountInfo {
        guard let result = object["result"] as? [String: Any] else {
            throw AppServerParserError.invalidEnvelope
        }
        guard let account = result["account"] as? [String: Any] else {
            return AccountInfo(email: nil, plan: nil, isLoggedIn: false)
        }
        return AccountInfo(
            email: account["email"] as? String,
            plan: account["planType"] as? String,
            isLoggedIn: true
        )
    }

    public static func weeklyWindow(from object: [String: Any]) throws -> UsageWindow {
        guard let result = object["result"] as? [String: Any],
              let limits = result["rateLimits"] as? [String: Any]
        else { throw AppServerParserError.missingRateLimits }

        let windows = [limits["primary"], limits["secondary"]]
            .compactMap { $0 as? [String: Any] }

        guard let weekly = windows.max(by: {
            int($0["windowDurationMins"]) < int($1["windowDurationMins"])
        }), let used = intOrNil(weekly["usedPercent"])
        else { throw AppServerParserError.missingRateLimits }

        let reset = intOrNil(weekly["resetsAt"]).map { Date(timeIntervalSince1970: TimeInterval($0)) }
        return UsageWindow(
            usedPercent: used,
            windowDurationMinutes: intOrNil(weekly["windowDurationMins"]),
            resetsAt: reset
        )
    }

    public static func dailyUsage(from object: [String: Any]) throws -> [DailyUsage] {
        guard let result = object["result"] as? [String: Any] else {
            throw AppServerParserError.invalidEnvelope
        }
        let buckets = result["dailyUsageBuckets"] as? [[String: Any]] ?? []
        return buckets.compactMap { bucket in
            guard let startDate = bucket["startDate"] as? String,
                  let tokens = int64OrNil(bucket["tokens"])
            else { return nil }
            return DailyUsage(startDate: startDate, tokens: tokens)
        }
        .suffix(7)
        .map { $0 }
    }

    public static func authURL(from object: [String: Any]) -> URL? {
        guard let result = object["result"] as? [String: Any],
              let value = result["authUrl"] as? String
        else { return nil }
        return URL(string: value)
    }

    private static func int(_ value: Any?) -> Int { intOrNil(value) ?? 0 }

    private static func intOrNil(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func int64OrNil(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? NSNumber { return value.int64Value }
        return nil
    }
}
