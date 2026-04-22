import Foundation

@main
struct DomainDigCLI {
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())

        guard let command = CommandLine.arguments.first else {
            fputs("usage: domaindig <domain> [--json]\n", stderr)
            Foundation.exit(1)
        }
        _ = command

        let wantsJSON = arguments.contains("--json") || arguments.contains("-j")
        let domains = arguments.filter { !$0.hasPrefix("-") }

        let requestedDomains = domains
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !requestedDomains.isEmpty else {
            fputs("usage: domaindig <domain> [--json]\n", stderr)
            Foundation.exit(1)
        }

        let inspectionService = DomainInspectionService()
        var reports: [DomainReport] = []
        var seen = Set<String>()

        for domain in requestedDomains {
            let normalizedDomain = domain.lowercased()
            guard seen.insert(normalizedDomain).inserted else { continue }
            reports.append(await inspectionService.inspect(domain: domain))
        }

        do {
            let data: Data
            if reports.count == 1, let report = reports.first {
                data = try DomainReportExporter.data(
                    for: report,
                    format: wantsJSON ? .json : .text
                )
            } else {
                data = try DomainReportExporter.data(
                    for: reports,
                    format: wantsJSON ? .json : .text,
                    title: "DomainDig Batch Report"
                )
            }
            FileHandle.standardOutput.write(data)
            if data.last != 0x0A {
                FileHandle.standardOutput.write(Data([0x0A]))
            }
        } catch {
            fputs("domaindig: \(error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }
}
