import Foundation
import SwiftData
import WidgetKit

// MARK: - Widget

enum WidgetBridge {
    @MainActor
    static func update(accounts: [Account], bills: [Bill], settings: AppSettings) {
        let spending = accounts.filter { $0.kind.isSpendable }.reduce(0) { $0 + $1.balance }
        let nextPayday = settings.paySchedule.nextPayday()
        let safe = CashForecast.safeToSpend(spendingMoney: spending, flows: bills.filter(\.isActive).map { $0.asFlow(accounts: accounts) },
                                            nextPayday: nextPayday, buffer: settings.safeToSpendBuffer)
        let nextBill = bills.filter { $0.isActive && !$0.isIncome }.min { $0.nextDueDate < $1.nextDueDate }
        WidgetSnapshot(safeToSpend: safe.amount, nextPayday: nextPayday, daysUntilPayday: safe.daysUntilPayday,
                       nextBillName: nextBill?.name, nextBillAmount: nextBill?.amount, nextBillDate: nextBill?.nextDueDate,
                       updatedAt: .now).save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - CSV export

enum CSVExporter {
    static func entriesCSV(_ entries: [LedgerEntry], accounts: [Account]) -> String {
        let dateFormat = Date.ISO8601FormatStyle().year().month().day()
        var lines = ["Date,Type,Category,Description,Amount,Account,To account"]
        for e in entries.sorted(by: { $0.date < $1.date }) {
            let to = accounts.first { $0.id == e.transferAccountID }?.name ?? ""
            let signed = e.kind == .expense ? -e.amount : e.amount
            lines.append([e.date.formatted(dateFormat), e.kind.rawValue, e.category.label, e.note,
                          String(format: "%.2f", signed), e.account?.name ?? "", to].map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func writeTempFile(_ csv: String) -> URL? {
        let name = "clarity-vaults-\(Date.now.formatted(Date.ISO8601FormatStyle().year().month().day())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try csv.write(to: url, atomically: true, encoding: .utf8); return url } catch { return nil }
    }

    private static func escape(_ field: String) -> String {
        // Quote fields containing separators, and neutralise spreadsheet formula injection.
        var f = field
        if let first = f.first, "=+-@".contains(first), Double(f) == nil { f = "'" + f }
        if f.contains(",") || f.contains("\"") || f.contains("\n") {
            f = "\"" + f.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return f
    }
}

// MARK: - Data management

enum DataManager {
    static func eraseAll(_ context: ModelContext) {
        try? context.delete(model: LedgerEntry.self)
        try? context.delete(model: BalanceSnapshot.self)
        try? context.delete(model: Account.self)
        try? context.delete(model: Bill.self)
        try? context.delete(model: CategoryBudget.self)
        try? context.save()
    }
}

// MARK: - Example data (for trying the app, screenshots and social content)

enum DemoData {
    static func load(into context: ModelContext, settings: AppSettings) {
        let cal = Fmt.calendar
        let now = Date.now
        func daysAgo(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: now) ?? now }
        func daysAhead(_ d: Int) -> Date { cal.date(byAdding: .day, value: d, to: cal.startOfDay(for: now)) ?? now }

        var schedule = PaySchedule()
        schedule.frequency = .monthlyOnDay
        schedule.dayOfMonth = 28
        settings.paySchedule = schedule

        // Accounts with ~16 weeks of history, ending at today's balance.
        let specs: [(String, AccountKind, Double, Double, Double, Double, Double)] = [
            // name, kind, balance now, apr, minimum, limit, balance 16 weeks ago
            ("Everyday current", .current, 1_240, 0, 0, 0, 860),
            ("Rainy day savings", .savings, 2_500, 0, 0, 0, 1_900),
            ("Visa credit card", .creditCard, 2_850, 24.9, 85, 4_000, 3_400),
            ("Store card", .creditCard, 640, 29.9, 25, 1_200, 910),
            ("Car loan", .loan, 6_400, 7.9, 190, 0, 7_100)
        ]
        var accounts: [Account] = []
        for (i, s) in specs.enumerated() {
            let account = Account(name: s.0, kind: s.1, balance: s.6, apr: s.3, minimumPayment: s.4,
                                  creditLimit: s.1 == .creditCard ? s.5 : 0, overdraftLimit: s.1 == .current ? 500 : 0,
                                  sortOrder: i, createdAt: daysAgo(112))
            context.insert(account)
            for week in stride(from: 16, through: 0, by: -1) {
                let progress = Double(16 - week) / 16
                let wobble = week == 0 ? 0 : sin(Double(week) * 1.7) * (s.1 == .current ? 120 : 25)
                account.recordBalance(s.6 + (s.2 - s.6) * progress + wobble, on: daysAgo(week * 7))
            }
            account.startingBalance = s.1.isDebt ? s.6 : 0
            accounts.append(account)
        }
        let current = accounts[0], visa = accounts[2]

        // Recurring income and bills
        let period = schedule.period(containing: now)
        let bills: [Bill] = [
            Bill(name: "Salary", amount: 2_350, category: .salary, frequency: .monthly, nextDueDate: period.end, isIncome: true, accountID: current.id),
            Bill(name: "Rent", amount: 850, category: .housing, frequency: .monthly, nextDueDate: daysAhead(5), isDirectDebit: false, accountID: current.id, reminderDaysBefore: 3),
            Bill(name: "Council tax", amount: 165, category: .councilTax, frequency: .councilTax10, nextDueDate: daysAhead(9), isDirectDebit: true, accountID: current.id),
            Bill(name: "Energy", amount: 120, category: .utilities, frequency: .monthly, nextDueDate: daysAhead(2), isDirectDebit: true, accountID: current.id),
            Bill(name: "Mobile", amount: 22, category: .utilities, frequency: .monthly, nextDueDate: daysAhead(14), isDirectDebit: true, accountID: current.id),
            Bill(name: "Streaming", amount: 10.99, category: .subscriptions, frequency: .monthly, nextDueDate: daysAhead(11), accountID: visa.id),
            Bill(name: "Car insurance", amount: 48, category: .insurance, frequency: .monthly, nextDueDate: daysAhead(18), isDirectDebit: true, accountID: current.id),
            Bill(name: "Gym", amount: 30, category: .health, frequency: .monthly, nextDueDate: daysAhead(-1), accountID: current.id),
            Bill(name: "TV licence", amount: 174.50, category: .subscriptions, frequency: .annually, nextDueDate: daysAhead(40), accountID: current.id)
        ]
        bills.forEach(context.insert)

        // ~4 months of day-to-day entries. Deterministic so screenshots are repeatable.
        // Entries are history only; balances already reflect them via snapshots.
        var rng = SeededGenerator(seed: 42)
        let spendPattern: [(SpendCategory, ClosedRange<Double>, Int, String)] = [
            (.groceries, 18...85, 3, "Supermarket"), (.transport, 4...40, 3, "Fuel & travel"),
            (.eatingOut, 6...45, 2, "Coffee / lunch"), (.shopping, 10...70, 1, "Shopping"),
            (.entertainment, 8...35, 1, "Cinema / days out"), (.personalCare, 8...30, 1, "Haircut / toiletries")
        ]
        for day in 0..<120 {
            let date = daysAgo(day)
            for (cat, range, perWeek, note) in spendPattern where Int.random(in: 0..<7, using: &rng) < perWeek {
                context.insert(LedgerEntry(amount: (Double.random(in: range, using: &rng) * 100).rounded() / 100,
                                           kind: .expense, category: cat, note: note, date: date,
                                           account: cat == .shopping ? visa : current))
            }
        }
        for p in schedule.recentPeriods(4, endingAt: now) {
            context.insert(LedgerEntry(amount: 2_350, kind: .income, category: .salary, note: "Salary", date: p.start, account: current))
            for bill in bills where !bill.isIncome && bill.frequency != .annually {
                let day = cal.date(byAdding: .day, value: min(bill.anchorDay % 28, 25), to: p.start) ?? p.start
                if day < now {
                    context.insert(LedgerEntry(amount: bill.amount, kind: .expense, category: bill.category, note: bill.name,
                                               date: day, account: accounts.first { $0.id == bill.accountID }, billID: bill.id))
                }
            }
            context.insert(LedgerEntry(amount: 250, kind: .transfer, category: .transfer, note: "Card payment",
                                       date: cal.date(byAdding: .day, value: 2, to: p.start) ?? p.start,
                                       account: current, transferAccountID: visa.id))
        }

        // Example category limits
        context.insert(CategoryBudget(category: .groceries, limit: 320))
        context.insert(CategoryBudget(category: .eatingOut, limit: 100))
        context.insert(CategoryBudget(category: .shopping, limit: 120))
        context.insert(CategoryBudget(category: .transport, limit: 150))

        try? context.save()
    }
}

/// Small deterministic RNG (SplitMix64) so example data is the same every time.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
