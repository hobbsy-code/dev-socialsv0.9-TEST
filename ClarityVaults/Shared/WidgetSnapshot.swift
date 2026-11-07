import Foundation

/// Small summary the app writes for the home-screen widget.
/// Compiled into both the app and the widget extension.
struct WidgetSnapshot: Codable {
    var safeToSpend: Double
    var nextPayday: Date
    var daysUntilPayday: Int
    var nextBillName: String?
    var nextBillAmount: Double?
    var nextBillDate: Date?
    var updatedAt: Date

    static let appGroup = "group.com.clarityvaults.app"
    private static let key = "widgetSnapshot"

    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(safeToSpend: 245.50, nextPayday: Date().addingTimeInterval(9 * 86_400), daysUntilPayday: 9,
                       nextBillName: "Energy", nextBillAmount: 120, nextBillDate: Date().addingTimeInterval(2 * 86_400),
                       updatedAt: Date())
    }

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.key)
    }
}
