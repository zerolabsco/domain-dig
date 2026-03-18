import Foundation

struct EmailSecurityService {
    /// Analyze email security records. SPF is parsed from existing TXT records;
    /// DMARC and DKIM require additional DoH queries.
    static func analyze(domain: String, txtRecords: [DNSRecord]) async -> EmailSecurityResult {
        // SPF: extract from existing TXT records
        let spfRecord = txtRecords.first(where: { $0.value.lowercased().hasPrefix("v=spf1") })
        let spf = EmailSecurityRecord(found: spfRecord != nil, value: spfRecord?.value)

        // DMARC and DKIM queries in parallel
        async let dmarcResult = queryTXT(subdomain: "_dmarc.\(domain)")
        async let dkimResult = queryDKIM(domain: domain)

        let dmarcValue = await dmarcResult
        let dkimValue = await dkimResult

        let dmarc = EmailSecurityRecord(
            found: dmarcValue != nil,
            value: dmarcValue
        )
        let dkim = EmailSecurityRecord(
            found: dkimValue != nil,
            value: dkimValue
        )

        return EmailSecurityResult(spf: spf, dmarc: dmarc, dkim: dkim)
    }

    /// Query a TXT record for the given subdomain via DoH.
    private static func queryTXT(subdomain: String) async -> String? {
        do {
            let records = try await DNSLookupService.lookup(domain: subdomain, recordType: .TXT)
            return records.first?.value
        } catch {
            return nil
        }
    }

    /// Try common DKIM selectors and return the first found.
    private static func queryDKIM(domain: String) async -> String? {
        let selectors = ["default", "google", "mail"]
        return await withTaskGroup(of: (Int, String?).self, returning: String?.self) { group in
            for (index, selector) in selectors.enumerated() {
                group.addTask {
                    let value = await queryTXT(subdomain: "\(selector)._domainkey.\(domain)")
                    return (index, value)
                }
            }

            var results: [(Int, String?)] = []
            for await result in group {
                results.append(result)
            }
            // Return the first (by selector order) that has a value
            return results
                .sorted { $0.0 < $1.0 }
                .first(where: { $0.1 != nil })?.1
        }
    }
}
