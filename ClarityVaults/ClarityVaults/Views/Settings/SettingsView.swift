import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var context
    @Query(sort: \LedgerEntry.date) private var entries: [LedgerEntry]
    @Query private var accounts: [Account]

    @State private var exportURL: URL?
    @State private var confirmErase = false
    @State private var confirmDemo = false

    var body: some View {
        Form {
            Section {
                PayScheduleEditor(schedule: $settings.paySchedule)
            } header: {
                Text("Payday")
            } footer: {
                let p = settings.currentPeriod
                Text("Your budget periods run payday to payday. Current period: \(Fmt.day(p.start)) to \(Fmt.day(p.end.addingTimeInterval(-1))).")
            }

            Section {
                LabeledContent("Safety buffer") {
                    AmountField(title: "0.00", value: $settings.safeToSpendBuffer).multilineTextAlignment(.trailing).frame(maxWidth: 120)
                }
            } header: {
                Text("Safe to spend")
            } footer: {
                Text("An amount kept back from your safe-to-spend figure for surprises.")
            }

            Section("Reminders") {
                Picker("Reminder time", selection: $settings.reminderHour) {
                    ForEach(6..<22) { h in Text(String(format: "%02d:00", h)).tag(h) }
                }
                Button("Notification settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                }
            }

            Section {
                Toggle("Lock with \(AppLock.biometryName)", isOn: $settings.appLockEnabled)
            } header: {
                Text("Privacy")
            } footer: {
                Text("Your data is stored on this iPhone and in any backups you choose to save. Clarity Vaults has no account, no bank login and no tracking.")
            }

            BackupSection()

            Section("Your data") {
                Button("Export activity as CSV") {
                    exportURL = CSVExporter.writeTempFile(CSVExporter.entriesCSV(entries, accounts: accounts))
                }
                if let exportURL {
                    ShareLink(item: exportURL) { Label("Share CSV file", systemImage: "square.and.arrow.up") }
                }
                Button("Load example data") { confirmDemo = true }
                Button("Erase all data", role: .destructive) { confirmErase = true }
            }

            Section("About") {
                NavigationLink("How Clarity Vaults works") { AboutView() }
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
            }

            Section { DisclaimerText() }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Erase everything?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Erase all data", role: .destructive) {
                DataManager.eraseAll(context)
                ReminderService.shared.cancelAll()
                exportURL = nil
            }
        } message: {
            Text("This deletes all accounts, bills and activity from this iPhone. It can't be undone. Back up first if you might want them again.")
        }
        .confirmationDialog("Load example data?", isPresented: $confirmDemo, titleVisibility: .visible) {
            Button("Replace my data with examples", role: .destructive) {
                DataManager.eraseAll(context)
                DemoData.load(into: context, settings: settings)
            }
        } message: {
            Text("Fills the app with realistic sample accounts, bills and spending so you can explore. This replaces anything you've entered.")
        }
    }
}

struct PayScheduleEditor: View {
    @Binding var schedule: PaySchedule

    var body: some View {
        Picker("I get paid", selection: $schedule.frequency) {
            ForEach(PayFrequency.allCases) { Text($0.label).tag($0) }
        }
        switch schedule.frequency {
        case .monthlyOnDay:
            Stepper("On the \(ordinal(schedule.dayOfMonth))", value: $schedule.dayOfMonth, in: 1...31)
            Toggle("If it's a weekend, paid the Friday before", isOn: $schedule.moveWeekendToFriday)
        case .lastWorkingDay:
            EmptyView()
        case .weekly, .fortnightly, .fourWeekly:
            DatePicker("A recent payday", selection: $schedule.anchorDate, displayedComponents: .date)
        }
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch (n % 10, n % 100) {
        case (_, 11...13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                group("Safe to spend", "Money in your current accounts and cash, minus bills due before your next payday and your safety buffer. Bills paid from a credit card aren't subtracted, because they don't leave your current account until you pay the card.")
                group("Pay periods", "Clarity Vaults budgets from payday to payday instead of by calendar month, so totals line up with how your money actually arrives.")
                group("Cash forecast", "Projects your spending money forward using only scheduled bills and income. Day-to-day spending isn't predicted. The chart shows what's already committed.")
                group("Debt payoff", "Each month interest is added (APR ÷ 12), every debt gets its minimum, and anything extra goes to one target debt: highest rate first (avalanche) or smallest balance first (snowball). When a debt is cleared its payment rolls on to the next. Real card minimums fall as balances fall, and promotional rates end, so treat dates as a guide and update balances regularly.")
                group("Your data", "Everything is stored on this device using Apple's on-device database. Nothing is sent to us or anyone else. Deleting the app deletes your data, so use Back up now in Settings (monthly, and before changing phones) to save a copy to your own iCloud Drive. Your iPhone's own iCloud Backup, if it's switched on, also includes the app's data.")
                group("Need help with debt?", "Free, impartial, confidential help is available from MoneyHelper (moneyhelper.org.uk), StepChange (stepchange.org) and National Debtline (nationaldebtline.org). If you're struggling, contact your lender early: they must treat you fairly.")
                DisclaimerText()
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("How it works")
    }

    private func group(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(Theme.ink)
            Text(body).font(.subheadline).foregroundStyle(Theme.muted)
        }
        .card()
    }
}
