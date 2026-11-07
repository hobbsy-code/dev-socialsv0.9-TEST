import SwiftUI
import SwiftData
import Charts

struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @State private var showingAdd = false
    @State private var showingCheckIn = false

    private var spending: [Account] { accounts.filter { $0.kind.isSpendable } }
    private var savings: [Account] { accounts.filter { $0.kind == .savings } }
    private var debts: [Account] { accounts.filter { $0.kind.isDebt } }

    var body: some View {
        NavigationStack {
            List {
                if accounts.isEmpty {
                    ContentUnavailableView {
                        Label("No accounts yet", systemImage: "building.columns")
                    } description: {
                        Text("Add your current account, savings, credit cards and loans. Type in the balance from your banking app. No bank login needed.")
                    } actions: {
                        Button("Add an account") { showingAdd = true }.buttonStyle(.borderedProminent)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        Button { showingCheckIn = true } label: {
                            Label("Update all balances", systemImage: "checkmark.seal")
                        }
                        if !debts.filter({ $0.balance > 0 }).isEmpty {
                            NavigationLink { PayoffPlannerView() } label: {
                                Label("Debt payoff planner", systemImage: "flag.checkered")
                            }
                        }
                    }
                }
                group("Spending money", spending)
                group("Savings", savings)
                group("What you owe", debts)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Accounts")
            .toolbar {
                Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                    .accessibilityLabel("Add account")
            }
            .sheet(isPresented: $showingAdd) { AccountEditor(account: nil) }
            .sheet(isPresented: $showingCheckIn) { BalanceCheckInView() }
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ items: [Account]) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { account in
                    NavigationLink { AccountDetailView(account: account) } label: { AccountRow(account: account) }
                }
                .onMove { from, to in move(items, from: from, to: to) }
            } header: {
                HStack {
                    Text(title)
                    Spacer()
                    Text(Fmt.money(items.reduce(0) { $0 + $1.balance }, pence: false)).monospacedDigit()
                }
            }
        }
    }

    private func move(_ items: [Account], from: IndexSet, to: Int) {
        var reordered = items
        reordered.move(fromOffsets: from, toOffset: to)
        let base = items.map(\.sortOrder).min() ?? 0
        for (i, account) in reordered.enumerated() { account.sortOrder = base + i }
        try? context.save()
    }
}

struct AccountRow: View {
    let account: Account
    var body: some View {
        HStack(spacing: 12) {
            AccountIcon(kind: account.kind)
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name).foregroundStyle(Theme.ink)
                Text(detail).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.money(account.balance)).font(.body.monospacedDigit())
                    .foregroundStyle(!account.kind.isDebt && account.balance < 0 ? Theme.negative : Theme.ink)
                if let progress = account.payoffProgress, progress > 0 {
                    Text("\(Int((progress * 100).rounded()))% repaid").font(.caption2).foregroundStyle(Theme.gold)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        var parts = [account.kind.label]
        if account.kind.isDebt && account.apr > 0 { parts.append(String(format: "%.1f%% APR", account.apr)) }
        if let u = account.utilisation { parts.append("\(Int((u * 100).rounded()))% of limit") }
        parts.append("updated \(Fmt.relativeDays(to: account.balanceUpdatedAt).replacingOccurrences(of: " overdue", with: " ago"))")
        return parts.joined(separator: " · ")
    }
}

struct AccountDetailView: View {
    @Bindable var account: Account
    @Query(sort: \LedgerEntry.date, order: .reverse) private var allEntries: [LedgerEntry]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @State private var editing = false
    @State private var updatingBalance = false

    private var entries: [LedgerEntry] {
        allEntries.filter { $0.account?.id == account.id || $0.transferAccountID == account.id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(account.kind.balanceLabel).font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    Text(Fmt.money(account.balance)).font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                    HStack(spacing: 14) {
                        if account.kind.isDebt && account.apr > 0 { Label(String(format: "%.1f%% APR", account.apr), systemImage: "percent") }
                        if account.minimumPayment > 0 { Label("Min \(Fmt.money(account.minimumPayment))", systemImage: "calendar") }
                        if account.creditLimit > 0 { Label("Limit \(Fmt.money(account.creditLimit, pence: false))", systemImage: "gauge") }
                    }
                    .font(.caption).foregroundStyle(.white.opacity(0.8))
                    Button("Update balance") { updatingBalance = true }
                        .buttonStyle(.borderedProminent).tint(Theme.gold).padding(.top, 4)
                }
                .vaultCard()

                if let progress = account.payoffProgress {
                    VStack(alignment: .leading, spacing: 8) {
                        CardHeader("Payoff progress", systemImage: "flag.checkered")
                        ProgressBar(fraction: progress, tint: Theme.gold, height: 10)
                        Text("\(Fmt.money(account.startingBalance - account.balance, pence: false)) repaid of \(Fmt.money(account.startingBalance, pence: false))")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    .card()
                }

                if account.sortedSnapshots.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        CardHeader("Balance history", systemImage: "chart.xyaxis.line")
                        Chart(account.sortedSnapshots) { snap in
                            LineMark(x: .value("Date", snap.date), y: .value("Balance", snap.balance))
                                .foregroundStyle(account.kind.isDebt ? Theme.gold : Theme.accent)
                                .interpolationMethod(.monotone)
                        }
                        .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.compactMoney(d)) } } } }
                        .frame(height: 180)
                    }
                    .card()
                }

                VStack(alignment: .leading, spacing: 12) {
                    CardHeader("Activity", systemImage: "list.bullet")
                    if entries.isEmpty {
                        Text("No entries for this account yet.").font(.subheadline).foregroundStyle(Theme.muted)
                    } else {
                        ForEach(entries.prefix(30)) { EntryRow(entry: $0, accounts: accounts) }
                    }
                }
                .card()
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit") { editing = true } }
        .sheet(isPresented: $editing) { AccountEditor(account: account) }
        .sheet(isPresented: $updatingBalance) { BalanceCheckInView(only: account) }
    }
}
