import SwiftUI
import SwiftData

/// Add or edit money in / out / transfers. Designed for speed:
/// amount is focused on open, the last-used account is remembered,
/// and a category is one tap.
struct EntryEditor: View {
    let entry: LedgerEntry?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @AppStorage("lastAccountID") private var lastAccountID = ""

    @State private var kind: EntryKind = .expense
    @State private var amount: Double = 0
    @State private var category: SpendCategory = .groceries
    @State private var accountID: UUID?
    @State private var toAccountID: UUID?
    @State private var date = Date.now
    @State private var note = ""
    @State private var loaded = false

    private var categories: [SpendCategory] {
        kind == .income ? SpendCategory.incomeCases : SpendCategory.expenseCases
    }

    private var canSave: Bool {
        amount > 0 && accountID != nil && (kind != .transfer || (toAccountID != nil && toAccountID != accountID))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(EntryKind.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    AmountField(title: "0.00", value: $amount, large: true)
                        .padding(.vertical, 4)
                }

                if kind != .transfer {
                    Section("Category") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
                            ForEach(categories) { cat in
                                Button { category = cat } label: {
                                    VStack(spacing: 4) {
                                        CategoryIcon(category: cat, size: 40)
                                            .overlay(Circle().stroke(category == cat ? cat.colour : .clear, lineWidth: 2))
                                        Text(cat.label).font(.caption2).foregroundStyle(Theme.ink)
                                            .lineLimit(2).multilineTextAlignment(.center)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(category == cat ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Picker(kind == .transfer ? "From" : kind == .income ? "Into" : "Paid from", selection: $accountID) {
                        Text("Choose").tag(UUID?.none)
                        ForEach(accounts) { Text($0.name).tag(Optional($0.id)) }
                    }
                    if kind == .transfer {
                        Picker("To", selection: $toAccountID) {
                            Text("Choose").tag(UUID?.none)
                            ForEach(accounts.filter { $0.id != accountID }) { Text($0.name).tag(Optional($0.id)) }
                        }
                    }
                    DatePicker("Date", selection: $date, in: ...Date.now.addingTimeInterval(86_400 * 365), displayedComponents: .date)
                    TextField(kind == .transfer ? "Note (e.g. credit card payment)" : "Note (optional)", text: $note)
                } footer: {
                    if kind == .transfer {
                        Text("Use a transfer to pay a credit card or loan, or move money to savings. It updates both balances and isn't counted as spending.")
                    }
                }

                if entry != nil {
                    Section {
                        Button("Delete entry", role: .destructive) { deleteEntry() }
                    }
                }
            }
            .navigationTitle(entry == nil ? "New entry" : "Edit entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(!canSave) }
            }
            .onAppear(perform: load)
            .onChange(of: kind) { _, newKind in
                if newKind == .income && !category.isIncome { category = .salary }
                if newKind == .expense && category.isIncome { category = .groceries }
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let entry {
            kind = entry.kind
            amount = entry.amount
            category = entry.category
            accountID = entry.account?.id
            toAccountID = entry.transferAccountID
            date = entry.date
            note = entry.note
        } else {
            let remembered = accounts.first { $0.id.uuidString == lastAccountID }
            accountID = (remembered ?? accounts.first { $0.kind == .current } ?? accounts.first)?.id
        }
    }

    private func save() {
        let account = accounts.first { $0.id == accountID }
        let resolvedCategory: SpendCategory = kind == .transfer ? .transfer : category

        if let entry {
            BalanceEngine.apply(entry, accounts: accounts, reverse: true)   // undo the old effect
            entry.amount = amount
            entry.kind = kind
            entry.category = resolvedCategory
            entry.account = account
            entry.transferAccountID = kind == .transfer ? toAccountID : nil
            entry.date = date
            entry.note = note
            BalanceEngine.apply(entry, accounts: accounts)
        } else {
            let new = LedgerEntry(amount: amount, kind: kind, category: resolvedCategory, note: note, date: date,
                                  account: account, transferAccountID: kind == .transfer ? toAccountID : nil)
            context.insert(new)
            BalanceEngine.apply(new, accounts: accounts)
        }
        if let accountID { lastAccountID = accountID.uuidString }
        try? context.save()
        dismiss()
    }

    private func deleteEntry() {
        guard let entry else { return }
        BalanceEngine.apply(entry, accounts: accounts, reverse: true)
        context.delete(entry)
        try? context.save()
        dismiss()
    }
}
