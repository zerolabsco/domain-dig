import XCTest

/// Shared plumbing for the accessibility audit suite.
///
/// `performAccessibilityAudit` checks contrast, hit-region size, clipped text at
/// large Dynamic Type, element descriptions, and trait correctness — the same
/// categories the accessibility pass in issue #21 works through.
///
/// **The suite reports by default and fails only for enforced categories.** The
/// audit surfaces violations that exist today, so failing on everything would
/// block unrelated PRs until the whole pass lands. `enforcedAuditTypes` below is
/// the ratchet: widen it as each phase of #21 clears a category.
///
/// Two alternatives were tried and rejected:
///
/// - *A per-screen baseline count.* Audit coverage is not nested across OS
///   versions — the same screen legitimately yields different counts on the
///   floor simulator and the current one, so no single committed number is
///   correct for both.
/// - *An environment variable.* Neither a plain `xcodebuild` env var nor a
///   `TEST_RUNNER_`-prefixed build setting reaches this process, so the toggle
///   silently did nothing. A committed constant also makes "when did contrast
///   become enforced?" answerable with `git blame` instead of CI tribal
///   knowledge.
@MainActor
enum AccessibilityAuditHarness {
    /// Launch argument that lifts feature gating so Pro-only screens are
    /// reachable. `PurchaseService` honours this in `DEBUG` builds only.
    private static let forceProPlusArgument = "DOMAIN_DIG_FORCE_PRO_PLUS"

    /// Audit categories that fail the build. Everything else is reported only.
    ///
    /// Empty until the accessibility pass starts landing. Suggested ratchet,
    /// following the phases in issue #21:
    ///
    /// - after phase 2 (semantic colors + light mode): `.contrast`
    /// - after phase 3 (Dynamic Type + reflow): `.textClipped`, `.dynamicType`,
    ///   `.hitRegion`
    /// - after phase 4 (VoiceOver): `.elementDetection`,
    ///   `.sufficientElementDescription`, `.trait`
    static let enforcedAuditTypes: XCUIAccessibilityAuditType = []

    /// How many times to retry an audit that misses its internal deadline.
    private static let auditAttempts = 3

    /// Launches the app with feature gating lifted, optionally at a specific
    /// content size category.
    static func launch(contentSizeCategory: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [forceProPlusArgument]
        if let contentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
        }
        app.launch()
        return app
    }

    /// Runs a full audit and records every finding against the test.
    ///
    /// Findings are logged and attached to the result bundle so a CI run
    /// produces the burndown list as an artifact rather than only a pass/fail.
    ///
    /// Returns `false` if the audit could not complete, leaving the screen
    /// unaudited. Callers turn that into an `XCTSkip` — reporting a pass would
    /// claim coverage that did not happen.
    @discardableResult
    static func audit(
        _ app: XCUIApplication,
        screen: String,
        test: XCTestCase
    ) throws -> Bool {
        var findings: [String] = []
        var timeout: Error?

        // The audit traverses the whole element tree and has its own internal
        // deadline, which slower CI runners miss on the denser screens. That is a
        // tooling timeout, not an app defect, so retry before giving up.
        //
        // Only the timeout is retried. If a category is enforced and the audit
        // reports findings before timing out, those failures are already recorded
        // and a retry would duplicate them — accepted, because the alternative is
        // losing the run to an infrastructure hiccup.
        for attempt in 1...auditAttempts {
            findings.removeAll()
            timeout = nil
            do {
                try app.performAccessibilityAudit { issue in
                    let isEnforced = !enforcedAuditTypes.intersection(issue.auditType).isEmpty
                    let marker = isEnforced ? "FAIL" : "report"
                    findings.append("[\(marker)][\(name(for: issue.auditType))] \(issue.compactDescription)")
                    // true suppresses the finding, false reports it as a test failure.
                    return !isEnforced
                }
                break
            } catch let error as NSError where error.isAccessibilityAuditTimeout {
                timeout = error
                print("\(screen): audit timed out (attempt \(attempt) of \(auditAttempts))")
            }
        }

        if timeout != nil {
            let message = "\(screen): audit did not complete in time after \(auditAttempts) attempts — screen NOT audited"
            print(message)
            let attachment = XCTAttachment(string: message)
            attachment.name = "a11y-audit-\(screen)-timeout"
            attachment.lifetime = .keepAlways
            test.add(attachment)
            return false
        }

        let summary = findings.isEmpty
            ? "\(screen): no accessibility findings"
            : "\(screen): \(findings.count) finding(s)\n" + findings.sorted().map { "  • \($0)" }.joined(separator: "\n")

        print(summary)

        let attachment = XCTAttachment(string: summary)
        attachment.name = "a11y-audit-\(screen)"
        attachment.lifetime = .keepAlways
        test.add(attachment)

        return true
    }

    /// `XCUIAccessibilityAuditType` is an option set whose description is just a
    /// raw bitmask, which makes the burndown list unreadable. Resolve it against
    /// the named members rather than hard-coding bit positions, so this keeps
    /// working if Apple adds audit types.
    private static func name(for type: XCUIAccessibilityAuditType) -> String {
        let known: [(XCUIAccessibilityAuditType, String)] = [
            (.contrast, "contrast"),
            (.elementDetection, "elementDetection"),
            (.hitRegion, "hitRegion"),
            (.sufficientElementDescription, "sufficientElementDescription"),
            (.dynamicType, "dynamicType"),
            (.textClipped, "textClipped"),
            (.trait, "trait")
        ]
        let matched = known.filter { type.contains($0.0) }.map(\.1)
        return matched.isEmpty ? "unknown(\(type.rawValue))" : matched.joined(separator: "+")
    }
}

private extension NSError {
    /// `Audit failed to complete in time` — the audit's own deadline, raised by
    /// XCTest rather than by anything wrong with the app.
    var isAccessibilityAuditTimeout: Bool {
        domain == "com.apple.xcode.xctest.accessibilityAudit" && code == -56
    }
}

extension XCUIApplication {
    /// Taps a root tab by its visible label.
    ///
    /// Falls back to a plain button query because the tab bar is only present in
    /// the compact size class — in regular width `RootTabView` renders a
    /// `NavigationSplitView` sidebar instead.
    @MainActor
    func selectRootTab(_ name: String) {
        let tabButton = tabBars.buttons[name]
        let element = tabButton.waitForExistence(timeout: 5) ? tabButton : buttons[name]
        XCTAssertTrue(
            element.waitForExistence(timeout: 5),
            "Could not find a way to reach the \(name) screen"
        )
        element.tap()
    }
}
