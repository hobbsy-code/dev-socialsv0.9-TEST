import SwiftUI
import SwiftData

struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var context
    @State private var page = 0
    @State private var schedule = PaySchedule()
    @State private var acceptedDisclaimer = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack {
                TabView(selection: $page) {
                    welcome.tag(0)
                    privacy.tag(1)
                    payday.tag(2)
                    finish.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                if page < 3 {
                    Button(page == 2 ? "Save payday" : "Continue") {
                        if page == 2 { settings.paySchedule = schedule }
                        withAnimation { page += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear { schedule = settings.paySchedule }
        .interactiveDismissDisabled()
    }

    private var welcome: some View {
        OnboardingPage(systemImage: nil,
                       title: "See your money clearly",
                       message: "Clarity Vaults brings your accounts, bills and debts into one calm place, so you know what's safe to spend and when you'll be debt-free.") {
            VaultMark(size: 96)
        }
    }

    private var privacy: some View {
        OnboardingPage(systemImage: "lock.shield",
                       title: "Private by design",
                       message: "No account, no bank login, no ads. Your figures stay on this iPhone. You type in balances from your banking apps, which takes about 30 seconds a week.") { EmptyView() }
    }

    private var payday: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar").font(.system(size: 48)).foregroundStyle(Theme.accent)
            Text("When do you get paid?").font(.title2.weight(.semibold)).foregroundStyle(Theme.ink)
            Text("Budgets run from payday to payday, so your numbers match real life.")
                .font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Form { PayScheduleEditor(schedule: $schedule) }
                .scrollContentBackground(.hidden)
                .frame(maxHeight: 220)
        }
        .padding(24)
    }

    private var finish: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal").font(.system(size: 48)).foregroundStyle(Theme.gold)
            Text("One last thing").font(.title2.weight(.semibold)).foregroundStyle(Theme.ink)
            DisclaimerText().multilineTextAlignment(.center)
            Toggle("I understand", isOn: $acceptedDisclaimer).padding(.horizontal, 40)
            VStack(spacing: 10) {
                Button("Start with my own accounts") { complete(demo: false) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                Button("Explore with example data") { complete(demo: true) }
                    .controlSize(.large)
            }
            .disabled(!acceptedDisclaimer)
        }
        .padding(24)
    }

    private func complete(demo: Bool) {
        if demo { DemoData.load(into: context, settings: settings) }
        settings.hasOnboarded = true
    }
}

private struct OnboardingPage<Hero: View>: View {
    let systemImage: String?
    let title: String
    let message: String
    @ViewBuilder var hero: () -> Hero

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 56)).foregroundStyle(Theme.accent)
            }
            hero()
            Text(title).font(.largeTitle.weight(.semibold)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            Text(message).font(.body).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(32)
    }
}
