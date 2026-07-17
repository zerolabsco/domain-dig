import Foundation

/// App Group handoff from the share extension to the app.
///
/// Share extensions cannot reliably open their host app, so the extension
/// drops the shared domain here and the app consumes it the next time it
/// becomes active, routing it into an inspection.
enum DomainDigShareInbox {
    private static let key = "pendingInspectDomain"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: DomainDigWidgetStore.appGroupID)
    }

    static func write(domain: String) {
        defaults?.set(domain, forKey: key)
    }

    /// Returns and clears the pending domain, if any.
    static func consume() -> String? {
        guard let defaults,
              let domain = defaults.string(forKey: key),
              !domain.isEmpty
        else { return nil }
        defaults.removeObject(forKey: key)
        return domain
    }
}
