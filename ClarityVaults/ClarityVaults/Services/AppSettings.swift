import Foundation
import SwiftUI

/// User preferences, persisted in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published var hasOnboarded: Bool { didSet { defaults.set(hasOnboarded, forKey: Keys.onboarded) } }
    @Published var appLockEnabled: Bool { didSet { defaults.set(appLockEnabled, forKey: Keys.appLock) } }
    @Published var safeToSpendBuffer: Double { didSet { defaults.set(safeToSpendBuffer, forKey: Keys.buffer) } }
    @Published var reminderHour: Int { didSet { defaults.set(reminderHour, forKey: Keys.reminderHour) } }
    @Published var payoffStrategy: PayoffStrategy { didSet { defaults.set(payoffStrategy.rawValue, forKey: Keys.strategy) } }
    @Published var payoffExtra: Double { didSet { defaults.set(payoffExtra, forKey: Keys.extra) } }
    @Published var lastCheckIn: Date? { didSet { defaults.set(lastCheckIn, forKey: Keys.checkIn) } }
    @Published var lastBackupAt: Date? { didSet { defaults.set(lastBackupAt, forKey: Keys.backup) } }
    @Published var paySchedule: PaySchedule {
        didSet { if let data = try? JSONEncoder().encode(paySchedule) { defaults.set(data, forKey: Keys.pay) } }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasOnboarded = defaults.bool(forKey: Keys.onboarded)
        appLockEnabled = defaults.bool(forKey: Keys.appLock)
        safeToSpendBuffer = defaults.object(forKey: Keys.buffer) as? Double ?? 50
        reminderHour = defaults.object(forKey: Keys.reminderHour) as? Int ?? 9
        payoffStrategy = PayoffStrategy(rawValue: defaults.string(forKey: Keys.strategy) ?? "") ?? .avalanche
        payoffExtra = defaults.object(forKey: Keys.extra) as? Double ?? 50
        lastCheckIn = defaults.object(forKey: Keys.checkIn) as? Date
        lastBackupAt = defaults.object(forKey: Keys.backup) as? Date
        if let data = defaults.data(forKey: Keys.pay), let schedule = try? JSONDecoder().decode(PaySchedule.self, from: data) {
            paySchedule = schedule
        } else {
            paySchedule = PaySchedule()
        }
    }

    var currentPeriod: DateInterval { paySchedule.period(containing: .now) }

    /// Nudge for the weekly balance check-in.
    var checkInDue: Bool {
        guard let lastCheckIn else { return true }
        return Date.now.timeIntervalSince(lastCheckIn) > 6 * 24 * 3600
    }

    /// Gentle nudge once a month (only once there's something worth backing up).
    var backupDue: Bool {
        guard let lastBackupAt else { return true }
        return Date.now.timeIntervalSince(lastBackupAt) > 30 * 24 * 3600
    }

    enum Keys {
        static let onboarded = "hasOnboarded"
        static let appLock = "appLockEnabled"
        static let buffer = "safeToSpendBuffer"
        static let reminderHour = "reminderHour"
        static let strategy = "payoffStrategy"
        static let extra = "payoffExtra"
        static let checkIn = "lastCheckIn"
        static let backup = "lastBackupAt"
        static let pay = "paySchedule"
    }
}
