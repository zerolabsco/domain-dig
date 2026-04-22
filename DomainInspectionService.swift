import Foundation

struct DomainInspectionService {
    private let reportBuilder = DomainReportBuilder()
    private let runtime: LookupRuntime

    init(runtime: LookupRuntime = .shared) {
        self.runtime = runtime
    }

    func inspect(domain: String, previousSnapshot: LookupSnapshot? = nil) async -> DomainReport {
        let snapshot = await inspectSnapshot(domain: domain, previousSnapshot: previousSnapshot)
        return reportBuilder.build(from: snapshot)
    }

    func inspectSnapshot(domain: String, previousSnapshot: LookupSnapshot? = nil) async -> LookupSnapshot {
        let normalizedDomain = normalize(domain)
        let startedAt = Date()
        let resolverDisplayName = DNSLookupService.currentResolverDisplayName()
        let resolverURLString = DNSLookupService.currentResolverURLString()
        var cachedSections = Set<LookupSectionKind>()
        var sectionSources: [LookupResultSource] = []

        async let dnsFetch = runtime.dns(domain: normalizedDomain)
        async let availabilityFetch = runtime.availability(domain: normalizedDomain)
        async let sslFetch = runtime.ssl(domain: normalizedDomain)
        async let hstsFetch = runtime.hsts(domain: normalizedDomain)
        async let httpFetch = runtime.http(domain: normalizedDomain)
        async let reachabilityFetch = runtime.reachability(domain: normalizedDomain)
        async let ownershipFetch = runtime.ownership(domain: normalizedDomain)
        async let redirectFetch = runtime.redirectChain(domain: normalizedDomain)
        async let subdomainFetch = runtime.subdomains(domain: normalizedDomain)
        async let portScanFetch = runtime.portScan(domain: normalizedDomain)

        let resolvedDNS = await dnsFetch
        let dnsResult = normalizeErrors(in: resolvedDNS.value)
        track(.dns, source: resolvedDNS.source, cachedSections: &cachedSections, sectionSources: &sectionSources)

        let availability = await availabilityFetch
        track(.availability, source: availability.source, cachedSections: &cachedSections, sectionSources: &sectionSources)

        let resolvedSSL = await sslFetch
        let sslResult = normalizeErrors(in: resolvedSSL.value)
        track(.ssl, source: resolvedSSL.source, cachedSections: &cachedSections, sectionSources: &sectionSources)

        let hsts = await hstsFetch
        track(.hsts, source: hsts.source, cachedSections: &cachedSections, sectionSources: &sectionSources)

        let http = await httpFetch
        let httpResult = normalizeErrors(in: http.value)
        track(.httpHeaders, source: http.source, cachedSections: &cachedSections, sectionSources: &sectionSources)

        let reachability = await reachabilityFetch
        let reachabilityResult = normalizeErrors(in: reachability.value)
        track(.reachability, source: reachability.source, cachedSections: &cachedSections, sectionSources: &sectionSources)

        let resolvedOwnership = await ownershipFetch
        let ownershipResult = normalizeErrors(in: resolvedOwnership.value)
        track(.ownership, source: resolvedOwnership.source, cachedSections: &cachedSections, sectionSources: &sectionSources)

        let redirects = await redirectFetch
        let redirectResult = normalizeErrors(in: redirects.value)
        track(.redirectChain, source: redirects.source, cachedSections: &cachedSections, sectionSources: &sectionSources)

        let resolvedSubdomains = await subdomainFetch
        let subdomainResult = normalizeErrors(in: resolvedSubdomains.value)
        track(.subdomains, source: resolvedSubdomains.source, cachedSections: &cachedSections, sectionSources: &sectionSources)

        let ports = await portScanFetch
        let portScanResult = normalizeErrors(in: ports.value)
        track(.portScan, source: ports.source, cachedSections: &cachedSections, sectionSources: &sectionSources)

        let dnsSections = mapServiceResult(dnsResult, emptyValue: [])
        let sslInfo = mapOptionalValueServiceResult(sslResult)
        let httpHeadersResult = mapHTTPResult(httpResult)
        let reachabilityResultValue = mapServiceResult(reachabilityResult, emptyValue: [])
        let redirectChain = mapServiceResult(redirectResult, emptyValue: [])
        let ownership = mapOptionalValueServiceResult(ownershipResult)
        let subdomains = mapServiceResult(subdomainResult, emptyValue: [])
        let portScanResults = await mapPortScanResult(portScanResult, domain: normalizedDomain)

        let txtRecords = dnsSections.value.first(where: { $0.recordType == .TXT })?.records ?? []
        let primaryIP = dnsSections.value.first(where: { $0.recordType == .A })?.records.first?.value
        let canReuseDNSDependents = canReuseDependentSections(from: previousSnapshot, dnsSections: dnsSections.value)
        let canReuseIPDependents = canReuseIPBasedSections(from: previousSnapshot, primaryIP: primaryIP)

        let emailOutcome: CachedLookupResult<ServiceResult<EmailSecurityResult>>
        if canReuseDNSDependents, let previousSnapshot, let emailSecurity = previousSnapshot.emailSecurity {
            emailOutcome = CachedLookupResult(value: .success(emailSecurity), source: .cached)
        } else if canReuseDNSDependents, let previousSnapshot, let error = previousSnapshot.emailSecurityError {
            emailOutcome = CachedLookupResult(value: .error(error), source: .cached)
        } else {
            emailOutcome = await runtime.email(domain: normalizedDomain, txtRecords: txtRecords)
        }
        track(.emailSecurity, source: emailOutcome.source, cachedSections: &cachedSections, sectionSources: &sectionSources)

        let suggestionsOutcome: CachedLookupResult<[DomainSuggestionResult]>
        if availability.value.status == .registered {
            suggestionsOutcome = await runtime.suggestions(domain: normalizedDomain)
            track(.suggestions, source: suggestionsOutcome.source, cachedSections: &cachedSections, sectionSources: &sectionSources)
        } else {
            suggestionsOutcome = CachedLookupResult(value: [], source: .live)
        }

        let ptrOutcome: CachedLookupResult<ServiceResult<String>>?
        let geoOutcome: CachedLookupResult<ServiceResult<IPGeolocation>>?
        if let primaryIP {
            if canReuseIPDependents, let previousSnapshot, let ptrRecord = previousSnapshot.ptrRecord {
                ptrOutcome = CachedLookupResult(value: .success(ptrRecord), source: .cached)
            } else if canReuseIPDependents, let previousSnapshot, let ptrError = previousSnapshot.ptrError {
                ptrOutcome = CachedLookupResult(value: .error(ptrError), source: .cached)
            } else {
                ptrOutcome = await runtime.ptr(ip: primaryIP, resolverURLString: resolverURLString)
            }

            if canReuseIPDependents, let previousSnapshot, let ipGeolocation = previousSnapshot.ipGeolocation {
                geoOutcome = CachedLookupResult(value: .success(ipGeolocation), source: .cached)
            } else if canReuseIPDependents, let previousSnapshot, let ipGeolocationError = previousSnapshot.ipGeolocationError {
                geoOutcome = CachedLookupResult(value: .error(ipGeolocationError), source: .cached)
            } else {
                geoOutcome = await runtime.ipGeolocation(ip: primaryIP)
            }

            if let ptrOutcome {
                track(.ptr, source: ptrOutcome.source, cachedSections: &cachedSections, sectionSources: &sectionSources)
            }
            if let geoOutcome {
                track(.ipGeolocation, source: geoOutcome.source, cachedSections: &cachedSections, sectionSources: &sectionSources)
            }
        } else {
            ptrOutcome = nil
            geoOutcome = nil
        }

        let emailSecurity = mapOptionalValueServiceResult(normalizeErrors(in: emailOutcome.value))
        let ptrRecord = mapOptionalServiceResult(ptrOutcome.map { normalizeErrors(in: $0.value) }, missingMessage: "No A record available")
        let geolocation = mapOptionalServiceResult(geoOutcome.map { normalizeErrors(in: $0.value) }, missingMessage: "No A record available")

        return LookupSnapshot(
            historyEntryID: nil,
            domain: availability.value.domain,
            timestamp: Date(),
            trackedDomainID: previousSnapshot?.trackedDomainID,
            resolverDisplayName: resolverDisplayName,
            resolverURLString: resolverURLString,
            totalLookupDurationMs: Int(Date().timeIntervalSince(startedAt) * 1000),
            dnsSections: dnsSections.value,
            dnsError: dnsSections.message,
            availabilityResult: availability.value,
            suggestions: suggestionsOutcome.value,
            sslInfo: sslInfo.value,
            sslError: sslInfo.message,
            hstsPreloaded: hsts.value,
            httpHeaders: httpHeadersResult.headers,
            httpSecurityGrade: httpHeadersResult.securityGrade,
            httpStatusCode: httpHeadersResult.statusCode,
            httpResponseTimeMs: httpHeadersResult.responseTimeMs,
            httpProtocol: httpHeadersResult.httpProtocol,
            http3Advertised: httpHeadersResult.http3Advertised,
            httpHeadersError: httpHeadersResult.error,
            reachabilityResults: reachabilityResultValue.value,
            reachabilityError: reachabilityResultValue.message,
            ipGeolocation: geolocation.value,
            ipGeolocationError: geolocation.message,
            emailSecurity: emailSecurity.value,
            emailSecurityError: emailSecurity.message,
            ownership: ownership.value,
            ownershipError: ownership.message,
            ptrRecord: ptrRecord.value,
            ptrError: ptrRecord.message,
            redirectChain: redirectChain.value,
            redirectChainError: redirectChain.message,
            subdomains: subdomains.value,
            subdomainsError: subdomains.message,
            portScanResults: portScanResults.value,
            portScanError: portScanResults.message,
            changeSummary: nil,
            resultSource: aggregateSource(sectionSources),
            cachedSections: Array(cachedSections).sorted { $0.rawValue < $1.rawValue },
            statusMessage: nil
        )
    }

