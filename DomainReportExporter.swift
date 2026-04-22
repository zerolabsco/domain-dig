import Foundation

enum DomainExportFormat: String {
    case text = "txt"
    case csv = "csv"
    case json = "json"

    var fileExtension: String { rawValue }
}

enum DomainReportExporter {
    static func data(for report: DomainReport, format: DomainExportFormat) throws -> Data {
        switch format {
        case .text:
            return Data(text(for: report).utf8)
        case .csv:
            return Data(csv(for: [report]).utf8)
        case .json:
            return try jsonEncoder.encode(report)
        }
    }

    static func data(for reports: [DomainReport], format: DomainExportFormat, title: String) throws -> Data {
        switch format {
        case .text:
            return Data(batchText(for: reports, title: title).utf8)
        case .csv:
            return Data(csv(for: reports).utf8)
        case .json:
            return try jsonEncoder.encode(reports)
        }
    }

    static func text(for report: DomainReport) -> String {
        var lines = [
            "DomainDig Report",
            "Domain: \(report.domain)",
            "Timestamp: \(textDateFormatter.string(from: report.timestamp))",
            "Availability: \(availabilityLabel(report.availability))"
        ]

        appendSection("Summary", to: &lines) {
            [
                "Primary IP: \(report.dns.primaryIP ?? "Unavailable")",
                "TLS Status: \(report.web.tlsStatus)",
                "HTTP: \(httpSummary(for: report))",
                "Email: \(report.email.summary)",
                "Subdomains: \(report.subdomains.count)"
            ]
        }

        appendSection("Ownership", to: &lines) {
            var ownershipLines = [
                "Registrar: \(report.ownership?.registrar ?? "Unavailable")",
                "Created: \(ownershipDateLabel(report.ownership?.createdDate))",
                "Expires: \(ownershipDateLabel(report.ownership?.expirationDate))",
                "Nameservers: \(joined(report.ownership?.nameservers) ?? "Unavailable")",
                "Status: \(joined(report.ownership?.status) ?? "Unavailable")",
                "Abuse Contact: \(report.ownership?.abuseEmail ?? "Unavailable")"
            ]
            if let error = report.dns.error, report.ownership == nil {
                ownershipLines.append("Error: \(error)")
            } else if let error = report.changeSummary?.message, report.ownership == nil, report.ownership == nil {
                _ = error
            }
            return ownershipLines
        }

        appendSection("DNS", to: &lines) {
            var dnsLines = [
                "Resolver: \(report.dns.resolverDisplayName)",
                "Resolver URL: \(report.dns.resolverURLString)",
                "Lookup Duration: \(durationLabel(report.dns.lookupDurationMs))",
                "Primary IP: \(report.dns.primaryIP ?? "Unavailable")",
                "PTR: \(report.dns.ptrRecord ?? report.dns.ptrError ?? "Unavailable")",
                "DNSSEC: \(dnssecLabel(report.dns.dnssecSigned))"
            ]
            if let error = report.dns.error {
                dnsLines.append("Error: \(error)")
            }
            if report.dns.recordSections.isEmpty {
                dnsLines.append("Records: None")
            } else {
                dnsLines.append("Records:")
                for section in report.dns.recordSections {
                    let values = (section.records + section.wildcardRecords).map(\.value)
                    let renderedValues = values.isEmpty ? "None" : values.joined(separator: " | ")
                    dnsLines.append("  \(section.recordType.rawValue): \(renderedValues)")
                }
            }
            return dnsLines
        }

        appendSection("Web", to: &lines) {
            var webLines = [
                "TLS Status: \(report.web.tlsStatus)",
                "Certificate Warning: \(report.web.certificateWarningLevel.title)",
                "Security Grade: \(report.web.securityGrade ?? "Unavailable")",
                "HTTP Status: \(report.web.statusCode.map(String.init) ?? "Unavailable")",
                "Protocol: \(report.web.httpProtocol ?? "Unavailable")",
                "HTTP/3 Advertised: \(report.web.http3Advertised ? "Yes" : "No")",
                "Final URL: \(report.web.finalURL ?? "Unavailable")",
                "HSTS Preloaded: \(booleanLabel(report.web.hstsPreloaded))",
                "Header Count: \(report.web.headerCount)"
            ]
            if let tlsError = report.web.tlsError {
                webLines.append("TLS Error: \(tlsError)")
            }
            if let headersError = report.web.headersError {
                webLines.append("Headers Error: \(headersError)")
            }
            if let redirectError = report.web.redirectError {
                webLines.append("Redirect Error: \(redirectError)")
            }
            if !report.web.headers.isEmpty {
                webLines.append("Headers:")
                for header in report.web.headers {
                    webLines.append("  \(header.name): \(header.value)")
                }
            }
            if !report.web.redirectChain.isEmpty {
                webLines.append("Redirect Chain:")
                for hop in report.web.redirectChain {
                    webLines.append("  \(hop.stepNumber). \(hop.statusCode) \(hop.url)\(hop.isFinal ? " (final)" : "")")
                }
            }
            return webLines
        }

        appendSection("Email", to: &lines) {
            var emailLines = [report.email.summary]
            if let records = report.email.records {
                emailLines.append("SPF: \(recordLabel(records.spf))")
                emailLines.append("DMARC: \(recordLabel(records.dmarc))")
                emailLines.append("DKIM: \(recordLabel(records.dkim))")
                emailLines.append("BIMI: \(recordLabel(records.bimi))")
                emailLines.append("MTA-STS: \(records.mtaSts?.txtFound == true ? records.mtaSts?.policyMode ?? "found" : "Unavailable")")
            }
            if let error = report.email.error {
                emailLines.append("Error: \(error)")
            }
            return emailLines
        }

        appendSection("Network", to: &lines) {
            var networkLines = [
                "Reachability: \(report.network.reachabilitySummary)",
                "Geolocation: \(report.network.geolocationSummary)",
                "Open Ports: \(report.network.openPorts.map(String.init).joined(separator: ", ").nilIfEmpty ?? "None")"
            ]
            if let error = report.network.reachabilityError {
                networkLines.append("Reachability Error: \(error)")
            }
            if let error = report.network.geolocationError {
                networkLines.append("Geolocation Error: \(error)")
            }
            if let error = report.network.portScanError {
                networkLines.append("Port Scan Error: \(error)")
            }
            if !report.network.portScan.isEmpty {
                networkLines.append("Port Scan:")
                for result in report.network.portScan {
                    networkLines.append(
                        "  \(result.port) \(result.service): \(result.open ? "open" : "closed")\(result.banner.map { " banner=\($0)" } ?? "")"
                    )
                }
            }
            return networkLines
        }

        appendSection("Subdomains", to: &lines) {
            if report.subdomains.isEmpty {
                return ["None"]
            }
            return report.subdomains.map { "- \($0)" }
        }

        appendSection("Changes", to: &lines) {
            guard let changeSummary = report.changeSummary else {
                return ["No comparison available"]
            }

            return [
                "Has Changes: \(changeSummary.hasChanges ? "Yes" : "No")",
                "Severity: \(changeSummary.severity.title)",
                "Summary: \(changeSummary.message)",
                "Changed Sections: \(changeSummary.changedSections.isEmpty ? "None" : changeSummary.changedSections.joined(separator: ", "))"
            ]
        }

        return lines.joined(separator: "\n")
    }

