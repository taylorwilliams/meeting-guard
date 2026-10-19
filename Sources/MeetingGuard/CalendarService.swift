import AppKit
import EventKit
import MeetingGuardCore

struct CalendarInfo: Identifiable {
    var id: String
    var title: String
    var source: String
    var colorHex: String
}

@MainActor
final class CalendarService {
    private let store = EKEventStore()
    private var sourceEvents: [String: EKEvent] = [:]

    var authorized: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    var denied: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .denied || status == .restricted || status == .writeOnly
    }

    func requestAccess() async throws -> Bool { try await store.requestFullAccessToEvents() }

    func refresh(now: Date) -> (calendars: [CalendarInfo], events: [GuardEvent]) {
        guard authorized else { sourceEvents = [:]; return ([], []) }
        let calendars = store.calendars(for: .event).map {
            CalendarInfo(id: $0.calendarIdentifier, title: $0.title, source: $0.source.title, colorHex: hex($0.cgColor))
        }.sorted { ($0.source, $0.title) < ($1.source, $1.title) }
        let lower = Calendar.current.startOfDay(for: now).addingTimeInterval(-86400)
        let upper = Calendar.current.date(byAdding: .day, value: 8, to: now)!
        let predicate = store.predicateForEvents(withStart: lower, end: upper, calendars: nil)
        sourceEvents = [:]
        let events = store.events(matching: predicate).compactMap { event -> GuardEvent? in
            guard event.status != .canceled, let start = event.startDate, let end = event.endDate,
                  let identifier = event.eventIdentifier, let calendar = event.calendar else { return nil }
            let id = "\(identifier):\(Int(start.timeIntervalSince1970))"
            sourceEvents[id] = event
            let participant = event.attendees?.first { $0.isCurrentUser }
            let participation: Participation
            switch participant?.participantStatus {
            case .declined: participation = .declined
            case .tentative: participation = .tentative
            case .pending: participation = .pending
            default: participation = .accepted
            }
            return GuardEvent(id: id, title: event.title ?? "Untitled event", start: start, end: end,
                calendarID: calendar.calendarIdentifier, calendarName: calendar.title, colorHex: hex(calendar.cgColor),
                location: event.location ?? "", notes: event.notes ?? "", url: event.url, participation: participation,
                isAllDay: event.isAllDay, isFree: event.availability == .free, hasAlarm: event.hasAlarms)
        }
        return (calendars, Array(Dictionary(events.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }).values)
            .sorted { $0.start < $1.start })
    }

    private func hex(_ color: CGColor?) -> String {
        guard let color, let rgb = NSColor(cgColor: color)?.usingColorSpace(.sRGB) else { return "628BFF" }
        return String(format: "%02X%02X%02X", Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
    }
}
