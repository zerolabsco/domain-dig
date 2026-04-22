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

        guard let domain = domains.first, !domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            fputs("usage: domaindig <domain> [--json]\n", stderr)
            Foundation.exit(1)
        }

        let inspectionService = DomainInspectionService()
        let report = await inspectionService.inspect(domain: domain)

        do {
            let data = try DomainReportExporter.data(
                for: report,
                format: wantsJSON ? .json : .text
            )
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
