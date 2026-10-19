import Foundation

public enum DeepLink {
    public static func alert(from url: URL, now: Date) -> GuardEvent? {
        guard url.scheme?.lowercased() == "meetingguard", url.host?.lowercased() == "alert",
              url.absoluteString.utf8.count <= 16_384, url.user == nil, url.password == nil,
              url.port == nil, url.fragment == nil, ["", "/"].contains(url.path),
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = parts.queryItems ?? []
        guard Set(items.map(\.name)).count == items.count,
              items.allSatisfy({ ["title", "notes"].contains($0.name) }),
              let title = items.first(where: { $0.name == "title" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty, title.count <= 500,
              !title.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        let notes = String((items.first(where: { $0.name == "notes" })?.value ?? "").prefix(10_000))
        return GuardEvent(id: "external:\(UUID().uuidString)", title: title, start: now,
                          end: now.addingTimeInterval(1800), calendarName: "External reminder", notes: notes, isReminder: true)
    }
}

/// External callers cannot open repeated confirmation dialogs without a gap.
public struct AutomationRateLimit: Sendable {
    private var lastRequest: TimeInterval?
    public init() {}
    public mutating func allow(at uptime: TimeInterval) -> Bool {
        if let lastRequest, uptime - lastRequest < 10 { return false }
        lastRequest = uptime
        return true
    }
}
