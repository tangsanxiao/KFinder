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

                MultiPaneBrowserView(
                    workspace: workspace, focusedDirectoryID: $focusedDirectoryID, paneViewModes: $paneViewModes)
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

            Text("Layout")
                .foregroundStyle(.secondary)

            layoutMenu

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

            Button {
                AppRelauncher.relaunch()
            } label: {
                Image(systemName: "arrow.clockwise.circle")
                    .frame(width: 30, height: 28)
            }
            .buttonStyle(.borderless)
            .help("Restart app (debug)")
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
        Button {
            isSidebarVisible.toggle()
        } label: {
            Image(systemName: "sidebar.left")
                .frame(width: 30, height: 28)
        }
        .buttonStyle(.borderless)
        .help(isSidebarVisible ? "Collapse sidebar" : "Expand sidebar")
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
                        store.applyLayout(layout)
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
    @EnvironmentObject private var store: WorkspaceStore
    let workspace: Workspace
    @Binding var focusedDirectoryID: UUID?
    @Binding var paneViewModes: [UUID: BrowserViewMode]
    @State private var mainFraction: CGFloat = 0.58
    @State private var resizeStartMainWidth: CGFloat?

    var body: some View {
        if workspace.directories.isEmpty {
            // All panes closed — show the same greyed add-pane placeholder as an
            // empty grid cell, so there is always a way to add a folder back.
            PaneAddPlaceholder { store.addDirectoriesFromOpenPanel() }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
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
        case .columns2, .columns3, .grid:
            gridPaneLayout(
                directories, columns: workspace.layout.gridColumns,
                minCells: workspace.layout.preferredPaneCount ?? directories.count)
        case .mainAndStack:
            mainAndStackPaneLayout(directories)
        }
    }

    private var visibleDirectories: [DirectoryItem] {
        Array(workspace.directories.prefix(6))
    }

    /// One slot in the pane grid: either a real pane or a greyed placeholder the
    /// user can click to add a folder (shown when the layout wants more panes
    /// than there are folders, e.g. after switching layout or closing a pane).
    private enum PaneCell: Identifiable {
        case pane(DirectoryItem)
        case placeholder(Int)

        var id: String {
            switch self {
            case .pane(let item): return "pane-\(item.id.uuidString)"
            case .placeholder(let index): return "placeholder-\(index)"
            }
        }
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

    private func gridPaneLayout(_ directories: [DirectoryItem], columns: Int, minCells: Int) -> some View {
        let cellCount = max(directories.count, minCells)
        let cells: [PaneCell] = (0..<cellCount).map { index in
            index < directories.count ? .pane(directories[index]) : .placeholder(index)
        }
        let rows = chunked(cells, size: columns)

        return VStack(spacing: 1) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 1) {
                    ForEach(row) { cell in
                        gridCell(cell)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    if row.count < columns {
                        ForEach(0..<(columns - row.count), id: \.self) { _ in
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func gridCell(_ cell: PaneCell) -> some View {
        switch cell {
        case .pane(let item):
            paneView(for: item)
        case .placeholder:
            PaneAddPlaceholder { store.addDirectoriesFromOpenPanel() }
        }
    }

    private func mainAndStackPaneLayout(_ directories: [DirectoryItem]) -> some View {
        GeometryReader { proxy in
            let sideItems = Array(directories.dropFirst())

            if let first = directories.first {
                let handleWidth: CGFloat = 6
                let minPane: CGFloat = 200
                let available = max(proxy.size.width - handleWidth, minPane * 2)
                let mainWidth = min(max(available * mainFraction, minPane), available - minPane)
                let sideWidth = available - mainWidth

                HStack(spacing: 0) {
                    paneView(for: first)
                        .frame(width: mainWidth)

                    paneResizeHandle(width: handleWidth, available: available, currentMain: mainWidth)

                    // The stack region always shows: existing side panes, or a
                    // greyed "add a pane" placeholder when there are none, so
                    // Main + Stack never collapses to a single lone pane.
                    Group {
                        if sideItems.isEmpty {
                            PaneAddPlaceholder { store.addDirectoriesFromOpenPanel() }
                        } else {
                            VStack(spacing: 1) {
                                ForEach(sideItems) { item in
                                    paneView(for: item)
                                }
                            }
                        }
                    }
                    .frame(width: sideWidth)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            }
        }
    }

    private func paneResizeHandle(width: CGFloat, available: CGFloat, currentMain: CGFloat) -> some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .hoverCursor(.resizeLeftRight)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let start = resizeStartMainWidth ?? currentMain
                        if resizeStartMainWidth == nil { resizeStartMainWidth = start }
                        let newMain = start + value.translation.width
                        mainFraction = min(max(newMain / available, 0.2), 0.8)
                    }
                    .onEnded { _ in resizeStartMainWidth = nil }
            )
    }

    private func chunked<T>(_ items: [T], size: Int) -> [[T]] {
        stride(from: 0, to: items.count, by: max(size, 1)).map { start in
            Array(items[start..<min(start + max(size, 1), items.count)])
        }
    }
}

private struct PaneAddPlaceholder: View {
    let onAdd: () -> Void
    @State private var isHovering = false

    var body: some View {
        ZStack {
            // Greyed, dashed-border backdrop — decoration only, NOT clickable.
            Color(nsColor: .windowBackgroundColor)
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                )
                .padding(6)
                .allowsHitTesting(false)

            // Only the icon + label triggers the add action, with a hover state.
            Button(action: onAdd) {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 30, weight: .light))
                    Text("点击添加文件面板")
                        .font(.system(size: 13))
                }
                .foregroundStyle(isHovering ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(isHovering ? 0.12 : 0))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .fixedSize()
            .onHover { isHovering = $0 }
            .hoverCursor(.pointingHand)
            .help("添加一个文件面板")
            .animation(.easeOut(duration: 0.12), value: isHovering)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
