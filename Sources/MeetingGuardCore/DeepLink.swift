import Foundation

public enum DeepLink {
    public static func alert(from url: URL, now: Date) -> GuardEvent? {
        guard url.scheme?.lowercased() == "meetingguard", url.host?.lowercased() == "alert",
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = parts.queryItems ?? []
        guard Set(items.map(\.name)).count == items.count,
              let title = items.first(where: { $0.name == "title" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty, title.count <= 500 else { return nil }
        let notes = String((items.first(where: { $0.name == "notes" })?.value ?? "").prefix(10_000))
        return GuardEvent(id: "external:\(UUID().uuidString)", title: title, start: now,
                          end: now.addingTimeInterval(1800), calendarName: "External reminder", notes: notes, isReminder: true)
    }
}
