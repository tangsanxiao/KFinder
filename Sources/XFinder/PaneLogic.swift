import Foundation

/// Pure keyboard-selection stepping for a pane's visible rows, extracted from
/// the view so it is unit-testable (the NSEvent plumbing itself is not).
enum PaneSelectionLogic {
    /// Selection state for Cmd+A: every visible row becomes selected, and the
    /// first visible row is the anchor for later Shift extension.
    static func selectAll(ids: [String]) -> (selection: Set<String>, anchor: String?) {
        (Set(ids), ids.first)
    }

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

struct PaneVisibleRow: Identifiable, Equatable {
    let file: BrowserFileItem
    let depth: Int
    let ordinal: Int
    let id: String

    init(file: BrowserFileItem, depth: Int, ordinal: Int) {
        self.file = file
        self.depth = depth
        self.ordinal = ordinal
        id = "\(file.id)-\(depth)"
    }
}

enum PaneVisibleRowLogic {
    static func flatten(
        _ items: [BrowserFileItem],
        expandedFolderIDs: Set<String>,
        expandedContents: [String: [BrowserFileItem]],
        canBrowseInline: (BrowserFileItem) -> Bool,
        sortAndFilterChildren: ([BrowserFileItem]) -> [BrowserFileItem]
    ) -> [PaneVisibleRow] {
        var rows: [PaneVisibleRow] = []
        rows.reserveCapacity(items.count + expandedContents.values.reduce(0) { $0 + $1.count })
        var ordinal = 0
        appendRows(
            items,
            depth: 0,
            ordinal: &ordinal,
            expandedFolderIDs: expandedFolderIDs,
            expandedContents: expandedContents,
            canBrowseInline: canBrowseInline,
            sortAndFilterChildren: sortAndFilterChildren,
            into: &rows
        )
        return rows
    }

    private static func appendRows(
        _ items: [BrowserFileItem],
        depth: Int,
        ordinal: inout Int,
        expandedFolderIDs: Set<String>,
        expandedContents: [String: [BrowserFileItem]],
        canBrowseInline: (BrowserFileItem) -> Bool,
        sortAndFilterChildren: ([BrowserFileItem]) -> [BrowserFileItem],
        into rows: inout [PaneVisibleRow]
    ) {
        for file in items {
            rows.append(PaneVisibleRow(file: file, depth: depth, ordinal: ordinal))
            ordinal += 1
            guard canBrowseInline(file),
                expandedFolderIDs.contains(file.id),
                let children = expandedContents[file.id]
            else { continue }
            appendRows(
                sortAndFilterChildren(children),
                depth: depth + 1,
                ordinal: &ordinal,
                expandedFolderIDs: expandedFolderIDs,
                expandedContents: expandedContents,
                canBrowseInline: canBrowseInline,
                sortAndFilterChildren: sortAndFilterChildren,
                into: &rows
            )
        }
    }
}
