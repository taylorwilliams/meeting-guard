import SwiftUI
import MeetingGuardCore

@MainActor
struct ReminderEditor: View {
    @ObservedObject var state: AppState
    let reminder: LocalReminder?
    @State private var title = ""
    @State private var date = Date().addingTimeInterval(300)
    @State private var notes = ""
    @State private var repeatRule: RepeatRule = .never
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(reminder == nil ? "A moment to remember" : "Edit reminder").font(.title2.bold())
            Form {
                TextField("Title", text: $title).textFieldStyle(.roundedBorder)
                DatePicker("When", selection: $date, displayedComponents: [.date, .hourAndMinute])
                Picker("Repeat", selection: $repeatRule) {
                    ForEach(RepeatRule.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                TextField("Notes or meeting link", text: $notes, axis: .vertical).lineLimit(3...6).textFieldStyle(.roundedBorder)
            }
            Text("Reminders alert at the chosen time, even when calendar filters exclude other events. Pause and work hours apply to every alert.")
                .font(.caption).foregroundStyle(.secondary)
            if repeatRule == .never && date <= Date() { Text("Choose a future time for a one-off reminder.").font(.caption).foregroundStyle(.orange) }
            HStack {
                if let reminder {
                    Button("Delete", role: .destructive) { state.reminders.removeAll { $0.id == reminder.id }; dismiss() }
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save reminder") {
                    var saved = reminder ?? LocalReminder(title: title, date: date)
                    saved.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    saved.date = date; saved.notes = notes; saved.repeatRule = repeatRule
                    state.saveReminder(saved); dismiss()
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (repeatRule == .never && date <= Date()))
            }
        }.padding(28).frame(width: 450).tint(.guardBlue)
        .onAppear {
            if let reminder { title = reminder.title; date = reminder.date; notes = reminder.notes; repeatRule = reminder.repeatRule }
        }
    }
}
