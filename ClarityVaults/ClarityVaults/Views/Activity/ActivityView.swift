import SwiftUI
import SwiftData

struct ActivityView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LedgerEntry.date, order: .reverse) private var entries: [LedgerEntry]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    @State private var filter: Filter = .all
    @State private var search = ""
    @State private var editing: LedgerEntry?
    @State private var showingAdd = false

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", out = "Out", income = "In", transfers = "Transfers"
        var id: String { rawValue }
    }

    private var filtered: [LedgerEntry] {
        entries.filter { e in
            let kindMatch: Bool = switch filter {
            case .all: true
            case .out: e.kind == .expense
            case .income: e.kind == .income
            case .transfers: e.kind == .transfer
            }
            guard kindMatch else { return false }
            guard !search.isEmpty else { return true }
            return e.note.localizedCaseInsensitiveContains(search) || e.category.label.localizedCaseInsensitiveContains(search)
                || (e.account?.name.localizedCaseInsensitiveContains(search) ?? false)
        }
    }

    private struct DayGroup: Identifiable {
        let day: Date
        let items: [LedgerEntry]
        var id: Date { day }
    }

    private var grouped: [DayGroup] {
        Dictionary(grouping: filtered) { Fmt.calendar.startOfDay(for: $0.date) }
            .map { DayGroup(day: $0.key, items: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Show", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if filtered.isEmpty {
                    ContentUnavailableView(search.isEmpty ? "No activity yet" : "No matches",
                                           systemImage: "list.bullet.rectangle",
                                           description: Text(search.isEmpty ? "Tap + to record money in or out. It takes a few seconds." : "Try a different search."))
                        .listRowBackground(Color.clear)
                }

                ForEach(grouped) { group in
                    Section {
                        ForEach(group.items) { entry in
                            Button { editing = entry } label: { EntryRow(entry: entry, accounts: accounts) }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { delete(entry) } label: { Label("Delete", systemImage: "trash") }
                                }
                                .swipeActions(edge: .leading) {
                                    Button { repeatToday(entry) } label: { Label("Repeat today", systemImage: "arrow.clockwise") }
                                        .tint(Theme.accent)
                                }
                        }
                    } header: {
                        HStack {
                            Text(Fmt.dayWithWeekday(group.day))
                            Spacer()
                            let net = group.items.reduce(0) { $0 + $1.cashFlow }
                            if net != 0 { Text(Fmt.signedMoney(net)).monospacedDigit() }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("Activity")
            .searchable(text: $search, prompt: "Search notes, categories, accounts")
            .toolbar {
                Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                    .accessibilityLabel("Add entry")
                    .disabled(accounts.isEmpty)
            }
            .sheet(isPresented: $showingAdd) { EntryEditor(entry: nil) }
            .sheet(item: $editing) { EntryEditor(entry: $0) }
        }
    }

    private func delete(_ entry: LedgerEntry) {
        BalanceEngine.apply(entry, accounts: accounts, reverse: true)
        context.delete(entry)
        try? context.save()
    }

    private func repeatToday(_ entry: LedgerEntry) {
        let copy = LedgerEntry(amount: entry.amount, kind: entry.kind, category: entry.category, note: entry.note,
                               date: .now, account: entry.account, transferAccountID: entry.transferAccountID)
        context.insert(copy)
        BalanceEngine.apply(copy, accounts: accounts)
        try? context.save()
    }
}

struct EntryRow: View {
    let entry: LedgerEntry
    let accounts: [Account]

    private var subtitle: String {
        if entry.kind == .transfer {
            let to = accounts.first { $0.id == entry.transferAccountID }?.name ?? "?"
            return "\(entry.account?.name ?? "?") → \(to)"
        }
        return [entry.category.label, entry.account?.name].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: entry.kind == .transfer ? .transfer : entry.category)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayTitle).font(.body).foregroundStyle(Theme.ink).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer()
            Text(entry.kind == .income ? "+\(Fmt.money(entry.amount))" : entry.kind == .expense ? "−\(Fmt.money(entry.amount))" : Fmt.money(entry.amount))
                .font(.body.monospacedDigit())
                .foregroundStyle(entry.kind == .income ? Theme.positive : Theme.ink)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
