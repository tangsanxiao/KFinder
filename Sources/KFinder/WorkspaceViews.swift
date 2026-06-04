import SwiftUI

struct WorkspaceDetailView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @Binding var focusedDirectoryID: UUID?
    @Binding var paneViewModes: [UUID: BrowserViewMode]
    @Binding var isSidebarVisible: Bool

    var body: some View {
        if let workspace = store.selectedWorkspace {
            VStack(spacing: 0) {
                FinderLikeToolbar(
                    workspace: workspace,
                    focusedDirectoryID: $focusedDirectoryID,
                    paneViewModes: $paneViewModes,
                    isSidebarVisible: $isSidebarVisible
                )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        Color(nsColor: .windowBackgroundColor)
                        WindowDragArea()
                            .frame(height: 44)
                    }

                Divider()

                MultiPaneBrowserView(workspace: workspace, focusedDirectoryID: $focusedDirectoryID, paneViewModes: $paneViewModes)
            }
        } else {
            EmptyStateView(
                title: "No Workspace",
                systemImage: "rectangle.3.group",
                description: "Create a workspace to start grouping folders into panes."
            )
        }
    }
}

private struct FinderLikeToolbar: View {
    @EnvironmentObject private var store: WorkspaceStore
    let workspace: Workspace
    @Binding var focusedDirectoryID: UUID?
    @Binding var paneViewModes: [UUID: BrowserViewMode]
    @Binding var isSidebarVisible: Bool
    @State private var isLayoutPopoverShown = false

    var body: some View {
        HStack(spacing: 14) {
            leadingControls

            Text(store.paneTitle(for: focusedDirectoryID))
                .font(.system(size: 20, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 180, maxWidth: 320, alignment: .leading)

            Spacer()

            Text("View")
                .foregroundStyle(.secondary)

            Picker("View", selection: viewMode) {
                ForEach(BrowserViewMode.allCases) { mode in
                    Image(systemName: mode.systemImage)
                        .help(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 156)
        }
        .padding(.leading, isSidebarVisible ? 0 : 66)
        .frame(height: 44)
        .background(Color(nsColor: .windowBackgroundColor))
        .onTapGesture(count: 2) {
            WindowZoomController.toggle()
        }
    }

    private var viewMode: Binding<BrowserViewMode> {
        Binding(
            get: {
                guard let focusedDirectoryID else { return .list }
                return paneViewModes[focusedDirectoryID, default: .list]
            },
            set: { newValue in
                guard let focusedDirectoryID else { return }
                paneViewModes[focusedDirectoryID] = newValue
            }
        )
    }

    private var leadingControls: some View {
        HStack(spacing: 4) {
            Button {
                isSidebarVisible.toggle()
            } label: {
                Image(systemName: "sidebar.left")
                    .frame(width: 30, height: 28)
            }
            .buttonStyle(.borderless)
            .help(isSidebarVisible ? "Collapse sidebar" : "Expand sidebar")

            layoutMenu
        }
    }

    private var layoutMenu: some View {
        Button {
            isLayoutPopoverShown.toggle()
        } label: {
            Image(systemName: workspace.layout.systemImage)
                .frame(width: 30, height: 28)
        }
        .buttonStyle(.borderless)
        .help("Layout and panes")
        .popover(isPresented: $isLayoutPopoverShown, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Layout")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(WorkspaceLayout.allCases) { layout in
                    Button {
                        var updated = workspace
                        updated.layout = layout
                        store.updateSelectedWorkspace(updated)
                        isLayoutPopoverShown = false
                    } label: {
                        Label(layout.title, systemImage: layout.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }

                Divider()

                Button {
                    store.addDirectoriesFromOpenPanel()
                    isLayoutPopoverShown = false
                } label: {
                    Label("Add Pane", systemImage: "square.split.2x2")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)

                Button {
                    store.importOpenFinderWindows()
                    isLayoutPopoverShown = false
                } label: {
                    Label("Import Finder Windows", systemImage: "macwindow.badge.plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .help("Import the folders from currently open Finder windows as panes.")
            }
            .padding(12)
            .frame(width: 220)
        }
    }
}

private struct MultiPaneBrowserView: View {
    let workspace: Workspace
    @Binding var focusedDirectoryID: UUID?
    @Binding var paneViewModes: [UUID: BrowserViewMode]

    var body: some View {
        if workspace.directories.isEmpty {
            EmptyStateView(
                title: "No Folders",
                systemImage: "folder",
                description: "Add folders as panes or import the Finder windows you already have open."
            )
        } else {
            paneLayout
                .background(Color(nsColor: .windowBackgroundColor))
                .onAppear {
                    keepFocusedPaneVisible()
                }
                .onChange(of: workspace.directories) { _ in
                    keepFocusedPaneVisible()
                }
        }
    }

    @ViewBuilder
    private var paneLayout: some View {
        let directories = visibleDirectories

        switch workspace.layout {
        case .columns2:
            gridPaneLayout(directories, columns: min(max(directories.count, 1), 2))
        case .columns3:
            gridPaneLayout(directories, columns: min(max(directories.count, 1), 3))
        case .grid:
            gridPaneLayout(directories, columns: directories.count <= 1 ? 1 : 2)
        case .mainAndStack:
            mainAndStackPaneLayout(directories)
        }
    }

    private var visibleDirectories: [DirectoryItem] {
        Array(workspace.directories.prefix(6))
    }

    private func keepFocusedPaneVisible() {
        let directories = visibleDirectories
        if focusedDirectoryID == nil || !directories.contains(where: { $0.id == focusedDirectoryID }) {
            focusedDirectoryID = directories.first?.id
        }
    }

    private func paneView(for item: DirectoryItem) -> some View {
        BrowserPane(
            root: item,
            isFocused: focusedDirectoryID == item.id,
            viewMode: paneViewModes[item.id, default: .list],
            onFocus: { focusedDirectoryID = item.id }
        )
        .onTapGesture {
            focusedDirectoryID = item.id
        }
    }

    private func gridPaneLayout(_ directories: [DirectoryItem], columns: Int) -> some View {
        let rows = chunked(directories, size: columns)

        return VStack(spacing: 1) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 1) {
                    ForEach(row) { item in
                        paneView(for: item)
                    }

                    if row.count < columns {
                        ForEach(0..<(columns - row.count), id: \.self) { _ in
                            Color.clear
                        }
                    }
                }
            }
        }
    }

    private func mainAndStackPaneLayout(_ directories: [DirectoryItem]) -> some View {
        HStack(spacing: 1) {
            if let first = directories.first {
                paneView(for: first)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
            }

            let sideItems = Array(directories.dropFirst())
            if !sideItems.isEmpty {
                VStack(spacing: 1) {
                    ForEach(sideItems) { item in
                        paneView(for: item)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func chunked(_ items: [DirectoryItem], size: Int) -> [[DirectoryItem]] {
        stride(from: 0, to: items.count, by: max(size, 1)).map { start in
            Array(items[start..<min(start + max(size, 1), items.count)])
        }
    }
}
