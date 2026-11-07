import SwiftUI
import SwiftData

struct BillEditor: View {
    let bill: Bill?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    @State private var isIncome = false
    @State private var name = ""
    @State private var amount: Double = 0
    @State private var category: SpendCategory = .utilities
    @State private var frequency: BillFrequency = .monthly
    @State private var nextDue = Date.now
    @State private var accountID: UUID?
    @State private var isDirectDebit = false
    @State private var reminderDays = 2
    @State private var remindOnDay = true
    @State private var isActive = true
    @State private var notes = ""
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $isIncome) {
                        Text("Bill").tag(false)
                        Text("Income").tag(true)
                    }
                    .pickerStyle(.segmented)
                    TextField(isIncome ? "Name (e.g. Salary)" : "Name (e.g. Energy)", text: $name)
                    AmountField(title: "Amount", value: $amount)
                    Picker("Category", selection: $category) {
                        ForEach(isIncome ? SpendCategory.incomeCases : SpendCategory.expenseCases) {
                            Label($0.label, systemImage: $0.symbol).tag($0)
                        }
                    }
                }

                Section {
                    Picker("How often", selection: $frequency) {
                        ForEach(BillFrequency.allCases) { Text($0.label).tag($0) }
                    }
                    DatePicker(isIncome ? "Next expected" : "Next due", selection: $nextDue, displayedComponents: .date)
                    Picker(isIncome ? "Paid into" : "Paid from", selection: $accountID) {
                        Text("Not set").tag(UUID?.none)
                        ForEach(accounts) { Text($0.name).tag(Optional($0.id)) }
                    }
                    if !isIncome { Toggle("Direct Debit", isOn: $isDirectDebit) }
                } footer: {
                    if frequency == .councilTax10 {
                        Text("Most councils collect over 10 months, April to January, with nothing due in February and March.")
                    } else if !isIncome {
                        Text("Bills paid from a credit card aren't taken off your safe-to-spend figure.")
                    }
                }

                if !isIncome {
                    Section("Reminders") {
                        Stepper(reminderDays == 0 ? "No early reminder" : "Remind me \(reminderDays) day\(reminderDays == 1 ? "" : "s") before",
                                value: $reminderDays, in: 0...14)
                        Toggle("Remind me on the day", isOn: $remindOnDay)
                    }
                }

                Section {
                    TextField("Notes (account number, provider, renewal date…)", text: $notes, axis: .vertical)
                    Toggle("Active", isOn: $isActive)
                } footer: {
                    if bill != nil { Text("Turn off Active to pause a bill without deleting it.") }
                }

                if bill != nil {
                    Section {
                        Button("Delete", role: .destructive) {
                            if let bill { context.delete(bill); try? context.save() }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(bill == nil ? (isIncome ? "New income" : "New bill") : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || amount <= 0)
                }
            }
            .onAppear(perform: load)
            .onChange(of: isIncome) { _, income in
                if income && !category.isIncome { category = .salary }
                if !income && category.isIncome { category = .utilities }
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let bill else {
            accountID = accounts.first { $0.kind == .current }?.id
            return
        }
        isIncome = bill.isIncome
        name = bill.name
        amount = bill.amount
        category = bill.category
        frequency = bill.frequency
        nextDue = bill.nextDueDate
        accountID = bill.accountID
        isDirectDebit = bill.isDirectDebit
        reminderDays = bill.reminderDaysBefore
        remindOnDay = bill.remindOnDueDay
        isActive = bill.isActive
        notes = bill.notes
    }

    private func save() {
        let target: Bill
        if let bill {
            target = bill
        } else {
            target = Bill(name: name, amount: amount, category: category, frequency: frequency, nextDueDate: nextDue)
            context.insert(target)
        }
        target.isIncome = isIncome
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.amount = amount
        target.category = category
        target.frequency = frequency
        target.nextDueDate = Fmt.calendar.startOfDay(for: nextDue)
        target.anchorDay = Fmt.calendar.component(.day, from: nextDue)
        target.accountID = accountID
        target.isDirectDebit = !isIncome && isDirectDebit
        target.reminderDaysBefore = reminderDays
        target.remindOnDueDay = remindOnDay
        target.isActive = isActive
        target.notes = notes
        try? context.save()

        // Ask for notification permission the first time a bill with reminders is saved.
        if !isIncome && (reminderDays > 0 || remindOnDay) {
            Task { _ = await ReminderService.shared.requestPermission() }
        }
        dismiss()
    }
}
