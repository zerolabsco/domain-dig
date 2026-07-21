import SwiftUI
import WidgetKit

struct DomainDigEntry: TimelineEntry {
    let date: Date
    let data: DomainDigWidgetData
}

struct DomainDigProvider: TimelineProvider {
    func placeholder(in _: Context) -> DomainDigEntry {
        DomainDigEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DomainDigEntry) -> Void) {
        let data = context.isPreview ? .placeholder : (DomainDigWidgetStore.read() ?? .placeholder)
        completion(DomainDigEntry(date: Date(), data: data))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<DomainDigEntry>) -> Void) {
        let data = DomainDigWidgetStore.read() ?? .empty
        let entry = DomainDigEntry(date: Date(), data: data)
        // The app reloads timelines on foreground and on watchlist changes; this
        // periodic refresh is a backstop so cert countdowns stay roughly current.
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date())
            ?? Date().addingTimeInterval(6 * 3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct DomainDigPortfolioWidget: Widget {
    let kind = "DomainDigPortfolioWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DomainDigProvider()) { entry in
            DomainDigWidgetView(data: entry.data)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Domain Portfolio")
        .description("Health and certificate status for your tracked domains.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct DomainDigWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let data: DomainDigWidgetData

    var body: some View {
        if data.totalDomains == 0 {
            emptyState
        } else {
            if family == .systemSmall {
                smallView
            } else {
                mediumOrLargeView
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(Color(.appTextSecondary))
            Text("No tracked domains")
                .font(.caption)
                .foregroundStyle(Color(.appTextSecondary))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "shield.lefthalf.filled")
                Text("DomainDig")
                    .fontWeight(.semibold)
                Spacer()
            }
            .font(.caption2)
            .foregroundStyle(Color(.appTextSecondary))

            Text("\(data.totalDomains)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("tracked")
                .font(.caption2)
                .foregroundStyle(Color(.appTextSecondary))

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                countPill(data.healthyCount, Color(.statusPositive))
                countPill(data.warningCount, Color(.statusWarning))
                countPill(data.criticalCount, Color(.statusCritical))
            }
        }
    }

    private func countPill(_ value: Int, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(value)").font(.caption).fontWeight(.medium)
        }
    }

    // MARK: Medium / Large

    private var mediumOrLargeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Domain Portfolio", systemImage: "shield.lefthalf.filled")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.appTextSecondary))
                Spacer()
                Text("\(data.totalDomains) tracked")
                    .font(.caption2)
                    .foregroundStyle(Color(.appTextSecondary))
            }

            HStack(spacing: 12) {
                summaryStat(data.healthyCount, "Healthy", Color(.statusPositive))
                summaryStat(data.warningCount, "Warning", Color(.statusWarning))
                summaryStat(data.criticalCount, "Critical", Color(.statusCritical))
                summaryStat(data.expiringSoonCount, "Expiring", Color(.statusWarning))
            }

            Divider()

            VStack(spacing: 6) {
                ForEach(data.domains.prefix(family == .systemLarge ? 6 : 3)) { domain in
                    Link(destination: DomainDigDeepLink.url(for: .detail(domain.domain))) {
                        domainRow(domain)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func summaryStat(_ value: Int, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(.headline)
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Color(.appTextSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func domainRow(_ domain: DomainDigWidgetDomain) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color(for: domain.status))
                .frame(width: 8, height: 8)
            if domain.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color(.appTextSecondary))
            }
            Text(domain.domain)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(certLabel(for: domain))
                .font(.caption2)
                .foregroundStyle(Color(.appTextSecondary))
        }
    }

    private func certLabel(for domain: DomainDigWidgetDomain) -> String {
        guard let days = domain.certDaysRemaining else { return "—" }
        if days < 0 { return "expired" }
        return "\(days)d"
    }

    private func color(for status: DomainDigWidgetStatus) -> Color {
        switch status {
        case .healthy: return Color(.statusPositive)
        case .warning: return Color(.statusWarning)
        case .critical: return Color(.statusCritical)
        }
    }
}
