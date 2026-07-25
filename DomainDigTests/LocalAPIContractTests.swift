import XCTest
@testable import DomainDig

/// Locks the Local API wire contract: the envelope shape, each payload's field
/// names, and the encoding conventions (`v1`, ISO-8601 dates, nil omission).
/// A rename or removed field fails here instead of silently breaking an external
/// consumer. Values are deliberately not asserted — only structure — so ordinary
/// behavior changes don't churn these tests.
final class LocalAPIContractTests: XCTestCase {
    private let encoder = LocalAPIContract.makeEncoder()

    // MARK: - Helpers

    private func json<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(object as? [String: Any])
    }

    private func keys<T: Encodable>(_ value: T) throws -> Set<String> {
        Set(try json(value).keys)
    }

    // MARK: - Envelope

    func testVersionIsV1() {
        XCTAssertEqual(LocalAPIContract.version, "v1")
    }

    func testSuccessEnvelopeOmitsErrorAndReportsVersion() throws {
        let envelope = LocalAPIEnvelope(
            success: true,
            data: PortfolioPayload(summary: Self.sampleSummary),
            error: nil,
            version: LocalAPIContract.version
        )
        let object = try json(envelope)

        XCTAssertEqual(Set(object.keys), ["success", "data", "version"], "nil error must be omitted from the envelope")
        XCTAssertEqual(object["success"] as? Bool, true)
        XCTAssertEqual(object["version"] as? String, "v1")
    }

    func testErrorEnvelopeOmitsDataAndCarriesCodeAndMessage() throws {
        let envelope = LocalAPIEnvelope<EmptyPayload>(
            success: false,
            data: nil,
            error: LocalAPIErrorPayload(code: "not_found", message: "The requested Local API route does not exist."),
            version: LocalAPIContract.version
        )
        let object = try json(envelope)

        XCTAssertEqual(Set(object.keys), ["success", "error", "version"], "nil data must be omitted from the envelope")
        XCTAssertEqual(object["success"] as? Bool, false)
        let error = try XCTUnwrap(object["error"] as? [String: Any])
        XCTAssertEqual(Set(error.keys), ["code", "message"])
        XCTAssertEqual(error["code"] as? String, "not_found")
    }

    // MARK: - Payload field names

    func testPortfolioSummaryFields() throws {
        XCTAssertEqual(
            try keys(Self.sampleSummary),
            ["totalDomains", "healthyCount", "warningCount", "criticalCount",
             "changedLast24h", "expiringSoonCount", "unreachableCount"]
        )
    }

    func testPortfolioPayloadFields() throws {
        XCTAssertEqual(try keys(PortfolioPayload(summary: Self.sampleSummary)), ["summary"])
    }

    func testDomainListPayloadFields() throws {
        let payload = DomainListPayload(domains: [TrackedDomain(domain: "example.com")])
        XCTAssertEqual(try keys(payload), ["domains"])
    }

    func testDomainDetailPayloadFieldsWhenPopulated() throws {
        let payload = DomainDetailPayload(
            domain: "example.com",
            trackedDomain: TrackedDomain(domain: "example.com"),
            latestReport: SnapshotFixture.report(domain: "example.com")
        )
        XCTAssertEqual(try keys(payload), ["domain", "trackedDomain", "latestReport"])
    }

    func testDomainDetailPayloadOmitsAbsentOptionals() throws {
        let payload = DomainDetailPayload(domain: "example.com", trackedDomain: nil, latestReport: nil)
        XCTAssertEqual(try keys(payload), ["domain"], "absent trackedDomain/latestReport are omitted, not null")
    }

    func testDomainHistoryPayloadFields() throws {
        let payload = DomainHistoryPayload(domain: "example.com", history: [])
        XCTAssertEqual(try keys(payload), ["domain", "history"])
    }

    func testRecentEventPayloadFields() throws {
        XCTAssertEqual(try keys(Self.sampleEvent), ["timestamp", "domain", "summary", "status", "severity"])
    }

    func testRecentEventsPayloadFields() throws {
        XCTAssertEqual(try keys(RecentEventsPayload(events: [Self.sampleEvent])), ["events"])
    }

    func testMonitoringPayloadFieldsAndEnumEncoding() throws {
        let payload = MonitoringPayload(
            isEnabled: true,
            scope: .allTracked,
            alertsEnabled: true,
            monitoredDomains: [Self.sampleMonitoringDomain]
        )
        let object = try json(payload)
        XCTAssertEqual(Set(object.keys), ["isEnabled", "scope", "alertsEnabled", "monitoredDomains"])
        XCTAssertEqual(object["scope"] as? String, "allTracked", "MonitoringScope encodes as its String raw value")
    }

    func testMonitoringDomainPayloadFieldsAndEnumEncoding() throws {
        let object = try json(Self.sampleMonitoringDomain)
        XCTAssertEqual(
            Set(object.keys),
            ["domain", "monitoringEnabled", "lastMonitoredAt", "lastAlertAt", "certificateWarningLevel"]
        )
        XCTAssertEqual(object["certificateWarningLevel"] as? String, "none")
    }

    func testMonitoringMutationPayloadFields() throws {
        XCTAssertEqual(
            try keys(MonitoringMutationPayload(domain: "example.com", monitoringEnabled: true)),
            ["domain", "monitoringEnabled"]
        )
    }

    func testInspectResponsePayloadFields() throws {
        XCTAssertEqual(try keys(InspectResponsePayload(report: SnapshotFixture.report())), ["report"])
    }

    // MARK: - Encoding conventions

    func testDatesEncodeAsISO8601() throws {
        let event = RecentEventPayload(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            domain: "example.com",
            summary: "changed",
            status: "changed",
            severity: "medium"
        )
        let object = try json(event)
        XCTAssertEqual(object["timestamp"] as? String, "2023-11-14T22:13:20Z")
    }

    // MARK: - Fixtures

    private static let sampleSummary = PortfolioSummary(
        totalDomains: 3,
        healthyCount: 1,
        warningCount: 1,
        criticalCount: 1,
        changedLast24h: 2,
        expiringSoonCount: 1,
        unreachableCount: 0
    )

    private static let sampleEvent = RecentEventPayload(
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
        domain: "example.com",
        summary: "Certificate is approaching expiry",
        status: "changed",
        severity: "medium"
    )

    private static let sampleMonitoringDomain = MonitoringDomainPayload(
        domain: "example.com",
        monitoringEnabled: true,
        lastMonitoredAt: Date(timeIntervalSince1970: 1_700_000_000),
        lastAlertAt: Date(timeIntervalSince1970: 1_700_000_000),
        certificateWarningLevel: .none
    )
}
