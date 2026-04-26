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
        .background {
            Color(nsColor: .windowBackgroundColor)
            WindowDragArea()
        }
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
            GeometryReader { proxy in
                let directories = visibleDirectories
                let frames = paneFrames(count: directories.count, layout: workspace.layout, size: proxy.size)

                ZStack(alignment: .topLeading) {
                    ForEach(Array(directories.enumerated()), id: \.element.id) { index, item in
                        BrowserPane(
                            root: item,
                            isFocused: focusedDirectoryID == item.id,
                            viewMode: paneViewModes[item.id, default: .list],
                            onFocus: { focusedDirectoryID = item.id }
                        )
                        .frame(width: frames[index].width, height: frames[index].height)
                        .position(x: frames[index].midX, y: frames[index].midY)
                        .onTapGesture {
                            focusedDirectoryID = item.id
                        }
                    }
                }
                .background(Color(nsColor: .windowBackgroundColor))
                .onAppear {
                    if focusedDirectoryID == nil || !directories.contains(where: { $0.id == focusedDirectoryID }) {
                        focusedDirectoryID = directories.first?.id
                    }
                }
                .onChange(of: workspace.directories) { directories in
                    if focusedDirectoryID == nil || !directories.contains(where: { $0.id == focusedDirectoryID }) {
                        focusedDirectoryID = directories.first?.id
                    }
                }
            }
        }
    }

    private var visibleDirectories: [DirectoryItem] {
        Array(workspace.directories.prefix(6))
    }

    private func paneFrames(count: Int, layout: WorkspaceLayout, size: CGSize) -> [CGRect] {
        let gap: CGFloat = 1
        let frame = CGRect(origin: .zero, size: size)

        switch layout {
        case .columns2:
            return gridFrames(count: count, columns: min(max(count, 1), 2), in: frame, gap: gap)
        case .columns3:
            return gridFrames(count: count, columns: min(max(count, 1), 3), in: frame, gap: gap)
        case .grid:
            return gridFrames(count: count, columns: count <= 1 ? 1 : 2, in: frame, gap: gap)
        case .mainAndStack:
            return mainAndStackFrames(count: count, in: frame, gap: gap)
        }
    }

    private func gridFrames(count: Int, columns: Int, in frame: CGRect, gap: CGFloat) -> [CGRect] {
        let rows = Int(ceil(Double(count) / Double(columns)))
        let width = (frame.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let height = (frame.height - CGFloat(rows - 1) * gap) / CGFloat(rows)

        return (0..<count).map { index in
            let row = index / columns
            let column = index % columns
            return CGRect(
                x: CGFloat(column) * (width + gap),
                y: CGFloat(row) * (height + gap),
                width: width,
                height: height
            )
        }
    }

    private func mainAndStackFrames(count: Int, in frame: CGRect, gap: CGFloat) -> [CGRect] {
        guard count > 1 else { return [frame] }
        let mainWidth = frame.width * 0.58
        let sideWidth = frame.width - mainWidth - gap
        let sideCount = count - 1
        let sideHeight = (frame.height - CGFloat(sideCount - 1) * gap) / CGFloat(sideCount)

        let main = CGRect(x: 0, y: 0, width: mainWidth, height: frame.height)
        let side = (0..<sideCount).map { index in
            CGRect(x: mainWidth + gap, y: CGFloat(index) * (sideHeight + gap), width: sideWidth, height: sideHeight)
        }
        return [main] + side
    }
}
