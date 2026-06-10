import Foundation

/// Pure keyboard-selection stepping for a pane's visible rows, extracted from
/// the view so it is unit-testable (the NSEvent plumbing itself is not).
enum PaneSelectionLogic {
    /// The row id an Up/Down arrow press should land on.
    /// - `ids`: visible row ids in display order.
    /// - `anchor`: the last clicked/keyed row (kept while Shift-extending).
    /// - Returns nil only when there are no rows.
    static func stepTarget(ids: [String], selection: Set<String>, anchor: String?, forward: Bool) -> String? {
        guard !ids.isEmpty else { return nil }

        let reference: Int?
        if let anchor, selection.contains(anchor), let anchorIndex = ids.firstIndex(of: anchor) {
            reference = anchorIndex
        } else {
            let selectedIndexes = ids.indices.filter { selection.contains(ids[$0]) }
            reference = forward ? selectedIndexes.max() : selectedIndexes.min()
        }

        guard let reference else { return forward ? ids.first : ids.last }
        let target = forward ? min(reference + 1, ids.count - 1) : max(reference - 1, 0)
        return ids[target]
    }
}

/// Pure name filtering for the pane's Cmd+F filter bar.
enum PaneFilterLogic {
    static func filter(_ items: [BrowserFileItem], query: String) -> [BrowserFileItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}
