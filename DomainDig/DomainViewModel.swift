import Foundation
import SwiftUI

@MainActor
@Observable
final class DomainViewModel {
    var domain: String = ""

    var dnsSections: [DNSSection] = []
    var dnsLoading = false
    var dnsError: String?

    var sslInfo: SSLCertificateInfo?
    var sslLoading = false
    var sslError: String?

    var hasRun = false
    private(set) var searchedDomain: String = ""

    private static let recentSearchesKey = "recentSearches"
    private static let maxRecent = 20

    var recentSearches: [String] = UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []

    var trimmedDomain: String {
        domain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .components(separatedBy: "/").first ?? ""
    }

    func run() {
        let target = trimmedDomain
        guard !target.isEmpty else { return }

        addRecentSearch(target)
        searchedDomain = target
        hasRun = true
        dnsSections = []
        dnsError = nil
        dnsLoading = true
        sslInfo = nil
        sslError = nil
        sslLoading = true

        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in
                    await self.runDNS(domain: target)
                }
                group.addTask { @MainActor in
                    await self.runSSL(domain: target)
                }
            }
        }
    }

    private func runDNS(domain: String) async {
        do {
            let sections = await DNSLookupService.lookupAll(domain: domain)
            dnsSections = sections
        }
        dnsLoading = false
    }

    private func runSSL(domain: String) async {
        do {
            let info = try await SSLCheckService.check(domain: domain)
            sslInfo = info
        } catch {
            sslError = error.localizedDescription
        }
        sslLoading = false
    }

    /// True when both lookups have finished (regardless of success/failure).
    var resultsLoaded: Bool {
        hasRun && !dnsLoading && !sslLoading
    }

    // MARK: - Export

    func exportText() -> String {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd HH:mm"
        let now = dateFmt.string(from: Date())

        var lines: [String] = [
            "DomainDig Export",
            "Domain: \(searchedDomain)",
            "Date: \(now)",
            "",
            "DNS Records",
            "-----------"
        ]

        for section in dnsSections {
            lines.append(section.recordType.rawValue)
            if let error = section.error {
                lines.append("  Error: \(error)")
            } else if section.records.isEmpty {
                lines.append("  No records found")
            } else {
                for record in section.records {
                    lines.append("  \(record.value)  TTL \(record.ttl)")
                }
            }
            if !section.wildcardRecords.isEmpty {
                lines.append("*.\(searchedDomain)")
                for record in section.wildcardRecords {
                    lines.append("  \(record.value)  TTL \(record.ttl)")
                }
            }
        }

        if let info = sslInfo {
            let certDateFmt = DateFormatter()
            certDateFmt.dateStyle = .medium
            certDateFmt.timeStyle = .none

            lines.append("")
            lines.append("SSL / TLS Certificate")
            lines.append("---------------------")
            lines.append("Common Name: \(info.commonName)")
            lines.append("Issuer: \(info.issuer)")
            lines.append("SANs: \(info.subjectAltNames.joined(separator: ", "))")
            lines.append("Valid From: \(certDateFmt.string(from: info.validFrom))")
            lines.append("Valid Until: \(certDateFmt.string(from: info.validUntil))")
            lines.append("Days Until Expiry: \(info.daysUntilExpiry)")
            lines.append("Chain Depth: \(info.chainDepth)")
        } else if let error = sslError {
            lines.append("")
            lines.append("SSL / TLS Certificate")
            lines.append("---------------------")
            lines.append("Error: \(error)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Recent Searches

    private func addRecentSearch(_ domain: String) {
        recentSearches.removeAll { $0.lowercased() == domain.lowercased() }
        recentSearches.insert(domain, at: 0)
        if recentSearches.count > Self.maxRecent {
            recentSearches = Array(recentSearches.prefix(Self.maxRecent))
        }
        UserDefaults.standard.set(recentSearches, forKey: Self.recentSearchesKey)
    }

    func clearRecentSearches() {
        recentSearches.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.recentSearchesKey)
    }
}
