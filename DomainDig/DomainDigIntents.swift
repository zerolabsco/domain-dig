import AppIntents
import Foundation

/// App Intent that runs a point-in-time domain inspection through the same
/// headless pipeline used by the CLI (`DomainInspectionService` ->
/// `DomainReportBuilder`) and returns a concise summary. Usable from
/// Shortcuts, Spotlight, the Action button, and Siri.
struct InspectDomainIntent: AppIntent {
    static var title: LocalizedStringResource = "Inspect Domain"
    static var description = IntentDescription(
        "Run a DomainDig inspection and return a summary of availability, risk, TLS, email security, and certificate health."
    )

    // Read-only inspection; no need to foreground the app.
    static var openAppWhenRun = false

    @Parameter(
        title: "Domain",
        description: "The domain to inspect, e.g. example.com",
        inputOptions: String.IntentInputOptions(
            keyboardType: .URL,
            capitalizationType: .none
        )
    )
    var domain: String

    static var parameterSummary: some ParameterSummary {
        Summary("Inspect \(\.$domain)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let requested = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requested.isEmpty else {
            throw InspectDomainError.emptyDomain
        }

        let snapshot = await DomainInspectionService().inspectSnapshot(domain: requested)
        let report = DomainReportBuilder().build(from: snapshot)

        let summary = Self.summaryText(for: report)
        let dialog = IntentDialog(stringLiteral: Self.spokenSummary(for: report))
        return .result(value: summary, dialog: dialog)
    }

    /// Multi-line summary suitable for a returned Shortcuts text value.
    static func summaryText(for report: DomainReport) -> String {
        let dnssec: String
        switch report.dns.dnssecSigned {
        case true?: dnssec = "Yes"
        case false?: dnssec = "No"
        case nil: dnssec = "Unknown"
        }

        var lines = [
            "\(report.domain) — \(report.availability.rawValue.capitalized)",
            "Risk: \(report.riskAssessment.level.title) (score \(report.riskAssessment.score))",
            "Health: \(report.health.title)",
            "TLS: \(report.web.tlsGrade.rawValue) · Email: \(report.email.grade?.rawValue ?? "—") · Cert: \(report.certificateExpiryState.title)",
            "IP: \(report.dns.primaryIP ?? "unknown") · DNSSEC: \(dnssec)"
        ]

        if let insight = report.insights.first {
            lines.append(insight)
        }

        return lines.joined(separator: "\n")
    }

    /// Short spoken/dialog line for Siri and the Shortcuts result banner.
    static func spokenSummary(for report: DomainReport) -> String {
        "\(report.domain) is \(report.availability.rawValue). Risk \(report.riskAssessment.level.title.lowercased()), health \(report.health.title.lowercased())."
    }
}

enum InspectDomainError: Error, CustomLocalizedStringResourceConvertible {
    case emptyDomain

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .emptyDomain:
            return "Enter a domain to inspect."
        }
    }
}

/// App Intent that opens DomainDig and adds a domain to the watchlist. It opens
/// the app via the `domaindig://watch` deep link so tracking goes through the
/// existing view-model path (premium limits, monitoring, history linking,
/// cloud-sync recording, and the paywall when over the free limit).
struct AddToWatchlistIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Domain to Watchlist"
    static var description = IntentDescription(
        "Open DomainDig and add a domain to your watchlist."
    )

    static var openAppWhenRun = true

    @Parameter(
        title: "Domain",
        description: "The domain to add, e.g. example.com",
        inputOptions: String.IntentInputOptions(
            keyboardType: .URL,
            capitalizationType: .none
        )
    )
    var domain: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$domain) to the watchlist")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let requested = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requested.isEmpty else {
            throw InspectDomainError.emptyDomain
        }

        // `openAppWhenRun` runs this in the app process, so the router hands the
        // action off to the running UI, which tracks through the existing path.
        DomainDigIntentRouter.shared.pendingAction = .watch(requested)
        return .result()
    }
}

/// App Intent that opens DomainDig and re-inspects every tracked domain. It runs
/// through the existing view-model batch path (`refreshAllTrackedDomains`), which
/// enforces the batch feature gate and surfaces the paywall when needed.
struct RunSweepIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Watchlist Sweep"
    static var description = IntentDescription(
        "Open DomainDig and re-inspect every domain on your watchlist."
    )

    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        DomainDigIntentRouter.shared.pendingAction = .sweep
        return .result()
    }
}

/// In-process hand-off from an `openAppWhenRun` intent to the running SwiftUI
/// layer. `RootTabView` observes `pendingAction` and performs it.
@MainActor
@Observable
final class DomainDigIntentRouter {
    static let shared = DomainDigIntentRouter()
    var pendingAction: DomainDigDeepLink.Action?
    private init() {}
}

/// Exposes DomainDig intents to Spotlight and Siri with invocation phrases.
struct DomainDigShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: InspectDomainIntent(),
            phrases: [
                "Inspect a domain with \(.applicationName)",
                "Dig a domain with \(.applicationName)"
            ],
            shortTitle: "Inspect Domain",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: AddToWatchlistIntent(),
            phrases: [
                "Add a domain to \(.applicationName)",
                "Watch a domain with \(.applicationName)"
            ],
            shortTitle: "Add to Watchlist",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: RunSweepIntent(),
            phrases: [
                "Run a sweep with \(.applicationName)",
                "Sweep my \(.applicationName) watchlist"
            ],
            shortTitle: "Run Sweep",
            systemImageName: "arrow.trianglehead.2.clockwise"
        )
    }
}
