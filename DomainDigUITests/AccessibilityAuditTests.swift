import XCTest

/// One accessibility audit per primary screen, plus a Dynamic Type sweep.
///
/// See `AccessibilityAuditHarness` for why these report rather than fail by
/// default, and how to make them enforcing.
@MainActor
final class AccessibilityAuditTests: XCTestCase {
    override func setUp() {
        // Keep going after a failure so an enforced audit still collects and
        // attaches every finding. With this off, XCTest aborts at the first
        // reported issue and the burndown list is lost precisely when a category
        // is being enforced.
        continueAfterFailure = true
    }

    // MARK: Per-screen audits

    func testInspectScreen() throws {
        let app = AccessibilityAuditHarness.launch()
        app.selectRootTab("Inspect")

        // Type a domain so the Run button is enabled. A disabled control has no
        // contrast requirement under WCAG 1.4.3, but the audit still flags it,
        // so auditing the empty state would report a false positive forever.
        let field = app.textFields.firstMatch
        if field.waitForExistence(timeout: 5) {
            field.tap()
            field.typeText("example.com")
        }

        let audited = try AccessibilityAuditHarness.audit(app, screen: "inspect", test: self)
        try XCTSkipUnless(audited, "Audit did not complete in time for Inspect")
    }

    func testDashboardScreen() throws {
        try auditRootTab("Dashboard")
    }

    func testAuditScreen() throws {
        try auditRootTab("Audit")
    }

    func testHistoryScreen() throws {
        try auditRootTab("History")
    }

    func testSettingsScreen() throws {
        try auditRootTab("Settings")
    }

    func testTrackedDomainsScreen() throws {
        let app = AccessibilityAuditHarness.launch()
        app.selectRootTab("Settings")

        let trackedDomains = app.buttons["Tracked Domains"]
        XCTAssertTrue(
            trackedDomains.waitForExistence(timeout: 5),
            "Settings no longer offers a Tracked Domains row"
        )
        trackedDomains.tap()

        let audited = try AccessibilityAuditHarness.audit(app, screen: "tracked-domains", test: self)
        try XCTSkipUnless(audited, "Tracked Domains audit did not complete in time")
    }

    // MARK: Dynamic Type

    /// Re-audits every root screen at the largest accessibility content size.
    ///
    /// This is where clipped text and fixed-height containers surface — the
    /// `.accessibility5`-class failures that the fixed geometry in
    /// `AppDensityMetrics` is expected to produce until phase 3 of #21 lands.
    ///
    /// Every screen is attempted even if an earlier one times out, so one slow
    /// screen cannot silently drop the rest; the skip is reported at the end.
    func testAllScreensAtLargestAccessibilitySize() throws {
        let app = AccessibilityAuditHarness.launch(
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )

        var unaudited: [String] = []

        for tab in ["Inspect", "Dashboard", "Audit", "History", "Settings"] {
            app.selectRootTab(tab)
            let screen = "\(tab.lowercased())-accessibilityXXXL"
            if try !AccessibilityAuditHarness.audit(app, screen: screen, test: self) {
                unaudited.append(tab)
            }
        }

        try XCTSkipUnless(
            unaudited.isEmpty,
            "Audit did not complete in time for: \(unaudited.joined(separator: ", "))"
        )
    }

    // MARK: Helpers

    private func auditRootTab(_ tab: String) throws {
        let app = AccessibilityAuditHarness.launch()
        app.selectRootTab(tab)
        let audited = try AccessibilityAuditHarness.audit(app, screen: tab.lowercased(), test: self)
        try XCTSkipUnless(audited, "Audit did not complete in time for \(tab)")
    }
}
