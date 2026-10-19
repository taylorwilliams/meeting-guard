import SwiftUI
import UniformTypeIdentifiers
import MeetingGuardCore

@MainActor
struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var offsets = ""
    @State private var offsetError: String?
    @State private var exportTheme = false
    @State private var importTheme = false
    @State private var durationUnit: Double = 60

    var body: some View {
        TabView {
            calendarSettings.tabItem { Label("Calendars", systemImage: "calendar") }
            alertSettings.tabItem { Label("Alerts", systemImage: "bell.badge") }
            filterSettings.tabItem { Label("Filters", systemImage: "line.3.horizontal.decrease.circle") }
            appearanceSettings.tabItem { Label("Appearance", systemImage: "paintpalette") }
            generalSettings.tabItem { Label("General", systemImage: "gearshape") }
        }.padding(16).frame(width: 640, height: 580).tint(.guardBlue)
            .onAppear { offsets = state.settings.alertOffsets.sorted(by: >).map { String(format: "%g", $0 / 60) }.joined(separator: ", ") }
            .fileExporter(isPresented: $exportTheme, document: ThemeDocument(theme: state.settings.theme), contentType: .json, defaultFilename: "MeetingGuard-theme") { result in
                if case .failure(let error) = result { state.error = error.localizedDescription }
            }
            .fileImporter(isPresented: $importTheme, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let granted = url.startAccessingSecurityScopedResource()
                    defer { if granted { url.stopAccessingSecurityScopedResource() } }
                    let document = try JSONDecoder().decode(ThemeFile.self, from: Data(contentsOf: url))
                    guard document.format == "MeetingGuardTheme", document.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
                    state.settings.theme = document.theme
                } catch { state.error = "Theme could not be imported: \(error.localizedDescription)" }
            }
    }

    private var calendarSettings: some View {
        Form {
            Section {
                if !state.authorized {
                    Text("Choose calendars already connected to macOS Calendar, including iCloud, Google and Exchange accounts.").foregroundStyle(.secondary)
                    if let message = state.calendarConnectionError {
                        Label(message, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.orange)
                    }
                    Button(state.requestingAccess ? "Connecting…" : state.accessDenied ? "Open Calendar Privacy Settings" : "Connect Calendars") {
                        if state.accessDenied { state.systemCalendarSettings() } else { state.connectCalendar() }
                    }.disabled(state.requestingAccess)
                }
                ForEach(state.calendars) { calendar in
                    Toggle(isOn: Binding(get: { !state.settings.disabledCalendars.contains(calendar.id) }, set: { enabled in
                        if enabled { state.settings.disabledCalendars.remove(calendar.id) } else { state.settings.disabledCalendars.insert(calendar.id) }
                    })) {
                        HStack {
                            Circle().fill(Color(hex: calendar.colorHex)).frame(width: 10, height: 10)
                            VStack(alignment: .leading) { Text(calendar.title); Text(calendar.source).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            } header: { Text("Calendars to watch") }
            Section {
                Button("Add accounts in macOS Settings…") { state.systemCalendarSettings() }
                Button("Refresh now") { state.refresh() }
                if let sync = state.lastSync { Text("Last refreshed at \(sync.formatted(date: .omitted, time: .standard))").font(.caption).foregroundStyle(.secondary) }
                Text("Meeting Guard checks local calendar data every minute and whenever macOS reports a change. Account synchronisation is managed by macOS Calendar.").font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    private var alertSettings: some View {
        Form {
            Section("Timing") {
                HStack {
                    TextField("Minutes before events", text: $offsets).textFieldStyle(.roundedBorder).onSubmit(applyOffsets)
                    Button("Apply", action: applyOffsets)
                }
                Text("Separate multiple alerts with commas, for example 5, 1, 0. Use 0 to alert at the start; decimals are supported. Maximum 24 hours.").font(.caption).foregroundStyle(.secondary)
                if let offsetError { Text(offsetError).font(.caption).foregroundStyle(.red) }
                Picker("Show on", selection: $state.settings.displayMode) { Text("All displays").tag(DisplayMode.all); Text("Display under pointer").tag(DisplayMode.active) }
            }
            Section("Sound") {
                Toggle("Play alert sound", isOn: $state.settings.playSound)
                Picker("Sound", selection: $state.settings.soundName) {
                    ForEach(["Foghorn", "Air Raid Siren", "Pulse Horn", "Deep Bass Pulse", "Glass", "Ping", "Hero", "Pop", "Submarine"], id: \.self) { Text($0).tag($0) }
                }.disabled(!state.settings.playSound)
                Slider(value: $state.settings.soundVolume, in: 0...1) { Text("Volume") }.disabled(!state.settings.playSound)
                Picker("Playback", selection: $state.settings.soundPlaybackMode) {
                    Text("Play once").tag(SoundRepeatMode.once)
                    Text("Repeat until answered").tag(SoundRepeatMode.untilAnswered)
                    Text("Repeat for a set time").tag(SoundRepeatMode.forDuration)
                }.disabled(!state.settings.playSound)
                if state.settings.soundPlaybackMode == .forDuration {
                    HStack {
                        Text("Repeat for")
                        Spacer(minLength: 16)
                        HStack(spacing: 10) {
                            TextField("Duration", value: Binding(get: { state.settings.repeatDurationSeconds / durationUnit }, set: { value in
                                state.settings.repeatDurationSeconds = value * durationUnit
                            }), format: .number.precision(.fractionLength(0...2)))
                                .labelsHidden().textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing).frame(width: 90)
                                .accessibilityLabel("Sound repeat duration")
                            Picker("Time unit", selection: $durationUnit) {
                                Text("seconds").tag(1.0); Text("minutes").tag(60.0)
                            }.labelsHidden().frame(width: 110)
                        }.fixedSize(horizontal: true, vertical: false)
                    }.disabled(!state.settings.playSound)
                    Text("Choose a duration from 1 second to 24 hours.").font(.caption).foregroundStyle(.secondary)
                }
                Text("Sound always stops when you dismiss, snooze or join. A timed sound stops after the chosen duration; the alert stays visible until answered.")
                    .font(.caption).foregroundStyle(.secondary)
                if state.settings.soundName == "Foghorn" {
                    Text("Foghorn repeats a long, low blast with a short pause.").font(.caption).foregroundStyle(.secondary)
                } else if state.settings.soundName == "Air Raid Siren" {
                    Text("Air Raid Siren continuously rises and falls in pitch.").font(.caption).foregroundStyle(.secondary)
                } else if state.settings.soundName == "Pulse Horn" {
                    Text("Pulse Horn plays even, steady DAAA blasts with short gaps.").font(.caption).foregroundStyle(.secondary)
                } else if state.settings.soundName == "Deep Bass Pulse" {
                    Text("Deep Bass Pulse blends a lower pulse with a clear higher horn tone.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section { Button("Try a sample full-screen alert") { state.previewAlert?() }; Text("Esc dismisses an alert. Snooze buttons offer 1 minute, 5 minutes, or the event's start time when available.").font(.caption).foregroundStyle(.secondary) }
        }.formStyle(.grouped)
    }

    private var filterSettings: some View {
        Form {
            Section("Events") {
                Toggle("Only accepted invitations", isOn: $state.settings.acceptedOnly)
                Toggle("Only events with a recognised video link", isOn: $state.settings.videoOnly)
                Toggle("Only events with a calendar alarm", isOn: $state.settings.alarmsOnly)
                Toggle("Skip events marked as free", isOn: $state.settings.skipFree)
                Toggle("Include all-day events", isOn: $state.settings.showAllDay)
                if state.settings.showAllDay { hourPicker("All-day event time", selection: $state.settings.allDayHour) }
                TextField("Exclude titles, locations or notes (one phrase per line)", text: $state.settings.excludedText, axis: .vertical).lineLimit(2...4)
            }
            Section("Work hours") {
                Toggle("Only alert during work hours", isOn: $state.settings.workHoursOnly)
                if state.settings.workHoursOnly {
                    HStack { hourPicker("From", selection: $state.settings.workStartHour); hourPicker("Until", selection: $state.settings.workEndHour) }
                    HStack {
                        ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                            Toggle(Calendar.current.shortWeekdaySymbols[day - 1], isOn: Binding(get: { state.settings.weekdays.contains(day) }, set: { value in
                                if value { state.settings.weekdays.insert(day) } else { state.settings.weekdays.remove(day) }
                            })).toggleStyle(.button)
                        }
                    }
                }
                Text("Declined invitations are always excluded. Work hours and pause suppress alerts, including custom reminders; suppressed alerts are skipped. Equal start and end hours cover the whole day.").font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    private var appearanceSettings: some View {
        Form {
            Section("Alert theme") {
                Picker("Palette", selection: $state.settings.theme) { ForEach(AlertTheme.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                VStack(spacing: 10) {
                    Image(systemName: "bell.badge.fill").font(.title).foregroundStyle(state.settings.theme.accent)
                    Text("A moment that matters").font(.title2.weight(.semibold)).foregroundStyle(.white)
                    Text("Your next meeting starts in 2 minutes").foregroundStyle(.white.opacity(0.65))
                }.frame(maxWidth: .infinity).padding(28).background(state.settings.theme.background, in: RoundedRectangle(cornerRadius: 12))
                HStack { Button("Export palette…") { exportTheme = true }; Button("Import palette…") { importTheme = true } }
            }
            Section("Privacy and menu bar") {
                Toggle("Hide event titles, locations and notes", isOn: $state.settings.privacyMode)
                Toggle("Show countdown in the menu bar", isOn: $state.settings.showMenuCountdown)
                Text("Privacy mode hides event details in the agenda and full-screen alerts. Meeting links still open when you choose Join.").font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }

    private var generalSettings: some View {
        Form {
            Section {
                Toggle("Launch Meeting Guard at login", isOn: Binding(get: { state.launchAtLogin }, set: { state.setLogin($0) }))
                Text("Keep the app running in your menu bar to receive alerts. This Mac cannot show alerts while asleep or powered off.").font(.caption).foregroundStyle(.secondary)
            }
            Section("About Meeting Guard") {
                Text("Version 0.1.0 · MIT licence").fontWeight(.medium)
                Text("An independent, open-source meeting reminder for macOS. Built with Swift, SwiftUI and EventKit. No analytics, subscriptions or external servers.").foregroundStyle(.secondary)
                Text("Settings, custom reminders and alert history are saved locally:").font(.caption)
                Text(state.dataPath).font(.caption.monospaced()).textSelection(.enabled)
                Button("Show local data folder") { NSWorkspace.shared.selectFile(state.dataPath, inFileViewerRootedAtPath: "") }
            }
        }.formStyle(.grouped)
    }

    private func hourPicker(_ title: String, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) { ForEach(0..<24, id: \.self) { hour in Text(String(format: "%02d:00", hour)).tag(hour) } }
    }

    private func applyOffsets() {
        let pieces = offsets.split(separator: ",", omittingEmptySubsequences: false)
        let values = pieces.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard values.count == pieces.count, !values.isEmpty, values.count <= 8,
              values.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1440 }) else {
            offsetError = "Enter 1–8 numbers between 0 and 1440, separated by commas."; return
        }
        state.settings.alertOffsets = Array(Set(values.map { ($0 * 60).rounded() })).sorted(by: >)
        offsetError = nil
    }
}

struct ThemeFile: Codable { var format = "MeetingGuardTheme"; var version = 1; var theme: AlertTheme }
struct ThemeDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var theme: AlertTheme
    init(theme: AlertTheme) { self.theme = theme }
    init(configuration: ReadConfiguration) throws {
        theme = try JSONDecoder().decode(ThemeFile.self, from: configuration.file.regularFileContents ?? Data()).theme
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try JSONEncoder().encode(ThemeFile(theme: theme)))
    }
}
