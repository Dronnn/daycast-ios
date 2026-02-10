import Foundation
import UserNotifications

struct ReminderDay: Codable, Identifiable {
    var weekday: Int      // 1 = Sunday, 2 = Monday, … 7 = Saturday
    var isActive: Bool
    var hour: Int
    var minute: Int

    var id: Int { weekday }
}

@Observable
final class NotificationManager {

    static let shared = NotificationManager()

    var remindersEnabled: Bool {
        didSet { UserDefaults.standard.set(remindersEnabled, forKey: "remindersEnabled") }
    }

    var schedule: [ReminderDay] {
        didSet { saveSchedule() }
    }

    // MARK: - Init

    private init() {
        remindersEnabled = UserDefaults.standard.bool(forKey: "remindersEnabled")

        if let data = UserDefaults.standard.data(forKey: "reminderSchedule"),
           let decoded = try? JSONDecoder().decode([ReminderDay].self, from: data) {
            schedule = decoded
        } else {
            // Default: all days active at 20:00
            schedule = (1...7).map { ReminderDay(weekday: $0, isActive: true, hour: 20, minute: 0) }
        }
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Scheduling

    func rescheduleAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard remindersEnabled else { return }

        let todayCount = currentItemCount()

        for day in schedule where day.isActive {
            var dateComponents = DateComponents()
            dateComponents.weekday = day.weekday
            dateComponents.hour = day.hour
            dateComponents.minute = day.minute

            let content = UNMutableNotificationContent()
            content.title = "daycast"
            content.body = "You added \(todayCount) items today. Ready to generate?"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "reminder-\(day.weekday)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func updateTodayNotification(itemCount: Int) {
        guard remindersEnabled else { return }

        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: Date())

        guard let day = schedule.first(where: { $0.weekday == todayWeekday && $0.isActive }) else { return }

        let center = UNUserNotificationCenter.current()
        let identifier = "reminder-\(day.weekday)"

        // Remove old, add updated
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        var dateComponents = DateComponents()
        dateComponents.weekday = day.weekday
        dateComponents.hour = day.hour
        dateComponents.minute = day.minute

        let content = UNMutableNotificationContent()
        content.title = "daycast"
        content.body = "You added \(itemCount) items today. Ready to generate?"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)

        saveItemCount(itemCount)
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Item Count Persistence

    private func saveItemCount(_ count: Int) {
        UserDefaults.standard.set(count, forKey: "reminderItemCount")
    }

    private func currentItemCount() -> Int {
        UserDefaults.standard.integer(forKey: "reminderItemCount")
    }

    // MARK: - Schedule Persistence

    private func saveSchedule() {
        if let data = try? JSONEncoder().encode(schedule) {
            UserDefaults.standard.set(data, forKey: "reminderSchedule")
        }
    }
}
