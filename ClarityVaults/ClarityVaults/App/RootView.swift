import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase
    @Query private var bills: [Bill]
    @Query private var accounts: [Account]

    @State private var isLocked = false
    @State private var selectedTab = Tab.home

    enum Tab: Hashable { case home, activity, bills, accounts, insights }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(Tab.home)
            ActivityView()
                .tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }
                .tag(Tab.activity)
            BillsView()
                .tabItem { Label("Bills", systemImage: "calendar.badge.clock") }
                .tag(Tab.bills)
            AccountsView()
                .tabItem { Label("Accounts", systemImage: "building.columns") }
                .tag(Tab.accounts)
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.pie") }
                .tag(Tab.insights)
        }
        // Hide balances in the app switcher when the lock is on.
        .blur(radius: settings.appLockEnabled && (isLocked || scenePhase != .active) ? 24 : 0)
        .overlay {
            if isLocked { LockView { isLocked = false } }
        }
        .fullScreenCover(isPresented: Binding(get: { !settings.hasOnboarded }, set: { _ in })) {
            OnboardingView()
        }
        .onAppear {
            isLocked = settings.appLockEnabled
            refreshBackgroundState()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                if settings.appLockEnabled { isLocked = true }
            case .active:
                refreshBackgroundState()
            default:
                break
            }
        }
        .onChange(of: bills.map(\.nextDueDate)) { _, _ in refreshBackgroundState() }
        .onChange(of: accounts.map(\.balance)) { _, _ in refreshBackgroundState() }
    }

    private func refreshBackgroundState() {
        let hour = settings.reminderHour
        let currentBills = bills
        Task { await ReminderService.shared.rescheduleAll(currentBills, hour: hour) }
        WidgetBridge.update(accounts: accounts, bills: bills, settings: settings)
    }
}

struct LockView: View {
    var onUnlock: () -> Void

    var body: some View {
        ZStack {
            Theme.navy.ignoresSafeArea()
            VStack(spacing: 20) {
                VaultMark(size: 72)
                Text("Clarity Vaults").font(.title2.weight(.semibold)).foregroundStyle(.white)
                Button {
                    Task { if await AppLock.authenticate() { onUnlock() } }
                } label: {
                    Label("Unlock with \(AppLock.biometryName)", systemImage: "lock.open")
                        .padding(.horizontal, 24).padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .task { if await AppLock.authenticate() { onUnlock() } }
    }
}
