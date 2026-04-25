import SwiftUI

struct DashboardView: View {
    @Environment(\.appDensity) private var appDensity
    @Bindable var viewModel: DomainViewModel
    @State private var collapsedGroups = Set<String>()

    private let summaryColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        List {
            if viewModel.trackedDomains.isEmpty {
                Section {
                    EmptyStateCardView(
                        title: "No Portfolio Yet",
                        message: "Track domains to get portfolio health, recent changes, expiry visibility, and an attention queue in one place.",
                        suggestion: "Inspect a domain and use the Track action, or add one directly from Tracked Domains in Settings.",
                        systemImage: "square.stack.3d.up.fill",
                        showsCardBackground: false
                    )
                }
                .listRowBackground(Color(.systemGray6).opacity(0.5))
            } else {
                Section {
                    LazyVGrid(columns: summaryColumns, spacing: 10) {
                        summaryCard(title: "Total Domains", value: viewModel.portfolioDashboardData.snapshot.totalDomains, filter: .all, tint: .cyan)
                        summaryCard(title: "Healthy", value: viewModel.portfolioDashboardData.snapshot.healthyCount, filter: .healthy, tint: .green)
                        summaryCard(title: "Warning", value: viewModel.portfolioDashboardData.snapshot.warningCount, filter: .warning, tint: .yellow)
                        summaryCard(title: "Critical", value: viewModel.portfolioDashboardData.snapshot.criticalCount, filter: .critical, tint: .red)
                        summaryCard(title: "Changes (24h)", value: viewModel.portfolioDashboardData.snapshot.changedLast24h, filter: .changed, tint: .orange)
                        summaryCard(title: "Unreachable", value: viewModel.portfolioDashboardData.snapshot.unreachableCount, filter: .unreachable, tint: .pink)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color(.systemGray6).opacity(0.5))

                Section("Quick Filters") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PortfolioFilterOption.allCases) { filter in
                                Button {
                                    viewModel.dashboardFilter = filter
                                } label: {
                                    Text(filter.title)
                                        .font(appDensity.font(.caption, weight: .semibold))
                                        .foregroundStyle(viewModel.dashboardFilter == filter ? Color.black : Color.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(viewModel.dashboardFilter == filter ? Color.cyan : Color(.systemGray5).opacity(0.6))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(Color(.systemGray6).opacity(0.5))

                Section("Recent Activity") {
                    if viewModel.filteredPortfolioRecentActivity.isEmpty {
                        dashboardEmptyRow("No recent portfolio changes")
                    } else {
                        ForEach(viewModel.filteredPortfolioRecentActivity.prefix(8)) { item in
                            if let trackedDomain = viewModel.trackedDomain(withID: item.trackedDomainID) {
                                NavigationLink {
                                    TrackedDomainDetailView(viewModel: viewModel, trackedDomain: trackedDomain)
                                } label: {
                                    PortfolioActivityRow(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listRowBackground(Color(.systemGray6).opacity(0.5))

                Section("Attention Required") {
                    if viewModel.filteredPortfolioAttentionRequired.isEmpty {
                        dashboardEmptyRow("Nothing urgent right now")
                    } else {
                        ForEach(viewModel.filteredPortfolioAttentionRequired.prefix(8)) { item in
                            if let trackedDomain = viewModel.trackedDomain(withID: item.trackedDomainID) {
                                NavigationLink {
                                    TrackedDomainDetailView(viewModel: viewModel, trackedDomain: trackedDomain)
                                } label: {
                                    PortfolioAttentionRow(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listRowBackground(Color(.systemGray6).opacity(0.5))

                Section("Expiring Soon") {
                    if viewModel.filteredPortfolioExpiringSoon.isEmpty {
                        dashboardEmptyRow("No certificates expiring within 30 days")
                    } else {
                        ForEach(viewModel.filteredPortfolioExpiringSoon.prefix(8)) { state in
                            NavigationLink {
                                TrackedDomainDetailView(viewModel: viewModel, trackedDomain: state.trackedDomain)
                            } label: {
                                PortfolioExpiryRow(state: state)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowBackground(Color(.systemGray6).opacity(0.5))

                Section("Portfolio List") {
                    if viewModel.filteredPortfolioGroups.isEmpty {
                        dashboardEmptyRow("No domains match the current filter")
                    } else {
                        ForEach(viewModel.filteredPortfolioGroups) { group in
                            DisclosureGroup(
                                isExpanded: disclosureBinding(for: group.apexDomain),
                                content: {
                                    ForEach(group.domains) { state in
                                        NavigationLink {
                                            TrackedDomainDetailView(viewModel: viewModel, trackedDomain: state.trackedDomain)
                                        } label: {
                                            WatchlistRowView(
                                                trackedDomain: state.trackedDomain,
                                                isRefreshing: viewModel.refreshingTrackedDomainID == state.trackedDomain.id
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                },
                                label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(group.apexDomain)
                                                .font(appDensity.font(.headline, design: .default, weight: .semibold))
                                            Text("\(group.domains.count) domain\(group.domains.count == 1 ? "" : "s")")
                                                .font(appDensity.font(.caption))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        groupBadge(for: group.domains)
                                    }
                                    .padding(.vertical, 4)
                                }
                            )
                        }
                    }
                }
                .listRowBackground(Color(.systemGray6).opacity(0.5))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Dashboard")
        .searchable(text: $viewModel.dashboardSearchText, prompt: "Search portfolio")
        .toolbar {
            if !viewModel.trackedDomains.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        AppHaptics.refresh()
                        viewModel.refreshAllTrackedDomains()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.batchLookupRunning)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func disclosureBinding(for apexDomain: String) -> Binding<Bool> {
        Binding(
            get: { !collapsedGroups.contains(apexDomain) },
            set: { isExpanded in
                if isExpanded {
                    collapsedGroups.remove(apexDomain)
                } else {
                    collapsedGroups.insert(apexDomain)
                }
            }
        )
    }

    private func summaryCard(title: String, value: Int, filter: PortfolioFilterOption, tint: Color) -> some View {
        Button {
            viewModel.dashboardFilter = filter
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(appDensity.font(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(value)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                HStack {
                    Circle()
                        .fill(tint)
                        .frame(width: 8, height: 8)
                    Text(filter.title)
                        .font(appDensity.font(.caption2, design: .default, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(appDensity.metrics.cardPadding)
            .background(cardBackground(for: filter))
            .clipShape(RoundedRectangle(cornerRadius: appDensity.metrics.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }

    private func cardBackground(for filter: PortfolioFilterOption) -> some ShapeStyle {
        if viewModel.dashboardFilter == filter {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.cyan.opacity(0.28), Color.cyan.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Color(.systemGray5).opacity(0.45))
    }

    private func dashboardEmptyRow(_ message: String) -> some View {
        Text(message)
            .font(appDensity.font(.caption))
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }

    private func groupBadge(for states: [PortfolioDomainStatus]) -> some View {
        let criticalCount = states.filter { $0.health == .critical }.count
        let warningCount = states.filter { $0.health == .warning }.count
        let title: String
        let color: Color

        if criticalCount > 0 {
            title = "\(criticalCount) critical"
            color = .red
        } else if warningCount > 0 {
            title = "\(warningCount) warning"
            color = .yellow
        } else {
            title = "Healthy"
            color = .green
        }

        return AppStatusBadgeView(
            model: .init(
                title: title,
                systemImage: criticalCount > 0 ? "exclamationmark.octagon.fill" : (warningCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"),
                foregroundColor: color,
                backgroundColor: color.opacity(0.16)
            )
        )
    }
}

private struct PortfolioActivityRow: View {
    @Environment(\.appDensity) private var appDensity
    let item: PortfolioActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22, height: 22)
                .background(iconColor.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.message)
                    .font(appDensity.font(.callout, design: .default))
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Text(item.domain)
                    Text(relativeTimestamp(item.timestamp))
                }
                .font(appDensity.font(.caption2))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch item.health {
        case .healthy:
            return .cyan
        case .warning:
            return .yellow
        case .critical:
            return .red
        }
    }
}

private struct PortfolioAttentionRow: View {
    @Environment(\.appDensity) private var appDensity
    let item: PortfolioAttentionItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AppStatusBadgeView(model: badgeModel)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.domain)
                    .font(appDensity.font(.callout))
                    .foregroundStyle(.primary)
                Text(item.reason)
                    .font(appDensity.font(.caption, design: .default))
                    .foregroundStyle(.secondary)
                Text(relativeTimestamp(item.timestamp))
                    .font(appDensity.font(.caption2))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var badgeModel: AppStatusBadgeModel {
        switch item.health {
        case .healthy:
            return .init(title: "Healthy", systemImage: "checkmark.circle.fill", foregroundColor: .green, backgroundColor: .green.opacity(0.16))
        case .warning:
            return .init(title: "Warning", systemImage: "exclamationmark.triangle.fill", foregroundColor: .yellow, backgroundColor: .yellow.opacity(0.16))
        case .critical:
            return .init(title: "Critical", systemImage: "exclamationmark.octagon.fill", foregroundColor: .red, backgroundColor: .red.opacity(0.16))
        }
    }
}

private struct PortfolioExpiryRow: View {
    @Environment(\.appDensity) private var appDensity
    let state: PortfolioDomainStatus

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.trackedDomain.domain)
                    .font(appDensity.font(.callout))
                    .foregroundStyle(.primary)
                Text(expirySubtitle)
                    .font(appDensity.font(.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            AppStatusBadgeView(model: badgeModel)
        }
        .padding(.vertical, 4)
    }

    private var expirySubtitle: String {
        if let days = state.certificateDaysRemaining {
            return "Expires in \(days) day\(days == 1 ? "" : "s")"
        }
        return "Certificate needs review"
    }

    private var badgeModel: AppStatusBadgeModel {
        switch state.certificateExpiryState {
        case .none:
            return .init(title: "Healthy", systemImage: "lock.fill", foregroundColor: .green, backgroundColor: .green.opacity(0.16))
        case .warning:
            return .init(title: "Warning", systemImage: "exclamationmark.triangle.fill", foregroundColor: .yellow, backgroundColor: .yellow.opacity(0.16))
        case .critical:
            return .init(title: "Critical", systemImage: "xmark.octagon.fill", foregroundColor: .red, backgroundColor: .red.opacity(0.16))
        }
    }
}

private func relativeTimestamp(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}
