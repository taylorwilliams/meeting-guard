import AppKit
import SwiftUI
import MeetingGuardCore

@main
enum MeetingGuardMain {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--diagnostics") {
            print("Meeting Guard 0.1.0 | macOS \(ProcessInfo.processInfo.operatingSystemVersionString) | calendar usage description: \(Bundle.main.object(forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription") != nil) | bundle: \(Bundle.main.bundleIdentifier ?? "unbundled")")
            return
        }
        if let identifier = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(options: [])
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState(demo: CommandLine.arguments.contains("--demo"))
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var dashboard: NSWindow?
    private var settingsWindow: NSWindow?
    private var presenter: AlertPresenter!
    private var subscriptions: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: AgendaView(state: state, compact: true))
        popover.contentSize = NSSize(width: 390, height: 600)
        presenter = AlertPresenter(state: state)
        state.onTick = { [weak self] in self?.updateStatus(); self?.presenter.reconcile() }
        state.onAlerts = { [weak self] tickets in self?.popover.performClose(nil); self?.presenter.enqueue(tickets) }
        state.openDashboard = { [weak self] in self?.showDashboard() }
        state.openSettings = { [weak self] in self?.showSettings() }
        state.previewAlert = { [weak self] in self?.popover.performClose(nil); self?.presenter.preview() }
        // Refresh visible state immediately when settings/filters are changed.
        state.$settings.dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.updateStatus(); self?.presenter.reconcile() }
        }.store(in: &subscriptions)
        state.start()
        updateStatus()
        if !CommandLine.arguments.contains("--background") { showDashboard() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDashboard(); return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls.prefix(8) {
            if let event = DeepLink.alert(from: url, now: Date()) {
                state.acceptExternal(event)
            }
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY); popover.contentViewController?.view.window?.makeKey() }
    }

    private func updateStatus() {
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: state.isPaused ? "bell.slash" : "bell.badge", accessibilityDescription: "Meeting Guard")
        button.image?.isTemplate = true
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        if state.isPaused { button.title = " Paused" }
        else if state.settings.showMenuCountdown, let next = state.nextEvent {
            let seconds = next.start.timeIntervalSince(state.now)
            if seconds < 0 { button.title = " Now" }
            else if seconds < 60 { button.title = " \(max(0, Int(seconds)))s" }
            else if seconds < 3600 { button.title = " \(Int(seconds / 60))m" }
            else if seconds < 86400 { button.title = " \(Int(seconds / 3600))h" }
            else { button.title = "" }
        } else { button.title = "" }
        button.toolTip = state.settings.privacyMode ? "Meeting Guard" : state.nextEvent.map { "\($0.title) · \(relativeTime($0.start, now: state.now))" } ?? "Meeting Guard · No upcoming events"
    }

    private func showDashboard() {
        popover.performClose(nil)
        if dashboard == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 740), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Meeting Guard"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: AgendaView(state: state))
            window.minSize = NSSize(width: 650, height: 680)
            window.center()
            dashboard = window
        }
        dashboard?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 672, height: 612), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Meeting Guard Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(state: state))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configureMenu() {
        let mainMenu = NSMenu()
        let appMenu = NSMenu()
        let appItem = NSMenuItem(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Meeting Guard", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addItem(appItem)
        let editMenu = NSMenu(title: "Edit")
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: ""); edit.submenu = editMenu
        for (title, action, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        mainMenu.addItem(edit)
        NSApp.mainMenu = mainMenu
    }
}

import Combine
