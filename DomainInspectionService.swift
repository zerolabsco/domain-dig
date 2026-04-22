import Foundation

struct DomainInspectionService {
    private let reportBuilder = DomainReportBuilder()

    func inspect(domain: String) async -> DomainReport {
        let snapshot = await inspectSnapshot(domain: domain)
        return reportBuilder.build(from: snapshot)
    }

    func inspectSnapshot(domain: String) async -> LookupSnapshot {
        let normalizedDomain = normalize(domain)
        let startedAt = Date()
        let resolverDisplayName = DNSLookupService.currentResolverDisplayName()
        let resolverURLString = DNSLookupService.currentResolverURLString()

        async let dnsResult = DNSLookupService.lookupAll(domain: normalizedDomain)
        async let availabilityResult = DomainAvailabilityService.check(domain: normalizedDomain)
        async let sslResult = SSLCheckService.check(domain: normalizedDomain)
        async let hstsResult = SSLCheckService.checkHSTSPreload(domain: normalizedDomain)
        async let httpResult = HTTPHeadersService.fetch(domain: normalizedDomain)
        async let reachabilityResult = ReachabilityService.checkAll(domain: normalizedDomain)
        async let ownershipResult = DomainOwnershipService.lookup(domain: normalizedDomain)
        async let redirectResult = RedirectChainService.trace(domain: normalizedDomain)
        async let subdomainResult = SubdomainDiscoveryService.discover(for: normalizedDomain)
        async let portScanResult = PortScanService.scanAll(domain: normalizedDomain)

        let resolvedDNS = await dnsResult
        let availability = await availabilityResult
        let resolvedSSL = await sslResult
        let hsts = await hstsResult
        let http = await httpResult
        let reachability = await reachabilityResult
        let resolvedOwnership = await ownershipResult
        let redirects = await redirectResult
        let resolvedSubdomains = await subdomainResult
        let ports = await portScanResult

        let dnsSections = mapServiceResult(resolvedDNS, emptyValue: [])
        let sslInfo = mapOptionalValueServiceResult(resolvedSSL)
        let httpHeadersResult = mapHTTPResult(http)
        let reachabilityResultValue = mapServiceResult(reachability, emptyValue: [])
        let redirectChain = mapServiceResult(redirects, emptyValue: [])
        let ownership = mapOptionalValueServiceResult(resolvedOwnership)
        let subdomains = mapServiceResult(resolvedSubdomains, emptyValue: [])
        let portScanResults = await mapPortScanResult(ports, domain: normalizedDomain)

        let txtRecords = dnsSections.value.first(where: { $0.recordType == .TXT })?.records ?? []
        let primaryIP = dnsSections.value.first(where: { $0.recordType == .A })?.records.first?.value

        async let emailResult = EmailSecurityService.analyze(domain: normalizedDomain, txtRecords: txtRecords)
        async let suggestions = availability.status == .registered
            ? DomainAvailabilityService.suggestions(for: normalizedDomain)
            : []

        let resolvedEmail = await emailResult
        let resolvedSuggestions = await suggestions

        let ptrResult: ServiceResult<String>?
        let geoResult: ServiceResult<IPGeolocation>?
        if let primaryIP {
            ptrResult = await ReverseDNSService.lookup(ip: primaryIP, resolverURLString: resolverURLString)
            geoResult = await IPGeolocationService.lookup(ip: primaryIP)
        } else {
            ptrResult = nil
            geoResult = nil
        }

        let emailSecurity = mapOptionalValueServiceResult(resolvedEmail)
        let ptrRecord = mapOptionalServiceResult(ptrResult, missingMessage: "No A record available")
        let geolocation = mapOptionalServiceResult(geoResult, missingMessage: "No A record available")

        return LookupSnapshot(
            historyEntryID: nil,
            domain: availability.domain,
            timestamp: Date(),
            trackedDomainID: nil,
            resolverDisplayName: resolverDisplayName,
            resolverURLString: resolverURLString,
            totalLookupDurationMs: Int(Date().timeIntervalSince(startedAt) * 1000),
            dnsSections: dnsSections.value,
            dnsError: dnsSections.message,
            availabilityResult: availability,
            suggestions: resolvedSuggestions,
            sslInfo: sslInfo.value,
            sslError: sslInfo.message,
            hstsPreloaded: hsts,
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
            isLive: false
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
