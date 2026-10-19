import SwiftUI
import MeetingGuardCore

@MainActor
struct AgendaView: View {
    @ObservedObject var state: AppState
    var compact = false
    @State private var todayOnly = true

    private var agenda: [GuardEvent] {
        state.visibleEvents.filter { !todayOnly || Calendar.current.isDate($0.start, inSameDayAs: state.now) || ($0.start < state.now && $0.end > state.now) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BrandMark(size: compact ? 30 : 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Meeting Guard").font(compact ? .headline : .title2.weight(.bold))
                    if !compact { Text(state.now.formatted(.dateTime.weekday(.wide).day().month(.wide))).foregroundStyle(.secondary) }
                }
                Spacer()
                Button { state.previewAlert?() } label: { Image(systemName: "play.rectangle") }.help("Try a sample alert")
                Button { state.openSettings?() } label: { Image(systemName: "gearshape") }.help("Settings")
            }.buttonStyle(.borderless).padding(compact ? 18 : 24)

            if state.demo { Label("Demo • sample events, no calendar access", systemImage: "sparkles").font(.caption).foregroundStyle(.secondary).padding(.bottom, 12) }
            if let error = state.error {
                HStack(alignment: .top) {
                    Label(error, systemImage: "exclamationmark.triangle").font(.caption)
                    Spacer()
                    Button("Dismiss") { state.error = nil }.buttonStyle(.borderless)
                }.padding(12).background(Color.orange.opacity(0.12)).padding(.horizontal, 18).padding(.bottom, 8)
            }
            if state.isPaused {
                HStack {
                    Label("Paused until \(state.settings.pausedUntil!.formatted(date: .omitted, time: .shortened))", systemImage: "pause.circle.fill")
                    Spacer()
                    Button("Resume") { state.pause(minutes: nil) }.buttonStyle(.borderless)
                }.font(.callout).padding(12).background(Color.orange.opacity(0.12)).padding(.horizontal, 18).padding(.bottom, 10)
            }
            if state.snoozedCount > 0 {
                HStack {
                    Menu {
                        ForEach(state.snoozedTickets) { ticket in
                            Button("Cancel: \(state.settings.privacyMode ? "Event" : ticket.event.title)") { state.dismiss(ticket) }
                        }
                    } label: { Label("\(state.snoozedCount) snoozed · manage", systemImage: "zzz") }
                        .menuStyle(.borderlessButton).fixedSize()
                    Spacer()
                }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.bottom, 12)
            }

            if !state.authorized && !state.demo {
                VStack(spacing: 14) {
                    EmptyMessage(icon: "calendar.badge.checkmark", title: "Make time for what matters", message: "Connect your calendars for full-screen meeting alerts. Your calendar data stays on this Mac.")
                    if let message = state.calendarConnectionError {
                        Label(message, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange).padding(.horizontal, 24)
                    }
                    Button(state.requestingAccess ? "Connecting…" : state.accessDenied ? "Open Calendar Privacy Settings" : "Connect Calendars") {
                        if state.accessDenied { state.systemCalendarSettings() } else { state.connectCalendar() }
                    }.buttonStyle(.borderedProminent).disabled(state.requestingAccess)
                    Button("Try a sample alert") { state.previewAlert?() }.buttonStyle(.borderless)
                }.padding(.bottom, 24)
            } else if let next = state.nextEvent, !compact {
                NextEventCard(event: next, state: state).padding(.horizontal, 24).padding(.bottom, 20)
            }

            HStack {
                Text("YOUR AGENDA").font(.caption.weight(.semibold)).tracking(1.4).foregroundStyle(.secondary)
                Spacer()
                Picker("Show", selection: $todayOnly) { Text("Today").tag(true); Text("7 days").tag(false) }.labelsHidden().pickerStyle(.segmented).frame(width: 146)
            }.padding(.horizontal, compact ? 18 : 24).padding(.bottom, 10)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(agenda.enumerated()), id: \.element.id) { index, event in
                        if index == 0 || !Calendar.current.isDate(event.start, inSameDayAs: agenda[index - 1].start) {
                            Text(event.start.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                                .font(.caption.weight(.medium)).foregroundStyle(.secondary).padding(.top, 10).padding(.bottom, 3)
                        }
                        EventRow(event: event, state: state)
                    }
                    if agenda.isEmpty {
                        EmptyMessage(icon: "checkmark.circle", title: "A little breathing room", message: "No matching events here. Add a reminder or check your calendars and filters.")
                    }
                    if !state.reminders.isEmpty { ReminderList(state: state) }
                }.padding(.horizontal, compact ? 18 : 24).padding(.bottom, 16)
            }.frame(minHeight: compact ? 100 : 120, maxHeight: .infinity)

            Divider()
            HStack(spacing: 12) {
                Button { state.editingReminder = nil; state.showReminderEditor = true } label: { Label("Reminder", systemImage: "plus") }
                Spacer()
                Menu {
                    Button("Resume alerts") { state.pause(minutes: nil) }.disabled(!state.isPaused)
                    Button("Pause for 15 minutes") { state.pause(minutes: 15) }
                    Button("Pause for 1 hour") { state.pause(minutes: 60) }
                    Button("Pause for 8 hours") { state.pause(minutes: 480) }
                } label: { Image(systemName: state.isPaused ? "pause.circle.fill" : "pause.circle") }.menuStyle(.borderlessButton).fixedSize().help("Pause alerts")
                Button { state.refresh() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh calendars")
                if compact {
                    Button { state.openDashboard?() } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.help("Open agenda window")
                }
                Menu {
                    Button("Settings…") { state.openSettings?() }
                    Button("Quit Meeting Guard") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
                } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize()
            }.buttonStyle(.borderless).padding(compact ? 16 : 20)
        }
        .tint(.guardBlue)
        .frame(width: compact ? 390 : nil)
        .frame(minWidth: compact ? nil : 650, minHeight: compact ? 540 : 680)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $state.showReminderEditor) { ReminderEditor(state: state, reminder: state.editingReminder) }
        .sheet(item: $state.selectedEvent) { EventDetail(event: $0, state: state) }
    }
}

