import SwiftUI
import SwiftData

struct BillsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \Bill.nextDueDate) private var bills: [Bill]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    @State private var editing: Bill?
    @State private var showingAdd = false
    @State private var paying: Bill?

    private var active: [Bill] { bills.filter(\.isActive) }
    private var period: DateInterval { settings.currentPeriod }
    private var overdue: [Bill] { active.filter { $0.isOverdue() } }
    private var beforePayday: [Bill] { active.filter { !$0.isOverdue() && $0.nextDueDate < period.end } }
    private var later: [Bill] { active.filter { $0.nextDueDate >= period.end } }
    private var paused: [Bill] { bills.filter { !$0.isActive } }

    var body: some View {
        NavigationStack {
            List {
                if !bills.isEmpty { summary }

                if bills.isEmpty {
                    ContentUnavailableView {
                        Label("No bills yet", systemImage: "calendar.badge.clock")
                    } description: {
                        Text("Add rent, council tax, energy, subscriptions and your salary. You'll get a reminder before each bill is due.")
                    } actions: {
                        Button("Add a bill") { showingAdd = true }.buttonStyle(.borderedProminent)
                    }
                    .listRowBackground(Color.clear)
                }

                section("Needs attention", overdue)
                section("Before payday (\(Fmt.day(period.end)))", beforePayday)
                section("Later", later)
                section("Paused", paused)
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Bills & income")
            .toolbar {
                Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                    .accessibilityLabel("Add bill")
            }
            .sheet(isPresented: $showingAdd) { BillEditor(bill: nil) }
            .sheet(item: $editing) { BillEditor(bill: $0) }
            .confirmationDialog(paying.map { dialogTitle(for: $0) } ?? "", isPresented: Binding(get: { paying != nil }, set: { if !$0 { paying = nil } }),
                                titleVisibility: .visible, presenting: paying) { bill in
                Button(bill.isIncome ? "Mark received and record it" : "Mark paid and record payment") { markPaid(bill, record: true) }
                Button(bill.isIncome ? "Mark received only" : "Mark paid only") { markPaid(bill, record: false) }
                Button("Skip this one") { skip(bill) }
                Button("Cancel", role: .cancel) {}
            } message: { bill in
                Text("The next due date moves to \(Fmt.day(BillScheduler.nextDate(after: bill.nextDueDate, frequency: bill.frequency, anchorDay: bill.anchorDay))). Recording it updates your account balance.")
            }
        }
    }

    private var summary: some View {
        let outBeforePayday = (overdue + beforePayday).filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        let monthly = active.filter { !$0.isIncome }.reduce(0) { $0 + $1.monthlyEquivalent }
        return Section {
            HStack {
                StatColumn(label: "Due before payday", value: Fmt.money(outBeforePayday, pence: false))
                StatColumn(label: "Bills per month (avg)", value: Fmt.money(monthly, pence: false))
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [Bill]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { bill in
                    Button { editing = bill } label: { BillRow(bill: bill) }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading) {
                            if bill.isActive {
                                Button { paying = bill } label: {
                                    Label(bill.isIncome ? "Received" : "Paid", systemImage: "checkmark.circle")
                                }
                                .tint(Theme.positive)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(bill)
                                try? context.save()
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                        .contextMenu {
                            if bill.isActive { Button("Mark \(bill.isIncome ? "received" : "paid")…") { paying = bill } }
                            Button("Edit") { editing = bill }
                        }
                }
            }
        }
    }

    private func dialogTitle(for bill: Bill) -> String {
        "\(bill.name): \(Fmt.money(bill.amount))"
    }

    private func markPaid(_ bill: Bill, record: Bool) {
        if record, let account = accounts.first(where: { $0.id == bill.accountID }) ?? accounts.first(where: { $0.kind == .current }) {
            let entry = LedgerEntry(amount: bill.amount, kind: bill.isIncome ? .income : .expense, category: bill.category,
                                    note: bill.name, date: min(Date.now, max(bill.nextDueDate, Date.now.addingTimeInterval(-86_400 * 60))),
                                    account: account, billID: bill.id)
            context.insert(entry)
            BalanceEngine.apply(entry, accounts: accounts)
        }
        bill.markPaid()
        try? context.save()
        paying = nil
    }

    private func skip(_ bill: Bill) {
        bill.nextDueDate = BillScheduler.nextDate(after: bill.nextDueDate, frequency: bill.frequency, anchorDay: bill.anchorDay)
        try? context.save()
        paying = nil
    }
}
