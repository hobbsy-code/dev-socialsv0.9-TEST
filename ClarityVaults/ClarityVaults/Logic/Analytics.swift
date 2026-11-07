import Foundation

struct PeriodTotals: Identifiable {
    let period: DateInterval
    let income: Double
    let outgoings: Double
    var net: Double { income - outgoings }
    var id: Date { period.start }
    var label: String { Fmt.day(period.start) }
}

struct CategoryTotal: Identifiable {
    let category: SpendCategory
    let amount: Double
    let share: Double
    var id: String { category.rawValue }
}

struct BudgetProgress: Identifiable {
    let category: SpendCategory
    let limit: Double
    let spent: Double
    var remaining: Double { limit - spent }
    var fraction: Double { limit > 0 ? spent / limit : 0 }
    var isOver: Bool { spent > limit }
    var id: String { category.rawValue }
}

struct WealthPoint: Identifiable {
    let date: Date
    let assets: Double
    let debts: Double
    var net: Double { assets - debts }
    var id: Date { date }
}

enum Analytics {

    static func entries(_ entries: [LedgerEntry], in period: DateInterval) -> [LedgerEntry] {
        entries.filter { $0.date >= period.start && $0.date < period.end }
    }

    static func totals(_ entries: [LedgerEntry], periods: [DateInterval]) -> [PeriodTotals] {
        periods.map { period in
            let inPeriod = Self.entries(entries, in: period)
            return PeriodTotals(period: period,
                                income: inPeriod.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount },
                                outgoings: inPeriod.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount })
        }
    }

    static func spendingByCategory(_ entries: [LedgerEntry], in period: DateInterval) -> [CategoryTotal] {
        let expenses = Self.entries(entries, in: period).filter { $0.kind == .expense }
        let total = expenses.reduce(0) { $0 + $1.amount }
        guard total > 0 else { return [] }
        let grouped = Dictionary(grouping: expenses, by: \.category)
        return grouped.map { CategoryTotal(category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount },
                                           share: $0.value.reduce(0) { $0 + $1.amount } / total) }
            .sorted { $0.amount > $1.amount }
    }

    /// Spending against each category limit, most-used first.
    static func budgetProgress(budgets: [CategoryBudget], entries: [LedgerEntry]) -> [BudgetProgress] {
        let spent = Dictionary(grouping: entries.filter { $0.kind == .expense }, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        return budgets.filter { $0.limit > 0 }
            .map { BudgetProgress(category: $0.category, limit: $0.limit, spent: spent[$0.category] ?? 0) }
            .sorted { $0.fraction > $1.fraction }
    }

    /// Net worth over time rebuilt from balance snapshots, sampled weekly.
    static func wealthHistory(accounts: [Account], weeks: Int = 26, now: Date = .now,
                              calendar: Calendar = Fmt.calendar) -> [WealthPoint] {
        let histories = accounts.map { ($0, $0.sortedSnapshots) }
        let earliest = histories.compactMap { $0.1.first?.date }.min() ?? now
        let today = calendar.startOfDay(for: now)
        var dates: [Date] = []
        for w in stride(from: weeks, through: 0, by: -1) {
            guard let d = calendar.date(byAdding: .day, value: -7 * w, to: today) else { continue }
            if d >= calendar.startOfDay(for: earliest) { dates.append(d) }
        }
        if dates.last != today { dates.append(today) }

        return dates.map { date in
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            var assets = 0.0, debts = 0.0
            for (account, snapshots) in histories {
                // Latest snapshot on or before this day; the current balance for today.
                let value: Double
                if date == today {
                    value = account.balance
                } else if let snap = snapshots.last(where: { $0.date < endOfDay }) {
                    value = snap.balance
                } else {
                    continue // account didn't exist yet
                }
                if account.kind.isDebt { debts += value } else { assets += value }
            }
            return WealthPoint(date: date, assets: assets, debts: debts)
        }
    }

    /// Typical monthly surplus (income minus outgoings), averaged over complete recent periods,
    /// used to suggest a realistic extra debt payment.
    static func averageSurplus(_ totals: [PeriodTotals]) -> Double? {
        let complete = totals.dropLast().filter { $0.income > 0 }   // ignore the period in progress
        guard !complete.isEmpty else { return nil }
        return complete.reduce(0) { $0 + $1.net } / Double(complete.count)
    }
}
