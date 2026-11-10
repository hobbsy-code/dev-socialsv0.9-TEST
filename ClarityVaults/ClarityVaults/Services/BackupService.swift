import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Creates and restores backup files. The user chooses where to save them
/// (normally iCloud Drive), so the data stays in their own iCloud account.
@MainActor
enum BackupService {

    // MARK: Create

    static func makeBackup(context: ModelContext, settings: AppSettings, now: Date = .now) throws -> BackupFile {
        let accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.sortOrder)]))
        let entries = try context.fetch(FetchDescriptor<LedgerEntry>(sortBy: [SortDescriptor(\.date)]))
        let bills = try context.fetch(FetchDescriptor<Bill>(sortBy: [SortDescriptor(\.nextDueDate)]))
        let budgets = try context.fetch(FetchDescriptor<CategoryBudget>())

        return BackupFile(
            createdAt: now,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            settings: .init(paySchedule: settings.paySchedule, safeToSpendBuffer: settings.safeToSpendBuffer,
                            reminderHour: settings.reminderHour, payoffStrategy: settings.payoffStrategy.rawValue,
                            payoffExtra: settings.payoffExtra),
            accounts: accounts.map { a in
                .init(id: a.id, name: a.name, kind: a.kindRaw, balance: a.balance, apr: a.apr, minimumPayment: a.minimumPayment,
                      creditLimit: a.creditLimit, overdraftLimit: a.overdraftLimit, includeInPayoff: a.includeInPayoff,
                      startingBalance: a.startingBalance, sortOrder: a.sortOrder, createdAt: a.createdAt,
                      balanceUpdatedAt: a.balanceUpdatedAt,
                      snapshots: a.sortedSnapshots.map { .init(date: $0.date, balance: $0.balance) })
            },
            entries: entries.map { e in
                .init(id: e.id, amount: e.amount, kind: e.kindRaw, category: e.categoryRaw, note: e.note, date: e.date,
                      accountID: e.account?.id, transferAccountID: e.transferAccountID, billID: e.billID)
            },
            bills: bills.map { b in
                .init(id: b.id, name: b.name, amount: b.amount, category: b.categoryRaw, frequency: b.frequencyRaw,
                      nextDueDate: b.nextDueDate, anchorDay: b.anchorDay, reminderDaysBefore: b.reminderDaysBefore,
                      remindOnDueDay: b.remindOnDueDay, isDirectDebit: b.isDirectDebit, isIncome: b.isIncome,
                      accountID: b.accountID, isActive: b.isActive, lastPaidDate: b.lastPaidDate, notes: b.notes,
                      createdAt: b.createdAt)
            },
            budgets: budgets.map { .init(category: $0.categoryRaw, limit: $0.limit) }
        )
    }

    // MARK: Restore

    /// Replaces everything in the app with the backup's contents.
    /// A safety copy of the current data is saved first so the restore can be undone.
    static func restore(_ backup: BackupFile, context: ModelContext, settings: AppSettings) throws {
        if let current = try? makeBackup(context: context, settings: settings), !current.isEmpty {
            try? current.encoded().write(to: safetyCopyURL, options: .atomic)
        }

        DataManager.eraseAll(context)

        var accountsByID: [UUID: Account] = [:]
        for a in backup.accounts {
            let account = Account(name: a.name, kind: AccountKind(rawValue: a.kind) ?? .current, balance: a.balance,
                                  apr: a.apr, minimumPayment: a.minimumPayment, creditLimit: a.creditLimit,
                                  overdraftLimit: a.overdraftLimit, sortOrder: a.sortOrder, createdAt: a.createdAt)
            account.id = a.id
            account.kindRaw = a.kind
            account.includeInPayoff = a.includeInPayoff
            account.startingBalance = a.startingBalance
            account.balanceUpdatedAt = a.balanceUpdatedAt
            context.insert(account)
            account.snapshots = a.snapshots.map { BalanceSnapshot(date: $0.date, balance: $0.balance) }
            accountsByID[a.id] = account
        }

        for e in backup.entries {
            let entry = LedgerEntry(amount: e.amount, kind: EntryKind(rawValue: e.kind) ?? .expense,
                                    category: SpendCategory(rawValue: e.category) ?? .other, note: e.note, date: e.date,
                                    account: e.accountID.flatMap { accountsByID[$0] },
                                    transferAccountID: e.transferAccountID, billID: e.billID)
            entry.id = e.id
            context.insert(entry)
        }

        for b in backup.bills {
            let bill = Bill(name: b.name, amount: b.amount, category: SpendCategory(rawValue: b.category) ?? .other,
                            frequency: BillFrequency(rawValue: b.frequency) ?? .monthly, nextDueDate: b.nextDueDate,
                            isDirectDebit: b.isDirectDebit, isIncome: b.isIncome, accountID: b.accountID,
                            reminderDaysBefore: b.reminderDaysBefore)
            bill.id = b.id
            bill.anchorDay = b.anchorDay
            bill.remindOnDueDay = b.remindOnDueDay
            bill.isActive = b.isActive
            bill.lastPaidDate = b.lastPaidDate
            bill.notes = b.notes
            bill.createdAt = b.createdAt
            context.insert(bill)
        }

        for budget in backup.budgets {
            context.insert(CategoryBudget(category: SpendCategory(rawValue: budget.category) ?? .other, limit: budget.limit))
        }

        try context.save()

        settings.paySchedule = backup.settings.paySchedule
        settings.safeToSpendBuffer = backup.settings.safeToSpendBuffer
        settings.reminderHour = backup.settings.reminderHour
        settings.payoffStrategy = PayoffStrategy(rawValue: backup.settings.payoffStrategy) ?? .avalanche
        settings.payoffExtra = backup.settings.payoffExtra
    }

    /// Reads a file the user picked in the Files app (it may live in iCloud Drive).
    static func readBackup(at url: URL) throws -> BackupFile {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try BackupFile.read(Data(contentsOf: url))
    }

    // MARK: Undo

    /// Copy of the data as it was just before the last restore.
    nonisolated static var safetyCopyURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("before-last-restore.json")
    }

    nonisolated static var safetyCopy: BackupFile? {
        guard let data = try? Data(contentsOf: safetyCopyURL) else { return nil }
        return try? BackupFile.read(data)
    }

    static func undoLastRestore(context: ModelContext, settings: AppSettings) throws {
        guard let previous = safetyCopy else { return }
        try restore(previous, context: context, settings: settings)
        // The restore above saved the restored-over data as the new safety copy; undo is a one-step action.
        try? FileManager.default.removeItem(at: safetyCopyURL)
    }
}

extension BackupFile {
    var isEmpty: Bool { accounts.isEmpty && entries.isEmpty && bills.isEmpty }
}

/// Wraps a backup so SwiftUI's file exporter can save it to iCloud Drive / Files.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(backup: BackupFile) throws { data = try backup.encoded() }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw BackupFile.ReadError.notABackup }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