@MainActor
private struct NextEventCard: View {
    let event: GuardEvent
    @ObservedObject var state: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("UP NEXT", systemImage: "clock").font(.caption.weight(.semibold)).tracking(1.4)
                Spacer()
                Text(relativeTime(event.start, now: state.now)).font(.callout.monospacedDigit())
            }.foregroundStyle(Color(hex: "B7C9FF"))
            Text(state.settings.privacyMode ? "Upcoming event" : event.title).font(.system(size: 28, weight: .semibold)).lineLimit(2)
            HStack {
                Text(event.start.formatted(date: .omitted, time: .shortened) + " – " + event.end.formatted(date: .omitted, time: .shortened)).foregroundStyle(.white.opacity(0.7))
                Spacer()
                if event.meetingURL != nil {
                    Button("Join call", systemImage: "video.fill") { state.join(event) }.buttonStyle(.borderedProminent)
                } else { Image(systemName: "calendar").foregroundStyle(.white.opacity(0.5)) }
            }
        }.padding(24).foregroundStyle(.white).background(LinearGradient(colors: [Color(hex: "1E2C50"), Color(hex: "141E35")], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
    }
}

@MainActor
struct EventRow: View {
    let event: GuardEvent
    @ObservedObject var state: AppState
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: event.colorHex)).frame(width: 4, height: 34)
            Button { state.selectedEvent = event } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(state.settings.privacyMode ? "Calendar event" : event.title).fontWeight(.medium).lineLimit(1)
                    Text(event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened) + " · " + relativeTime(event.start, now: state.now))
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).help("Event details")
            if event.meetingURL != nil {
                Button { state.join(event) } label: { Image(systemName: "video.fill").foregroundStyle(Color.guardBlue) }.buttonStyle(.borderless).help("Join \(MeetingLink.service(for: event.meetingURL))")
            }
        }.padding(12).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
    }
}

@MainActor
private struct ReminderList: View {
    @ObservedObject var state: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SAVED REMINDERS").font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(.secondary).padding(.top, 22)
            ForEach(state.reminders) { reminder in
                HStack {
                    Toggle("Enable \(reminder.title)", isOn: Binding(get: { reminder.enabled }, set: { value in
                        var edited = reminder; edited.enabled = value; state.saveReminder(edited)
                    })).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(reminder.title).lineLimit(1)
                        Text(reminder.repeatRule == .never ? reminder.date.formatted(date: .abbreviated, time: .shortened) : "\(reminder.repeatRule.rawValue.capitalized) at \(reminder.date.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Edit") { state.editingReminder = reminder; state.showReminderEditor = true }.buttonStyle(.borderless)
                }
            }
        }
    }
}

@MainActor
struct EventDetail: View {
    let event: GuardEvent
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text(state.settings.privacyMode ? "Event details hidden" : event.title).font(.title2.bold()); Spacer(); Button("Done") { dismiss() } }
            Label(event.start.formatted(date: .complete, time: .shortened), systemImage: "calendar")
            Label(event.calendarName, systemImage: "circle.fill").foregroundStyle(Color(hex: event.colorHex))
            if !state.settings.privacyMode {
                if !event.location.isEmpty { Text(event.location).textSelection(.enabled) }
                if !event.notes.isEmpty { ScrollView { Text(event.notes).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 180) }
            }
            HStack {
                if event.meetingURL != nil { Button("Join call") { state.join(event); dismiss() }.buttonStyle(.borderedProminent) }
                Spacer()
                Button("Skip alerts for this event") {
                    state.dismiss(AlertTicket(id: event.id, event: event, scheduled: state.now)); dismiss()
                }
            }
        }.padding(26).frame(width: 480)
    }
}
