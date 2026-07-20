import ActivityKit
import Foundation

/// Live Activity contract for an in-flight watchlist sweep or batch lookup.
///
/// Lives in `Shared/` because the app starts/updates the activity and the
/// widget extension renders it. Explicitly `nonisolated`: the app target sets
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which would otherwise infer a
/// main-actor-isolated `ActivityAttributes` conformance that ActivityKit cannot
/// use from its concurrent contexts.
nonisolated struct SweepActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var completed: Int
        var total: Int
        var currentDomain: String?
        var changed: Int
        var warnings: Int

        var fractionComplete: Double {
            guard total > 0 else { return 0 }
            return Double(completed) / Double(total)
        }
    }

    /// User-facing title for the run, e.g. "Watchlist Sweep" or "Batch Lookup".
    var title: String
    var startedAt: Date
}
