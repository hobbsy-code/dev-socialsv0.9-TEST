import Foundation
import UserNotifications

/// Local notifications for bills. Nothing leaves the device.
///
/// iOS allows 64 pending notifications per app, so only the next occurrence of
/// each bill is scheduled (up to two notifications per bill). Everything is
/// rescheduled whenever the app becomes active or a bill changes.
@MainActor
final class ReminderService {
    static let shared = ReminderService()
    private let center = UNUserNotificationCenter.current()

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func isAuthorised() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    func rescheduleAll(_ bills: [Bill], hour: Int) async {
        center.removeAllPendingNotificationRequests()
        guard await isAuthorised() else { return }
        let upcoming = bills.filter { $0.isActive && !$0.isIncome }
            .sorted { $0.nextDueDate < $1.nextDueDate }
            .prefix(30)
        for bill in upcoming {
            await schedule(bill, hour: hour)
        }
    }

    private func schedule(_ bill: Bill, hour: Int) async {
        let cal = Fmt.calendar
        let due = cal.startOfDay(for: bill.nextDueDate)
        let amount = Fmt.money(bill.amount)
        let ddNote = bill.isDirectDebit ? " (Direct Debit — check there's enough in the account)" : ""

        if bill.reminderDaysBefore > 0,
           let before = cal.date(byAdding: .day, value: -bill.reminderDaysBefore, to: due) {
            let when = bill.reminderDaysBefore == 1 ? "tomorrow" : "in \(bill.reminderDaysBefore) days"
            await add(id: "\(bill.id)-before", day: before, hour: hour,
                      title: "\(bill.name) due \(when)",
                      body: "\(amount) on \(Fmt.dayWithWeekday(due))\(ddNote)")
        }
        if bill.remindOnDueDay {
            await add(id: "\(bill.id)-due", day: due, hour: hour,
                      title: "\(bill.name) is due today",
                      body: "\(amount)\(ddNote). Mark it paid in Clarity Vaults to move it to next time.")
        }
    }

    private func add(id: String, day: Date, hour: Int, title: String, body: String) async {
        var comps = Fmt.calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = 0
        guard let fireDate = Fmt.calendar.date(from: comps), fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
