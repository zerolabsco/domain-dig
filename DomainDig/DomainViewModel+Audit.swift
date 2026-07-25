import Foundation
import SwiftUI

/// Audit review surface of `DomainViewModel`: reading audit sessions and their
/// timeline, and mutating a session's status, notes, checklist, and findings.
///
/// `startAudit(for:)` deliberately stays on the main type — it drives a live
/// inspection to seed the session, so it belongs with the inspection pipeline
/// until that is extracted. Everything here operates purely on `auditSessions`
/// and persists through `persistAuditSessions()`.
extension DomainViewModel {
    func audits(for domain: String) -> [AuditSession] {
        auditSessions
            .filter { $0.domain.caseInsensitiveCompare(domain) == .orderedSame }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func auditSession(withID id: UUID) -> AuditSession? {
        auditSessions.first(where: { $0.id == id })
    }

    func auditTimeline(for domain: String) -> [AuditTimelinePoint] {
        let sessions = audits(for: domain).sorted { $0.createdAt > $1.createdAt }
        return sessions.map { session in
            let repeatedIssues = sessions
                .filter { $0.id != session.id }
                .flatMap(\.findings)
                .map { $0.title.lowercased() }
            let repeatedIssueCount = session.findings.filter {
                repeatedIssues.contains($0.title.lowercased())
            }.count

            return AuditTimelinePoint(
                id: session.id,
                sessionID: session.id,
                domain: session.domain,
                createdAt: session.createdAt,
                status: session.status,
                findingCount: session.findings.count,
                openHighSeverityCount: session.findings.filter { $0.severity == .high && $0.status != .resolved }.count,
                repeatedIssueCount: repeatedIssueCount
            )
        }
    }

    func updateAuditStatus(_ status: AuditStatus, sessionID: UUID) {
        guard let index = auditSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        auditSessions[index].status = status
        persistAuditSessions()
    }

    func updateAuditNotes(_ notes: String, sessionID: UUID) {
        guard let index = auditSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        auditSessions[index].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        persistAuditSessions()
    }

    func toggleAuditChecklistItem(sessionID: UUID, itemID: UUID) {
        guard let sessionIndex = auditSessions.firstIndex(where: { $0.id == sessionID }),
              let itemIndex = auditSessions[sessionIndex].checklist.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        auditSessions[sessionIndex].checklist[itemIndex].isComplete.toggle()
        auditSessions[sessionIndex].checklist[itemIndex].completedAt = auditSessions[sessionIndex].checklist[itemIndex].isComplete ? Date() : nil
        persistAuditSessions()
    }

    func addAuditFinding(
        sessionID: UUID,
        title: String,
        severity: AuditFindingSeverity,
        summary: String,
        evidenceReferences: [String],
        notes: String,
        checklistAreas: [AuditChecklistArea]
    ) {
        guard let index = auditSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let finding = AuditFinding(
            title: title,
            severity: severity,
            summary: summary,
            evidenceReferences: evidenceReferences,
            notes: notes,
            status: .open,
            checklistAreas: checklistAreas
        )
        auditSessions[index].findings.insert(finding, at: 0)
        persistAuditSessions()
    }

    func updateAuditFinding(_ finding: AuditFinding, sessionID: UUID) {
        guard let sessionIndex = auditSessions.firstIndex(where: { $0.id == sessionID }),
              let findingIndex = auditSessions[sessionIndex].findings.firstIndex(where: { $0.id == finding.id }) else {
            return
        }

        var updatedFinding = finding
        updatedFinding.updatedAt = Date()
        auditSessions[sessionIndex].findings[findingIndex] = updatedFinding
        persistAuditSessions()
    }

    func removeAuditFindings(at offsets: IndexSet, sessionID: UUID) {
        guard let sessionIndex = auditSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        auditSessions[sessionIndex].findings.remove(atOffsets: offsets)
        persistAuditSessions()
    }

    func exportAuditData(sessionID: UUID, format: AuditExportFormat) -> Data? {
        guard let session = auditSession(withID: sessionID) else { return nil }
        return try? AuditExporter.data(for: session, format: format)
    }
}
