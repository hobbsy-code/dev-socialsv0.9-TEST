import Foundation
import SwiftData

// All properties have defaults so the store can later be synced with
// CloudKit (iCloud) without a migration.

@Model
final class Account {
    var id: UUID = UUID()
    var name: String = ""
    var kindRaw: String = AccountKind.current.rawValue
    /// Assets: money held (negative = overdrawn). Debts: amount owed, as a positive number.
    var balance: Double = 0
    /// Annual interest rate in percent, e.g. 24.9
    var apr: Double = 0
    var minimumPayment: Double = 0
    var creditLimit: Double = 0
    var overdraftLimit: Double = 0
    var includeInPayoff: Bool = true
    /// Highest amount owed recorded, used to show payoff progress for debts.
    var startingBalance: Double = 0
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var balanceUpdatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \BalanceSnapshot.account)
    var snapshots: [BalanceSnapshot]? = []

    @Relationship(deleteRule: .nullify, inverse: \LedgerEntry.account)
    var entries: [LedgerEntry]? = []

    init(name: String, kind: AccountKind, balance: Double, apr: Double = 0,
         minimumPayment: Double = 0, creditLimit: Double = 0, overdraftLimit: Double = 0,
         sortOrder: Int = 0, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.balance = balance
        self.apr = apr
        self.minimumPayment = minimumPayment
        self.creditLimit = creditLimit
        self.overdraftLimit = overdraftLimit
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.balanceUpdatedAt = createdAt
        self.startingBalance = kind.isDebt ? balance : 0
        // Mortgages are long-term; leave them out of the payoff plan unless the user opts in.
        self.includeInPayoff = kind != .mortgage
    }

    var kind: AccountKind {
        get { AccountKind(rawValue: kindRaw) ?? .current }
        set { kindRaw = newValue.rawValue }
    }

    /// Signed contribution to net worth.
    var netValue: Double { kind.isDebt ? -balance : balance }

    /// Credit utilisation for cards (0...1+), nil if no limit set.
    /// Share of the starting debt that has been repaid (0...1), nil for assets.
    var payoffProgress: Double? {
        guard kind.isDebt, startingBalance > 0 else { return nil }
        return min(max(1 - balance / startingBalance, 0), 1)
    }

    var utilisation: Double? {
        guard kind == .creditCard, creditLimit > 0 else { return nil }
        return balance / creditLimit
    }

    /// Sets a new balance and records it in the history used for charts.
    func recordBalance(_ newBalance: Double, on date: Date = .now) {
        balance = (newBalance * 100).rounded() / 100
        if kind.isDebt { startingBalance = max(startingBalance, balance) }
        balanceUpdatedAt = date
        // Appending sets the inverse (`snapshot.account`) automatically.
        let snapshot = BalanceSnapshot(date: date, balance: balance)
        if snapshots == nil { snapshots = [] }
        snapshots?.append(snapshot)
    }

    var sortedSnapshots: [BalanceSnapshot] {
        (snapshots ?? []).sorted { $0.date < $1.date }
    }
}

@Model
final class BalanceSnapshot {
    var date: Date = Date()
    var balance: Double = 0
    var account: Account?

    init(date: Date, balance: Double) {
        self.date = date
        self.balance = balance
    }
}

@Model
final class LedgerEntry {
    var id: UUID = UUID()
    var amount: Double = 0                 // always positive
    var kindRaw: String = EntryKind.expense.rawValue
    var categoryRaw: String = SpendCategory.other.rawValue
    var note: String = ""
    var date: Date = Date()
    var account: Account?
    /// Destination account for transfers (e.g. paying a credit card from a current account).
    var transferAccountID: UUID?
    /// Set when the entry was created by marking a bill as paid.
    var billID: UUID?

    init(amount: Double, kind: EntryKind, category: SpendCategory, note: String = "",
         date: Date = .now, account: Account? = nil, transferAccountID: UUID? = nil, billID: UUID? = nil) {
        self.id = UUID()
        self.amount = amount
        self.kindRaw = kind.rawValue
        self.categoryRaw = category.rawValue
        self.note = note
        self.date = date
        self.account = account
        self.transferAccountID = transferAccountID
        self.billID = billID
    }

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var category: SpendCategory {
        get { SpendCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var displayTitle: String { note.isEmpty ? category.label : note }

    /// Signed effect on "money in vs money out" (transfers are neutral).
    var cashFlow: Double {
        switch kind {
        case .income: amount
        case .expense: -amount
        case .transfer: 0
        }
    }
}

@Model
final class Bill {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Double = 0
    var categoryRaw: String = SpendCategory.other.rawValue
    var frequencyRaw: String = BillFrequency.monthly.rawValue
    var nextDueDate: Date = Date()
    /// Day of month the bill is normally due; stops 31st drifting to 28th after February.
    var anchorDay: Int = 1
    var reminderDaysBefore: Int = 2
    var remindOnDueDay: Bool = true
    var isDirectDebit: Bool = false
    /// Recurring money in (e.g. salary, benefits) rather than a bill.
    var isIncome: Bool = false
    var accountID: UUID?
    var isActive: Bool = true
    var lastPaidDate: Date?
    var notes: String = ""
    var createdAt: Date = Date()

    init(name: String, amount: Double, category: SpendCategory, frequency: BillFrequency,
         nextDueDate: Date, isDirectDebit: Bool = false, isIncome: Bool = false,
         accountID: UUID? = nil, reminderDaysBefore: Int = 2) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.frequencyRaw = frequency.rawValue
        self.nextDueDate = Fmt.calendar.startOfDay(for: nextDueDate)
        self.anchorDay = Fmt.calendar.component(.day, from: nextDueDate)
        self.isDirectDebit = isDirectDebit
        self.isIncome = isIncome
        self.accountID = accountID
        self.reminderDaysBefore = reminderDaysBefore
    }

    var category: SpendCategory {
        get { SpendCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var frequency: BillFrequency {
        get { BillFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    var monthlyEquivalent: Double { amount * frequency.paymentsPerYear / 12 }

    func isOverdue(now: Date = .now) -> Bool {
        nextDueDate < Fmt.calendar.startOfDay(for: now)
    }

    /// Moves the due date on by one cycle after payment.
    func markPaid(on date: Date = .now) {
        lastPaidDate = date
        nextDueDate = BillScheduler.nextDate(after: nextDueDate, frequency: frequency, anchorDay: anchorDay)
    }
}

/// Optional spending limit for a category, per pay period.
@Model
final class CategoryBudget {
    var categoryRaw: String = SpendCategory.other.rawValue
    var limit: Double = 0

    init(category: SpendCategory, limit: Double) {
        self.categoryRaw = category.rawValue
        self.limit = limit
    }

    var category: SpendCategory { SpendCategory(rawValue: categoryRaw) ?? .other }
}
