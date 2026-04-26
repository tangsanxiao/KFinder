import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @State private var focusedDirectoryID: UUID?
    @State private var paneViewModes: [UUID: BrowserViewMode] = [:]
    @State private var isSidebarVisible = true

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                SidebarView(
                    focusedDirectoryID: $focusedDirectoryID,
                    collapse: { isSidebarVisible = false }
                )
                .frame(width: 250)

                Divider()
            } else {
                CollapsedSidebarHandle {
                    isSidebarVisible = true
                }
                .frame(width: 44)

                Divider()
            }

            WorkspaceDetailView(focusedDirectoryID: $focusedDirectoryID, paneViewModes: $paneViewModes)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(WindowChromeConfigurator())
        .onAppear {
            focusedDirectoryID = store.selectedWorkspace?.directories.first?.id
        }
        .onChange(of: store.selectedWorkspaceID) { _ in
            focusedDirectoryID = store.selectedWorkspace?.directories.first?.id
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
