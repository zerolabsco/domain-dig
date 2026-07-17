import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum AuditExportFormat: String, CaseIterable, Identifiable {
    case pdf
    case json
    case markdown

    var id: String { rawValue }

    var fileExtension: String { rawValue == "markdown" ? "md" : rawValue }
}

enum AuditExporter {
    static func data(for session: AuditSession, format: AuditExportFormat) throws -> Data {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(session)
        case .markdown:
            return Data(markdown(for: session).utf8)
        case .pdf:
            return try pdfData(for: session)
        }
    }

    static func markdown(for session: AuditSession) -> String {
        var lines: [String] = [
            "# DomainDig Audit",
            "",
            "- Domain: \(session.domain)",
            "- Review Date: \(session.createdAt.formatted(date: .abbreviated, time: .shortened))",
            "- Reviewer: \(session.reviewer)",
            "- Status: \(session.status.title)",
            "- Evidence Captured: \(session.evidence.capturedAt.formatted(date: .abbreviated, time: .shortened))",
            "- Checklist Progress: \(session.completedChecklistCount)/\(session.checklist.count)",
            ""
        ]

        if !session.notes.isEmpty {
            lines.append("## Summary Notes")
            lines.append(session.notes)
            lines.append("")
        }

        lines.append("## Findings Summary")
        if session.findings.isEmpty {
            lines.append("No findings recorded.")
        } else {
            for finding in session.findings {
                lines.append("- [\(finding.severity.title)] \(finding.title) (\(finding.status.title))")
            }
        }
        lines.append("")

        lines.append("## Key Risks")
        if session.keyRisks.isEmpty {
            lines.append("No medium or high-severity risks recorded.")
        } else {
            for finding in session.keyRisks {
                lines.append("- \(finding.title): \(finding.summary)")
            }
        }
        lines.append("")

        lines.append("## Checklist")
        for item in session.checklist {
            lines.append("- [\(item.isComplete ? "x" : " ")] \(item.title): \(item.detail)")
        }
        lines.append("")

        lines.append("## Findings")
        if session.findings.isEmpty {
            lines.append("No findings recorded.")
        } else {
            for finding in session.findings {
                lines.append("### \(finding.title)")
                lines.append("- Severity: \(finding.severity.title)")
                lines.append("- Status: \(finding.status.title)")
                if !finding.checklistAreas.isEmpty {
                    lines.append("- Checklist Areas: \(finding.checklistAreas.map(\.title).joined(separator: ", "))")
                }
                lines.append("- Summary: \(finding.summary)")
                if !finding.evidenceReferences.isEmpty {
                    lines.append("- Evidence: \(finding.evidenceReferences.joined(separator: " | "))")
                }
                if !finding.notes.isEmpty {
                    lines.append("- Notes: \(finding.notes)")
                }
                lines.append("")
            }
        }

        lines.append("## Evidence Snapshot")
        lines.append("- Availability: \(availabilityTitle(session.evidence.report.availability))")
        lines.append("- Risk Score: \(session.evidence.report.riskAssessment.score) (\(session.evidence.report.riskAssessment.level.title))")
        lines.append("- TLS Status: \(session.evidence.report.web.tlsStatus)")
        lines.append("- Final URL: \(session.evidence.report.web.finalURL ?? "Unavailable")")
        lines.append("- Primary IP: \(session.evidence.report.dns.primaryIP ?? "Unavailable")")
        lines.append("- Reachability: \(session.evidence.report.network.reachabilitySummary)")
        lines.append("- Ownership: \(session.evidence.report.ownership?.registrar ?? "Unavailable")")
        lines.append("- Historical Context Snapshots: \(session.evidence.historicalContext.count)")

        return lines.joined(separator: "\n")
    }

    private static func availabilityTitle(_ status: DomainAvailabilityStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .registered:
            return "Registered"
        case .unknown:
            return "Unknown"
        }
    }

    private static func pdfData(for session: AuditSession) throws -> Data {
        let markdown = markdown(for: session)
        #if canImport(UIKit)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        return renderer.pdfData { context in
            let lines = markdown.components(separatedBy: .newlines)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byWordWrapping
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .paragraphStyle: paragraphStyle
            ]

            var yOffset: CGFloat = 36
            context.beginPage()

            for line in lines {
                if yOffset > 744 {
                    context.beginPage()
                    yOffset = 36
                }

                let renderedLine = NSString(string: line.isEmpty ? " " : line)
                renderedLine.draw(
                    in: CGRect(x: 36, y: yOffset, width: 540, height: 22),
                    withAttributes: attributes
                )
                yOffset += 16
            }
        }
        #else
        return Data(markdown.utf8)
        #endif
    }
}
