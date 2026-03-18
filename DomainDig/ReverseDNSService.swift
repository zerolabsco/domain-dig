import Foundation

struct ReverseDNSService {
    /// Look up the PTR record for an IPv4 address via Cloudflare DoH.
    static func lookup(ip: String) async -> String? {
        let octets = ip.split(separator: ".")
        guard octets.count == 4 else { return nil }

        let reversed = octets.reversed().joined(separator: ".")
        let ptrDomain = "\(reversed).in-addr.arpa"

        // PTR record type = 12
        do {
            let records = try await lookupPTR(domain: ptrDomain)
            return records.first
        } catch {
            return nil
        }
    }

    private static func lookupPTR(domain: String) async throws -> [String] {
        var components = URLComponents(string: "https://cloudflare-dns.com/dns-query")!
        components.queryItems = [
            URLQueryItem(name: "name", value: domain),
            URLQueryItem(name: "type", value: "12") // PTR
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

        return answers
            .filter { $0.type == 12 }
            .map { $0.data.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
    }
}
