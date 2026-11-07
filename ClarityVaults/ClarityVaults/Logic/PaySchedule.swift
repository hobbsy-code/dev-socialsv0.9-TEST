import Foundation

/// When the user gets paid. Budget periods run from one payday to the next,
/// rather than by calendar month, a commonly requested feature UK users rarely get.
struct PaySchedule: Codable, Equatable {
    var frequency: PayFrequency = .monthlyOnDay
    /// Day of the month for `.monthlyOnDay` (1–31).
    var dayOfMonth: Int = 28
    /// Any known payday, for weekly / fortnightly / 4-weekly schedules.
    var anchorDate: Date = Fmt.calendar.startOfDay(for: .now)
    /// Move a weekend payday back to the Friday before (common UK employer practice).
    var moveWeekendToFriday: Bool = true

    /// The pay period containing `date`: [last payday, next payday).
    func period(containing date: Date, calendar: Calendar = Fmt.calendar) -> DateInterval {
        let day = calendar.startOfDay(for: date)
        switch frequency {
        case .weekly:      return intervalPeriod(containing: day, length: 7, calendar)
        case .fortnightly: return intervalPeriod(containing: day, length: 14, calendar)
        case .fourWeekly:  return intervalPeriod(containing: day, length: 28, calendar)
        case .monthlyOnDay, .lastWorkingDay:
            let thisMonth = payday(inMonthOf: day, calendar)
            if day >= thisMonth {
                let next = payday(inMonthOf: addMonths(1, to: day, calendar), calendar)
                return DateInterval(start: thisMonth, end: next)
            } else {
                let previous = payday(inMonthOf: addMonths(-1, to: day, calendar), calendar)
                return DateInterval(start: previous, end: thisMonth)
            }
        }
    }

    /// The next payday strictly after today (the end of the current period).
    func nextPayday(after date: Date = .now, calendar: Calendar = Fmt.calendar) -> Date {
        period(containing: date, calendar: calendar).end
    }

    /// The `count` most recent periods, oldest first, ending with the current one.
    func recentPeriods(_ count: Int, endingAt date: Date = .now, calendar: Calendar = Fmt.calendar) -> [DateInterval] {
        var periods: [DateInterval] = []
        var current = period(containing: date, calendar: calendar)
        for _ in 0..<max(count, 1) {
            periods.insert(current, at: 0)
            let dayBefore = calendar.date(byAdding: .day, value: -1, to: current.start) ?? current.start
            current = period(containing: dayBefore, calendar: calendar)
        }
        return periods
    }

    // MARK: Internals

    private func intervalPeriod(containing day: Date, length: Int, _ calendar: Calendar) -> DateInterval {
        let anchor = calendar.startOfDay(for: anchorDate)
        let diff = calendar.dateComponents([.day], from: anchor, to: day).day ?? 0
        let cycles = Int((Double(diff) / Double(length)).rounded(.down))
        let start = calendar.date(byAdding: .day, value: cycles * length, to: anchor) ?? day
        let end = calendar.date(byAdding: .day, value: length, to: start) ?? day
        return DateInterval(start: start, end: end)
    }

    private func payday(inMonthOf date: Date, _ calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month], from: date)
        comps.day = 1
        guard let first = calendar.date(from: comps),
              let days = calendar.range(of: .day, in: .month, for: first)?.count else { return date }
        let targetDay = frequency == .lastWorkingDay ? days : min(max(dayOfMonth, 1), days)
        comps.day = targetDay
        let raw = calendar.date(from: comps) ?? date
        let shouldAdjust = frequency == .lastWorkingDay || moveWeekendToFriday
        return shouldAdjust ? previousWeekday(onOrBefore: raw, calendar) : raw
    }

    private func previousWeekday(onOrBefore date: Date, _ calendar: Calendar) -> Date {
        var d = date
        // 1 = Sunday, 7 = Saturday in the Gregorian calendar
        while [1, 7].contains(calendar.component(.weekday, from: d)) {
            d = calendar.date(byAdding: .day, value: -1, to: d) ?? d
        }
        return d
    }

    private func addMonths(_ n: Int, to date: Date, _ calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month], from: date)
        comps.day = 1
        let first = calendar.date(from: comps) ?? date
        return calendar.date(byAdding: .month, value: n, to: first) ?? date
    }
}
