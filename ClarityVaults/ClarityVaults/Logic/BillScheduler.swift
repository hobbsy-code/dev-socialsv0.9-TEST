import Foundation

/// Pure date logic for recurring bills. No SwiftData dependency so it can be unit tested.
enum BillScheduler {

    /// The next due date after `date` for a bill of the given frequency.
    /// `anchorDay` is the day of month the bill is normally due (1–31); months
    /// shorter than that use their last day, then snap back afterwards.
    static func nextDate(after date: Date, frequency: BillFrequency, anchorDay: Int,
                         calendar: Calendar = Fmt.calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        switch frequency {
        case .weekly:      return addDays(7, to: start, calendar)
        case .fortnightly: return addDays(14, to: start, calendar)
        case .fourWeekly:  return addDays(28, to: start, calendar)
        case .monthly:     return addMonths(1, to: start, anchorDay: anchorDay, calendar)
        case .quarterly:   return addMonths(3, to: start, anchorDay: anchorDay, calendar)
        case .annually:    return addMonths(12, to: start, anchorDay: anchorDay, calendar)
        case .councilTax10:
            // Most English councils collect over 10 months, April to January.
            var next = addMonths(1, to: start, anchorDay: anchorDay, calendar)
            switch calendar.component(.month, from: next) {
            case 2: next = addMonths(2, to: next, anchorDay: anchorDay, calendar)
            case 3: next = addMonths(1, to: next, anchorDay: anchorDay, calendar)
            default: break
            }
            return next
        }
    }

    /// All due dates from `firstDue` that fall before `end` (exclusive).
    static func occurrences(firstDue: Date, frequency: BillFrequency, anchorDay: Int,
                            before end: Date, calendar: Calendar = Fmt.calendar, limit: Int = 400) -> [Date] {
        var dates: [Date] = []
        var current = calendar.startOfDay(for: firstDue)
        while current < end && dates.count < limit {
            dates.append(current)
            current = nextDate(after: current, frequency: frequency, anchorDay: anchorDay, calendar: calendar)
        }
        return dates
    }

    // MARK: Helpers

    static func addDays(_ days: Int, to date: Date, _ calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    static func addMonths(_ months: Int, to date: Date, anchorDay: Int, _ calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month], from: date)
        comps.day = 1
        guard let firstOfMonth = calendar.date(from: comps),
              let targetMonth = calendar.date(byAdding: .month, value: months, to: firstOfMonth),
              let daysInMonth = calendar.range(of: .day, in: .month, for: targetMonth)?.count
        else { return date }
        var target = calendar.dateComponents([.year, .month], from: targetMonth)
        target.day = min(max(anchorDay, 1), daysInMonth)
        return calendar.date(from: target) ?? date
    }
}
