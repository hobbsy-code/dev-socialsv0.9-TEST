import SwiftUI

/// Simple vault-door brand mark drawn in code (swap for the real logo asset when available).
struct VaultMark: View {
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(LinearGradient(colors: [Theme.navySoft, Theme.navy], startPoint: .top, endPoint: .bottom))
            Circle().stroke(Theme.gold, lineWidth: size * 0.06).padding(size * 0.2)
            Circle().fill(Theme.gold).frame(width: size * 0.14)
            ForEach(0..<4) { i in
                Capsule().fill(Theme.gold)
                    .frame(width: size * 0.05, height: size * 0.16)
                    .offset(y: -size * 0.19)
                    .rotationEffect(.degrees(Double(i) * 90 + 45))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct CategoryIcon: View {
    let category: SpendCategory
    var size: CGFloat = 36
    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(category.colour)
            .frame(width: size, height: size)
            .background(category.colour.opacity(0.14), in: Circle())
            .accessibilityHidden(true)
    }
}

struct AccountIcon: View {
    let kind: AccountKind
    var size: CGFloat = 36
    var body: some View {
        Image(systemName: kind.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(kind.isDebt ? Theme.gold : Theme.accent)
            .frame(width: size, height: size)
            .background((kind.isDebt ? Theme.gold : Theme.accent).opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Text field for money that accepts "£1,200.50" style input.
struct AmountField: View {
    let title: String
    @Binding var value: Double
    var large = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text("£").foregroundStyle(Theme.muted)
            TextField(title, text: $text)
                .keyboardType(.decimalPad)
                .focused($focused)
                .onChange(of: text) { _, new in value = Fmt.parseAmount(new) ?? 0 }
        }
        .font(large ? .system(size: 40, weight: .semibold, design: .rounded) : .body)
        .onAppear { text = value == 0 ? "" : String(format: "%.2f", value) }
        .onChange(of: value) { _, newValue in
            // Values set from outside (e.g. loading an entry to edit) while not typing.
            if !focused { text = newValue == 0 ? "" : String(format: "%.2f", newValue) }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused, let v = Fmt.parseAmount(text) { text = String(format: "%.2f", v) }
        }
    }
}

struct ProgressBar: View {
    let fraction: Double
    var tint: Color = Theme.accent
    var height: CGFloat = 8
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.hairline)
                Capsule().fill(tint).frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue("\(Int(fraction * 100)) percent")
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage).font(.system(size: 36)).foregroundStyle(Theme.accent)
            Text(title).font(.headline).foregroundStyle(Theme.ink)
            Text(message).font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.borderedProminent).padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .card()
    }
}

struct StatColumn: View {
    let label: String
    let value: String
    var tint: Color = Theme.ink
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(Theme.muted)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Plain-English disclaimer shown wherever the app makes projections.
struct DisclaimerText: View {
    var body: some View {
        Text("Clarity Vaults is a budgeting tool, not financial advice. Forecasts are estimates based on the figures you enter and assume fixed rates and payments. For free, impartial debt help contact MoneyHelper or StepChange.")
            .font(.footnote)
            .foregroundStyle(Theme.muted)
    }
}

struct BillRow: View {
    let bill: Bill
    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: bill.category)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(bill.name).font(.body.weight(.medium)).foregroundStyle(Theme.ink)
                    if bill.isDirectDebit { Tag(text: "DD") }
                    if bill.isIncome { Tag(text: "Income", tint: Theme.positive) }
                }
                Text("\(Fmt.dayWithWeekday(bill.nextDueDate)) · \(Fmt.relativeDays(to: bill.nextDueDate))")
                    .font(.caption)
                    .foregroundStyle(bill.isOverdue() && !bill.isIncome ? Theme.negative : Theme.muted)
            }
            Spacer()
            Text(bill.isIncome ? "+\(Fmt.money(bill.amount))" : Fmt.money(bill.amount))
                .font(.body.monospacedDigit())
                .foregroundStyle(bill.isIncome ? Theme.positive : Theme.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

struct Tag: View {
    let text: String
    var tint: Color = Theme.accent
    var body: some View {
        Text(text).font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(tint.opacity(0.14), in: Capsule())
            .foregroundStyle(tint)
    }
}

struct BudgetProgressRow: View {
    let progress: BudgetProgress
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(progress.category.label).font(.subheadline).foregroundStyle(Theme.ink)
                Spacer()
                Text(progress.isOver ? "\(Fmt.money(-progress.remaining, pence: false)) over" : "\(Fmt.money(progress.remaining, pence: false)) left")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(progress.isOver ? Theme.caution : Theme.muted)
            }
            ProgressBar(fraction: progress.fraction, tint: progress.isOver ? Theme.caution : progress.category.colour)
        }
        .accessibilityElement(children: .combine)
    }
}
