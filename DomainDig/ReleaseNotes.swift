import Foundation

/// Release notes shown in the "What's New" sheet, loaded from the bundled
/// `ReleaseNotes.json`. No network access — the content ships with the app.
struct ReleaseNotes: Decodable {
    let version: String
    let highlights: [String]

    static func bundled() -> ReleaseNotes? {
        guard let url = Bundle.main.url(forResource: "ReleaseNotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let notes = try? JSONDecoder().decode(ReleaseNotes.self, from: data) else {
            return nil
        }
        return notes
    }
}
