import Foundation

/// Pure grid geometry for the pane area: given a layout preset and the actual
/// pane count, produces the real rows×columns the grid will render. This is
/// the single source of truth the grid AND the Layout control both read, so
/// what the control says always matches what the panes do (the old
/// view-local math drifted from the layout icon).
enum PaneGridGeometry {
    struct Grid: Equatable {
        let columns: Int
        /// Total slots — panes plus "待添加" placeholders, rounded up to whole
        /// rows so every empty cell is a real selectable placeholder.
        let cellCount: Int

        var rows: Int { cellCount / columns + (cellCount % columns == 0 ? 0 : 1) }
    }

    static func grid(for layout: WorkspaceLayout, paneCount: Int) -> Grid {
        let columns = max(layout.gridColumns, 1)
        let base = max(paneCount, layout.preferredPaneCount ?? paneCount, 1)
        let rounded = Int((Double(base) / Double(columns)).rounded(.up)) * columns
        return Grid(columns: columns, cellCount: rounded)
    }

    /// Live description for the Layout control, e.g. "3 面板 · Three Columns"
    /// or "5 面板 · Grid (3×2)" when panes overflow the preset's cells.
    static func describe(layout: WorkspaceLayout, paneCount: Int) -> String {
        let paneText = "\(paneCount) 面板"
        guard layout != .mainAndStack else { return "\(paneText) · \(layout.title)" }
        let grid = grid(for: layout, paneCount: paneCount)
        if let preferred = layout.preferredPaneCount, grid.cellCount <= preferred {
            return "\(paneText) · \(layout.title)"
        }
        return "\(paneText) · \(layout.title) (\(grid.rows)×\(grid.columns))"
    }
}
