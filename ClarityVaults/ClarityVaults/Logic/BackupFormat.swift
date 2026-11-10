import Foundation

/// The on-disk backup format: a single JSON file the user saves to iCloud Drive / Files.
///
/// Plain Codable structs (no SwiftData), so the format is stable, testable and
/// independent of how the app stores data internally. Bump `currentVersion`
/// when the format changes, and keep decoding older versions.
struct BackupFile: Codable, Equatable {
    static let currentVersion = 1

    var formatVersion: Int = BackupFile.currentVersion
    var createdAt: Date
    var appVersion: String
    var settings: SettingsBackup
    var accounts: [AccountBackup]
    var entries: [EntryBackup]
    var bills: [BillBackup]
    var budgets: [BudgetBackup]

    struct SettingsBackup: Codable, Equatable {
        var paySchedule: PaySchedule
        var safeToSpendBuffer: Double
        var reminderHour: Int
        var payoffStrategy: String
        var payoffExtra: Double
    }

    struct SnapshotBackup: Codable, Equatable {
        var date: Date
        var balance: Double
    }

    struct AccountBackup: Codable, Equatable {
        var id: UUID
        var name: String
        var kind: String
        var balance: Double
        var apr: Double
        var minimumPayment: Double
        var creditLimit: Double
        var overdraftLimit: Double
        var includeInPayoff: Bool
        var startingBalance: Double
        var sortOrder: Int
        var createdAt: Date
        var balanceUpdatedAt: Date
        var snapshots: [SnapshotBackup]
    }

    struct EntryBackup: Codable, Equatable {
        var id: UUID
        var amount: Double
        var kind: String
        var category: String
        var note: String
        var date: Date
        var accountID: UUID?
        var transferAccountID: UUID?
        var billID: UUID?
    }

    struct BillBackup: Codable, Equatable {
        var id: UUID
        var name: String
        var amount: Double
        var category: String
        var frequency: String
        var nextDueDate: Date
        var anchorDay: Int
        var reminderDaysBefore: Int
        var remindOnDueDay: Bool
        var isDirectDebit: Bool
        var isIncome: Bool
        var accountID: UUID?
        var isActive: Bool
        var lastPaidDate: Date?
        var notes: String
        var createdAt: Date
    }

    struct BudgetBackup: Codable, Equatable {
        var category: String
        var limit: Double
    }

    // MARK: Encoding

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func encoded() throws -> Data { try Self.encoder().encode(self) }

    enum ReadError: LocalizedError, Equatable {
        case notABackup
        case newerVersion(Int)

        var errorDescription: String? {
            switch self {
            case .notABackup:
                "This file isn't a Clarity Vaults backup, or it's damaged."
            case .newerVersion(let v):
                "This backup was made by a newer version of Clarity Vaults (format \(v)). Update the app from the App Store, then try again."
            }
        }
    }

    /// Reads a backup, checking it's ours and a version we understand.
    static func read(_ data: Data) throws -> BackupFile {
        struct Header: Decodable { var formatVersion: Int? }
        guard let header = try? decoder().decode(Header.self, from: data), let version = header.formatVersion else {
            throw ReadError.notABackup
        }
        guard version <= currentVersion else { throw ReadError.newerVersion(version) }
        do {
            return try decoder().decode(BackupFile.self, from: data)
        } catch {
            throw ReadError.notABackup
        }
    }

    // MARK: Summary shown before restoring

    var summary: String {
        let parts = [
            "\(accounts.count) account\(accounts.count == 1 ? "" : "s")",
            "\(bills.count) bill\(bills.count == 1 ? "" : "s")",
            "\(entries.count) entr\(entries.count == 1 ? "y" : "ies")"
        ]
        return parts.joined(separator: ", ")
    }

    var suggestedFilename: String {
        "Clarity Vaults backup \(createdAt.formatted(Date.ISO8601FormatStyle().year().month().day()))"
    }
}
