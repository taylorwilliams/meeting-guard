import Foundation
import Testing
@testable import MeetingGuardCore

private let epoch = Date(timeIntervalSince1970: 1_800_000_000)

private func event(_ id: String = "meeting", start: Date = epoch.addingTimeInterval(120)) -> GuardEvent {
    GuardEvent(id: id, title: "Weekly planning", start: start, end: start.addingTimeInterval(1800))
}

@Test func firesOnceAcrossTicksAndPersistedRestarts() throws {
    var scheduler = AlertScheduler()
    let meeting = event()
    #expect(scheduler.due(events: [meeting], settings: .init(), now: epoch.addingTimeInterval(-1)).isEmpty)
    #expect(scheduler.due(events: [meeting], settings: .init(), now: epoch).count == 1)
    #expect(scheduler.due(events: [meeting], settings: .init(), now: epoch.addingTimeInterval(1)).isEmpty)
    let persisted = try JSONEncoder().encode(scheduler.ledger)
    var restarted = AlertScheduler(ledger: try JSONDecoder().decode(AlertLedger.self, from: persisted))
    #expect(restarted.due(events: [meeting], settings: .init(), now: epoch.addingTimeInterval(5)).isEmpty)
}

@Test func wakesDuringCatchUpWindowButSkipsOldOrFinishedEvents() {
    var scheduler = AlertScheduler()
    #expect(scheduler.due(events: [event()], settings: .init(), now: epoch.addingTimeInterval(300)).count == 1)
    var late = AlertScheduler()
    #expect(late.due(events: [event()], settings: .init(), now: epoch.addingTimeInterval(601)).isEmpty)
    var finished = AlertScheduler()
    #expect(finished.due(events: [event(start: epoch.addingTimeInterval(-2000))], settings: .init(), now: epoch).isEmpty)
}

@Test func simultaneousEventsAreNotDropped() {
    var scheduler = AlertScheduler()
    let tickets = scheduler.due(events: [event("one"), event("two")], settings: .init(), now: epoch)
    #expect(Set(tickets.map(\.event.id)) == ["one", "two"])
}

@Test func multipleOffsetsAndDismissalApplyToOneOccurrence() {
    var settings = GuardSettings(); settings.alertOffsets = [300, 60]
    let meeting = event(start: epoch.addingTimeInterval(300))
    var scheduler = AlertScheduler()
    #expect(scheduler.due(events: [meeting], settings: settings, now: epoch).count == 1)
    #expect(scheduler.due(events: [meeting], settings: settings, now: epoch.addingTimeInterval(240)).count == 1)
    var dismissed = AlertScheduler()
    _ = dismissed.due(events: [meeting], settings: settings, now: epoch)
    dismissed.dismiss(meeting, now: epoch)
    #expect(dismissed.due(events: [meeting], settings: settings, now: epoch.addingTimeInterval(240)).isEmpty)
    let recurrence = event("next-occurrence", start: epoch.addingTimeInterval(540))
    #expect(dismissed.due(events: [recurrence], settings: settings, now: epoch.addingTimeInterval(240)).count == 1)
}

@Test func wakingAcrossMultipleOffsetsProducesOneAlert() {
    var settings = GuardSettings(); settings.alertOffsets = [300, 120, 0]
    var scheduler = AlertScheduler()
    let tickets = scheduler.due(events: [event()], settings: settings, now: epoch.addingTimeInterval(130))
    #expect(tickets.count == 1)
    #expect(tickets.first?.scheduled == epoch.addingTimeInterval(120))
}

@Test func snoozeSuppressesOtherOffsetsAndSurvivesRestart() {
    var settings = GuardSettings(); settings.alertOffsets = [120, 60]
    let meeting = event()
    var scheduler = AlertScheduler()
    let first = scheduler.due(events: [meeting], settings: settings, now: epoch).first!
    scheduler.snooze(first, until: epoch.addingTimeInterval(90))
    #expect(scheduler.due(events: [meeting], settings: settings, now: epoch.addingTimeInterval(60)).isEmpty)
    var restarted = AlertScheduler(ledger: scheduler.ledger)
    let due = restarted.due(events: [meeting], settings: settings, now: epoch.addingTimeInterval(90))
    #expect(due.count == 1)
    #expect(due.first?.id.hasPrefix("snooze:") == true)
    #expect(restarted.due(events: [meeting], settings: settings, now: epoch.addingTimeInterval(91)).isEmpty)
}

