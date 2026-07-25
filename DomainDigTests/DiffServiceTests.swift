import XCTest
@testable import DomainDig

/// Characterization tests for the field-level diff engine. `DiffService` is a
/// pure function over two `DomainReport`s, so every case here pins observable
/// behavior (change classification, normalization, summary phrasing) against a
/// deterministic fixture.
final class DiffServiceTests: XCTestCase {

    func testIdenticalReportsProduceNoChanges() {
        let report = SnapshotFixture.report(
            availability: .registered,
            ownership: DomainOwnership(registrar: "Example Registrar")
        )

        let diff = DiffService.compare(from: report, to: report)

        XCTAssertEqual(diff.changeCount, 0)
        XCTAssertTrue(diff.changedSectionTitles.isEmpty)
        XCTAssertFalse(diff.sections.contains { $0.hasChanges })
    }

    func testAvailabilityTransitionIsReportedAsChanged() {
        let old = SnapshotFixture.report(availability: .available)
        let new = SnapshotFixture.report(availability: .registered)

        let diff = DiffService.compare(from: old, to: new)

        let availability = try? XCTUnwrap(diff.sections.first { $0.id == "availability" })
        let item = availability?.items.first { $0.id == "availability" }
        XCTAssertEqual(item?.changeType, .changed)
        XCTAssertEqual(item?.oldValue, "Available")
        XCTAssertEqual(item?.newValue, "Registered")
        XCTAssertTrue(diff.changedSectionTitles.contains("Domain / Availability"))
    }

    func testPrimaryIPChangeSurfacesInAvailabilitySection() {
        let old = SnapshotFixture.report(
            availability: .registered,
            dnsSections: [SnapshotFixture.dnsSection(type: .A, values: ["203.0.113.10"])]
        )
        let new = SnapshotFixture.report(
            availability: .registered,
            dnsSections: [SnapshotFixture.dnsSection(type: .A, values: ["203.0.113.20"])]
        )

        let diff = DiffService.compare(from: old, to: new)
        let item = diff.sections
            .first { $0.id == "availability" }?
            .items.first { $0.id == "primary-ip" }

        XCTAssertEqual(item?.changeType, .changed)
        XCTAssertEqual(item?.oldValue, "203.0.113.10")
        XCTAssertEqual(item?.newValue, "203.0.113.20")
    }

    func testCaseAndWhitespaceDifferencesAreNotChanges() {
        let old = SnapshotFixture.report(ownership: DomainOwnership(registrar: "GoDaddy"))
        let new = SnapshotFixture.report(ownership: DomainOwnership(registrar: "  godaddy  "))

        let diff = DiffService.compare(from: old, to: new)
        let item = diff.sections
            .first { $0.id == "ownership" }?
            .items.first { $0.id == "registrar" }

        XCTAssertEqual(item?.changeType, .unchanged, "case- and whitespace-only differences must not register as changes")
    }

    func testAddedAndRemovedOwnershipFields() {
        let absent = SnapshotFixture.report(ownership: nil)
        let present = SnapshotFixture.report(ownership: DomainOwnership(registrar: "Example Registrar"))

        let added = DiffService.compare(from: absent, to: present)
            .sections.first { $0.id == "ownership" }?
            .items.first { $0.id == "registrar" }
        XCTAssertEqual(added?.changeType, .added)
        XCTAssertNil(added?.oldValue)
        XCTAssertEqual(added?.newValue, "Example Registrar")

        let removed = DiffService.compare(from: present, to: absent)
            .sections.first { $0.id == "ownership" }?
            .items.first { $0.id == "registrar" }
        XCTAssertEqual(removed?.changeType, .removed)
        XCTAssertEqual(removed?.oldValue, "Example Registrar")
        XCTAssertNil(removed?.newValue)
    }

    func testDNSRecordValueChangeIsDetected() {
        let old = SnapshotFixture.report(
            dnsSections: [SnapshotFixture.dnsSection(type: .NS, values: ["ns1.example.com", "ns2.example.com"])]
        )
        let new = SnapshotFixture.report(
            dnsSections: [SnapshotFixture.dnsSection(type: .NS, values: ["ns1.example.com", "ns3.example.com"])]
        )

        let dns = DiffService.compare(from: old, to: new).sections.first { $0.id == "dns" }
        let records = dns?.items.first { $0.id == "dns-ns-records" }
        XCTAssertEqual(records?.changeType, .changed)
    }

    func testDNSRecordReorderIsNotAChange() {
        // Values are normalized (sorted, lowercased) before comparison, so a pure
        // reorder must diff as unchanged.
        let old = SnapshotFixture.report(
            dnsSections: [SnapshotFixture.dnsSection(type: .NS, values: ["ns1.example.com", "ns2.example.com"])]
        )
        let new = SnapshotFixture.report(
            dnsSections: [SnapshotFixture.dnsSection(type: .NS, values: ["NS2.example.com", "NS1.example.com"])]
        )

        let records = DiffService.compare(from: old, to: new)
            .sections.first { $0.id == "dns" }?
            .items.first { $0.id == "dns-ns-records" }
        XCTAssertEqual(records?.changeType, .unchanged)
    }

    func testSummaryMessagePhrasing() {
        XCTAssertEqual(DiffService.summaryMessage(from: [], changeCount: 0), "No meaningful changes")
        XCTAssertEqual(DiffService.summaryMessage(from: ["DNS"], changeCount: 1), "DNS changed")
        XCTAssertEqual(
            DiffService.summaryMessage(from: ["DNS", "Ownership"], changeCount: 3),
            "DNS and ownership changed (3 items)"
        )
    }

    func testContextNoteFlagsDifferentResolvers() {
        let old = SnapshotFixture.report(resolverURLString: "https://one.example/dns-query")
        let new = SnapshotFixture.report(resolverURLString: "https://two.example/dns-query")

        let note = DiffService.comparisonContextNote(from: old, to: new)
        XCTAssertEqual(note, "Compared snapshots used different DNS resolvers.")
    }

    func testContextNoteNilWhenResolversMatch() {
        let report = SnapshotFixture.report()
        XCTAssertNil(DiffService.comparisonContextNote(from: report, to: report))
    }

    func testCertificateWarningLevelThresholds() {
        func level(daysUntilExpiry days: Int?) -> CertificateWarningLevel {
            let ssl = days.map { SnapshotFixture.certificate(daysUntilExpiry: $0) }
            return DiffService.certificateWarningLevel(for: SnapshotFixture.snapshot(sslInfo: ssl))
        }

        XCTAssertEqual(level(daysUntilExpiry: nil), .none)
        XCTAssertEqual(level(daysUntilExpiry: 45), .none)
        XCTAssertEqual(level(daysUntilExpiry: 29), .warning)
        XCTAssertEqual(level(daysUntilExpiry: 14), .warning)
        XCTAssertEqual(level(daysUntilExpiry: 13), .critical)
        XCTAssertEqual(level(daysUntilExpiry: 0), .critical)
    }

    func testCrossDomainComparisonPairsBothDomains() {
        let a = SnapshotFixture.report(domain: "alpha.example", availability: .registered)
        let b = SnapshotFixture.report(domain: "beta.example", availability: .available)

        let result = DiffService.compare(domainA: a, domainB: b)

        XCTAssertEqual(result.domainA, "alpha.example")
        XCTAssertEqual(result.domainB, "beta.example")
        XCTAssertTrue(result.changeCount > 0)
    }
}