    private func normalize(_ domain: String) -> String {
        domain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .components(separatedBy: "/").first?
            .lowercased() ?? domain.lowercased()
    }

    private func track(
        _ section: LookupSectionKind,
        source: LookupResultSource,
        cachedSections: inout Set<LookupSectionKind>,
        sectionSources: inout [LookupResultSource]
    ) {
        sectionSources.append(source)
        if source != .live {
            cachedSections.insert(section)
        }
    }

    private func aggregateSource(_ sectionSources: [LookupResultSource]) -> LookupResultSource {
        let normalizedSources = sectionSources.map { source -> LookupResultSource in
            source == .mixed ? .cached : source
        }

        let hasLive = normalizedSources.contains(.live)
        let hasCached = normalizedSources.contains(.cached)

        switch (hasLive, hasCached) {
        case (true, true):
            return .mixed
        case (false, true):
            return .cached
        default:
            return .live
        }
    }

    private func canReuseDependentSections(from previousSnapshot: LookupSnapshot?, dnsSections: [DNSSection]) -> Bool {
        guard let previousSnapshot else { return false }
        return dnsSignature(for: previousSnapshot.dnsSections) == dnsSignature(for: dnsSections)
    }

    private func canReuseIPBasedSections(from previousSnapshot: LookupSnapshot?, primaryIP: String?) -> Bool {
        guard let previousSnapshot else { return false }
        let previousIP = previousSnapshot.dnsSections.first(where: { $0.recordType == .A })?.records.first?.value
        return primaryIP == previousIP
    }

