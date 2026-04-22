import Foundation

struct LookupSnapshot {
    let historyEntryID: UUID?
    let domain: String
    let timestamp: Date
    let trackedDomainID: UUID?
    let resolverDisplayName: String
    let resolverURLString: String
    let totalLookupDurationMs: Int?
    let dnsSections: [DNSSection]
    let dnsError: String?
    let availabilityResult: DomainAvailabilityResult?
    let suggestions: [DomainSuggestionResult]
    let sslInfo: SSLCertificateInfo?
    let sslError: String?
    let hstsPreloaded: Bool?
    let httpHeaders: [HTTPHeader]
    let httpSecurityGrade: String?
    let httpStatusCode: Int?
    let httpResponseTimeMs: Int?
    let httpProtocol: String?
    let http3Advertised: Bool
    let httpHeadersError: String?
    let reachabilityResults: [PortReachability]
    let reachabilityError: String?
    let ipGeolocation: IPGeolocation?
    let ipGeolocationError: String?
    let emailSecurity: EmailSecurityResult?
    let emailSecurityError: String?
    let ownership: DomainOwnership?
    let ownershipError: String?
    let ptrRecord: String?
    let ptrError: String?
    let redirectChain: [RedirectHop]
    let redirectChainError: String?
    let subdomains: [DiscoveredSubdomain]
    let subdomainsError: String?
    let portScanResults: [PortScanResult]
    let portScanError: String?
    let changeSummary: DomainChangeSummary?
    let isLive: Bool
}

extension HistoryEntry {
    var snapshot: LookupSnapshot {
        LookupSnapshot(
            historyEntryID: id,
            domain: domain,
            timestamp: timestamp,
            trackedDomainID: trackedDomainID,
            resolverDisplayName: resolverDisplayName,
            resolverURLString: resolverURLString,
            totalLookupDurationMs: totalLookupDurationMs,
            dnsSections: dnsSections,
            dnsError: nil,
            availabilityResult: availabilityResult,
            suggestions: suggestions,
            sslInfo: sslInfo,
            sslError: sslError,
            hstsPreloaded: hstsPreloaded,
            httpHeaders: httpHeaders,
            httpSecurityGrade: HTTPSecurityGrade.grade(for: httpHeaders).rawValue,
            httpStatusCode: nil,
            httpResponseTimeMs: nil,
            httpProtocol: nil,
            http3Advertised: false,
            httpHeadersError: httpHeadersError,
            reachabilityResults: reachabilityResults,
            reachabilityError: reachabilityError,
            ipGeolocation: ipGeolocation,
            ipGeolocationError: ipGeolocationError,
            emailSecurity: emailSecurity,
            emailSecurityError: emailSecurityError,
            ownership: ownership,
            ownershipError: ownershipError,
            ptrRecord: ptrRecord,
            ptrError: ptrError,
            redirectChain: redirectChain,
            redirectChainError: redirectChainError,
            subdomains: subdomains,
            subdomainsError: subdomainsError,
            portScanResults: portScanResults,
            portScanError: portScanError,
            changeSummary: changeSummary,
            isLive: false
        )
    }
}
