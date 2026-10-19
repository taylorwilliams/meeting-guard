import Foundation
import Testing
@testable import MeetingGuardCore

@Test func meetingLinksPreferRecognisedHostsAndRejectLookalikes() {
    #expect(MeetingLink.find(in: ["https://example.org", "Join https://meet.google.com/abc-defg-hij"])?.host == "meet.google.com")
    #expect(MeetingLink.find(in: ["https://zoom.us.evil.example/j/123"]) == nil)
    #expect(MeetingLink.find(in: ["https://notzoom.us/j/123"]) == nil)
    #expect(MeetingLink.find(in: ["https://user:secret@zoom.us/j/123"]) == nil)
    #expect(MeetingLink.find(in: ["javascript:alert(1)", "file:///etc/passwd"]) == nil)
    #expect(MeetingLink.find(in: ["Join https://us02web.zoom.us/j/123?pwd=foo&amp;bar=baz"])?.query == "pwd=foo&bar=baz")
    #expect(MeetingLink.find(in: ["<a href=\"https://teams.microsoft.com/l/meetup-join/123\">Join meeting</a>"])?.host == "teams.microsoft.com")
}

@Test func weekdayRemindersSkipWeekends() {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Europe/London")!
    let from = ISO8601DateFormatter().date(from: "2026-10-23T09:00:00+01:00")!
    let reminder = LocalReminder(title: "Stretch", date: from, repeatRule: .weekdays)
    let dates = reminder.occurrences(from: from, to: from.addingTimeInterval(5 * 86400), calendar: calendar)
    #expect(dates.count == 3)
    #expect(dates.allSatisfy { (2...6).contains(calendar.component(.weekday, from: $0.start)) })
    #expect(Set(dates.map(\.id)).count == dates.count)
}

@Test func dailyReminderRetainsLocalClockAcrossDaylightSavingBoundary() {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Europe/London")!
    let from = ISO8601DateFormatter().date(from: "2026-10-24T09:00:00+01:00")!
    let reminder = LocalReminder(title: "Break", date: from, repeatRule: .daily)
    let dates = reminder.occurrences(from: from, to: from.addingTimeInterval(3 * 86400), calendar: calendar)
    #expect(dates.count == 3)
    #expect(dates.allSatisfy { calendar.component(.hour, from: $0.start) == 9 })
    #expect(dates[1].start.timeIntervalSince(dates[0].start) == 25 * 3600)
}

@Test func weeklyReminderRetainsWeekdayAndNeverRunsBeforeAnchor() {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let anchor = ISO8601DateFormatter().date(from: "2026-10-21T09:00:00Z")!
    let reminder = LocalReminder(title: "Check-in", date: anchor, repeatRule: .weekly)
    let events = reminder.occurrences(from: anchor.addingTimeInterval(-5 * 86400), to: anchor.addingTimeInterval(15 * 86400), calendar: calendar)
    #expect(events.count == 3)
    #expect(events.allSatisfy { $0.start >= anchor && calendar.component(.weekday, from: $0.start) == 4 })
}

@Test func disabledRemindersNeverProduceOccurrences() {
    let now = Date()
    let reminder = LocalReminder(title: "Disabled", date: now, repeatRule: .daily, enabled: false)
    #expect(reminder.occurrences(from: now, to: now.addingTimeInterval(86400)).isEmpty)
}

@Test func localStateRoundTripIncludesSnoozesAndRestrictedPermissions() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = StateStore(url: directory.appendingPathComponent("state.json"))
    var state = SavedState()
    state.reminders = [LocalReminder(title: "Test", date: Date())]
    state.settings.disabledCalendars = ["private"]
    let event = GuardEvent(id: "1", title: "Sample", start: Date(), end: Date().addingTimeInterval(600))
    state.ledger.snoozed["1"] = AlertTicket(id: "snooze1", event: event, scheduled: Date().addingTimeInterval(60))
    try store.save(state)
    let loaded = try store.load()
    #expect(loaded.settings == state.settings)
    #expect(loaded.reminders == state.reminders)
    #expect(loaded.ledger == state.ledger)
    let attributes = try FileManager.default.attributesOfItem(atPath: store.url.path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
}

@Test func corruptAndFutureStateFilesArePreserved() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = StateStore(url: directory.appendingPathComponent("state.json"))
    let corrupt = Data("invalid json".utf8)
    try corrupt.write(to: store.url)
    #expect(throws: (any Error).self) { try store.load() }
    #expect(try Data(contentsOf: store.url) == corrupt)
    var future = SavedState(); future.schemaVersion = 500
    try store.save(future)
    #expect(throws: (any Error).self) { try store.load() }
}

@Test func deepLinksValidateSchemeTitleAndDuplicateParameters() {
    let now = Date()
    #expect(DeepLink.alert(from: URL(string: "meetingguard://alert?title=Take%20a%20break&notes=Stretch")!, now: now)?.title == "Take a break")
    #expect(DeepLink.alert(from: URL(string: "otherapp://alert?title=Test")!, now: now) == nil)
    #expect(DeepLink.alert(from: URL(string: "meetingguard://alert?notes=NoTitle")!, now: now) == nil)
    #expect(DeepLink.alert(from: URL(string: "meetingguard://alert?title=one&title=two")!, now: now) == nil)
}
