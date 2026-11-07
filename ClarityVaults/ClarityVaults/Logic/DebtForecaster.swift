import Foundation

struct DebtInput: Identifiable, Equatable {
    let id: UUID
    var name: String
    var balance: Double
    /// Annual rate in percent.
    var apr: Double
    var minimumPayment: Double
}

struct PayoffPoint: Identifiable {
    let month: Int          // 0 = today
    let date: Date
    let total: Double
    let byDebt: [UUID: Double]
    var id: Int { month }
}

struct PayoffPlan {
    /// Months until every debt is cleared; nil if it never clears within the horizon.
    let months: Int?
    let totalInterest: Double
    let totalPaid: Double
    let points: [PayoffPoint]
    /// Month in which each debt reaches zero.
    let payoffMonth: [UUID: Int]
    /// The order debts are targeted with extra money.
    let order: [UUID]

    var isPaidOff: Bool { months != nil }

    func debtFreeDate(from start: Date = .now, calendar: Calendar = Fmt.calendar) -> Date? {
        guard let months else { return nil }
        return calendar.date(byAdding: .month, value: months, to: start)
    }
}

/// Month-by-month payoff simulation.
///
/// Each month: interest is added (APR / 12), every debt gets its minimum payment,
/// then anything left from the monthly budget goes to the target debt according
/// to the strategy. When a debt is cleared its minimum "rolls over" to the next
/// target because the total monthly budget stays the same.
///
/// Simplifications (shown to the user): fixed minimum payments, monthly
/// compounding, no fees or promotional 0% periods.
enum DebtForecaster {

    static let maxMonths = 600 // 50 years

    static func plan(debts input: [DebtInput],
                     monthlyBudget: Double,
                     strategy: PayoffStrategy,
                     lumpSum: Double = 0,
                     lumpSumMonth: Int = 1,
                     start: Date = .now,
                     calendar: Calendar = Fmt.calendar) -> PayoffPlan {

        let debts = input.filter { $0.balance > 0.005 }
        let order = ordered(debts, strategy: strategy).map(\.id)
        var balances = Dictionary(uniqueKeysWithValues: debts.map { ($0.id, $0.balance) })
        let byID = Dictionary(uniqueKeysWithValues: debts.map { ($0.id, $0) })

        var points = [PayoffPoint(month: 0, date: start, total: balances.values.reduce(0, +), byDebt: balances)]
        var payoffMonth: [UUID: Int] = [:]
        var totalInterest = 0.0
        var totalPaid = 0.0

        guard !debts.isEmpty else {
            return PayoffPlan(months: 0, totalInterest: 0, totalPaid: 0, points: points, payoffMonth: [:], order: [])
        }

        var month = 0
        while month < maxMonths {
            month += 1

            // 1. Interest
            for id in order where balances[id, default: 0] > 0.005 {
                let interest = balances[id, default: 0] * byID[id]!.apr / 1200
                balances[id, default: 0] += interest
                totalInterest += interest
            }

            var budget = monthlyBudget + (month == lumpSumMonth ? lumpSum : 0)

            // 2. Minimum payments
            for id in order where balances[id, default: 0] > 0.005 && budget > 0 {
                let pay = min(byID[id]!.minimumPayment, balances[id, default: 0], budget)
                balances[id, default: 0] -= pay
                budget -= pay
                totalPaid += pay
            }

            // 3. Everything left goes to targets in strategy order
            for id in order where balances[id, default: 0] > 0.005 && budget > 0 {
                let pay = min(balances[id, default: 0], budget)
                balances[id, default: 0] -= pay
                budget -= pay
                totalPaid += pay
            }

            for id in order where payoffMonth[id] == nil && balances[id, default: 0] <= 0.005 {
                balances[id] = 0
                payoffMonth[id] = month
            }

            let total = balances.values.reduce(0, +)
            let date = calendar.date(byAdding: .month, value: month, to: start) ?? start
            points.append(PayoffPoint(month: month, date: date, total: total, byDebt: balances))

            if total <= 0.005 {
                return PayoffPlan(months: month, totalInterest: totalInterest, totalPaid: totalPaid,
                                  points: points, payoffMonth: payoffMonth, order: order)
            }

            // If the total owed is higher than a year ago (and no lump sum is still to come),
            // interest outpaces payments and the debt will never clear. Stop early.
            if month >= 12 && month > lumpSumMonth && total > points[month - 12].total {
                break
            }
        }

        return PayoffPlan(months: nil, totalInterest: totalInterest, totalPaid: totalPaid,
                          points: points, payoffMonth: payoffMonth, order: order)
    }

    static func ordered(_ debts: [DebtInput], strategy: PayoffStrategy) -> [DebtInput] {
        switch strategy {
        case .avalanche:
            return debts.sorted { $0.apr != $1.apr ? $0.apr > $1.apr : $0.balance < $1.balance }
        case .snowball:
            return debts.sorted { $0.balance != $1.balance ? $0.balance < $1.balance : $0.apr > $1.apr }
        }
    }

    static func totalMinimums(_ debts: [DebtInput]) -> Double {
        debts.filter { $0.balance > 0.005 }.reduce(0) { $0 + $1.minimumPayment }
    }
}
