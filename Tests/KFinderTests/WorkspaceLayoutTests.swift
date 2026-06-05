import Testing
import Foundation
@testable import KFinder

@MainActor
@Test func applyLayoutSwitchesWithoutAddingOrRemovingPanes() {
    let store = WorkspaceStore()
    store.createWorkspace() // fresh workspace seeded with a single Documents pane
    let count = store.selectedWorkspace?.directories.count

    // Layout only changes arrangement; empty grid cells become "add a pane"
    // placeholders rather than auto-created panes, so the folder count is stable.
    store.applyLayout(.grid)
    #expect(store.selectedWorkspace?.layout == .grid)
    #expect(store.selectedWorkspace?.directories.count == count)

    store.applyLayout(.columns3)
    #expect(store.selectedWorkspace?.layout == .columns3)
    #expect(store.selectedWorkspace?.directories.count == count)
}

@Test func layoutPaneCountMetadataIsConsistent() {
    #expect(WorkspaceLayout.columns2.preferredPaneCount == 2)
    #expect(WorkspaceLayout.columns3.preferredPaneCount == 3)
    #expect(WorkspaceLayout.grid.preferredPaneCount == 4)
    #expect(WorkspaceLayout.mainAndStack.preferredPaneCount == nil)
}
