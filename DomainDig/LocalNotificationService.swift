import Foundation
import UserNotifications

@MainActor
final class LocalNotificationService {
    static let shared = LocalNotificationService()

    private init() {}

    static let domainUserInfoKey = "domain"
    static let domainCategoryIdentifier = "domain-event"
    static let reinspectActionIdentifier = "reinspect"

    func configureForegroundPresentation() {
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationCenterDelegate.shared

        let reinspect = UNNotificationAction(
            identifier: Self.reinspectActionIdentifier,
            title: "Re-inspect",
            options: []
        )
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.domainCategoryIdentifier,
                actions: [reinspect],
                intentIdentifiers: [],
                options: []
            )
        ])
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func isAuthorizedForAlerts() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    func notifyDomainEvent(domain: String, message: String, severity: ChangeSeverity) async {
        await schedule(
            identifier: "domain-change-\(domain)",
            title: domain,
            body: message,
            interruptionLevel: severity == .high ? .timeSensitive : .active,
            domain: domain
        )
    }

    func notifyCertificateWarning(domain: String, daysRemaining: Int) async {
        await schedule(
            identifier: "cert-warning-\(domain)",
            title: domain,
            body: "Certificate expires in \(daysRemaining) days",
            interruptionLevel: .timeSensitive,
            domain: domain
        )
    }

    func notifyMonitoringAlert(
        domain: String,
        message: String,
        severity: MonitoringAlertSeverity
    ) async {
        let interruptionLevel: UNNotificationInterruptionLevel
        switch severity {
        case .critical:
            interruptionLevel = .timeSensitive
        case .warning, .info:
            interruptionLevel = .active
        }

        await schedule(
            identifier: "monitoring-\(domain)-\(UUID().uuidString)",
            title: domain,
            body: message,
            interruptionLevel: interruptionLevel,
            domain: domain
        )
    }

    func notifyMonitoringSummary(
        domain: String,
        alerts: [MonitoringPendingAlert]
    ) async {
        let summary = alerts
            .sorted { $0.detectedAt < $1.detectedAt }
            .prefix(2)
            .map(\.message)
            .joined(separator: " • ")
        let body: String
        if alerts.count <= 1 {
            body = alerts.first?.message ?? "Monitoring change detected"
        } else if summary.isEmpty {
            body = "\(alerts.count) monitoring changes detected"
        } else {
            body = "\(alerts.count) monitoring changes: \(summary)"
        }

        let severity = alerts.map(\.severity).max() ?? .info
        let interruptionLevel: UNNotificationInterruptionLevel = severity == .critical ? .timeSensitive : .active

        await schedule(
            identifier: "monitoring-summary-\(domain)-\(UUID().uuidString)",
            title: domain,
            body: body,
            interruptionLevel: interruptionLevel,
            domain: domain
        )
    }

    func notifySweepComplete(summary: BatchSweepSummary) async {
        let body = "\(summary.changedDomains) changed, \(summary.warningDomains) warnings, \(summary.unchangedDomains) unchanged"
        await schedule(
            identifier: "sweep-complete",
            title: summary.source == .watchlistRefresh ? "Check All Complete" : "Batch Complete",
            body: body,
            interruptionLevel: .active
        )
    }

    func clearAllNotifications() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private func schedule(
        identifier: String,
        title: String,
        body: String,
        interruptionLevel: UNNotificationInterruptionLevel,
        domain: String? = nil
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = interruptionLevel
        if let domain {
            // Group alerts per domain and let taps/actions route back into it.
            content.threadIdentifier = domain
            content.userInfo = [Self.domainUserInfoKey: domain]
            content.categoryIdentifier = Self.domainCategoryIdentifier
        }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}

private final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let domain = userInfo[LocalNotificationService.domainUserInfoKey] as? String,
              !domain.isEmpty
        else { return }

        let action: DomainDigDeepLink.Action
        switch response.actionIdentifier {
        case LocalNotificationService.reinspectActionIdentifier:
            action = .inspect(domain)
        default:
            // Default tap: open the tracked domain's detail.
            action = .detail(domain)
        }

        await MainActor.run {
            DomainDigIntentRouter.shared.pendingAction = action
        }
    }
}
