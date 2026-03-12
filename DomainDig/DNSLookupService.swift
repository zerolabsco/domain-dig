import Foundation

struct DNSLookupService {
    private static let baseURL = "https://cloudflare-dns.com/dns-query"

    static func lookup(domain: String, recordType: DNSRecordType) async throws -> [DNSRecord] {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "name", value: domain),
            URLQueryItem(name: "type", value: String(recordType.queryType))
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("application/dns-json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let dnsResponse = try JSONDecoder().decode(CloudflareDNSResponse.self, from: data)

        guard let answers = dnsResponse.Answer else {
            return []
        }

        // Filter answers to only include the requested type
        return answers
            .filter { $0.type == recordType.queryType }
            .map { answer in
                let value = answer.data.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return DNSRecord(value: value, ttl: answer.TTL)
            }
    }

    /// Record types that support wildcard queries.
    private nonisolated(unsafe) static let wildcardTypes: Set<DNSRecordType> = [.A, .AAAA, .MX, .TXT]

    static func lookupAll(domain: String) async -> [DNSSection] {
        // Each task returns (recordType, apex records, wildcard records).
        typealias Result = (type: DNSRecordType, records: [DNSRecord], wildcard: [DNSRecord], error: String?)

        return await withTaskGroup(of: Result.self, returning: [DNSSection].self) { group in
            for recordType in DNSRecordType.allCases {
                group.addTask {
                    var apexRecords: [DNSRecord] = []
                    var wildcardRecords: [DNSRecord] = []
                    var lookupError: String?

                    // Apex query
                    do {
                        apexRecords = try await lookup(domain: domain, recordType: recordType)
                    } catch {
                        lookupError = error.localizedDescription
                    }

                    // Wildcard query (only for applicable types, and only if apex didn't fail)
                    if wildcardTypes.contains(recordType) && lookupError == nil {
                        do {
                            wildcardRecords = try await lookup(domain: "*.\(domain)", recordType: recordType)
                        } catch {
                            // Wildcard failure is non-fatal; just leave empty
                        }
                    }

                    return (recordType, apexRecords, wildcardRecords, lookupError)
                }
            }

            var sections: [DNSSection] = []
            for await result in group {
                sections.append(DNSSection(
                    recordType: result.type,
                    records: result.records,
                    wildcardRecords: result.wildcard,
                    error: result.error
                ))
            }

            // Sort to maintain consistent order
            let order = DNSRecordType.allCases
            return sections.sorted { a, b in
                (order.firstIndex(of: a.recordType) ?? 0) < (order.firstIndex(of: b.recordType) ?? 0)
            }
        }
    }
}
