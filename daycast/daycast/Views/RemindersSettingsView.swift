import SwiftUI

struct RemindersSettingsView: View {

    @State private var manager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss

    // Weekday labels starting from Monday (weekday 2) through Sunday (weekday 1)
    private let orderedWeekdays: [(weekday: Int, label: String)] = [
        (2, "Monday"),
        (3, "Tuesday"),
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
        (7, "Saturday"),
        (1, "Sunday"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable Reminders", isOn: $manager.remindersEnabled)
                        .onChange(of: manager.remindersEnabled) { _, newValue in
                            if newValue {
                                Task {
                                    let granted = await manager.requestPermission()
                                    if !granted {
                                        manager.remindersEnabled = false
                                    } else {
                                        manager.rescheduleAll()
                                    }
                                }
                            } else {
                                manager.cancelAll()
                            }
                        }
                }

                if manager.remindersEnabled {
                    Section("Schedule") {
                        ForEach(orderedWeekdays, id: \.weekday) { entry in
                            dayRow(weekday: entry.weekday, label: entry.label)
                        }
                    }
                }
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Day Row

    @ViewBuilder
    private func dayRow(weekday: Int, label: String) -> some View {
        if let index = manager.schedule.firstIndex(where: { $0.weekday == weekday }) {
            HStack {
                Toggle(label, isOn: $manager.schedule[index].isActive)
                    .onChange(of: manager.schedule[index].isActive) { _, _ in
                        manager.rescheduleAll()
                    }

                if manager.schedule[index].isActive {
                    DatePicker(
                        "",
                        selection: timeBinding(for: index),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .onChange(of: manager.schedule[index].hour) { _, _ in
                        manager.rescheduleAll()
                    }
                    .onChange(of: manager.schedule[index].minute) { _, _ in
                        manager.rescheduleAll()
                    }
                }
            }
        }
    }

    // MARK: - Time Binding

    private func timeBinding(for index: Int) -> Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = manager.schedule[index].hour
                components.minute = manager.schedule[index].minute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                manager.schedule[index].hour = comps.hour ?? 20
                manager.schedule[index].minute = comps.minute ?? 0
            }
        )
    }
}

#Preview {
    RemindersSettingsView()
}
