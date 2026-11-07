import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load() ?? .placeholder)
        // The app reloads the widget whenever data changes; refresh at midnight so "days to payday" stays right.
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

struct ClarityWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private let navy = Color(red: 0.06, green: 0.11, blue: 0.20)
    private let gold = Color(red: 0.85, green: 0.68, blue: 0.36)

    private var days: Int {
        let cal = Calendar.current
        return max(cal.dateComponents([.day], from: cal.startOfDay(for: entry.date), to: cal.startOfDay(for: entry.snapshot.nextPayday)).day ?? 0, 0)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Safe to spend").font(.caption).foregroundStyle(.white.opacity(0.7))
                Text(money(entry.snapshot.safeToSpend))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6).lineLimit(1)
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Label("\(days) day\(days == 1 ? "" : "s") to payday", systemImage: "calendar")
                    .font(.caption2).foregroundStyle(gold)
            }
            if family == .systemMedium, let name = entry.snapshot.nextBillName,
               let amount = entry.snapshot.nextBillAmount, let date = entry.snapshot.nextBillDate {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next bill").font(.caption).foregroundStyle(.white.opacity(0.7))
                    Text(name).font(.headline).foregroundStyle(.white).lineLimit(1)
                    Text(money(amount)).font(.subheadline).foregroundStyle(.white.opacity(0.9))
                    Spacer(minLength: 0)
                    Text(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "en_GB"))))
                        .font(.caption2).foregroundStyle(gold)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [navy, Color(red: 0.11, green: 0.18, blue: 0.31)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func money(_ v: Double) -> String {
        v.formatted(.currency(code: "GBP").locale(Locale(identifier: "en_GB")).precision(.fractionLength(0)))
    }
}

@main
struct ClarityWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClarityWidget", provider: SnapshotProvider()) { entry in
            ClarityWidgetView(entry: entry)
        }
        .configurationDisplayName("Safe to spend")
        .description("What's safe to spend until payday, and your next bill.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
