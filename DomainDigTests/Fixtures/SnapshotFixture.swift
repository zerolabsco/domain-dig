import Foundation
@testable import DomainDig

/// Deterministic builders for the deep `LookupSnapshot` / `DomainReport` models
/// so the core unit tests can construct inputs without wiring up every one of the
/// ~75 snapshot fields at each call site.
///
/// `snapshot(...)` exposes only the fields the tests actually vary; everything
/// else defaults to an empty/absent value. `report(...)` runs a snapshot through
/// the real `DomainReportBuilder`, which is both the natural constructor for the
/// otherwise-unconstructable `DomainReport` and, for the builder tests, the unit
/// under test.
enum SnapshotFixture {
    /// Fixed instant so timestamp-derived output (diff ranges, export headers) is
    /// stable across runs.
    static let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    static let defaultResolverURL = "https://resolver.example/dns-query"

    static func snapshot(
        domain: String = "example.com",
        timestamp: Date = referenceDate,
        resolverURLString: String = defaultResolverURL,
        resultSource: LookupResultSource = .live,
        availability: DomainAvailabilityStatus? = nil,
        ownership: DomainOwnership? = nil,
        dnsSections: [DNSSection] = [],
        ptrRecord: String? = nil,
        sslInfo: SSLCertificateInfo? = nil,
        httpHeaders: [HTTPHeader] = [],
        httpStatusCode: Int? = nil,
        httpSecurityGrade: String? = nil,
        subdomains: [DiscoveredSubdomain] = [],
        extendedSubdomains: [DiscoveredSubdomain] = [],
        isPartialSnapshot: Bool = false,
        validationIssues: [String] = [],
        changeSummary: DomainChangeSummary? = nil
    ) -> LookupSnapshot {
        LookupSnapshot(
            historyEntryID: nil,
            domain: domain,
            timestamp: timestamp,
            trackedDomainID: nil,
            note: nil,
            appVersion: "test",
            resolverDisplayName: "Test Resolver",
            resolverURLString: resolverURLString,
            dataSources: [],
            provenanceBySection: [:],
            availabilityConfidence: nil,
            ownershipConfidence: nil,
            subdomainConfidence: nil,
            emailSecurityConfidence: nil,
            geolocationConfidence: nil,
            errorDetails: [:],
            isPartialSnapshot: isPartialSnapshot,
            validationIssues: validationIssues,
            totalLookupDurationMs: nil,
            snapshotIndex: nil,
            previousSnapshotID: nil,
            changeCount: 0,
            severitySummary: nil,
            dnsSections: dnsSections,
            dnsError: nil,
            availabilityResult: availability.map { DomainAvailabilityResult(domain: domain, status: $0) },
            suggestions: [],
            sslInfo: sslInfo,
            sslError: nil,
            hstsPreloaded: nil,
            httpHeaders: httpHeaders,
            httpSecurityGrade: httpSecurityGrade,
            httpStatusCode: httpStatusCode,
            httpResponseTimeMs: nil,
            httpProtocol: nil,
            http3Advertised: false,
            httpHeadersError: nil,
            reachabilityResults: [],
            reachabilityError: nil,
            ipGeolocation: nil,
            ipGeolocationError: nil,
            emailSecurity: nil,
            emailSecurityError: nil,
            ownership: ownership,
            ownershipError: nil,
            ownershipHistory: [],
            ownershipHistoryError: nil,
            inferredProvider: nil,
            priorProviders: [],
            domainClassification: nil,
            ownershipTransitions: [],
            hostingTransitions: [],
            subdomainHistory: [],
            riskSignals: [],
            intelligenceTimeline: [],
            ptrRecord: ptrRecord,
            ptrError: nil,
            redirectChain: [],
            redirectChainError: nil,
            subdomains: subdomains,
            subdomainsError: nil,
            extendedSubdomains: extendedSubdomains,
            extendedSubdomainsError: nil,
            dnsHistory: [],
            dnsHistoryError: nil,
            domainPricing: nil,
            domainPricingError: nil,
            reputation: nil,
            reputationError: nil,
            portScanResults: [],
            portScanError: nil,
            changeSummary: changeSummary,
            resultSource: resultSource,
            cachedSections: [],
            statusMessage: nil
        )
    }

    static func report(
        domain: String = "example.com",
        timestamp: Date = referenceDate,
        resolverURLString: String = defaultResolverURL,
        resultSource: LookupResultSource = .live,
        availability: DomainAvailabilityStatus? = nil,
        ownership: DomainOwnership? = nil,
        dnsSections: [DNSSection] = [],
        ptrRecord: String? = nil,
        sslInfo: SSLCertificateInfo? = nil,
        httpHeaders: [HTTPHeader] = [],
        httpStatusCode: Int? = nil,
        httpSecurityGrade: String? = nil,
        subdomains: [DiscoveredSubdomain] = [],
        extendedSubdomains: [DiscoveredSubdomain] = [],
        isPartialSnapshot: Bool = false,
        validationIssues: [String] = []
    ) -> DomainReport {
        DomainReportBuilder().build(
            from: snapshot(
                domain: domain,
                timestamp: timestamp,
                resolverURLString: resolverURLString,
                resultSource: resultSource,
                availability: availability,
                ownership: ownership,
                dnsSections: dnsSections,
                ptrRecord: ptrRecord,
                sslInfo: sslInfo,
                httpHeaders: httpHeaders,
                httpStatusCode: httpStatusCode,
                httpSecurityGrade: httpSecurityGrade,
                subdomains: subdomains,
                extendedSubdomains: extendedSubdomains,
                isPartialSnapshot: isPartialSnapshot,
                validationIssues: validationIssues
            ),
            deriveChangeSummary: false
        )
    }

    // MARK: - Nested model conveniences

    static func dnsSection(
        type: DNSRecordType,
        values: [String],
        ttl: Int = 300,
        dnssecSigned: Bool? = nil,
        wildcards: [String] = []
    ) -> DNSSection {
        DNSSection(
            recordType: type,
            records: values.map { DNSRecord(value: $0, ttl: ttl) },
            wildcardRecords: wildcards.map { DNSRecord(value: $0, ttl: ttl) },
            dnssecSigned: dnssecSigned
        )
    }

    static func certificate(
        commonName: String = "example.com",
        issuer: String = "Test CA",
        daysUntilExpiry: Int = 90
    ) -> SSLCertificateInfo {
        SSLCertificateInfo(
            commonName: commonName,
            subjectAltNames: [commonName],
            issuer: issuer,
            validFrom: referenceDate,
            validUntil: referenceDate.addingTimeInterval(Double(daysUntilExpiry) * 86_400),
            daysUntilExpiry: daysUntilExpiry,
            chainDepth: 1
        )
    }
}
