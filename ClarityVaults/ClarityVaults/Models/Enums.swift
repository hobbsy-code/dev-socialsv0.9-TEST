import SwiftUI

// Enums are stored on models as raw strings (SwiftData predicates cannot
// filter on enum values reliably), with computed accessors on each model.

enum AccountKind: String, Codable, CaseIterable, Identifiable {
    case current, savings, cash, creditCard, loan, mortgage

    var id: String { rawValue }

    var label: String {
        switch self {
        case .current: "Current account"
        case .savings: "Savings"
        case .cash: "Cash"
        case .creditCard: "Credit card"
        case .loan: "Loan"
        case .mortgage: "Mortgage"
        }
    }

    var symbol: String {
        switch self {
        case .current: "building.columns"
        case .savings: "lock.shield"
        case .cash: "banknote"
        case .creditCard: "creditcard"
        case .loan: "doc.text"
        case .mortgage: "house"
        }
    }

    /// Debts store the amount owed as a positive balance.
    var isDebt: Bool { self == .creditCard || self == .loan || self == .mortgage }

    /// Money you can spend day to day (used for "safe to spend").
    var isSpendable: Bool { self == .current || self == .cash }

    var balanceLabel: String { isDebt ? "Amount owed" : "Balance" }
}

enum EntryKind: String, Codable, CaseIterable, Identifiable {
    case expense, income, transfer
    var id: String { rawValue }
    var label: String {
        switch self {
        case .expense: "Out"
        case .income: "In"
        case .transfer: "Transfer"
        }
    }
}

enum SpendCategory: String, Codable, CaseIterable, Identifiable {
    // Income
    case salary, benefits, sideIncome, refund, otherIncome
    // Outgoings
    case housing, councilTax, utilities, groceries, transport, eatingOut, shopping,
         subscriptions, insurance, debtRepayment, health, childcare, personalCare,
         entertainment, gifts, savings, other
    // Transfers between your own accounts
    case transfer

    var id: String { rawValue }

    var isIncome: Bool { [.salary, .benefits, .sideIncome, .refund, .otherIncome].contains(self) }

    static var incomeCases: [SpendCategory] { allCases.filter { $0.isIncome } }
    static var expenseCases: [SpendCategory] { allCases.filter { !$0.isIncome && $0 != .transfer } }

    var label: String {
        switch self {
        case .salary: "Salary"
        case .benefits: "Benefits"
        case .sideIncome: "Side income"
        case .refund: "Refund"
        case .otherIncome: "Other income"
        case .housing: "Rent / mortgage"
        case .councilTax: "Council tax"
        case .utilities: "Energy & water"
        case .groceries: "Groceries"
        case .transport: "Transport"
        case .eatingOut: "Eating out"
        case .shopping: "Shopping"
        case .subscriptions: "Subscriptions"
        case .insurance: "Insurance"
        case .debtRepayment: "Debt repayment"
        case .health: "Health"
        case .childcare: "Childcare"
        case .personalCare: "Personal care"
        case .entertainment: "Entertainment"
        case .gifts: "Gifts"
        case .savings: "Savings"
        case .other: "Other"
        case .transfer: "Transfer"
        }
    }

    var symbol: String {
        switch self {
        case .salary: "briefcase"
        case .benefits: "hand.raised"
        case .sideIncome: "sparkles"
        case .refund: "arrow.uturn.backward"
        case .otherIncome: "plus.circle"
        case .housing: "house"
        case .councilTax: "building.2"
        case .utilities: "bolt"
        case .groceries: "cart"
        case .transport: "car"
        case .eatingOut: "fork.knife"
        case .shopping: "bag"
        case .subscriptions: "play.rectangle"
        case .insurance: "shield"
        case .debtRepayment: "creditcard"
        case .health: "heart"
        case .childcare: "figure.and.child.holdinghands"
        case .personalCare: "comb"
        case .entertainment: "ticket"
        case .gifts: "gift"
        case .savings: "lock.shield"
        case .other: "ellipsis.circle"
        case .transfer: "arrow.left.arrow.right"
        }
    }

    /// Each outgoing category has its own colour so charts never show two categories in the same hue.
    var colour: Color { Color(hex: colourHex) }

    var colourHex: UInt32 {
        switch self {
        case .salary: 0x2E7D4F
        case .benefits: 0x1F8A84
        case .sideIncome: 0xD9AE5B
        case .refund: 0x3E9CC9
        case .otherIncome: 0x6AA84F
        case .housing: 0x8E6CC4
        case .councilTax: 0xE08A3C
        case .utilities: 0x3E9CC9
        case .groceries: 0x6AA84F
        case .transport: 0x5B6B82
        case .eatingOut: 0x1F8A84
        case .shopping: 0xD9AE5B
        case .subscriptions: 0x4C6FBF
        case .insurance: 0xC2637A
        case .debtRepayment: 0xA9742A
        case .health: 0xD16BA5
        case .childcare: 0x7FB3D5
        case .personalCare: 0xB39DDB
        case .entertainment: 0x9C8A6E
        case .gifts: 0xEF8E7A
        case .savings: 0x0E5E5A
        case .other: 0xA0AAB8
        case .transfer: 0x5B6B82
        }
    }
}

enum BillFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly, fortnightly, fourWeekly, monthly, quarterly, annually, councilTax10

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly: "Weekly"
        case .fortnightly: "Fortnightly"
        case .fourWeekly: "Every 4 weeks"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .annually: "Yearly"
        case .councilTax10: "10 monthly (Apr–Jan)"
        }
    }

    /// Approximate number of payments a year, for monthly-equivalent totals.
    var paymentsPerYear: Double {
        switch self {
        case .weekly: 52
        case .fortnightly: 26
        case .fourWeekly: 13
        case .monthly: 12
        case .quarterly: 4
        case .annually: 1
        case .councilTax10: 10
        }
    }
}

enum PayFrequency: String, Codable, CaseIterable, Identifiable {
    case monthlyOnDay, lastWorkingDay, weekly, fortnightly, fourWeekly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .monthlyOnDay: "Monthly on a set date"
        case .lastWorkingDay: "Last working day of the month"
        case .weekly: "Weekly"
        case .fortnightly: "Fortnightly"
        case .fourWeekly: "Every 4 weeks"
        }
    }

    var usesAnchorDate: Bool { self == .weekly || self == .fortnightly || self == .fourWeekly }
}

enum PayoffStrategy: String, Codable, CaseIterable, Identifiable {
    case avalanche, snowball
    var id: String { rawValue }
    var label: String { self == .avalanche ? "Avalanche" : "Snowball" }
    var explanation: String {
        switch self {
        case .avalanche: "Highest interest rate first. Usually costs the least overall."
        case .snowball: "Smallest balance first. Quicker wins to keep you motivated."
        }
    }
}
