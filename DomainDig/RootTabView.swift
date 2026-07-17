import SwiftUI

private enum RootTab: Hashable {
    case dashboard
    case audit
    case history
    case inspect
    case settings
}

struct RootTabView: View {
    @Bindable var viewModel: DomainViewModel
    @State private var purchaseService = PurchaseService.shared
    @State private var intentRouter = DomainDigIntentRouter.shared
    @State private var selectedTab: RootTab = FeatureAccessService.currentTier == .free ? .inspect : .dashboard

    var body: some View {
        let _ = purchaseService.currentTier

        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(viewModel: viewModel)
            }
            .tabItem {
                Label("Dashboard", systemImage: "square.grid.2x2")
            }
            .tag(RootTab.dashboard)

            NavigationStack {
                AuditListView(viewModel: viewModel)
            }
            .tabItem {
                Label("Audit", systemImage: "checklist")
            }
            .tag(RootTab.audit)

            NavigationStack {
                HistoryView(viewModel: viewModel)
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            }
            .tag(RootTab.history)

            ContentView(viewModel: viewModel)
                .tabItem {
                    Label("Inspect", systemImage: "magnifyingglass")
                }
                .tag(RootTab.inspect)

            NavigationStack {
                SettingsView(viewModel: viewModel)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(RootTab.settings)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.isPaywallPresented },
            set: { viewModel.isPaywallPresented = $0 }
        )) {
            PaywallView()
        }
        .alert(item: Binding(
            get: { viewModel.upgradePrompt },
            set: { viewModel.upgradePrompt = $0 }
        )) { prompt in
            Alert(
                title: Text(prompt.title),
                message: Text(prompt.message),
                primaryButton: .default(Text("Open Paywall")) {
                    viewModel.upgradePrompt = nil
                    viewModel.isPaywallPresented = true
                },
                secondaryButton: .cancel(Text("Continue")) {
                    viewModel.upgradePrompt = nil
                }
            )
        }
        .onChange(of: purchaseService.currentTier) { _, newValue in
            if newValue != .free, selectedTab == .inspect, viewModel.trackedDomains.isEmpty == false {
                selectedTab = .dashboard
            }
        }
        .onOpenURL { url in
            guard let action = DomainDigDeepLink.action(from: url) else { return }
            perform(action)
        }
        .onChange(of: intentRouter.pendingAction) { _, action in
            consume(action)
        }
        .task {
            consume(intentRouter.pendingAction)
        }
    }

    private func consume(_ action: DomainDigDeepLink.Action?) {
        guard let action else { return }
        intentRouter.pendingAction = nil
        perform(action)
    }

    private func perform(_ action: DomainDigDeepLink.Action) {
        switch action {
        case let .inspect(domain):
            viewModel.domain = domain
            selectedTab = .inspect
            viewModel.run()
        case let .watch(domain):
            // On success show the dashboard (where tracked domains live); on
            // failure stay put so the upgrade/paywall alert surfaces in place.
            if viewModel.trackDomain(domain: domain, availabilityStatus: nil) {
                selectedTab = .dashboard
            }
        }
    }
}