    static func batchText(for reports: [DomainReport], title: String) -> String {
        guard !reports.isEmpty else {
            return "\(title)\nNo results available."
        }

        var lines = [title, String(repeating: "=", count: title.count), ""]
        for (index, report) in reports.enumerated() {
            if index > 0 {
                lines.append("")
                lines.append(String(repeating: "=", count: 48))
                lines.append("")
            }
            lines.append(text(for: report))
        }
        return lines.joined(separator: "\n")
    }

    static func csv(for reports: [DomainReport]) -> String {
        let headers = [
            "domain",
            "timestamp",
            "availability",
            "registrar",
            "ownership_expires",
            "nameservers",
            "primary_ip",
            "ptr_record",
            "dnssec_signed",
            "tls_status",
            "certificate_warning_level",
            "hsts_preloaded",
            "http_status",
            "http_security_grade",
            "final_url",
            "email_summary",
            "subdomain_count",
            "subdomains",
            "open_ports",
            "reachability_summary",
            "geolocation_summary",
            "change_summary"
        ]

        let rows = reports.map { report in
            let expirationDate = report.ownership?.expirationDate.map(csvDateFormatter.string(from:)) ?? ""
            let nameservers = joined(report.ownership?.nameservers) ?? ""
            let dnssecSigned = report.dns.dnssecSigned.map { $0 ? "true" : "false" } ?? ""
            let hstsPreloaded = report.web.hstsPreloaded.map { $0 ? "true" : "false" } ?? ""
            let httpStatus = report.web.statusCode.map(String.init) ?? ""
            let subdomainCount = String(report.subdomains.count)
            let subdomains = report.subdomains.joined(separator: " | ")
            let openPorts = report.network.openPorts.map(String.init).joined(separator: " | ")

            return [
                report.domain,
                csvDateFormatter.string(from: report.timestamp),
                availabilityLabel(report.availability),
                report.ownership?.registrar ?? "",
                expirationDate,
                nameservers,
                report.dns.primaryIP ?? "",
                report.dns.ptrRecord ?? "",
                dnssecSigned,
                report.web.tlsStatus,
                report.web.certificateWarningLevel.rawValue,
                hstsPreloaded,
                httpStatus,
                report.web.securityGrade ?? "",
                report.web.finalURL ?? "",
                report.email.summary,
                subdomainCount,
                subdomains,
                openPorts,
                report.network.reachabilitySummary,
                report.network.geolocationSummary,
                report.changeSummary?.message ?? ""
            ]
        }

        return ([headers] + rows)
            .map { row in row.map(csvEscaped).joined(separator: ",") }
            .joined(separator: "\n")
    }

