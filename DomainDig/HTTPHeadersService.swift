import Foundation

struct HTTPHeadersService {
    static func fetch(domain: String) async throws -> [HTTPHeader] {
        let url = URL(string: "https://\(domain)")!
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "HEAD"

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return httpResponse.allHeaderFields.compactMap { key, value in
            guard let name = key as? String,
                  let val = value as? String else { return nil }
            return HTTPHeader(name: name, value: val)
        }
        .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}
