import AppKit
import SwiftUI
import MeetingGuardCore

private final class AlertPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AlertPresenter {
    private let state: AppState
    private var queue: [AlertTicket] = []
    private var panels: [NSPanel] = []
    private let sound = AlertSoundPlayer()
    private var keyMonitor: Any?
    private var displayObserver: NSObjectProtocol?
    private var previousApplication: NSRunningApplication?

    init(state: AppState) {
        self.state = state
        displayObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in if self?.queue.isEmpty == false { self?.render() } }
        }
    }

    func enqueue(_ tickets: [AlertTicket]) {
        let wasEmpty = queue.isEmpty
        for ticket in tickets where !queue.contains(where: { $0.event.id == ticket.event.id }) { queue.append(ticket) }
        if wasEmpty { previousApplication = NSWorkspace.shared.frontmostApplication }
        if !queue.isEmpty { render() }
    }

    func preview() {
        guard queue.isEmpty else { return }
        let start = Date().addingTimeInterval(120)
        let event = GuardEvent(id: "preview", title: "A moment that matters", start: start, end: start.addingTimeInterval(1800),
                               calendarName: "Sample alert", location: "Your meeting, right on time.", notes: "This is a preview. Dismiss with the button below or press Esc.")
        enqueue([AlertTicket(id: "preview", event: event, scheduled: Date())])
    }

    func reconcile() {
        if !state.settings.playSound { sound.stop() }
        let valid = Set(state.visibleEvents.filter { !state.isDismissed($0) }.map(\.id))
        let count = queue.count
        queue.removeAll { $0.event.id != "preview" && (!valid.contains($0.event.id) || state.isPaused) }
        if count != queue.count { render() }
    }

    private func render() {
        closePanels()
        guard let ticket = queue.first else {
            sound.stop()
            // Restore focus only when one of our alert panels still owns the app focus.
            previousApplication?.activate(options: [])
            previousApplication = nil
            return
        }
        let screens: [NSScreen]
        if state.settings.displayMode == .all { screens = NSScreen.screens }
        else { screens = [NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main].compactMap { $0 } }
        for screen in screens {
            let panel = AlertPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.isOpaque = true
            panel.backgroundColor = NSColor(state.settings.theme.background)
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.setFrame(screen.frame, display: true)
            panel.contentView = NSHostingView(rootView: FullScreenAlert(ticket: ticket, count: queue.count, state: state,
                dismiss: { [weak self] in self?.finish(snoozeUntil: nil) },
                snooze: { [weak self] date in self?.finish(snoozeUntil: date) },
                join: { [weak self] in self?.state.join(ticket.event); self?.finish(snoozeUntil: nil, restoreFocus: false) }))
            panels.append(panel)
            panel.orderFrontRegardless()
        }
        panels.first?.makeKey()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { Task { @MainActor in self?.finish(snoozeUntil: nil) }; return nil }
            return event
        }
        if !sound.start(alertID: ticket.id, settings: state.settings) {
            state.error = "The alert sound could not be played. Check the selected sound and your Mac's audio output."
        }
    }

    private func finish(snoozeUntil: Date?, restoreFocus: Bool = true) {
        guard let ticket = queue.first else { return }
        if ticket.event.id != "preview" {
            if let snoozeUntil { state.snooze(ticket, until: snoozeUntil) } else { state.dismiss(ticket) }
        }
        queue.removeFirst()
        if !restoreFocus { previousApplication = nil }
        render()
    }

    private func closePanels() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        panels.forEach { $0.orderOut(nil); $0.close() }
        panels = []
    }
}

@MainActor
private struct FullScreenAlert: View {
    let ticket: AlertTicket
    let count: Int
    @ObservedObject var state: AppState
    let dismiss: () -> Void
    let snooze: (Date) -> Void
    let join: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack { Label("MEETING GUARD", systemImage: "bell.badge.fill").tracking(2); Spacer(); if count > 1 { Text("\(count) alerts waiting") } }
                    .font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.5)).padding(36)
                Spacer(minLength: 20)
                VStack(spacing: 24) {
                    Image(systemName: ticket.event.isReminder ? "sparkles" : "calendar.badge.clock")
                        .font(.system(size: 38, weight: .light)).foregroundStyle(state.settings.theme.accent)
                        .frame(width: 92, height: 92).background(state.settings.theme.accent.opacity(0.1), in: Circle())
                    Text(ticket.event.isReminder ? "A LITTLE REMINDER" : "TIME TO COME UP FOR AIR")
                        .font(.caption.weight(.semibold)).tracking(3).foregroundStyle(state.settings.theme.accent)
                    Text(state.settings.privacyMode ? "Your next event" : ticket.event.title)
                        .font(.system(size: min(60, geometry.size.width / 20), weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center).lineLimit(3).minimumScaleFactor(0.6)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(relativeTime(ticket.event.start, now: context.date))
                            .font(.system(size: 28, weight: .light)).monospacedDigit().foregroundStyle(.white.opacity(0.7))
                    }
                    Text(ticket.event.start.formatted(date: .omitted, time: .shortened) + " – " + ticket.event.end.formatted(date: .omitted, time: .shortened))
                        .font(.callout).foregroundStyle(.white.opacity(0.5))
                    if !state.settings.privacyMode && !ticket.event.location.isEmpty {
                        Text(ticket.event.location).font(.callout).foregroundStyle(.white.opacity(0.6)).lineLimit(2).multilineTextAlignment(.center)
                    }
                    if !state.settings.privacyMode && !ticket.event.notes.isEmpty {
                        DisclosureGroup("Notes") { ScrollView { Text(ticket.event.notes).font(.callout).textSelection(.enabled) }.frame(maxHeight: 100) }
                            .foregroundStyle(.white.opacity(0.7)).frame(maxWidth: 480)
                    }
                    HStack(spacing: 14) {
                        Button("Dismiss", action: dismiss).keyboardShortcut(.cancelAction)
                        if ticket.event.meetingURL != nil { Button("Join \(MeetingLink.service(for: ticket.event.meetingURL))", action: join).buttonStyle(.borderedProminent) }
                    }.controlSize(.large).buttonStyle(.bordered).padding(.top, 16)
                    HStack(spacing: 20) {
                        Text("Snooze").foregroundStyle(.white.opacity(0.35))
                        ForEach([1, 5], id: \.self) { minutes in
                            if Date().addingTimeInterval(Double(minutes * 60)) < ticket.event.end {
                                Button("\(minutes) min") { snooze(Date().addingTimeInterval(Double(minutes * 60))) }
                            }
                        }
                        if ticket.event.start > state.now.addingTimeInterval(10) {
                            Button("Until start") { snooze(ticket.event.start) }
                        }
                    }.font(.callout).buttonStyle(.borderless).foregroundStyle(state.settings.theme.accent).padding(.top, 6)
                }.padding(.horizontal, 50).frame(maxWidth: 920)
                Spacer(minLength: 20)
                Text("Take a breath. You have time.     ·     Esc to dismiss")
                    .font(.caption).foregroundStyle(.white.opacity(0.35)).padding(30)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RadialGradient(colors: [state.settings.theme.accent.opacity(0.07), .clear], center: .center, startRadius: 0, endRadius: 650))
                .background(state.settings.theme.background).foregroundStyle(.white).tint(state.settings.theme.accent).environment(\.colorScheme, .dark)
        }
    }
}