@Test func deletedOrFilteredEventCannotResurfaceFromSnooze() {
    var scheduler = AlertScheduler()
    let ticket = scheduler.due(events: [event()], settings: .init(), now: epoch).first!
    scheduler.snooze(ticket, until: epoch.addingTimeInterval(60))
    #expect(scheduler.due(events: [], settings: .init(), now: epoch.addingTimeInterval(60)).isEmpty)
    #expect(scheduler.ledger.snoozed.isEmpty)
}

@Test func editedEventUsesFreshDetailsAndNewTriggerTime() {
    var scheduler = AlertScheduler()
    let first = scheduler.due(events: [event()], settings: .init(), now: epoch).first!
    scheduler.snooze(first, until: epoch.addingTimeInterval(60))
    var edited = event(); edited.title = "Updated title"
    #expect(scheduler.due(events: [edited], settings: .init(), now: epoch.addingTimeInterval(60)).first?.event.title == "Updated title")
}

@Test func pauseSkipsDueAlertsWithoutResumeBurst() {
    var settings = GuardSettings(); settings.pausedUntil = epoch.addingTimeInterval(30)
    var scheduler = AlertScheduler()
    #expect(scheduler.due(events: [event()], settings: settings, now: epoch).isEmpty)
    settings.pausedUntil = nil
    #expect(scheduler.due(events: [event()], settings: settings, now: epoch.addingTimeInterval(31)).isEmpty)
}

@Test func calendarFiltersAndCaseInsensitiveExclusions() {
    var settings = GuardSettings()
    var meeting = event()
    meeting.participation = .declined
    #expect(!settings.allows(meeting))
    meeting.participation = .pending
    settings.acceptedOnly = true
    #expect(!settings.allows(meeting))
    meeting.participation = .accepted
    #expect(settings.allows(meeting))
    settings.disabledCalendars = ["local"]
    #expect(!settings.allows(meeting))
    settings.disabledCalendars = []
    settings.excludedText = "holiday\nPLANNING"
    #expect(!settings.allows(meeting))
    meeting.isReminder = true
    #expect(settings.allows(meeting))
}

@Test func declinedAndFreeAndAllDayAndVideoFilters() {
    var settings = GuardSettings()
    var meeting = event()
    meeting.isAllDay = true
    #expect(!settings.allows(meeting))
    settings.showAllDay = true
    #expect(settings.allows(meeting))
    settings.skipFree = true; meeting.isFree = true
    #expect(!settings.allows(meeting))
    meeting.isFree = false; settings.videoOnly = true
    #expect(!settings.allows(meeting))
    meeting.notes = "Join https://meet.google.com/abc-defg-hij"
    #expect(settings.allows(meeting))
}

@Test func localReminderFiresAtExactTimeRatherThanCalendarLeadTime() {
    var scheduler = AlertScheduler()
    var reminder = event(start: epoch)
    reminder.isReminder = true
    #expect(scheduler.due(events: [reminder], settings: .init(), now: epoch.addingTimeInterval(-1)).isEmpty)
    #expect(scheduler.due(events: [reminder], settings: .init(), now: epoch).count == 1)
}

@Test func workHoursHandleWeekendsAndOvernightShifts() {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let friday = ISO8601DateFormatter().date(from: "2026-10-23T23:00:00Z")!
    var settings = GuardSettings(); settings.workHoursOnly = true
    #expect(!settings.allowsAlert(at: friday, calendar: calendar))
    settings.workStartHour = 22; settings.workEndHour = 6
    #expect(settings.allowsAlert(at: friday, calendar: calendar))
    #expect(settings.allowsAlert(at: friday.addingTimeInterval(3 * 3600), calendar: calendar))
    #expect(!settings.allowsAlert(at: friday.addingTimeInterval(24 * 3600), calendar: calendar))
}

@Test func allDayAlertsUseConfiguredLocalHour() {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Europe/London")!
    let day = ISO8601DateFormatter().date(from: "2026-10-19T00:00:00+01:00")!
    var settings = GuardSettings(); settings.showAllDay = true; settings.allDayHour = 9
    var meeting = event(start: day); meeting.isAllDay = true
    let alertDate = settings.alertDate(for: meeting, offset: 120, calendar: calendar)
    #expect(calendar.component(.hour, from: alertDate) == 8)
    #expect(calendar.component(.minute, from: alertDate) == 58)
}
