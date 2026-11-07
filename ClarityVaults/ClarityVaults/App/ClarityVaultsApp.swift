import SwiftUI
import SwiftData

@main
struct ClarityVaultsApp: App {
    @StateObject private var settings = AppSettings()

    private let container: ModelContainer = {
        let schema = Schema([Account.self, BalanceSnapshot.self, LedgerEntry.self, Bill.self, CategoryBudget.self])
        // Stored only on this device. (iCloud sync is a v1.1 option; see docs/ROADMAP.md.)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not open the Clarity Vaults data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