    private static func appendSection(_ title: String, to lines: inout [String], body: () -> [String]) {
        lines.append("")
        lines.append(title)
        lines.append(String(repeating: "-", count: title.count))
        lines.append(contentsOf: body())
    }

    private static func availabilityLabel(_ status: DomainAvailabilityStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .registered:
            return "Registered"
        case .unknown:
            return "Unknown"
        }
    }

    private static func joined(_ values: [String]?) -> String? {
        guard let values, !values.isEmpty else { return nil }
        return values.joined(separator: " | ")
    }

    private static func dnssecLabel(_ value: Bool?) -> String {
        switch value {
        case true:
            return "Signed"
        case false:
            return "Unsigned"
        case nil:
            return "Unavailable"
        }
    }

    private static func ownershipDateLabel(_ date: Date?) -> String {
        guard let date else { return "Unavailable" }
        return textDateFormatter.string(from: date)
    }

    private static func durationLabel(_ durationMs: Int?) -> String {
        durationMs.map { "\($0) ms" } ?? "Unavailable"
    }

    private static func httpSummary(for report: DomainReport) -> String {
        let parts = [report.web.statusCode.map(String.init), report.web.securityGrade].compactMap { $0 }
        return parts.isEmpty ? report.web.headersError ?? "Unavailable" : parts.joined(separator: " / ")
    }

    private static func booleanLabel(_ value: Bool?) -> String {
        guard let value else { return "Unavailable" }
        return value ? "Yes" : "No"
    }

    private static func recordLabel(_ record: EmailSecurityRecord) -> String {
        if record.found {
            return record.value ?? "Present"
        }
        return "Unavailable"
    }

    private static let textDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let csvDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    nonisolated private static func csvEscaped(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
