import XCTest
@testable import DomainDig

/// Characterization tests for the snapshot → report projection. These lock the
/// field-mapping and derivation rules the export/diff contracts depend on.
final class DomainReportBuilderTests: XCTestCase {
    private let builder = DomainReportBuilder()

    func testCoreIdentityFieldsPassThrough() {
        let report = builder.build(
            from: SnapshotFixture.snapshot(
                domain: "mapped.example",
                resolverURLString: "https://r.example/dns-query"
            ),
            deriveChangeSummary: false
        )

        XCTAssertEqual(report.domain, "mapped.example")
        XCTAssertEqual(report.timestamp, SnapshotFixture.referenceDate)
        XCTAssertEqual(report.resolverURLString, "https://r.example/dns-query")
        XCTAssertFalse(report.metadata.schemaVersion.isEmpty)
    }

    func testAvailabilityDefaultsToUnknownWhenAbsent() {
        let unknown = builder.build(from: SnapshotFixture.snapshot(availability: nil), deriveChangeSummary: false)
        XCTAssertEqual(unknown.availability, .unknown)

        let registered = builder.build(from: SnapshotFixture.snapshot(availability: .registered), deriveChangeSummary: false)
        XCTAssertEqual(registered.availability, .registered)
    }

    func testPrimaryIPComesFromFirstARecord() {
        let report = builder.build(
            from: SnapshotFixture.snapshot(
                dnsSections: [
                    SnapshotFixture.dnsSection(type: .A, values: ["198.51.100.7", "198.51.100.8"]),
                    SnapshotFixture.dnsSection(type: .AAAA, values: ["2001:db8::1"])
                ]
            ),
            deriveChangeSummary: false
        )

        XCTAssertEqual(report.dns.primaryIP, "198.51.100.7")
        XCTAssertEqual(report.network.primaryIP, "198.51.100.7")
    }

    func testPrimaryIPNilWithoutARecord() {
        let report = builder.build(
            from: SnapshotFixture.snapshot(
                dnsSections: [SnapshotFixture.dnsSection(type: .MX, values: ["mail.example.com"])]
            ),
            deriveChangeSummary: false
        )
        XCTAssertNil(report.dns.primaryIP)
    }

    func testDNSSECDerivedFromSections() {
        let signed = builder.build(
            from: SnapshotFixture.snapshot(
                dnsSections: [SnapshotFixture.dnsSection(type: .A, values: ["203.0.113.1"], dnssecSigned: true)]
            ),
            deriveChangeSummary: false
        )
        XCTAssertEqual(signed.dns.dnssecSigned, true)

        let unknown = builder.build(
            from: SnapshotFixture.snapshot(
                dnsSections: [SnapshotFixture.dnsSection(type: .A, values: ["203.0.113.1"])]
            ),
            deriveChangeSummary: false
        )
        XCTAssertNil(unknown.dns.dnssecSigned)
    }

    func testTLSStatusReflectsCertificatePresence() {
        let valid = builder.build(
            from: SnapshotFixture.snapshot(sslInfo: SnapshotFixture.certificate()),
            deriveChangeSummary: false
        )
        XCTAssertEqual(valid.web.tlsStatus, "valid")

        let missing = builder.build(from: SnapshotFixture.snapshot(sslInfo: nil), deriveChangeSummary: false)
        XCTAssertEqual(missing.web.tlsStatus, "unavailable")
    }

    func testWebHeaderCountAndFinalURL() {
        let report = builder.build(
            from: SnapshotFixture.snapshot(
                httpHeaders: [
                    HTTPHeader(name: "Content-Type", value: "text/html"),
                    HTTPHeader(name: "Strict-Transport-Security", value: "max-age=63072000")
                ],
                httpStatusCode: 200
            ),
            deriveChangeSummary: false
        )

        XCTAssertEqual(report.web.headerCount, 2)
        XCTAssertEqual(report.web.statusCode, 200)
        XCTAssertNil(report.web.finalURL, "no redirect chain means no final URL")
    }

    func testPartialSnapshotAndValidationIssuesPropagate() {
        let report = builder.build(
            from: SnapshotFixture.snapshot(
                isPartialSnapshot: true,
                validationIssues: ["missing DNS", "stale WHOIS"]
            ),
            deriveChangeSummary: false
        )

        XCTAssertTrue(report.isPartialSnapshot)
        XCTAssertEqual(report.validationIssues, ["missing DNS", "stale WHOIS"])
        XCTAssertTrue(report.metadata.isPartialSnapshot)
        XCTAssertEqual(report.metadata.validationIssues, ["missing DNS", "stale WHOIS"])
    }

    func testRecordSectionsArePreserved() {
        let sections = [
            SnapshotFixture.dnsSection(type: .A, values: ["203.0.113.1"]),
            SnapshotFixture.dnsSection(type: .MX, values: ["mail.example.com"])
        ]
        let report = builder.build(
            from: SnapshotFixture.snapshot(dnsSections: sections),
            deriveChangeSummary: false
        )

        XCTAssertEqual(Set(report.dns.recordSections.map(\.recordType)), [.A, .MX])
    }
}
