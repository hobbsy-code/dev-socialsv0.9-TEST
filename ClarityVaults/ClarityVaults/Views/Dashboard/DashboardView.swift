import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Binding var selectedTab: RootView.Tab
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Bill.nextDueDate) private var bills: [Bill]
    @Query(sort: \LedgerEntry.date, order: .reverse) private var entries: [LedgerEntry]
    @Query private var budgets: [CategoryBudget]

    @State private var showingAdd = false
    @State private var showingCheckIn = false
    @State private var showingBreakdown = false

    private var period: DateInterval { settings.currentPeriod }
    private var spendingMoney: Double { accounts.filter { $0.kind.isSpendable }.reduce(0) { $0 + $1.balance } }
    private var flows: [ScheduledFlow] { bills.filter(\.isActive).map { $0.asFlow(accounts: accounts) } }
    private var safe: SafeToSpend {
        CashForecast.safeToSpend(spendingMoney: spendingMoney, flows: flows,
                                 nextPayday: period.end, buffer: settings.safeToSpendBuffer)
    }
    private var periodEntries: [LedgerEntry] { Analytics.entries(entries, in: period) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if accounts.isEmpty {
                        EmptyStateView(systemImage: "building.columns", title: "Add your first account",
                                       message: "Start with your main current account. You can add credit cards, loans and savings too. Everything stays on this iPhone.",
                                       actionTitle: "Go to Accounts") { selectedTab = .accounts }
                    } else {
                        safeToSpendCard
                        if settings.checkInDue {
                            checkInCard
                        } else if settings.backupDue && accounts.contains(where: { $0.createdAt < Date.now.addingTimeInterval(-7 * 86_400) }) {
                            backupCard
                        }
                        periodCard
                        forecastCard
                        upcomingCard
                        netPositionCard
                        debtCard
                        recentCard
                    }
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle(greeting)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                        .accessibilityLabel("Add entry")
                        .disabled(accounts.isEmpty)
                }
            }
            .sheet(isPresented: $showingAdd) { EntryEditor(entry: nil) }
            .sheet(isPresented: $showingCheckIn) { BalanceCheckInView() }
        }
    }

    private var greeting: String {
        let hour = Fmt.calendar.component(.hour, from: .now)
        return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    }

    // MARK: Cards

    private var safeToSpendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Safe to spend until payday").font(.subheadline).foregroundStyle(.white.opacity(0.75))
                Spacer()
                VaultMark(size: 28)
            }
            Text(Fmt.money(safe.amount))
                .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(safe.amount < 0 ? Color(hex: 0xF5A898) : .white)
                .contentTransition(.numericText())
            HStack(spacing: 16) {
                Label("\(safe.daysUntilPayday) day\(safe.daysUntilPayday == 1 ? "" : "s") to payday", systemImage: "calendar")
                if safe.amount > 0 && safe.daysUntilPayday > 0 {
                    Label("\(Fmt.money(safe.perDay, pence: false)) a day", systemImage: "sun.max")
                }
            }
            .font(.caption).foregroundStyle(.white.opacity(0.8))

            if showingBreakdown {
                Divider().overlay(.white.opacity(0.2))
                breakdownRow("Spending money (current & cash)", safe.spendingMoney)
                breakdownRow("Bills due before \(Fmt.day(safe.nextPayday))", -safe.billsBeforePayday)
                if safe.incomeBeforePayday > 0 { breakdownRow("Income due before payday", safe.incomeBeforePayday) }
                breakdownRow("Safety buffer", -safe.buffer)
            }
            Button(showingBreakdown ? "Hide breakdown" : "How is this worked out?") {
                withAnimation { showingBreakdown.toggle() }
            }
            .font(.caption.weight(.semibold)).foregroundStyle(Theme.gold)
        }
        .vaultCard()
    }

    private func breakdownRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text(Fmt.signedMoney(value)).font(.caption.monospacedDigit()).foregroundStyle(.white)
        }
    }

    private var checkInCard: some View {
        Button { showingCheckIn = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal").font(.title2).foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly check-in").font(.headline).foregroundStyle(Theme.ink)
                    Text("Update your balances from your banking apps. About 30 seconds.")
                        .font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var backupCard: some View {
        NavigationLink { SettingsView() } label: {
            HStack(spacing: 12) {
                Image(systemName: "icloud.and.arrow.up").font(.title2).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time for a backup").font(.headline).foregroundStyle(Theme.ink)
                    Text(settings.lastBackupAt == nil
                         ? "Save a copy to your iCloud Drive so nothing is lost if you change phones."
                         : "It's been over a month. Save a fresh copy to your iCloud Drive.")
                        .font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var periodCard: some View {
        let income = periodEntries.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }
        let out = periodEntries.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }
        let budgetRows = Analytics.budgetProgress(budgets: budgets, entries: periodEntries).prefix(4)

        return VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "This pay period", systemImage: "calendar") {
                Text("\(Fmt.day(period.start)) – \(Fmt.day(period.end.addingTimeInterval(-1)))")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            HStack {
                StatColumn(label: "Money in", value: Fmt.money(income, pence: false), tint: Theme.positive)
                StatColumn(label: "Money out", value: Fmt.money(out, pence: false))
                StatColumn(label: "Difference", value: Fmt.signedMoney(income - out), tint: income - out >= 0 ? Theme.positive : Theme.negative)
            }
            if !budgetRows.isEmpty {
                Divider()
                ForEach(Array(budgetRows)) { BudgetProgressRow(progress: $0) }
            }
        }
        .card()
    }

    private var forecastCard: some View {
        let points = CashForecast.project(startBalance: spendingMoney, flows: flows, days: 35)
        let lowest = CashForecast.lowestPoint(points)
        return VStack(alignment: .leading, spacing: 10) {
            CardHeader("Cash forecast", systemImage: "chart.line.uptrend.xyaxis")
            Text("Your spending money over the next 5 weeks, based on scheduled bills and income.")
                .font(.caption).foregroundStyle(Theme.muted)
            Chart {
                ForEach(points) { p in
                    AreaMark(x: .value("Date", p.date), y: .value("Balance", p.balance))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.25), Theme.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.stepEnd)
                    LineMark(x: .value("Date", p.date), y: .value("Balance", p.balance))
                        .foregroundStyle(Theme.accent)
                        .interpolationMethod(.stepEnd)
                }
                RuleMark(x: .value("Payday", period.end))
                    .foregroundStyle(Theme.gold)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) { Text("Payday").font(.caption2).foregroundStyle(Theme.gold) }
                if (lowest?.balance ?? 0) < 0 {
                    RuleMark(y: .value("Zero", 0)).foregroundStyle(Theme.negative.opacity(0.6))
                }
            }
            .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.compactMoney(d)) } } } }
            .frame(height: 150)
            if let lowest, lowest.balance < 0 {
                Label("Heads up: you could dip to \(Fmt.money(lowest.balance)) around \(Fmt.day(lowest.date)) before day-to-day spending.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(Theme.caution)
            } else if let lowest {
                Text("Lowest point: \(Fmt.money(lowest.balance)) on \(Fmt.day(lowest.date)), before day-to-day spending.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
        }
        .card()
    }

    private var upcomingCard: some View {
        let horizon = max(period.end, Fmt.calendar.date(byAdding: .day, value: 10, to: .now) ?? .now)
        let upcoming = bills.filter { $0.isActive && $0.nextDueDate < horizon }.prefix(6)
        return VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Coming up", systemImage: "calendar.badge.clock") {
                Button("All bills") { selectedTab = .bills }.font(.caption.weight(.semibold))
            }
            if upcoming.isEmpty {
                Text("Nothing due before payday.").font(.subheadline).foregroundStyle(Theme.muted)
            } else {
                ForEach(Array(upcoming)) { bill in BillRow(bill: bill) }
            }
        }
        .card()
    }

    private var netPositionCard: some View {
        let assets = accounts.filter { !$0.kind.isDebt }.reduce(0) { $0 + $1.balance }
        let owed = accounts.filter { $0.kind.isDebt }.reduce(0) { $0 + $1.balance }
        return NavigationLink { InsightsScreen(initialSection: .wealth) } label: {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader("Your position", systemImage: "scalemass")
                HStack {
                    StatColumn(label: "You have", value: Fmt.money(assets, pence: false), tint: Theme.positive)
                    StatColumn(label: "You owe", value: Fmt.money(owed, pence: false))
                    StatColumn(label: "Net worth", value: Fmt.money(assets - owed, pence: false))
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var debtCard: some View {
        let debts = accounts.filter { $0.kind.isDebt && $0.includeInPayoff && $0.balance > 0 }
        if !debts.isEmpty {
            let inputs = debts.map { DebtInput(id: $0.id, name: $0.name, balance: $0.balance, apr: $0.apr, minimumPayment: $0.minimumPayment) }
            let plan = DebtForecaster.plan(debts: inputs, monthlyBudget: DebtForecaster.totalMinimums(inputs) + settings.payoffExtra,
                                           strategy: settings.payoffStrategy)
            let start = debts.reduce(0) { $0 + max($1.startingBalance, $1.balance) }
            let now = debts.reduce(0) { $0 + $1.balance }
            NavigationLink { PayoffPlannerView() } label: {
                VStack(alignment: .leading, spacing: 10) {
                    CardHeader("Debt-free date", systemImage: "flag.checkered")
                    if let date = plan.debtFreeDate() {
                        Text(Fmt.monthYear(date)).font(.title2.weight(.semibold)).foregroundStyle(Theme.ink)
                        Text("Paying \(Fmt.money(settings.payoffExtra, pence: false)) a month on top of minimums (\(settings.payoffStrategy.label.lowercased())).")
                            .font(.caption).foregroundStyle(Theme.muted)
                    } else {
                        Text("Not on track yet").font(.title3.weight(.semibold)).foregroundStyle(Theme.caution)
                        Text("Current payments don't clear these debts. Open the planner to see what would.")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    if start > 0 {
                        ProgressBar(fraction: 1 - now / start, tint: Theme.gold)
                        Text("\(Int(((1 - now / start) * 100).rounded()))% of tracked debt repaid so far")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                }
                .card()
            }
            .buttonStyle(.plain)
        }
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Recent activity", systemImage: "clock.arrow.circlepath") {
                Button("See all") { selectedTab = .activity }.font(.caption.weight(.semibold))
            }
            if entries.isEmpty {
                Text("Nothing recorded yet. Tap + to add money in or out.").font(.subheadline).foregroundStyle(Theme.muted)
            } else {
                ForEach(entries.prefix(5)) { EntryRow(entry: $0, accounts: accounts) }
            }
        }
        .card()
    }
}
