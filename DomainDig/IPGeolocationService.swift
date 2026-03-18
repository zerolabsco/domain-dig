import Foundation

struct IPGeolocationService {
    static func lookup(ip: String) async throws -> IPGeolocation {
        let url = URL(string: "https://ipapi.co/\(ip)/json/")!
        let request = URLRequest(url: url, timeoutInterval: 10)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(IPGeolocation.self, from: data)
    }
}
