import SwiftUI

struct HistoryView: View {
    @Environment(\.appDensity) private var appDensity
    @Bindable var viewModel: DomainViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showClearAllConfirmation = false

    private var groupedHistory: [HistoryGroup] {
        HistoryGroup.groups(for: viewModel.filteredHistory)
    }

    var body: some View {
        List {
            if viewModel.filteredHistory.isEmpty {
                EmptyStateCardView(
                    title: "No History Yet",
                    message: "History stores local snapshots of previous inspections so you can revisit and compare them later.",
                    suggestion: "Run a lookup to create your first saved snapshot.",
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                )
                    .listRowBackground(Color(.systemGray6).opacity(0.5))
            } else {
                ForEach(groupedHistory) { group in
                    Section(group.title) {
                        ForEach(group.entries) { entry in
                            NavigationLink {
                                HistoryDetailView(viewModel: viewModel, entry: entry)
                            } label: {
                                VStack(alignment: .leading, spacing: appDensity.metrics.rowSpacing + 1) {
                                    HStack(alignment: .center, spacing: 8) {
                                        Text(entry.domain)
                                            .font(appDensity.font(.callout))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        AppStatusBadgeView(model: AppStatusFactory.change(entry.changeSummary))
                                    }

                                    HStack(spacing: 8) {
                                        AppStatusBadgeView(model: AppStatusFactory.availability(entry.availabilityResult?.status))
                                        AppStatusBadgeView(model: AppStatusFactory.tls(sslInfo: entry.sslInfo, error: entry.sslError))
                                    }

                                    HStack(spacing: 8) {
                                        Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        Text(entry.timestamp.formatted(.relative(presentation: .named)))
                                        Text(entry.resolverDisplayName)
                                        if let totalLookupDurationMs = entry.totalLookupDurationMs {
                                            Text("\(totalLookupDurationMs) ms")
                                        }
                                    }
                                    .font(appDensity.font(.caption2))
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.removeHistoryEntries(withIDs: [entry.id])
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .listRowBackground(Color(.systemGray6).opacity(0.5))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("History")
        .searchable(text: $viewModel.historySearchText, prompt: "Search domains")
        .toolbar {
            if !viewModel.history.isEmpty {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Date Range", selection: $viewModel.historyDateFilter) {
                            ForEach(HistoryDateFilter.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }

                        Picker("Change Filter", selection: $viewModel.historyChangeFilter) {
                            ForEach(ChangeFilterOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }

                        Picker("Sort", selection: $viewModel.historySortOption) {
                            ForEach(HistorySortOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }

                        Button("Clear All", role: .destructive) {
                            showClearAllConfirmation = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }

                    EditButton()
                }
            }
        }
        .alert("Clear history?", isPresented: $showClearAllConfirmation) {
            Button("Clear All", role: .destructive) {
                viewModel.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all saved history entries. This cannot be undone.")
        }
        .onChange(of: viewModel.rerunNavigationToken) { _, _ in
            dismiss()
        }
        .preferredColorScheme(.dark)
    }

    private func deleteFilteredHistoryEntries(at offsets: IndexSet) {
        let ids = offsets.map { viewModel.filteredHistory[$0].id }
        viewModel.removeHistoryEntries(withIDs: ids)
    }
}

struct HistoryDetailView: View {
    @Environment(\.appDensity) private var appDensity
    @Bindable var viewModel: DomainViewModel
    let entry: HistoryEntry
    @Environment(\.dismiss) private var dismiss

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var snapshot: LookupSnapshot {
        entry.snapshot
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                snapshotBanner
                SummaryView(fields: DomainViewModel.summaryFields(from: snapshot))
                    .padding(.top, 8)
                DomainSectionView(
                    isCollapsed: .constant(false),
                    rows: DomainViewModel.domainRows(from: snapshot),
                    suggestions: DomainViewModel.suggestionRows(from: snapshot),
                    showSuggestions: entry.availabilityResult?.status == .registered && !entry.suggestions.isEmpty,
                    availabilityLoading: false,
                    suggestionsLoading: false,
                    trackedDomain: viewModel.trackedDomains.first(where: { $0.domain.lowercased() == entry.domain.lowercased() }),
                    trackingLimitMessage: nil,
                    onTrack: {
                        _ = viewModel.trackDomain(domain: entry.domain, availabilityStatus: entry.availabilityResult?.status)
                    },
                    onTogglePinned: {
                        guard let trackedDomain = viewModel.trackedDomains.first(where: { $0.domain.lowercased() == entry.domain.lowercased() }) else { return }
                        viewModel.togglePinned(for: trackedDomain)
                    },
                    onEditNote: nil
                )
                    .padding(.top, appDensity.metrics.sectionSpacing)
                OwnershipSectionView(
                    isCollapsed: .constant(false),
                    rows: DomainViewModel.ownershipRows(from: snapshot),
                    loading: false,
                    error: snapshot.ownershipError,
                    showsHistoryPlaceholder: !DataAccessService.hasAccess(to: .ownershipHistory)
                )
                .padding(.top, appDensity.metrics.sectionSpacing)
                SubdomainsSectionView(
                    isCollapsed: .constant(false),
                    rows: DomainViewModel.subdomainRows(from: snapshot),
                    loading: false,
                    error: snapshot.subdomainsError,
                    showsExtendedPlaceholder: !DataAccessService.hasAccess(to: .extendedSubdomains)
                )
                .padding(.top, appDensity.metrics.sectionSpacing)
                if let comparisonSnapshot = viewModel.comparisonSnapshot(for: entry) {
                    if let changeSummary = entry.changeSummary {
                        DomainChangeSummaryView(summary: changeSummary)
                            .padding(.top, appDensity.metrics.sectionSpacing)
                    }
                    DomainDiffView(
                        title: "Compared With Previous Snapshot",
                        sections: DomainDiffService.diff(from: comparisonSnapshot, to: snapshot),
                        showsUnchanged: false
                    )
                    .padding(.top, appDensity.metrics.sectionSpacing)
                }
                DNSSectionView(
                    isCollapsed: .constant(false),
                    dnssecLabel: DomainViewModel.dnssecLabel(from: snapshot),
                    sections: DomainViewModel.dnsRows(from: snapshot),
                    ptrMessage: DomainViewModel.ptrMessage(from: snapshot),
                    loading: false,
                    sectionError: snapshot.dnsError
                )
                .padding(.top, appDensity.metrics.sectionSpacing)
                WebSectionView(
                    isCollapsed: .constant(false),
                    certificateRows: DomainViewModel.webCertificateRows(from: snapshot),
                    sslInfo: snapshot.sslInfo,
                    sslLoading: false,
                    sslError: snapshot.sslError,
                    responseRows: DomainViewModel.webResponseRows(from: snapshot),
                    headers: snapshot.httpHeaders,
                    headersLoading: false,
                    headersError: snapshot.httpHeadersError,
                    redirects: DomainViewModel.redirectRows(from: snapshot),
                    redirectLoading: false,
                    redirectError: snapshot.redirectChainError,
                    finalURL: snapshot.redirectChain.last?.url
                )
                .padding(.top, appDensity.metrics.sectionSpacing)
                EmailSectionView(
                    isCollapsed: .constant(false),
                    rows: DomainViewModel.emailRows(from: snapshot),
                    loading: false,
                    error: snapshot.emailSecurityError
                )
                .padding(.top, appDensity.metrics.sectionSpacing)
                NetworkSectionView(
                    isCollapsed: .constant(false),
                    reachabilityRows: DomainViewModel.reachabilityRows(from: snapshot),
                    reachabilityLoading: false,
                    reachabilityError: snapshot.reachabilityError,
                    locationRows: DomainViewModel.locationRows(from: snapshot),
                    geolocation: snapshot.ipGeolocation,
                    geolocationLoading: false,
                    geolocationError: snapshot.ipGeolocationError,
                    standardPortRows: DomainViewModel.portRows(from: snapshot, kind: .standard),
                    customPortRows: DomainViewModel.portRows(from: snapshot, kind: .custom),
                    portScanLoading: false,
                    portScanError: snapshot.portScanError,
                    customPortScanLoading: false,
                    customPortScanError: nil,
                    isCloudflareProxied: snapshot.httpHeaders.contains(where: { $0.name.lowercased() == "cf-ray" }),
                    customPortsExpanded: .constant(false),
                    customPortInput: .constant(""),
                    onScanCustomPorts: {}
                )
                .padding(.top, appDensity.metrics.sectionSpacing)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color.black)
        .navigationTitle(entry.domain)
        .toolbar {
            Button("Re-run") {
                viewModel.rerunLookup(from: entry)
            }
        }
        .onChange(of: viewModel.rerunNavigationToken) { _, _ in
            dismiss()
        }
        .preferredColorScheme(.dark)
    }

    private var snapshotBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "archivebox")
                .font(.caption)
            Text("Snapshot from \(dateFormatter.string(from: entry.timestamp))")
                .font(appDensity.font(.caption))
            Spacer()
            Text("Live re-run available")
                .font(appDensity.font(.caption2))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.secondary)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: appDensity.metrics.cardCornerRadius))
        .padding(.vertical, 12)
    }
}

private struct HistoryGroup: Identifiable {
    let title: String
    let entries: [HistoryEntry]

    var id: String { title }

    static func groups(for entries: [HistoryEntry]) -> [HistoryGroup] {
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let grouped = Dictionary(grouping: entries) { entry -> String in
            if calendar.isDate(entry.timestamp, inSameDayAs: today) {
                return "Today"
            }
            if calendar.isDate(entry.timestamp, inSameDayAs: yesterday) {
                return "Yesterday"
            }
            return "Older"
        }

        return ["Today", "Yesterday", "Older"].compactMap { title in
            guard let entries = grouped[title], !entries.isEmpty else { return nil }
            return HistoryGroup(title: title, entries: entries)
        }
    }
}
