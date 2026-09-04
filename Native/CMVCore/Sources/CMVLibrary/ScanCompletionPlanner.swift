import CMVDomain

/// Derives deletions only after a complete source scan. Streaming batches may
/// persist changed metadata immediately, but an interrupted scan must never
/// convert unseen records into missing tracks.
public enum ScanCompletionPlanner {
    public static func missingIdentifiers(
        existing: [Track],
        seenIdentifiers: Set<String>,
        completedWithoutIssues: Bool
    ) -> [String] {
        guard completedWithoutIssues else { return [] }
        return existing.lazy
            .filter {
                $0.availability != .missing &&
                !seenIdentifiers.contains($0.fileIdentifier)
            }
            .map(\.fileIdentifier)
            .sorted()
    }
}