    private func dnsSignature(for sections: [DNSSection]) -> String {
        sections
            .sorted { $0.recordType.rawValue < $1.recordType.rawValue }
            .map { section in
                let records = section.records
                    .sorted { $0.value < $1.value }
                    .map { "\($0.value)|\($0.ttl)" }
                    .joined(separator: ",")
                let wildcardRecords = section.wildcardRecords
                    .sorted { $0.value < $1.value }
                    .map { "\($0.value)|\($0.ttl)" }
                    .joined(separator: ",")
                return [
                    section.recordType.rawValue,
                    records,
                    wildcardRecords,
                    section.dnssecSigned.map { $0 ? "signed" : "unsigned" } ?? "unknown",
                    section.error ?? ""
                ].joined(separator: "#")
            }
            .joined(separator: "||")
    }

    private func normalizeErrors<Value>(in result: ServiceResult<Value>) -> ServiceResult<Value> {
        switch result {
        case let .success(value):
            return .success(value)
        case let .empty(message):
            return .empty(message)
        case let .error(message):
            return .error(classifiedMessage(from: message))
        }
    }

    private func classifiedMessage(from message: String) -> String {
        let normalizedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedMessage = normalizedMessage.lowercased()

        if lowercasedMessage.hasPrefix("network error:")
            || lowercasedMessage.hasPrefix("timeout:")
            || lowercasedMessage.hasPrefix("rate limit:")
            || lowercasedMessage.hasPrefix("parsing error:") {
            return normalizedMessage
        }

        if lowercasedMessage.contains("timed out") {
            return "Timeout: Request timed out"
        }
        if lowercasedMessage.contains("429")
            || lowercasedMessage.contains("too many requests")
            || lowercasedMessage.contains("rate limit") {
            return "Rate limit: Try again shortly"
        }
        if lowercasedMessage.contains("cannot parse")
            || lowercasedMessage.contains("decoding")
            || lowercasedMessage.contains("json") {
            return "Parsing error: Invalid server response"
        }
        if lowercasedMessage.contains("offline")
            || lowercasedMessage.contains("internet connection")
            || lowercasedMessage.contains("not connected")
            || lowercasedMessage.contains("network connection") {
            return "Network error: Offline"
        }

        return "Network error: \(normalizedMessage)"
    }

