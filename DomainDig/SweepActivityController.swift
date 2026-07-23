import ActivityKit
import Foundation

/// Starts, updates, and ends the sweep Live Activity around a batch run.
///
/// Holds the activity's `id` (a Sendable `String`) rather than the
/// `Activity` object itself. `Activity` is not Sendable, and sending the
/// stored reference into the fire-and-forget update task while `self` still
/// held it was a Swift 6 region-isolation violation (issue #27). Each task
/// re-resolves the activity via `Activity.activities`, ActivityKit's
/// sanctioned lookup, so nothing non-Sendable crosses an isolation boundary.
@MainActor
final class SweepActivityController {
    static let shared = SweepActivityController()

    private var activityID: String?

    private init() { /* Singleton; use the shared instance. */ }

    func begin(title: String, total: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // A previous activity that never ended (e.g. app killed mid-sweep)
        // would otherwise linger; replace it.
        end(changed: 0, warnings: 0, immediately: true)

        let state = SweepActivityAttributes.ContentState(
            completed: 0,
            total: total,
            currentDomain: nil,
            changed: 0,
            warnings: 0
        )
        let activity = try? Activity.request(
            attributes: SweepActivityAttributes(title: title, startedAt: Date()),
            content: ActivityContent(state: state, staleDate: nil)
        )
        activityID = activity?.id
    }

    func update(completed: Int, total: Int, currentDomain: String?) {
        guard let activityID else { return }
        let state = SweepActivityAttributes.ContentState(
            completed: completed,
            total: total,
            currentDomain: currentDomain,
            changed: 0,
            warnings: 0
        )
        Task {
            guard let activity = Self.activity(withID: activityID) else { return }
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end(changed: Int, warnings: Int, immediately: Bool = false) {
        guard let activityID else { return }
        self.activityID = nil
        Task {
            guard let activity = Self.activity(withID: activityID) else { return }
            let total = activity.content.state.total
            let state = SweepActivityAttributes.ContentState(
                completed: total,
                total: total,
                currentDomain: nil,
                changed: changed,
                warnings: warnings
            )
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: immediately ? .immediate : .after(Date().addingTimeInterval(60))
            )
        }
    }

    private nonisolated static func activity(withID id: String) -> Activity<SweepActivityAttributes>? {
        Activity<SweepActivityAttributes>.activities.first { $0.id == id }
    }
}
