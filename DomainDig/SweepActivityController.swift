import ActivityKit
import Foundation

/// Starts, updates, and ends the sweep Live Activity around a batch run.
@MainActor
final class SweepActivityController {
    static let shared = SweepActivityController()

    private var activity: Activity<SweepActivityAttributes>?

    private init() {}

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
        activity = try? Activity.request(
            attributes: SweepActivityAttributes(title: title, startedAt: Date()),
            content: ActivityContent(state: state, staleDate: nil)
        )
    }

    func update(completed: Int, total: Int, currentDomain: String?) {
        guard let activity else { return }
        let state = SweepActivityAttributes.ContentState(
            completed: completed,
            total: total,
            currentDomain: currentDomain,
            changed: 0,
            warnings: 0
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end(changed: Int, warnings: Int, immediately: Bool = false) {
        guard let activity else { return }
        self.activity = nil
        let state = SweepActivityAttributes.ContentState(
            completed: activity.content.state.total,
            total: activity.content.state.total,
            currentDomain: nil,
            changed: changed,
            warnings: warnings
        )
        Task {
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: immediately ? .immediate : .after(Date().addingTimeInterval(60))
            )
        }
    }
}
