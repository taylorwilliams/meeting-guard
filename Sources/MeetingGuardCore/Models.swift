import Foundation

public enum Participation: String, Codable, Sendable { case accepted, tentative, pending, declined }

public struct GuardEvent: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var calendarID: String
    public var calendarName: String
    public var colorHex: String
    public var location: String
    public var notes: String
    public var url: URL?
    public var participation: Participation
    public var isAllDay: Bool
    public var isFree: Bool
    public var hasAlarm: Bool
    public var isReminder: Bool

    public init(id: String, title: String, start: Date, end: Date, calendarID: String = "local",
                calendarName: String = "Reminders", colorHex: String = "628BFF", location: String = "",
                notes: String = "", url: URL? = nil, participation: Participation = .accepted,
                isAllDay: Bool = false, isFree: Bool = false, hasAlarm: Bool = true, isReminder: Bool = false) {
        self.id = id; self.title = title; self.start = start; self.end = end
        self.calendarID = calendarID; self.calendarName = calendarName; self.colorHex = colorHex
        self.location = location; self.notes = notes; self.url = url; self.participation = participation
        self.isAllDay = isAllDay; self.isFree = isFree; self.hasAlarm = hasAlarm; self.isReminder = isReminder
    }

    public var meetingURL: URL? { MeetingLink.find(in: [url?.absoluteString ?? "", location, notes]) }
}

public enum AlertTheme: String, CaseIterable, Codable, Sendable { case midnight, ocean, ember }
public enum DisplayMode: String, CaseIterable, Codable, Sendable { case active, all }

public struct GuardSettings: Codable, Equatable, Sendable {
    public var alertOffsets: [TimeInterval] = [120]
    public var disabledCalendars: Set<String> = []
    public var showAllDay = false
    public var allDayHour = 9
    public var acceptedOnly = false
    public var videoOnly = false
    public var alarmsOnly = false
    public var skipFree = false
    public var excludedText = ""
    public var workHoursOnly = false
    public var workStartHour = 8
    public var workEndHour = 18
    public var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    public var displayMode: DisplayMode = .all
    public var theme: AlertTheme = .midnight
    public var playSound = true
    // Retained so version 0.1 settings still decode and preserve their playback choice.
    public var repeatSound = false
    public var soundRepeatMode: SoundRepeatMode? = .forDuration
    public var soundRepeatSeconds: TimeInterval? = 120
    public var soundName = "Foghorn"
    public var soundVolume: Double = 0.6
    public var privacyMode = false
    public var showMenuCountdown = true
    public var pausedUntil: Date?

    public init() {}

    public var soundPlaybackMode: SoundRepeatMode {
        get { soundRepeatMode ?? (repeatSound ? .untilAnswered : .once) }
        set { soundRepeatMode = newValue; repeatSound = newValue != .once }
    }

    public var repeatDurationSeconds: TimeInterval {
        get { Self.validDuration(soundRepeatSeconds ?? 120) }
        set { soundRepeatSeconds = Self.validDuration(newValue) }
    }

    private static func validDuration(_ seconds: TimeInterval) -> TimeInterval {
        seconds.isFinite ? min(86400, max(1, seconds)) : 120
    }

    public func allows(_ event: GuardEvent) -> Bool {
        // Personal reminders deliberately bypass calendar-specific filters.
        if event.isReminder { return true }
        guard !disabledCalendars.contains(event.calendarID), event.participation != .declined else { return false }
        if event.isAllDay && !showAllDay { return false }
        if acceptedOnly && event.participation != .accepted { return false }
        if videoOnly && event.meetingURL == nil { return false }
        if alarmsOnly && !event.hasAlarm { return false }
        if skipFree && event.isFree { return false }
        let text = event.title + " " + event.location + " " + event.notes
        return !excludedText.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.contains { text.localizedCaseInsensitiveContains($0) }
    }

    public func allowsAlert(at date: Date, calendar: Calendar = .current) -> Bool {
        if let pausedUntil, pausedUntil > date { return false }
        guard workHoursOnly else { return true }
        let hour = calendar.component(.hour, from: date)
        if workStartHour == workEndHour { return weekdays.contains(calendar.component(.weekday, from: date)) }
        if workStartHour < workEndHour {
            return weekdays.contains(calendar.component(.weekday, from: date)) && hour >= workStartHour && hour < workEndHour
        }
        // After midnight, an overnight shift belongs to the day on which it began.
        if hour >= workStartHour { return weekdays.contains(calendar.component(.weekday, from: date)) }
        guard hour < workEndHour, let yesterday = calendar.date(byAdding: .day, value: -1, to: date) else { return false }
        return weekdays.contains(calendar.component(.weekday, from: yesterday))
    }

    public func alertDate(for event: GuardEvent, offset: TimeInterval, calendar: Calendar = .current) -> Date {
        let start = event.isAllDay
            ? calendar.date(bySettingHour: allDayHour, minute: 0, second: 0, of: event.start) ?? event.start
            : event.start
        return start.addingTimeInterval(-offset)
    }
}

public enum RepeatRule: String, CaseIterable, Codable, Sendable { case never, daily, weekdays, weekly }

public struct LocalReminder: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var title: String
    public var date: Date
    public var notes: String
    public var repeatRule: RepeatRule
    public var enabled: Bool

    public init(title: String, date: Date, notes: String = "", repeatRule: RepeatRule = .never, enabled: Bool = true) {
        self.title = title; self.date = date; self.notes = notes; self.repeatRule = repeatRule; self.enabled = enabled
    }

    public func occurrences(from lower: Date, to upper: Date, calendar: Calendar = .current) -> [GuardEvent] {
        guard enabled, lower < upper else { return [] }
        var dates: [Date] = []
        if repeatRule == .never {
            if date >= lower && date < upper { dates = [date] }
        } else {
            let anchorDay = calendar.startOfDay(for: date)
            var day = max(anchorDay, calendar.startOfDay(for: lower))
            let clock = calendar.dateComponents([.hour, .minute, .second], from: date)
            // Calendar arithmetic retains the user's wall-clock time across DST changes.
            while day < upper {
                if let candidate = calendar.date(bySettingHour: clock.hour ?? 0, minute: clock.minute ?? 0,
                                                 second: clock.second ?? 0, of: day), candidate >= date,
                   candidate >= lower, candidate < upper {
                    let weekday = calendar.component(.weekday, from: candidate)
                    if repeatRule == .daily || (repeatRule == .weekdays && (2...6).contains(weekday)) ||
                        (repeatRule == .weekly && weekday == calendar.component(.weekday, from: date)) {
                        dates.append(candidate)
                    }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
                day = next
            }
        }
        return dates.map { occurrence in
            GuardEvent(id: "reminder:\(id.uuidString):\(Int(occurrence.timeIntervalSince1970))", title: title,
                       start: occurrence, end: occurrence.addingTimeInterval(1800), notes: notes, isReminder: true)
        }
    }
}
