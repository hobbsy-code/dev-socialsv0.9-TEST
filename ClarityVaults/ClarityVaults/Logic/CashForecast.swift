import Foundation

/// A recurring item reduced to what forecasting needs (decoupled from SwiftData for testing).
struct ScheduledFlow {
    var name: String
    var amount: Double
    var isIncome: Bool
    var nextDue: Date
    var frequency: BillFrequency
    var anchorDay: Int
    /// False when paid from a credit card / savings, so it doesn't hit spending money.
    var affectsSpendingMoney: Bool
}

struct SafeToSpend {
    let spendingMoney: Double      // current + cash balances
    let billsBeforePayday: Double
    let incomeBeforePayday: Double // recurring income arriving before the next payday (e.g. weekly side income)
    let buffer: Double
    let nextPayday: Date
    let daysUntilPayday: Int

    var amount: Double { spendingMoney - billsBeforePayday + incomeBeforePayday - buffer }
    var perDay: Double { daysUntilPayday > 0 ? max(amount, 0) / Double(daysUntilPayday) : max(amount, 0) }
}

struct ForecastPoint: Identifiable {
    let date: Date
    let balance: Double
    var id: Date { date }
}

enum CashForecast {

    /// How much can be spent before the next payday once bills due before then are covered.
    /// Overdue bills (due date already passed, not yet marked paid) are included.
    static func safeToSpend(spendingMoney: Double, flows: [ScheduledFlow], nextPayday: Date,
                            buffer: Double, now: Date = .now, calendar: Calendar = Fmt.calendar) -> SafeToSpend {
        var bills = 0.0, income = 0.0
        for flow in flows where flow.affectsSpendingMoney {
            let dates = BillScheduler.occurrences(firstDue: flow.nextDue, frequency: flow.frequency,
                                                  anchorDay: flow.anchorDay, before: nextPayday, calendar: calendar)
            if flow.isIncome {
                // Only income strictly before payday; the payday salary itself starts the next period.
                income += Double(dates.filter { $0 >= calendar.startOfDay(for: now) }.count) * flow.amount
            } else {
                bills += Double(dates.count) * flow.amount
            }
        }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: nextPayday).day ?? 0
        return SafeToSpend(spendingMoney: spendingMoney, billsBeforePayday: bills, incomeBeforePayday: income,
                           buffer: buffer, nextPayday: nextPayday, daysUntilPayday: max(days, 0))
    }

    /// Day-by-day projected spending-money balance from scheduled income and bills only.
    /// Day-to-day spending isn't included; the chart shows what's committed.
    static func project(startBalance: Double, flows: [ScheduledFlow], days: Int = 60,
                        now: Date = .now, calendar: Calendar = Fmt.calendar) -> [ForecastPoint] {
        let today = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: days, to: today) else { return [] }
        var changes: [Date: Double] = [:]
        for flow in flows where flow.affectsSpendingMoney {
            for date in BillScheduler.occurrences(firstDue: flow.nextDue, frequency: flow.frequency,
                                                  anchorDay: flow.anchorDay, before: end, calendar: calendar) {
                if flow.isIncome && date < today { continue } // past income has already arrived (or not); don't assume
                let day = max(date, today) // overdue bills still need paying, so they land today
                changes[day, default: 0] += flow.isIncome ? flow.amount : -flow.amount
            }
        }
        var points: [ForecastPoint] = []
        var balance = startBalance
        for offset in 0...days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            balance += changes[day, default: 0]
            points.append(ForecastPoint(date: day, balance: balance))
        }
        return points
    }

    /// Lowest projected balance and when it happens: early warning for going overdrawn.
    static func lowestPoint(_ points: [ForecastPoint]) -> ForecastPoint? {
        points.min { $0.balance < $1.balance }
    }
}

extension Bill {
    func asFlow(accounts: [Account]) -> ScheduledFlow {
        let account = accounts.first { $0.id == accountID }
        return ScheduledFlow(name: name, amount: amount, isIncome: isIncome, nextDue: nextDueDate,
                             frequency: frequency, anchorDay: anchorDay,
                             affectsSpendingMoney: account?.kind.isSpendable ?? true)
    }
}
