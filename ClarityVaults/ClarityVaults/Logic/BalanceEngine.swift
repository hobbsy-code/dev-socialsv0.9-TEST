import Foundation

/// Keeps account balances in step with entries.
///
/// Sign rules:
/// - Assets (current, savings, cash): money in increases the balance.
/// - Debts (credit card, loan, mortgage): balance is the amount owed, so spending
///   on a card increases it and paying it off decreases it.
enum BalanceEngine {

    /// Change in an account's stored balance when money flows *out* of it.
    static func outflowDelta(_ amount: Double, kind: AccountKind) -> Double { kind.isDebt ? amount : -amount }
    /// Change in an account's stored balance when money flows *into* it.
    static func inflowDelta(_ amount: Double, kind: AccountKind) -> Double { kind.isDebt ? -amount : amount }

    struct Effect: Equatable {
        var accountID: UUID
        var delta: Double
    }

    /// Pure calculation of what an entry does to balances.
    static func effects(amount: Double, kind: EntryKind, sourceID: UUID?, sourceKind: AccountKind?,
                        destinationID: UUID?, destinationKind: AccountKind?) -> [Effect] {
        var result: [Effect] = []
        switch kind {
        case .income:
            if let sourceID, let sourceKind { result.append(Effect(accountID: sourceID, delta: inflowDelta(amount, kind: sourceKind))) }
        case .expense:
            if let sourceID, let sourceKind { result.append(Effect(accountID: sourceID, delta: outflowDelta(amount, kind: sourceKind))) }
        case .transfer:
            if let sourceID, let sourceKind { result.append(Effect(accountID: sourceID, delta: outflowDelta(amount, kind: sourceKind))) }
            if let destinationID, let destinationKind { result.append(Effect(accountID: destinationID, delta: inflowDelta(amount, kind: destinationKind))) }
        }
        return result
    }

    /// Applies (or reverses) an entry's effect on the given accounts.
    static func apply(_ entry: LedgerEntry, accounts: [Account], reverse: Bool = false, on date: Date = .now) {
        let destination = accounts.first { $0.id == entry.transferAccountID }
        let list = effects(amount: entry.amount, kind: entry.kind,
                           sourceID: entry.account?.id, sourceKind: entry.account?.kind,
                           destinationID: destination?.id, destinationKind: destination?.kind)
        for effect in list {
            guard let account = accounts.first(where: { $0.id == effect.accountID }) else { continue }
            account.recordBalance(account.balance + (reverse ? -effect.delta : effect.delta), on: date)
        }
    }
}
