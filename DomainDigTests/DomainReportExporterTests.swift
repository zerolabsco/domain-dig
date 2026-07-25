import XCTest
@testable import DomainDig

/// Characterization tests for the export surface. These pin the format dispatch,
/// the JSON round-trip (the canonical machine contract), and the structural
/// invariants of the human-readable formats.
final class DomainReportExporterTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testEveryFormatProducesNonEmptyData() throws {
        let report = SnapshotFixture.report(availability: .registered)
        for format in DomainExportFormat.allCases {
            let data = try DomainReportExporter.data(for: report, format: format)
            XCTAssertFalse(data.isEmpty, "\(format.rawValue) export was empty")
        }
    }

    func testJSONExportRoundTripsToReport() throws {
        let report = SnapshotFixture.report(domain: "roundtrip.example", availability: .registered)

        let data = try DomainReportExporter.data(for: report, format: .json)
        let decoded = try decoder.decode(DomainReport.self, from: data)

        XCTAssertEqual(decoded.domain, "roundtrip.example")
        XCTAssertEqual(decoded.availability, .registered)
        XCTAssertEqual(decoded.timestamp, report.timestamp)
    }

    func testBatchJSONExportRoundTripsToReportArray() throws {
        let reports = [
            SnapshotFixture.report(domain: "one.example"),
            SnapshotFixture.report(domain: "two.example")
        ]

        let data = try DomainReportExporter.data(for: reports, format: .json, title: "Batch")
        let decoded = try decoder.decode([DomainReport].self, from: data)

        XCTAssertEqual(decoded.map(\.domain), ["one.example", "two.example"])
    }

    func testCSVHasHeaderAndOneRowPerReport() {
        let reports = [
            SnapshotFixture.report(domain: "alpha.example"),
            SnapshotFixture.report(domain: "beta.example")
        ]

        let csv = DomainReportExporter.csv(for: reports)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)

        XCTAssertEqual(lines.count, 3, "one header line plus one row per report")
        XCTAssertTrue(lines[0].contains("\"domain\""))
        XCTAssertTrue(csv.contains("\"alpha.example\""))
        XCTAssertTrue(csv.contains("\"beta.example\""))
    }

    func testMarkdownIsHeadedAndNamesTheDomain() {
        let markdown = DomainReportExporter.markdown(for: SnapshotFixture.report(domain: "md.example"))

        XCTAssertTrue(markdown.hasPrefix("# "), "markdown export should open with an H1")
        XCTAssertTrue(markdown.contains("md.example"))
    }

    func testTextExportNamesTheDomain() {
        let text = DomainReportExporter.text(for: SnapshotFixture.report(domain: "txt.example"))
        XCTAssertTrue(text.contains("txt.example"))
    }

    func testBatchExportsCarryTitleAndEveryDomain() {
        let reports = [
            SnapshotFixture.report(domain: "first.example"),
            SnapshotFixture.report(domain: "second.example")
        ]

        let markdown = DomainReportExporter.batchMarkdown(for: reports, title: "Portfolio Sweep")
        XCTAssertTrue(markdown.contains("Portfolio Sweep"))
        XCTAssertTrue(markdown.contains("first.example"))
        XCTAssertTrue(markdown.contains("second.example"))

        let text = DomainReportExporter.batchText(for: reports, title: "Portfolio Sweep")
        XCTAssertTrue(text.contains("Portfolio Sweep"))
        XCTAssertTrue(text.contains("first.example"))
        XCTAssertTrue(text.contains("second.example"))
    }

    func testPDFExportHasPDFSignature() throws {
        let data = try DomainReportExporter.data(for: SnapshotFixture.report(), format: .pdf)
        XCTAssertTrue(data.starts(with: Array("%PDF".utf8)), "PDF export should begin with the %PDF signature")
    }

    func testTimelineTextNamesTheDomain() {
        let reports = [
            SnapshotFixture.report(domain: "timeline.example", timestamp: SnapshotFixture.referenceDate),
            SnapshotFixture.report(
                domain: "timeline.example",
                timestamp: SnapshotFixture.referenceDate.addingTimeInterval(86_400)
            )
        ]

        let text = DomainReportExporter.timelineText(for: reports, domain: "timeline.example", includeDiffSummary: false)
        XCTAssertTrue(text.contains("timeline.example"))
    }
}
