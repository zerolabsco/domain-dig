import Foundation

/// History query surface of `DomainViewModel`: reading snapshots for a domain,
/// grouping them into a timeline, the two-snapshot selection model, and
/// generating/navigating diffs between snapshots.
///
/// This is the read/compare side of history. The pipeline that *produces*
/// history — `performLookup`, `applySnapshot`, `saveHistoryEntry`,
/// `persistHistory`, and the snapshot-metadata bookkeeping — stays on the main
/// type with the inspection code.
extension DomainViewModel {
    func resolverMismatchNote(for entry: HistoryEntry) -> String? {
        guard entry.resolverURLString != resolverURLString else { return nil }
        return "Current resolver differs from this snapshot. Re-running may produce different evidence."
    }

    func resolverMismatchNote(for trackedDomain: TrackedDomain) -> String? {
        guard let snapshot = latestSnapshot(for: trackedDomain), snapshot.resolverURLString != resolverURLString else {
            return nil
        }
        return "Current resolver differs from the latest snapshot for this tracked domain."
    }

    func comparisonSnapshot(for entry: HistoryEntry) -> LookupSnapshot? {
        previousHistoryEntry(for: entry)?.snapshot
    }

    func timelineEntries(for domain: String) -> [SnapshotSummary] {
        historyEntries(for: domain).map(\.snapshotSummary)
    }

    func timelineSections(for domain: String, grouping: TimelineGroupingOption? = nil) -> [TimelineSection] {
        let entries = timelineEntries(for: domain)
        let grouping = grouping ?? timelineGrouping

        guard grouping == .relativeDay else {
            return entries.isEmpty ? [] : [TimelineSection(id: "all", title: "All Snapshots", entries: entries)]
        }

        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let grouped = Dictionary(grouping: entries) { entry -> String in
            if calendar.isDate(entry.timestamp, inSameDayAs: today) {
                return "Today"
            }
            if calendar.isDate(entry.timestamp, inSameDayAs: yesterday) {
                return "Yesterday"
            }
            return "Older"
        }

        return ["Today", "Yesterday", "Older"].compactMap { title in
            guard let items = grouped[title], !items.isEmpty else { return nil }
            return TimelineSection(id: title.lowercased(), title: title, entries: items)
        }
    }

    func historyEntries(for domain: String) -> [HistoryEntry] {
        history
            .filter { $0.domain.caseInsensitiveCompare(domain) == .orderedSame }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func historyEntry(withID id: UUID) -> HistoryEntry? {
        history.first(where: { $0.id == id })
    }

    func previousHistoryEntry(for entry: HistoryEntry) -> HistoryEntry? {
        let siblings = historyEntries(for: entry.domain)
        guard let index = siblings.firstIndex(where: { $0.id == entry.id }) else { return nil }
        let nextIndex = index + 1
        guard siblings.indices.contains(nextIndex) else { return nil }
        return siblings[nextIndex]
    }

    func toggleSnapshotSelection(_ entry: HistoryEntry) {
        if selectedSnapshotIDs.contains(entry.id) {
            selectedSnapshotIDs.remove(entry.id)
        } else if selectedSnapshotIDs.count < 2 {
            selectedSnapshotIDs.insert(entry.id)
        } else if let oldest = selectedSnapshotIDs.first {
            selectedSnapshotIDs.remove(oldest)
            selectedSnapshotIDs.insert(entry.id)
        }
    }

    func clearSnapshotSelection() {
        selectedSnapshotIDs.removeAll()
    }

    var selectedSnapshots: [HistoryEntry] {
        selectedSnapshotIDs.compactMap(historyEntry(withID:)).sorted { $0.timestamp < $1.timestamp }
    }

    @discardableResult
    func generateDiffForSelectedSnapshots(focusSectionID: String? = nil) -> DomainDiff? {
        guard selectedSnapshots.count == 2 else {
            activeDomainDiff = nil
            activeDiffChangeIndex = 0
            return nil
        }

        let diff = DiffService.compare(from: selectedSnapshots[0].snapshot, to: selectedSnapshots[1].snapshot)
        activeDomainDiff = diff
        if let focusSectionID, let index = diff.changedSectionIDs.firstIndex(of: focusSectionID) {
            activeDiffChangeIndex = index
        } else {
            activeDiffChangeIndex = 0
        }
        return diff
    }

    func generateDiff(from olderEntry: HistoryEntry, to newerEntry: HistoryEntry, focusSectionID: String? = nil) -> DomainDiff {
        selectedSnapshotIDs = [olderEntry.id, newerEntry.id]
        let diff = DiffService.compare(from: olderEntry.snapshot, to: newerEntry.snapshot)
        activeDomainDiff = diff
        if let focusSectionID, let index = diff.changedSectionIDs.firstIndex(of: focusSectionID) {
            activeDiffChangeIndex = index
        } else {
            activeDiffChangeIndex = 0
        }
        return diff
    }

    func historyEntry(for batchResult: BatchLookupResult) -> HistoryEntry? {
        guard let historyEntryID = batchResult.historyEntryID else { return nil }
        return history.first(where: { $0.id == historyEntryID })
    }

    var currentDiffTargetSectionID: String? {
        guard let activeDomainDiff, activeDomainDiff.changedSectionIDs.indices.contains(activeDiffChangeIndex) else {
            return nil
        }
        return activeDomainDiff.changedSectionIDs[activeDiffChangeIndex]
    }

    func moveToNextDiffChange() {
        guard let activeDomainDiff, !activeDomainDiff.changedSectionIDs.isEmpty else { return }
        activeDiffChangeIndex = min(activeDiffChangeIndex + 1, activeDomainDiff.changedSectionIDs.count - 1)
    }

    func moveToPreviousDiffChange() {
        guard activeDomainDiff != nil else { return }
        activeDiffChangeIndex = max(activeDiffChangeIndex - 1, 0)
    }
}