    private func mapServiceResult<Value>(_ result: ServiceResult<Value>, emptyValue: Value) -> (value: Value, message: String?) {
        switch result {
        case let .success(value):
            return (value, nil)
        case let .empty(message), let .error(message):
            return (emptyValue, message)
        }
    }

    private func mapOptionalValueServiceResult<Value>(_ result: ServiceResult<Value>) -> (value: Value?, message: String?) {
        switch result {
        case let .success(value):
            return (value, nil)
        case let .empty(message), let .error(message):
            return (nil, message)
        }
    }

    private func mapOptionalServiceResult<Value>(
        _ result: ServiceResult<Value>?,
        missingMessage: String
    ) -> (value: Value?, message: String?) {
        guard let result else {
            return (nil, missingMessage)
        }

        switch result {
        case let .success(value):
            return (value, nil)
        case let .empty(message), let .error(message):
            return (nil, message)
        }
    }

    private func mapPortScanResult(_ result: ServiceResult<[PortScanResult]>, domain: String) async -> (value: [PortScanResult], message: String?) {
        switch result {
        case let .success(results):
            return (await enrichOpenPortBanners(in: results, domain: domain), nil)
        case let .empty(message), let .error(message):
            return ([], message)
        }
    }

    private func mapHTTPResult(_ result: ServiceResult<HTTPHeadersResult>) -> (
        headers: [HTTPHeader],
        securityGrade: String?,
        statusCode: Int?,
        responseTimeMs: Int?,
        httpProtocol: String?,
        http3Advertised: Bool,
        error: String?
    ) {
        switch result {
        case let .success(value):
            return (
                headers: value.headers,
                securityGrade: HTTPSecurityGrade.grade(for: value.headers).rawValue,
                statusCode: value.statusCode,
                responseTimeMs: value.responseTimeMs,
                httpProtocol: value.httpProtocol,
                http3Advertised: value.http3Advertised,
                error: nil
            )
        case let .empty(message), let .error(message):
            return (
                headers: [],
                securityGrade: nil,
                statusCode: nil,
                responseTimeMs: nil,
                httpProtocol: nil,
                http3Advertised: false,
                error: message
            )
        }
    }

    private func enrichOpenPortBanners(in results: [PortScanResult], domain: String) async -> [PortScanResult] {
        let banners = await withTaskGroup(of: (UInt16, String?).self, returning: [UInt16: String].self) { group in
            for result in results where result.open {
                group.addTask {
                    let banner = await PortScanService.grabBanner(host: domain, port: result.port)
                    return (result.port, banner)
                }
            }

            var collected: [UInt16: String] = [:]
            for await (port, banner) in group {
                if let banner {
                    collected[port] = banner
                }
            }
            return collected
        }

        return results.map { result in
            var updated = result
            updated.banner = banners[result.port]
            return updated
        }
    }
}
