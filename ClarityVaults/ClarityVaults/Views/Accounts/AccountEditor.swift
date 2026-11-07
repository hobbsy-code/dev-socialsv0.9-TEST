import SwiftUI
import SwiftData

struct AccountEditor: View {
    let account: Account?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    @State private var name = ""
    @State private var kind: AccountKind = .current
    @State private var balance: Double = 0
    @State private var isOverdrawn = false
    @State private var apr: Double = 0
    @State private var minimum: Double = 0
    @State private var limit: Double = 0
    @State private var overdraft: Double = 0
    @State private var includeInPayoff = true
    @State private var loaded = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Barclays current)", text: $name)
                    Picker("Type", selection: $kind) {
                        ForEach(AccountKind.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                    }
                }

                Section {
                    AmountField(title: kind.balanceLabel, value: $balance)
                    if kind == .current { Toggle("Overdrawn", isOn: $isOverdrawn) }
                } header: {
                    Text(kind.balanceLabel)
                } footer: {
                    Text(kind.isDebt ? "Enter what you owe today as a positive number, from your statement or banking app."
                                     : "Copy today's balance from your banking app.")
                }

                if kind.isDebt {
                    Section {
                        LabeledContent("Interest rate (APR %)") {
                            TextField("0.0", value: $apr, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Monthly minimum") { AmountField(title: "0.00", value: $minimum).multilineTextAlignment(.trailing) }
                        if kind == .creditCard {
                            LabeledContent("Credit limit") { AmountField(title: "0.00", value: $limit).multilineTextAlignment(.trailing) }
                        }
                        Toggle("Include in payoff plan", isOn: $includeInPayoff)
                    } header: {
                        Text("Repayment details")
                    } footer: {
                        Text("Find the APR and minimum payment on your latest statement. Card minimums change as the balance falls; update them now and then for the most accurate forecast.")
                    }
                }

                if kind == .current {
                    Section("Arranged overdraft") {
                        LabeledContent("Overdraft limit") { AmountField(title: "0.00", value: $overdraft).multilineTextAlignment(.trailing) }
                    }
                }

                if account != nil {
                    Section {
                        Button("Delete account", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(account == nil ? "New account" : "Edit account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete \(name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete account and its history", role: .destructive) {
                    if let account { context.delete(account); try? context.save() }
                    dismiss()
                }
            } message: {
                Text("Entries stay in Activity but are no longer linked to an account.")
            }
            .onAppear(perform: load)
            .onChange(of: kind) { _, newKind in
                // Mortgages are long-term, so leave them out of the payoff plan by default.
                if account == nil { includeInPayoff = newKind != .mortgage }
            }
        }
    }

    private func load() {
        guard !loaded, let account else { loaded = true; return }
        loaded = true
        name = account.name
        kind = account.kind
        balance = abs(account.balance)
        isOverdrawn = !account.kind.isDebt && account.balance < 0
        apr = account.apr
        minimum = account.minimumPayment
        limit = account.creditLimit
        overdraft = account.overdraftLimit
        includeInPayoff = account.includeInPayoff
    }

    private func save() {
        let signedBalance = (kind == .current && isOverdrawn) ? -abs(balance) : abs(balance)
        let target: Account
        if let account {
            target = account
            target.kind = kind
            if abs(target.balance - signedBalance) > 0.004 { target.recordBalance(signedBalance) }
        } else {
            target = Account(name: name, kind: kind, balance: 0, sortOrder: (accounts.map(\.sortOrder).max() ?? -1) + 1)
            context.insert(target)
            target.recordBalance(signedBalance)
            target.startingBalance = kind.isDebt ? signedBalance : 0
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.apr = kind.isDebt ? apr : 0
        target.minimumPayment = kind.isDebt ? minimum : 0
        target.creditLimit = kind == .creditCard ? limit : 0
        target.overdraftLimit = kind == .current ? overdraft : 0
        target.includeInPayoff = kind.isDebt && includeInPayoff
        try? context.save()
        dismiss()
    }
}

/// Weekly check-in: type in each balance from your banking apps.
/// Much faster than logging every transaction, and keeps the forecasts honest.
struct BalanceCheckInView: View {
    var only: Account? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \Account.sortOrder) private var allAccounts: [Account]
    @State private var values: [UUID: Double] = [:]

    private var accounts: [Account] { only.map { [$0] } ?? allAccounts }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(accounts) { account in
                        HStack {
                            AccountIcon(kind: account.kind, size: 30)
                            VStack(alignment: .leading) {
                                Text(account.name)
                                Text("Was \(Fmt.money(account.balance))").font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            AmountField(title: "0.00", value: Binding(
                                get: { values[account.id] ?? account.balance },
                                set: { values[account.id] = $0 }))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 130)
                        }
                    }
                } footer: {
                    Text("Overdrawn current account? Enter a minus sign, e.g. -120. For cards and loans, enter what you owe.")
                }
            }
            .navigationTitle(only == nil ? "Weekly check-in" : "Update balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
        }
    }

    private func save() {
        for account in accounts {
            // Always record a snapshot on check-in so the history chart shows the confirmation.
            account.recordBalance(values[account.id] ?? account.balance)
        }
        try? context.save()
        if only == nil { settings.lastCheckIn = .now }
        dismiss()
    }
}
