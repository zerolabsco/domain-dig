import Foundation
import WidgetKit

extension DomainViewModel {
    /// Publishes the current portfolio state to the App Group container so the
    /// widget can render it, then asks WidgetKit to refresh its timelines.
    func refreshWidgetData() {
        #if DEBUG
        // Fixture sessions must not write fixture domains into the shared
        // widget store — it is an App Group file that outlives the launch.
        if auditFixturesActive { return }
        #endif
        let data = portfolioDashboardData
        let snapshot = data.snapshot

        let ordered = data.domainStates.sorted { lhs, rhs in
            if lhs.trackedDomain.isPinned != rhs.trackedDomain.isPinned {
                return lhs.trackedDomain.isPinned
            }
            return lhs.health.widgetSeverityRank > rhs.health.widgetSeverityRank
        }

        let domains = ordered.prefix(6).map { state in
            DomainDigWidgetDomain(
                domain: state.trackedDomain.domain,
                isPinned: state.trackedDomain.isPinned,
                status: state.health.widgetStatus,
                certDaysRemaining: state.certificateDaysRemaining,
                lastChange: state.lastChangeDate
            )
        }

        DomainDigWidgetStore.write(
            DomainDigWidgetData(
                generatedAt: Date(),
                totalDomains: snapshot.totalDomains,
                healthyCount: snapshot.healthyCount,
                warningCount: snapshot.warningCount,
                criticalCount: snapshot.criticalCount,
                expiringSoonCount: snapshot.expiringSoonCount,
                unreachableCount: snapshot.unreachableCount,
                domains: Array(domains)
            )
        )
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private extension DomainHealth {
    var widgetStatus: DomainDigWidgetStatus {
        switch self {
        case .healthy: return .healthy
        case .warning: return .warning
        case .critical: return .critical
        }
    }

    var widgetSeverityRank: Int {
        switch self {
        case .healthy: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }
}
