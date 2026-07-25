import XCTest
@testable import DomainDig

/// Tests for the App Info surface's deterministic logic: the mailto builder, the
/// version display format, and that the bundled release notes ship and parse.
final class AppInfoTests: XCTestCase {

    func testMailURLEncodesSubjectAndBody() throws {
        let url = try XCTUnwrap(AppInfoView.mailURL(
            to: "hello@zerolabs.sh",
            subject: "DomainDig Issue Report",
            body: "line one\nline two"
        ))

        XCTAssertEqual(url.scheme, "mailto")
        let string = url.absoluteString
        XCTAssertTrue(string.hasPrefix("mailto:hello@zerolabs.sh?"))
        XCTAssertTrue(string.contains("subject=DomainDig%20Issue%20Report"))
        XCTAssertTrue(string.contains("body=line%20one%0Aline%20two"))
    }

    func testMailURLOmitsEmptyQueryItems() throws {
        let url = try XCTUnwrap(AppInfoView.mailURL(to: "hello@zerolabs.sh", subject: "", body: ""))
        XCTAssertEqual(url.absoluteString, "mailto:hello@zerolabs.sh")
    }

    func testVersionDisplayPairsMarketingVersionAndBuild() {
        XCTAssertEqual(AppInfo.versionDisplay, "\(AppInfo.marketingVersion) (build \(AppInfo.buildNumber))")
    }

    func testDiagnosticsReportContainsVersionOSAndModelOnly() {
        let report = AppInfo.diagnosticsReport
        XCTAssertTrue(report.contains(AppInfo.marketingVersion))
        XCTAssertTrue(report.contains(AppInfo.systemVersion))
        XCTAssertTrue(report.contains(AppInfo.deviceModel))
        // Three lines, nothing more — no identifiers beyond version/OS/model.
        XCTAssertEqual(report.split(separator: "\n").count, 3)
    }

    func testBundledReleaseNotesShipAndParse() throws {
        let notes = try XCTUnwrap(ReleaseNotes.bundled(), "ReleaseNotes.json must be bundled and decodable")
        XCTAssertFalse(notes.version.isEmpty)
        XCTAssertFalse(notes.highlights.isEmpty)
    }
}
