import Testing

@testable import XFinder

@Test func gridPadsToPreferredCountWithPlaceholders() {
    // 1 pane on Three Columns → 3 cells (2 placeholders), one row.
    let grid = PaneGridGeometry.grid(for: .columns3, paneCount: 1)
    #expect(grid == PaneGridGeometry.Grid(columns: 3, cellCount: 3))
    #expect(grid.rows == 1)
}

@Test func gridRoundsOverflowUpToWholeRows() {
    // 5 panes on Grid (2 columns, prefers 4) → 6 cells over 3 rows.
    let grid = PaneGridGeometry.grid(for: .grid, paneCount: 5)
    #expect(grid == PaneGridGeometry.Grid(columns: 2, cellCount: 6))
    #expect(grid.rows == 3)
}

@Test func gridAlwaysHasAtLeastOneCell() {
    let grid = PaneGridGeometry.grid(for: .mainAndStack, paneCount: 0)
    #expect(grid.cellCount >= 1)
}

@Test func describeShowsRealRowsOnlyWhenOverflowing() {
    #expect(PaneGridGeometry.describe(layout: .columns3, paneCount: 3) == "Three Columns")
    #expect(PaneGridGeometry.describe(layout: .grid, paneCount: 5) == "Grid (3×2)")
    #expect(PaneGridGeometry.describe(layout: .single, paneCount: 1) == "Single")
}
