import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @State private var paneViewModes: [UUID: BrowserViewMode] = [:]
    @State private var isSidebarVisible = true

    /// Focus is owned by the store (single source of truth); this binding lets
    /// the existing child views keep their `focusedDirectoryID` interface.
    private var focusedDirectoryID: Binding<UUID?> {
        Binding(get: { store.focusedPaneID }, set: { store.focusedPaneID = $0 })
    }

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                SidebarView(
                    focusedDirectoryID: focusedDirectoryID
                )
                .frame(width: 175)

                Divider()
            }

            WorkspaceDetailView(
                focusedDirectoryID: focusedDirectoryID,
                paneViewModes: $paneViewModes,
                isSidebarVisible: $isSidebarVisible
            )
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowChromeConfigurator())
        .onAppear {
            if store.focusedPaneID == nil {
                store.focusedPaneID = store.selectedWorkspace?.directories.first?.id
            }
        }
        .onChange(of: store.selectedWorkspaceID) { _ in
            store.focusedPaneID = store.selectedWorkspace?.directories.first?.id
        }
        .alert("KFinder", isPresented: errorBinding) {
            Button("OK") {
                store.lastError = nil
            }
        } message: {
            Text(store.lastError ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.lastError != nil },
            set: { if $0 == false { store.lastError = nil } }
        )
    }
}
