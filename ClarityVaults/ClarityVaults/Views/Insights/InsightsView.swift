import SwiftUI
import SwiftData
import Charts

enum InsightsPage: String, CaseIterable, Identifiable {
    case spending = "Spending", cashFlow = "In vs out", wealth = "Net worth"
    var id: String { rawValue }
}

/// Tab root.
struct InsightsView: View {
    var body: some View {
        NavigationStack { InsightsScreen() }
    }
}

/// Insights content; also pushed from Home (opening on Net worth).
struct InsightsScreen: View {
    var initialSection: InsightsPage = .spending

    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \LedgerEntry.date, order: .reverse) private var entries: [LedgerEntry]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query private var budgets: [CategoryBudget]

    @State private var section: InsightsPage?
    @State private var periodOffset = 0       // 0 = current pay period, 1 = previous…
    @State private var selectedAngle: Double?
    @State private var showingLimits = false

    private var current: InsightsPage { section ?? initialSection }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("View", selection: Binding(get: { current }, set: { section = $0 })) {
                    ForEach(InsightsPage.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch current {
                case .spending: spendingSection
                case .cashFlow: cashFlowSection
                case .wealth: wealthSection
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("Insights")
        .sheet(isPresented: $showingLimits) { CategoryLimitsView() }
    }

    // MARK: Spending by category

    private var selectedPeriod: DateInterval {
        settings.paySchedule.recentPeriods(periodOffset + 1).first ?? settings.currentPeriod
    }

    private var spendingSection: some View {
        let totals = Analytics.spendingByCategory(entries, in: selectedPeriod)
        let total = totals.reduce(0) { $0 + $1.amount }
        let selected = selectedCategory(in: totals)
        let budgetRows = Analytics.budgetProgress(budgets: budgets, entries: Analytics.entries(entries, in: selectedPeriod))

        return VStack(spacing: 16) {
            HStack {
                Button { periodOffset += 1 } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous period")
                Spacer()
                VStack(spacing: 2) {
                    Text(periodOffset == 0 ? "This pay period" : periodOffset == 1 ? "Last pay period" : "\(periodOffset) periods ago")
                        .font(.subheadline.weight(.semibold))
                    Text("\(Fmt.day(selectedPeriod.start)) – \(Fmt.day(selectedPeriod.end.addingTimeInterval(-1)))")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                Button { periodOffset = max(0, periodOffset - 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(periodOffset == 0)
                    .accessibilityLabel("Next period")
            }
            .card()

            if totals.isEmpty {
                EmptyStateView(systemImage: "chart.pie", title: "No spending recorded",
                               message: "Add money out in Activity, or mark bills as paid, to see where your money goes.")
            } else {
                VStack(spacing: 12) {
                    Chart(totals) { item in
                        SectorMark(angle: .value("Amount", item.amount), innerRadius: .ratio(0.62), angularInset: 1.5)
                            .foregroundStyle(item.category.colour)
                            .opacity(selected == nil || selected?.id == item.id ? 1 : 0.35)
                            .cornerRadius(3)
                    }
                    .chartAngleSelection(value: $selectedAngle)
                    .chartBackground { proxy in
                        GeometryReader { geo in
                            if let frame = proxy.plotFrame {
                                let rect = geo[frame]
                                VStack(spacing: 2) {
                                    Text(selected?.category.label ?? "Total spent").font(.caption).foregroundStyle(Theme.muted)
                                    Text(Fmt.money(selected?.amount ?? total, pence: false)).font(.title3.weight(.semibold).monospacedDigit())
                                    if let selected { Text("\(Int((selected.share * 100).rounded()))%").font(.caption).foregroundStyle(Theme.muted) }
                                }
                                .position(x: rect.midX, y: rect.midY)
                            }
                        }
                    }
                    .frame(height: 240)

                    ForEach(totals) { item in
                        HStack(spacing: 10) {
                            CategoryIcon(category: item.category, size: 30)
                            Text(item.category.label).foregroundStyle(Theme.ink)
                            Spacer()
                            Text("\(Int((item.share * 100).rounded()))%").font(.caption).foregroundStyle(Theme.muted)
                            Text(Fmt.money(item.amount, pence: false)).monospacedDigit().frame(minWidth: 70, alignment: .trailing)
                        }
                    }
                }
                .card()
            }

            VStack(alignment: .leading, spacing: 12) {
                CardHeader(title: "Spending limits", systemImage: "gauge.with.dots.needle.33percent") {
                    Button(budgetRows.isEmpty ? "Set up" : "Edit") { showingLimits = true }.font(.caption.weight(.semibold))
                }
                if budgetRows.isEmpty {
                    Text("Set a limit for categories like groceries or eating out, and see what's left each pay period.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                } else {
                    ForEach(budgetRows) { BudgetProgressRow(progress: $0) }
                }
            }
            .card()
        }
    }

    private func selectedCategory(in totals: [CategoryTotal]) -> CategoryTotal? {
        guard let selectedAngle else { return nil }
        var running = 0.0
        for item in totals {
            running += item.amount
            if selectedAngle <= running { return item }
        }
        return nil
    }

    // MARK: Money in vs out by pay period

    private var cashFlowSection: some View {
        let periods = settings.paySchedule.recentPeriods(6)
        let totals = Analytics.totals(entries, periods: periods)
        let surplus = Analytics.averageSurplus(totals)

        return VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader("Money in vs out", systemImage: "chart.bar")
                Text("Last 6 pay periods").font(.caption).foregroundStyle(Theme.muted)
                Chart {
                    ForEach(totals) { t in
                        BarMark(x: .value("Period", t.label), y: .value("Amount", t.income))
                            .foregroundStyle(by: .value("Type", "In"))
                            .position(by: .value("Type", "In"))
                        BarMark(x: .value("Period", t.label), y: .value("Amount", t.outgoings))
                            .foregroundStyle(by: .value("Type", "Out"))
                            .position(by: .value("Type", "Out"))
                    }
                }
                .chartForegroundStyleScale(["In": Theme.accent, "Out": Theme.gold])
                .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.compactMoney(d)) } } } }
                .frame(height: 220)
            }
            .card()

            VStack(alignment: .leading, spacing: 10) {
                CardHeader("Each period", systemImage: "list.number")
                ForEach(Array(totals.reversed())) { t in
                    HStack {
                        Text("From \(Fmt.day(t.period.start))").foregroundStyle(Theme.ink)
                        Spacer()
                        Text(Fmt.signedMoney(t.net)).monospacedDigit()
                            .foregroundStyle(t.net >= 0 ? Theme.positive : Theme.negative)
                    }
                    .font(.subheadline)
                }
                if let surplus {
                    Divider()
                    Text(surplus >= 0
                         ? "On average you have \(Fmt.money(surplus, pence: false)) left each pay period. Putting part of this towards debt or savings is often the quickest win."
                         : "On average you spend \(Fmt.money(-surplus, pence: false)) more than comes in each period. The Bills tab is a good place to look for savings.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }
            .card()
        }
    }

    // MARK: Net worth over time

    private var wealthSection: some View {
        let history = Analytics.wealthHistory(accounts: accounts)
        let latest = history.last
        return VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                CardHeader("Net worth", systemImage: "chart.line.uptrend.xyaxis")
                if let latest {
                    HStack {
                        StatColumn(label: "You have", value: Fmt.money(latest.assets, pence: false), tint: Theme.positive)
                        StatColumn(label: "You owe", value: Fmt.money(latest.debts, pence: false))
                        StatColumn(label: "Net worth", value: Fmt.money(latest.net, pence: false))
                    }
                }
                if history.count > 1 {
                    Chart {
                        ForEach(history) { p in
                            LineMark(x: .value("Date", p.date), y: .value("Amount", p.assets), series: .value("Series", "You have"))
                                .foregroundStyle(by: .value("Series", "You have"))
                            LineMark(x: .value("Date", p.date), y: .value("Amount", p.debts), series: .value("Series", "You owe"))
                                .foregroundStyle(by: .value("Series", "You owe"))
                            LineMark(x: .value("Date", p.date), y: .value("Amount", p.net), series: .value("Series", "Net worth"))
                                .foregroundStyle(by: .value("Series", "Net worth"))
                                .lineStyle(StrokeStyle(lineWidth: 3))
                        }
                    }
                    .chartForegroundStyleScale(["You have": Theme.accent, "You owe": Theme.gold, "Net worth": Theme.ink])
                    .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.compactMoney(d)) } } } }
                    .frame(height: 240)
                } else {
                    Text("Your chart builds up as you update balances. Try the weekly check-in.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                }
            }
            .card()

            if let first = history.first, let latest, history.count > 1 {
                let change = latest.net - first.net
                VStack(alignment: .leading, spacing: 6) {
                    Text("Since \(Fmt.day(first.date))").font(.caption).foregroundStyle(Theme.muted)
                    Text("\(change >= 0 ? "Up" : "Down") \(Fmt.money(abs(change), pence: false))")
                        .font(.title3.weight(.semibold)).foregroundStyle(change >= 0 ? Theme.positive : Theme.ink)
                    Text(change >= 0 ? "Every pound of debt repaid counts here too." : "Big one-off costs happen. What matters is the trend over months.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                .card()
            }
        }
    }
}

struct CategoryLimitsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var budgets: [CategoryBudget]
    @State private var limits: [SpendCategory: Double] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(SpendCategory.expenseCases) { cat in
                        HStack {
                            CategoryIcon(category: cat, size: 28)
                            Text(cat.label)
                            Spacer()
                            AmountField(title: "No limit", value: Binding(get: { limits[cat] ?? 0 }, set: { limits[cat] = $0 }))
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 110)
                        }
                    }
                } footer: {
                    Text("Limits apply to each pay period. Leave blank for no limit. Bills you mark as paid count towards their category.")
                }
            }
            .navigationTitle("Spending limits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear {
                for b in budgets { limits[b.category] = b.limit }
            }
        }
    }

    private func save() {
        for (cat, limit) in limits {
            if let existing = budgets.first(where: { $0.category == cat }) {
                if limit > 0 { existing.limit = limit } else { context.delete(existing) }
            } else if limit > 0 {
                context.insert(CategoryBudget(category: cat, limit: limit))
            }
        }
        try? context.save()
        dismiss()
    }
}
