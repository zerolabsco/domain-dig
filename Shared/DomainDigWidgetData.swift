import Foundation

/// App Group + snapshot shared between the app (writer) and the widget (reader).
///
/// Deliberately self-contained: it references no app-target types (TrackedDomain,
/// PortfolioSnapshot, DomainHealth, …) so it compiles unchanged into the widget
/// extension. The app maps its richer types into these DTOs.
enum DomainDigWidgetStore {
    static let appGroupID = "group.net.cleberg.DomainDig"
    private static let key = "widgetData"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func write(_ data: DomainDigWidgetData) {
        guard let defaults, let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: key)
    }

    static func read() -> DomainDigWidgetData? {
        guard let defaults,
              let encoded = defaults.data(forKey: key),
              let data = try? JSONDecoder().decode(DomainDigWidgetData.self, from: encoded)
        else { return nil }
        return data
    }
}

struct DomainDigWidgetData: Codable, Sendable {
    var generatedAt: Date
    var totalDomains: Int
    var healthyCount: Int
    var warningCount: Int
    var criticalCount: Int
    var expiringSoonCount: Int
    var unreachableCount: Int
    var domains: [DomainDigWidgetDomain]

    static let placeholder = DomainDigWidgetData(
        generatedAt: .distantPast,
        totalDomains: 3,
        healthyCount: 2,
        warningCount: 1,
        criticalCount: 0,
        expiringSoonCount: 1,
        unreachableCount: 0,
        domains: [
            DomainDigWidgetDomain(domain: "example.com", isPinned: true, status: .healthy, certDaysRemaining: 240, lastChange: nil),
            DomainDigWidgetDomain(domain: "cleberg.net", isPinned: false, status: .warning, certDaysRemaining: 21, lastChange: nil),
            DomainDigWidgetDomain(domain: "example.org", isPinned: false, status: .healthy, certDaysRemaining: 88, lastChange: nil)
        ]
    )

    /// Empty state used before the app has written any data.
    static let empty = DomainDigWidgetData(
        generatedAt: .distantPast,
        totalDomains: 0,
        healthyCount: 0,
        warningCount: 0,
        criticalCount: 0,
        expiringSoonCount: 0,
        unreachableCount: 0,
        domains: []
    )
}

struct DomainDigWidgetDomain: Codable, Sendable, Identifiable {
    var domain: String
    var isPinned: Bool
    var status: DomainDigWidgetStatus
    var certDaysRemaining: Int?
    var lastChange: Date?

    var id: String { domain }
}

enum DomainDigWidgetStatus: String, Codable, Sendable {
    case healthy
    case warning
    case critical
}
