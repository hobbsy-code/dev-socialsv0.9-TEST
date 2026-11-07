import Foundation

/// UK-specific formatting. All money is GBP, all dates en-GB.
enum Fmt {
    static let locale = Locale(identifier: "en_GB")

    static var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        cal.timeZone = .current
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    static func money(_ value: Double, pence: Bool = true) -> String {
        value.formatted(.currency(code: "GBP").locale(locale).precision(.fractionLength(pence ? 2 : 0)))
    }

    /// "+£12.00" / "−£12.00"
    static func signedMoney(_ value: Double) -> String {
        let base = money(abs(value))
        return value < 0 ? "−\(base)" : "+\(base)"
    }

    /// Short form for chart axes: £950, £1.2k, £14k
    static func compactMoney(_ value: Double) -> String {
        let sign = value < 0 ? "−" : ""
        let v = abs(value)
        switch v {
        case 10_000...: return "\(sign)£\(Int((v / 1000).rounded()))k"
        case 1_000...:  return "\(sign)£\(String(format: "%.1f", v / 1000))k"
        default:        return "\(sign)£\(Int(v.rounded()))"
        }
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(locale))           // 7 Nov
    }

    static func dayWithWeekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(locale)) // Sat 7 Nov
    }

    static func monthYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year().locale(locale))                // November 2026
    }

    static func shortMonth(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).locale(locale))                // Nov
    }

    /// "today", "tomorrow", "in 3 days", "2 days ago"
    static func relativeDays(to date: Date, from now: Date = .now) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "today"
        case 1: return "tomorrow"
        case -1: return "yesterday"
        case let d where d > 1: return "in \(d) days"
        default: return "\(-days) days overdue"
        }
    }

    /// "2 years 4 months"
    static func duration(months: Int) -> String {
        let years = months / 12, rem = months % 12
        var parts: [String] = []
        if years > 0 { parts.append("\(years) year\(years == 1 ? "" : "s")") }
        if rem > 0 || years == 0 { parts.append("\(rem) month\(rem == 1 ? "" : "s")") }
        return parts.joined(separator: " ")
    }

    /// Parses user-typed amounts such as "£1,250.50" or "12.5".
    static func parseAmount(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite else { return nil }
        return value
    }
}
