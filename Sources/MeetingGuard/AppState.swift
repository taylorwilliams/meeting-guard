import AppKit
import Combine
import EventKit
import ServiceManagement
import MeetingGuardCore

@MainActor
final class AppState: ObservableObject {
    @Published var settings: GuardSettings { didSet { persist(); rebuildEvents() } }
    @Published var reminders: [LocalReminder] { didSet { persist(); rebuildEvents() } }
    @Published private(set) var calendars: [CalendarInfo] = []
    @Published private(set) var events: [GuardEvent] = []
    @Published private(set) var authorized = false
    @Published private(set) var accessDenied = false
    @Published private(set) var now = Date()
    @Published private(set) var lastSync: Date?
    @Published var error: String?
    @Published var requestingAccess = false
    @Published var calendarConnectionError: String?
    @Published var showReminderEditor = false
    @Published var editingReminder: LocalReminder?
    @Published var selectedEvent: GuardEvent?
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    var onTick: (() -> Void)?
    var onAlerts: (([AlertTicket]) -> Void)?
    var openSettings: (() -> Void)?
    var openDashboard: (() -> Void)?
    var previewAlert: (() -> Void)?
    private let service = CalendarService()
    private let store: StateStore
    private var scheduler: AlertScheduler
    private var calendarEvents: [GuardEvent] = []
    private var externalEvents: [GuardEvent] = []
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var canPersist = true
    let demo: Bool

    init(demo: Bool = false) {
        self.demo = demo
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        store = StateStore(url: root.appendingPathComponent("MeetingGuard/state.json"))
        var saved = SavedState()
        var loadError: String?
        if !demo {
            do { saved = try store.load() }
            catch { loadError = "Saved settings could not be read. Your file is preserved at \(store.url.path). Quit and restore or rename it before saving new settings." }
        }
        settings = saved.settings
        reminders = saved.reminders
        scheduler = AlertScheduler(ledger: saved.ledger)
        externalEvents = saved.ledger.snoozed.values.map(\.event).filter { $0.id.hasPrefix("external:") }
        error = loadError
        canPersist = loadError == nil && !demo
        if demo {
            let today = Date()
            calendarEvents = [
                GuardEvent(id: "demo:1", title: "Design catch-up", start: today.addingTimeInterval(1500), end: today.addingTimeInterval(3300), calendarName: "Work", location: "https://meet.google.com/example-demo-test", notes: "A sample event for exploring Meeting Guard."),
                GuardEvent(id: "demo:2", title: "Time to reset", start: today.addingTimeInterval(7200), end: today.addingTimeInterval(8100), calendarName: "Personal", colorHex: "56CDB2", location: "Take a walk, make a tea"),
                GuardEvent(id: "demo:3", title: "Plan the next chapter", start: today.addingTimeInterval(10800), end: today.addingTimeInterval(12600), calendarName: "Work", colorHex: "BE9AFF")
            ]
        }
        rebuildEvents()
    }

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        observers.append(NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh(); self?.tick() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name.NSSystemClockDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh(); self?.tick() }
        })
    }

    var visibleEvents: [GuardEvent] { events.filter { $0.end > now && settings.allows($0) } }
    var nextEvent: GuardEvent? { visibleEvents.first { $0.start > now } ?? visibleEvents.first }
    var isPaused: Bool { (settings.pausedUntil ?? .distantPast) > now }
    var snoozedCount: Int { scheduler.ledger.snoozed.count }
    var snoozedTickets: [AlertTicket] { scheduler.ledger.snoozed.values.sorted { $0.scheduled < $1.scheduled } }
    var dataPath: String { store.url.path }
    var canAcceptExternal: Bool { externalEvents.filter { $0.end > Date() }.count < 5 }

    func connectCalendar() {
        guard !requestingAccess else { return }
        guard !demo else {
            calendarConnectionError = "Calendar access is unavailable in demo mode. Quit and reopen Meeting Guard normally to connect your calendars."
            return
        }
        calendarConnectionError = nil
        requestingAccess = true
        Task {
            defer { requestingAccess = false }
            do {
                let granted = try await service.requestAccess()
                refresh()
                if !granted || !authorized {
                    calendarConnectionError = accessDenied
                        ? "Calendar access is off. Allow full access for Meeting Guard in System Settings → Privacy & Security → Calendars, then return here."
                        : "macOS did not grant calendar access. Make sure you opened the latest Meeting Guard.app, then quit and reopen it before trying again."
                }
            } catch {
                refresh()
                calendarConnectionError = "Calendar access failed: \(error.localizedDescription)"
            }
        }
    }

    func refresh() {
        now = Date()
        if !demo {
            authorized = service.authorized
            if authorized { calendarConnectionError = nil }
            accessDenied = service.denied
            let snapshot = service.refresh(now: now)
            calendars = snapshot.calendars
            calendarEvents = snapshot.events
        }
        lastSync = now
        rebuildEvents()
        tick()
    }

    private func rebuildEvents() {
        let lower = now.addingTimeInterval(-86400)
        let upper = Calendar.current.date(byAdding: .day, value: 8, to: now)!
        externalEvents.removeAll { $0.end <= now }
        events = (calendarEvents + externalEvents + reminders.flatMap { $0.occurrences(from: lower, to: upper) })
            .sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }

    private func tick() {
        now = Date()
        if now.timeIntervalSince(lastSync ?? .distantPast) >= 60 { refresh(); return }
        let previous = scheduler.ledger
        let due = scheduler.due(events: events, settings: settings, now: now)
        if scheduler.ledger != previous { persist() }
        if !due.isEmpty { onAlerts?(due) }
        onTick?()
    }

    func dismiss(_ ticket: AlertTicket) {
        scheduler.dismiss(ticket.event, now: now)
        if ticket.event.id.hasPrefix("external:") {
            externalEvents.removeAll { $0.id == ticket.event.id }
            rebuildEvents()
        }
        persist()
    }

    func isDismissed(_ event: GuardEvent) -> Bool { scheduler.ledger.dismissed[event.id] != nil }

    func acceptExternal(_ event: GuardEvent) {
        guard canAcceptExternal else { return }
        externalEvents.append(event)
        rebuildEvents()
        tick()
    }

    func snooze(_ ticket: AlertTicket, until: Date) {
        guard until > now && until < ticket.event.end else { return }
        scheduler.snooze(ticket, until: until)
        persist()
    }

    func pause(minutes: Double?) {
        settings.pausedUntil = minutes.map { Date().addingTimeInterval($0 * 60) }
    }

    func saveReminder(_ reminder: LocalReminder) {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) { reminders[index] = reminder }
        else { reminders.append(reminder) }
    }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { self.error = "Could not change launch at login: \(error.localizedDescription)" }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func join(_ event: GuardEvent) {
        guard let url = event.meetingURL, MeetingLink.safeWebURL(url) else { return }
        if !NSWorkspace.shared.open(url) { error = "The meeting link could not be opened." }
    }

    func systemCalendarSettings() {
        let target = accessDenied ? "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars" : "x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension"
        if let url = URL(string: target) { NSWorkspace.shared.open(url) }
    }

    private func persist() {
        guard canPersist else { return }
        var state = SavedState()
        state.settings = settings; state.reminders = reminders; state.ledger = scheduler.ledger
        do { try store.save(state) }
        catch { self.error = "Changes could not be saved: \(error.localizedDescription)" }
    }
}
