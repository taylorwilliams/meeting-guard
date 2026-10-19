import Foundation

public struct AlertTicket: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var event: GuardEvent
    public var scheduled: Date
    public init(id: String, event: GuardEvent, scheduled: Date) { self.id = id; self.event = event; self.scheduled = scheduled }
}

public struct AlertLedger: Codable, Equatable, Sendable {
    public var delivered: [String: Date] = [:]
    public var dismissed: [String: Date] = [:]
    public var snoozed: [String: AlertTicket] = [:]
    public init() {}
}

/// Deterministic scheduler. Call with a clock supplied by the host so wake, restart,
/// simultaneous meetings and late calendar updates follow the same delivery policy.
public struct AlertScheduler: Sendable {
    public var ledger: AlertLedger
    public let catchUpWindow: TimeInterval = 600
    public init(ledger: AlertLedger = .init()) { self.ledger = ledger }

    public mutating func due(events: [GuardEvent], settings: GuardSettings, now: Date,
                             calendar: Calendar = .current) -> [AlertTicket] {
        var result: [AlertTicket] = []
        let eligible = events.filter { settings.allows($0) }
        let byID = Dictionary(eligible.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (id, ticket) in ledger.snoozed {
            guard let event = byID[id], event.end > now, ledger.dismissed[id] == nil else {
                ledger.snoozed.removeValue(forKey: id); continue
            }
            if ticket.scheduled <= now {
                ledger.snoozed.removeValue(forKey: id)
                if now.timeIntervalSince(ticket.scheduled) <= catchUpWindow && settings.allowsAlert(at: now, calendar: calendar) {
                    result.append(AlertTicket(id: ticket.id, event: event, scheduled: ticket.scheduled))
                }
            }
        }
        for event in eligible where event.end > now && ledger.dismissed[event.id] == nil {
            let offsets = event.isReminder ? [0] : settings.alertOffsets
            var latest: AlertTicket?
            for offset in Set(offsets) {
                let date = settings.alertDate(for: event, offset: offset, calendar: calendar)
                let key = "\(event.id):\(Int(date.timeIntervalSince1970))"
                guard date <= now, ledger.delivered[key] == nil else { continue }
                // Consume suppressed/expired alerts so unpausing doesn't create a burst.
                ledger.delivered[key] = now
                if now.timeIntervalSince(date) <= catchUpWindow && ledger.snoozed[event.id] == nil &&
                    settings.allowsAlert(at: now, calendar: calendar) {
                    let ticket = AlertTicket(id: key, event: event, scheduled: date)
                    if latest == nil || latest!.scheduled < date { latest = ticket }
                }
            }
            if let latest, !result.contains(where: { $0.event.id == event.id }) { result.append(latest) }
        }
        let retention = now.addingTimeInterval(-8 * 86400)
        ledger.delivered = ledger.delivered.filter { $0.value > retention }
        ledger.dismissed = ledger.dismissed.filter { $0.value > retention }
        return result.sorted { $0.event.start == $1.event.start ? $0.id < $1.id : $0.event.start < $1.event.start }
    }

    public mutating func dismiss(_ event: GuardEvent, now: Date) {
        ledger.dismissed[event.id] = now
        ledger.snoozed.removeValue(forKey: event.id)
    }

    public mutating func snooze(_ ticket: AlertTicket, until date: Date) {
        var copy = ticket
        copy.id = "snooze:\(ticket.event.id):\(Int(date.timeIntervalSince1970))"
        copy.scheduled = date
        ledger.snoozed[ticket.event.id] = copy
    }
}
