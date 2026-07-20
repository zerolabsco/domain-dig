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
        try AccessibilityAuditHarness.audit(app, screen: "inspect", test: self)
    }

    func testDashboardScreen() throws {
        let app = AccessibilityAuditHarness.launch()
        app.selectRootTab("Dashboard")
        try AccessibilityAuditHarness.audit(app, screen: "dashboard", test: self)
    }

    func testAuditScreen() throws {
        let app = AccessibilityAuditHarness.launch()
        app.selectRootTab("Audit")
        try AccessibilityAuditHarness.audit(app, screen: "audit", test: self)
    }

    func testHistoryScreen() throws {
        let app = AccessibilityAuditHarness.launch()
        app.selectRootTab("History")
        try AccessibilityAuditHarness.audit(app, screen: "history", test: self)
    }

    func testSettingsScreen() throws {
        let app = AccessibilityAuditHarness.launch()
        app.selectRootTab("Settings")
        try AccessibilityAuditHarness.audit(app, screen: "settings", test: self)
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

        try AccessibilityAuditHarness.audit(app, screen: "tracked-domains", test: self)
    }

    // MARK: Dynamic Type

    /// Re-audits every root screen at the largest accessibility content size.
    ///
    /// This is where clipped text and fixed-height containers surface — the
    /// `.accessibility5`-class failures that the fixed geometry in
    /// `AppDensityMetrics` is expected to produce until phase 3 of #21 lands.
    func testAllScreensAtLargestAccessibilitySize() throws {
        let app = AccessibilityAuditHarness.launch(
            contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )

        for tab in ["Inspect", "Dashboard", "Audit", "History", "Settings"] {
            app.selectRootTab(tab)
            try AccessibilityAuditHarness.audit(
                app,
                screen: "\(tab.lowercased())-accessibilityXXXL",
                test: self
            )
        }
    }
}
