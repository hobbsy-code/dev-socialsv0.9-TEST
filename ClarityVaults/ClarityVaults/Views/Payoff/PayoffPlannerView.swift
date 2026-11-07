import SwiftUI
import SwiftData
import Charts

struct PayoffPlannerView: View {
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \LedgerEntry.date, order: .reverse) private var entries: [LedgerEntry]

    @State private var lumpSum: Double = 0
    @State private var lumpSumMonth = 1

    private var debtAccounts: [Account] { accounts.filter { $0.kind.isDebt && $0.includeInPayoff && $0.balance > 0 } }
    private var inputs: [DebtInput] {
        debtAccounts.map { DebtInput(id: $0.id, name: $0.name, balance: $0.balance, apr: $0.apr, minimumPayment: $0.minimumPayment) }
    }
    private var minimums: Double { DebtForecaster.totalMinimums(inputs) }
    private var plan: PayoffPlan {
        DebtForecaster.plan(debts: inputs, monthlyBudget: minimums + settings.payoffExtra, strategy: settings.payoffStrategy,
                            lumpSum: lumpSum, lumpSumMonth: lumpSumMonth)
    }
    private var minimumOnlyPlan: PayoffPlan {
        DebtForecaster.plan(debts: inputs, monthlyBudget: minimums, strategy: settings.payoffStrategy)
    }
    private var otherStrategyPlan: PayoffPlan {
        DebtForecaster.plan(debts: inputs, monthlyBudget: minimums + settings.payoffExtra,
                            strategy: settings.payoffStrategy == .avalanche ? .snowball : .avalanche,
                            lumpSum: lumpSum, lumpSumMonth: lumpSumMonth)
    }
    private var suggestedExtra: Double? {
        let totals = Analytics.totals(entries, periods: settings.paySchedule.recentPeriods(4))
        guard let surplus = Analytics.averageSurplus(totals), surplus > 20 else { return nil }
        return (surplus * 0.5 / 10).rounded(.down) * 10   // half the typical surplus, in £10 steps
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if debtAccounts.isEmpty {
                    EmptyStateView(systemImage: "flag.checkered", title: "No debts to plan",
                                   message: "Add credit cards or loans in Accounts with their APR and minimum payment to see your debt-free date.")
                } else {
                    summaryCard
                    controlsCard
                    chartCard
                    orderCard
                    warnings
                    DisclaimerText().padding(.horizontal, 4)
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("Payoff planner")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Summary

    private var summaryCard: some View {
        let p = plan, baseline = minimumOnlyPlan
        return VStack(alignment: .leading, spacing: 12) {
            Text("Debt-free by").font(.subheadline).foregroundStyle(.white.opacity(0.75))
            if let date = p.debtFreeDate(), let months = p.months {
                Text(Fmt.monthYear(date)).font(.system(size: 34, weight: .semibold, design: .rounded))
                Text("\(Fmt.duration(months: months)) · \(Fmt.money(p.totalInterest, pence: false)) interest")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                if let baseMonths = baseline.months, settings.payoffExtra > 0 || lumpSum > 0 {
                    let monthsSaved = baseMonths - months
                    let interestSaved = baseline.totalInterest - p.totalInterest
                    if monthsSaved > 0 || interestSaved > 1 {
                        Divider().overlay(.white.opacity(0.2))
                        Label("\(Fmt.duration(months: max(monthsSaved, 0))) sooner and \(Fmt.money(max(interestSaved, 0), pence: false)) less interest than minimum payments alone",
                              systemImage: "sparkles")
                            .font(.caption).foregroundStyle(Theme.gold)
                    }
                } else if baseline.months == nil {
                    Divider().overlay(.white.opacity(0.2))
                    Label("Minimum payments alone wouldn't clear this debt. Your extra payment makes the difference.", systemImage: "sparkles")
                        .font(.caption).foregroundStyle(Theme.gold)
                }
            } else {
                Text("Not within 50 years").font(.title2.weight(.semibold))
                Text("Payments don't cover the interest being added. Increase the monthly amount below.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
            }
        }
        .vaultCard()
    }

    // MARK: Controls

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Strategy", selection: $settings.payoffStrategy) {
                ForEach(PayoffStrategy.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            Text(settings.payoffStrategy.explanation).font(.caption).foregroundStyle(Theme.muted)

            let other = otherStrategyPlan
            if let a = plan.months, let b = other.months {
                let diff = other.totalInterest - plan.totalInterest
                Text(abs(diff) < 1 && a == b
                     ? "Both strategies finish at the same time for your debts."
                     : diff > 0
                        ? "\(settings.payoffStrategy.label) saves \(Fmt.money(diff, pence: false)) in interest compared with \(settings.payoffStrategy == .avalanche ? "snowball" : "avalanche")."
                        : "\(settings.payoffStrategy == .avalanche ? "Snowball" : "Avalanche") would save \(Fmt.money(-diff, pence: false)) more, but \(settings.payoffStrategy.label.lowercased()) may suit you better. Both work.")
                    .font(.caption).foregroundStyle(Theme.muted)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Extra each month").font(.subheadline.weight(.medium))
                    Spacer()
                    Text(Fmt.money(settings.payoffExtra, pence: false)).font(.headline.monospacedDigit()).foregroundStyle(Theme.accent)
                }
                Slider(value: $settings.payoffExtra, in: 0...1_000, step: 10)
                Text("On top of \(Fmt.money(minimums, pence: false)) minimum payments, a total of \(Fmt.money(minimums + settings.payoffExtra, pence: false)) a month.")
                    .font(.caption).foregroundStyle(Theme.muted)
                if let suggestedExtra, abs(suggestedExtra - settings.payoffExtra) >= 10 {
                    Button {
                        settings.payoffExtra = min(suggestedExtra, 1_000)
                    } label: {
                        Label("Try \(Fmt.money(suggestedExtra, pence: false)), half your usual monthly surplus", systemImage: "lightbulb")
                            .font(.caption.weight(.semibold))
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("One-off payment (bonus, tax refund…)").font(.subheadline.weight(.medium))
                HStack {
                    AmountField(title: "0.00", value: $lumpSum)
                    Stepper("in \(lumpSumMonth == 1 ? "1 month" : "\(lumpSumMonth) months")", value: $lumpSumMonth, in: 1...60)
                        .font(.caption)
                }
            }
        }
        .card()
    }

    // MARK: Chart

    private struct DebtSlice: Identifiable {
        let date: Date
        let name: String
        let amount: Double
        var id: String { "\(name)-\(date.timeIntervalSince1970)" }
    }

    private var chartCard: some View {
        let p = plan
        let names = Dictionary(uniqueKeysWithValues: inputs.map { ($0.id, $0.name) })
        let step = max(1, p.points.count / 60)       // keep the chart light for long plans
        let sampled = p.points.enumerated().filter { $0.offset % step == 0 || $0.offset == p.points.count - 1 }.map(\.element)
        let slices = sampled.flatMap { point in
            p.order.map { DebtSlice(date: point.date, name: names[$0] ?? "", amount: point.byDebt[$0] ?? 0) }
        }
        let domain = p.order.compactMap { names[$0] }
        let colours = domain.indices.map { Theme.chartPalette[$0 % Theme.chartPalette.count] }

        return VStack(alignment: .leading, spacing: 10) {
            CardHeader("Balance over time", systemImage: "chart.line.downtrend.xyaxis")
            Chart(slices) { s in
                AreaMark(x: .value("Date", s.date), y: .value("Owed", s.amount))
                    .foregroundStyle(by: .value("Debt", s.name))
                    .interpolationMethod(.monotone)
            }
            .chartForegroundStyleScale(domain: domain, range: colours)
            .chartYAxis { AxisMarks { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.compactMoney(d)) } } } }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 220)
        }
        .card()
    }

    // MARK: Order

    private var orderCard: some View {
        let p = plan
        return VStack(alignment: .leading, spacing: 12) {
            CardHeader("Payoff order", systemImage: "list.number")
            ForEach(Array(p.order.enumerated()), id: \.element) { index, id in
                if let account = debtAccounts.first(where: { $0.id == id }) {
                    HStack(spacing: 12) {
                        Text("\(index + 1)").font(.caption.weight(.bold)).foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Theme.chartPalette[index % Theme.chartPalette.count], in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name).foregroundStyle(Theme.ink)
                            Text("\(Fmt.money(account.balance, pence: false)) · \(String(format: "%.1f", account.apr))% APR")
                                .font(.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        if let m = p.payoffMonth[id], let date = Fmt.calendar.date(byAdding: .month, value: m, to: .now) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Cleared").font(.caption2).foregroundStyle(Theme.muted)
                                Text(Fmt.monthYear(date)).font(.caption.weight(.semibold)).foregroundStyle(Theme.positive)
                            }
                        } else {
                            Text("—").foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
            Text("Each time a debt is cleared, its payment moves to the next one, so your monthly total stays the same and payoff gets faster.")
                .font(.caption).foregroundStyle(Theme.muted)
        }
        .card()
    }

    @ViewBuilder private var warnings: some View {
        let underwater = debtAccounts.filter { $0.minimumPayment <= $0.balance * $0.apr / 1200 && $0.apr > 0 }
        let missing = debtAccounts.filter { $0.apr == 0 && $0.kind == .creditCard }
        if !underwater.isEmpty || !missing.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(underwater) { a in
                    Label("\(a.name): the minimum payment doesn't cover the monthly interest, so this balance grows unless more is paid.",
                          systemImage: "exclamationmark.triangle").foregroundStyle(Theme.caution)
                }
                ForEach(missing) { a in
                    Label("\(a.name) has 0% APR. If that's a promotional rate, note when it ends: the rate usually jumps.",
                          systemImage: "info.circle").foregroundStyle(Theme.muted)
                }
            }
            .font(.caption)
            .card()
        }
    }
}
