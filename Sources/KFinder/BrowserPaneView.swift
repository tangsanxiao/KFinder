import SwiftUI

struct BrowserPane: View {
    @EnvironmentObject private var store: WorkspaceStore
    let root: DirectoryItem
    let isFocused: Bool
    let viewMode: BrowserViewMode
    let onFocus: () -> Void

    @State private var currentURL: URL
    @State private var backStack: [URL] = []
    @State private var forwardStack: [URL] = []
    @State private var items: [BrowserFileItem] = []
    @State private var expandedFolders: Set<String> = []
    @State private var expandedContents: [String: [BrowserFileItem]] = [:]
    @State private var selection: BrowserFileItem.ID?
    @State private var errorMessage: String?
    @State private var toolbarTooltip: String?

    init(root: DirectoryItem, isFocused: Bool, viewMode: BrowserViewMode, onFocus: @escaping () -> Void) {
        self.root = root
        self.isFocused = isFocused
        self.viewMode = viewMode
        self.onFocus = onFocus
        _currentURL = State(initialValue: URL(fileURLWithPath: root.path))
    }

    var body: some View {
        VStack(spacing: 0) {
            paneToolbar
                .zIndex(2)
            Divider()
                .zIndex(2)
            if viewMode != .columns {
                tableHeader
                    .zIndex(1)
                Divider()
                    .zIndex(1)
            }

            if let errorMessage {
                EmptyStateView(title: "Cannot Open Folder", systemImage: "exclamationmark.triangle", description: errorMessage)
            } else {
                fileContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipped()
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: isFocused ? 16 : 0))
        .overlay {
            RoundedRectangle(cornerRadius: isFocused ? 16 : 0)
                .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 2)
        }
        .simultaneousGesture(TapGesture().onEnded { onFocus() })
        .task(id: currentURL) {
            reload()
        }
        .onChange(of: store.fileOperationRevision) { _ in
            reloadPreservingExpansion()
        }
        .onChange(of: root.path) { newPath in
            currentURL = URL(fileURLWithPath: newPath)
            backStack.removeAll()
            forwardStack.removeAll()
            expandedFolders.removeAll()
            expandedContents.removeAll()
        }
    }

    @ViewBuilder
    private var fileContent: some View {
        switch viewMode {
        case .icons:
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 12) {
                    ForEach(items) { file in
                        IconFileCell(
                            file: file,
                            isSelected: selection == file.id,
                            isActivePane: isFocused,
                            select: {
                                onFocus()
                                select(file)
                            },
                            open: {
                                onFocus()
                                open(file)
                            },
                            trash: {
                                onFocus()
                                store.moveToTrash(file.url)
                            }
                        )
                    }
                }
                .padding(12)
            }
        case .list:
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(flatRows) { row in
                        FileRow(
                            file: row.file,
                            depth: row.depth,
                            isExpanded: expandedFolders.contains(row.file.id),
                            isSelected: selection == row.file.id,
                            isActivePane: isFocused,
                            destinations: destinations,
                            select: {
                                onFocus()
                                select(row.file)
                            },
                            open: {
                                onFocus()
                                open(row.file)
                            },
                            toggleExpansion: {
                                onFocus()
                                toggleExpansion(row.file)
                            },
                            copy: { copyPath(row.file.url.path) },
                            reveal: { NSWorkspace.shared.activateFileViewerSelecting([row.file.url]) },
                            trash: {
                                store.moveToTrash(row.file.url)
                                reload()
                            },
                            copyTo: { destination in
                                store.copy(row.file.url, to: destination)
                                reload()
                            },
                            moveTo: { destination in
                                store.move(row.file.url, to: destination)
                                reload()
                            }
                        )
                    }
                }
            }
        case .columns:
            columnContent
        }
    }

    private var columnContent: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                columnList(items, width: 240)

                if let selectedFolderChildren {
                    Divider()
                    columnList(selectedFolderChildren, width: 260)
                }
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }

    private var paneToolbar: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 8) {
                Button {
                    onFocus()
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(backStack.isEmpty)
                .help("Back")

                Button {
                    onFocus()
                    goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(forwardStack.isEmpty)
                .help("Forward")

                Button {
                    onFocus()
                    goUp()
                } label: {
                    Image(systemName: "arrow.up")
                }
                .disabled(currentURL.path == "/")
                .help("Parent folder")

                pathCrumbs
                Spacer(minLength: 8)

                PaneToolbarActionButton(
                    systemImage: "arrow.up.forward.app",
                    accessibilityLabel: "Reveal in Finder",
                    tooltip: "在 Finder 中显示当前目录",
                    hoveredTooltip: $toolbarTooltip
                ) {
                    onFocus()
                    NSWorkspace.shared.activateFileViewerSelecting([currentURL])
                }

                PaneToolbarActionButton(
                    systemImage: "doc.on.doc",
                    accessibilityLabel: "Copy Path",
                    tooltip: "复制当前目录路径",
                    hoveredTooltip: $toolbarTooltip
                ) {
                    onFocus()
                    copyPath(currentURL.path)
                }

                PaneToolbarActionButton(
                    systemImage: "xmark.circle",
                    accessibilityLabel: "Close Pane",
                    tooltip: "关闭当前文件管理面板",
                    hoveredTooltip: $toolbarTooltip
                ) {
                    onFocus()
                    store.removeDirectory(root)
                }
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .frame(height: 44)

            if let toolbarTooltip {
                Text(toolbarTooltip)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.black.opacity(0.82))
                    )
                    .fixedSize()
                    .padding(.trailing, 10)
                    .offset(y: 34)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .zIndex(3)
            }
        }
        .frame(height: 44)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var pathCrumbs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(crumbs, id: \.url.path) { crumb in
                    Button {
                        onFocus()
                        navigate(to: crumb.url)
                    } label: {
                        HStack(spacing: 4) {
                            if crumb.isRoot {
                                Image(systemName: "internaldrive")
                            }
                            Text(crumb.title)
                                .lineLimit(1)
                            if crumb.url != crumbs.last?.url {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .clipped()
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("Name")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Modified")
                .frame(width: 150, alignment: .leading)
            Text("Size")
                .frame(width: 90, alignment: .trailing)
            Text("Kind")
                .frame(width: 120, alignment: .leading)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var crumbs: [PathCrumb] {
        var result: [PathCrumb] = []
        var url = currentURL.standardizedFileURL
        let root = URL(fileURLWithPath: "/")

        while true {
            let isRoot = url.path == "/"
            result.append(PathCrumb(url: url, title: isRoot ? "Macintosh HD" : url.lastPathComponent, isRoot: isRoot))
            if isRoot { break }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path {
                result.append(PathCrumb(url: root, title: "Macintosh HD", isRoot: true))
                break
            }
            url = parent
        }

        return result.reversed()
    }

    private var destinations: [PaneDestination] {
        store.paneDestinations(excluding: root.id)
    }

    private var selectedFolderChildren: [BrowserFileItem]? {
        guard let selected = items.first(where: { $0.id == selection }),
              selected.canBrowseInline else { return nil }
        return expandedContents[selected.id]
    }

    private func columnList(_ source: [BrowserFileItem], width: CGFloat) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(source) { file in
                ColumnFileRow(
                    file: file,
                    isSelected: selection == file.id,
                    isActivePane: isFocused,
                    destinations: destinations,
                    select: {
                        onFocus()
                        select(file)
                    },
                    open: {
                        onFocus()
                        open(file)
                    },
                    copy: { copyPath(file.url.path) },
                    reveal: { NSWorkspace.shared.activateFileViewerSelecting([file.url]) },
                    trash: {
                        store.moveToTrash(file.url)
                        reload()
                    },
                    copyTo: { destination in
                        store.copy(file.url, to: destination)
                        reload()
                    },
                    moveTo: { destination in
                        store.move(file.url, to: destination)
                        reload()
                    }
                )
            }
        }
        .frame(width: width, alignment: .topLeading)
    }

    private func reload() {
        do {
            store.updatePaneLocation(id: root.id, url: currentURL)
            items = try FileBrowserService.contents(of: currentURL)
            expandedFolders.removeAll()
            expandedContents.removeAll()
            errorMessage = nil
        } catch {
            items = []
            errorMessage = error.localizedDescription
        }
    }

    private func reloadPreservingExpansion() {
        do {
            store.updatePaneLocation(id: root.id, url: currentURL)
            items = try FileBrowserService.contents(of: currentURL)
            for folderID in expandedFolders {
                let folderURL = URL(fileURLWithPath: folderID)
                expandedContents[folderID] = try? FileBrowserService.contents(of: folderURL)
            }
            errorMessage = nil
        } catch {
            items = []
            errorMessage = error.localizedDescription
        }
    }

    private var flatRows: [FileTreeRow] {
        flatten(items, depth: 0)
    }

    private func flatten(_ source: [BrowserFileItem], depth: Int) -> [FileTreeRow] {
        source.flatMap { file -> [FileTreeRow] in
            var rows = [FileTreeRow(file: file, depth: depth)]
            if expandedFolders.contains(file.id), let children = expandedContents[file.id] {
                rows.append(contentsOf: flatten(children, depth: depth + 1))
            }
            return rows
        }
    }

    private func toggleExpansion(_ file: BrowserFileItem) {
        guard file.canBrowseInline else { return }
        if expandedFolders.contains(file.id) {
            expandedFolders.remove(file.id)
            return
        }

        do {
            expandedContents[file.id] = try FileBrowserService.contents(of: file.url)
            expandedFolders.insert(file.id)
        } catch {
            store.lastError = error.localizedDescription
        }
    }

    private func select(_ file: BrowserFileItem) {
        selection = file.id
        guard viewMode == .columns, file.canBrowseInline else { return }
        if expandedContents[file.id] == nil {
            expandedContents[file.id] = try? FileBrowserService.contents(of: file.url)
        }
    }

    private func open(_ file: BrowserFileItem) {
        if file.canBrowseInline {
            navigate(to: file.url)
        } else {
            NSWorkspace.shared.open(file.url)
        }
    }

    private func navigate(to url: URL) {
        onFocus()
        guard url != currentURL else { return }
        backStack.append(currentURL)
        forwardStack.removeAll()
        currentURL = url
        selection = nil
    }

    private func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(currentURL)
        currentURL = previous
        selection = nil
    }

    private func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentURL)
        currentURL = next
        selection = nil
    }

    private func goUp() {
        navigate(to: currentURL.deletingLastPathComponent())
    }

    private func copyPath(_ path: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        store.statusMessage = "Copied path"
    }
}

private struct PathCrumb: Hashable {
    let url: URL
    let title: String
    let isRoot: Bool
}

private struct FileTreeRow: Identifiable {
    let file: BrowserFileItem
    let depth: Int

    var id: String { "\(file.id)-\(depth)" }
}

private struct PaneToolbarActionButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let tooltip: String
    @Binding var hoveredTooltip: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(accessibilityLabel)
        .help(tooltip)
        .onHover { isHovered in
            withAnimation(.easeOut(duration: 0.08)) {
                hoveredTooltip = isHovered ? tooltip : nil
            }
        }
    }
}
