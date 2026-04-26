import SwiftUI
import UniformTypeIdentifiers

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
    @State private var renamingFileID: BrowserFileItem.ID?
    @State private var renameDraft = ""
    @State private var sortKey: BrowserSortKey = .name
    @State private var sortAscending = true
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
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers)
        }
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
                    ForEach(sortedItems) { file in
                        IconFileCell(
                            file: file,
                            isSelected: selection == file.id,
                            isActivePane: isFocused,
                            isRenaming: renamingFileID == file.id,
                            renameDraft: $renameDraft,
                            select: {
                                onFocus()
                                select(file)
                            },
                            nameClick: {
                                onFocus()
                                handleNameClick(file)
                            },
                            commitRename: { commitRename(file) },
                            cancelRename: { cancelRename() },
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
                            isRenaming: renamingFileID == row.file.id,
                            renameDraft: $renameDraft,
                            destinations: destinations,
                            select: {
                                onFocus()
                                select(row.file)
                            },
                            nameClick: {
                                onFocus()
                                handleNameClick(row.file)
                            },
                            commitRename: { commitRename(row.file) },
                            cancelRename: { cancelRename() },
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
                columnList(sortedItems, width: 240)

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
            SortHeaderButton(
                title: "Modified",
                key: .modified,
                currentKey: sortKey,
                isAscending: sortAscending,
                action: { setSort(.modified) }
            )
                .frame(width: 150, alignment: .leading)
            Text("Size")
                .frame(width: 96, alignment: .trailing)
                .padding(.trailing, 18)
            SortHeaderButton(
                title: "Kind",
                key: .kind,
                currentKey: sortKey,
                isAscending: sortAscending,
                action: { setSort(.kind) }
            )
                .frame(width: 136, alignment: .leading)
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

    private var sortedItems: [BrowserFileItem] {
        sorted(items)
    }

    private var selectedFolderChildren: [BrowserFileItem]? {
        guard let selected = items.first(where: { $0.id == selection }),
              selected.canBrowseInline else { return nil }
        return expandedContents[selected.id].map(sorted)
    }

    private func columnList(_ source: [BrowserFileItem], width: CGFloat) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(source) { file in
                ColumnFileRow(
                    file: file,
                    isSelected: selection == file.id,
                    isActivePane: isFocused,
                    isRenaming: renamingFileID == file.id,
                    renameDraft: $renameDraft,
                    destinations: destinations,
                    select: {
                        onFocus()
                        select(file)
                    },
                    nameClick: {
                        onFocus()
                        handleNameClick(file)
                    },
                    commitRename: { commitRename(file) },
                    cancelRename: { cancelRename() },
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
            renamingFileID = nil
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
        flatten(sortedItems, depth: 0)
    }

    private func flatten(_ source: [BrowserFileItem], depth: Int) -> [FileTreeRow] {
        source.flatMap { file -> [FileTreeRow] in
            var rows = [FileTreeRow(file: file, depth: depth)]
            if expandedFolders.contains(file.id), let children = expandedContents[file.id] {
                rows.append(contentsOf: flatten(sorted(children), depth: depth + 1))
            }
            return rows
        }
    }

    private func setSort(_ key: BrowserSortKey) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = key.defaultAscending
        }
    }

    private func sorted(_ source: [BrowserFileItem]) -> [BrowserFileItem] {
        source.sorted { lhs, rhs in
            let order: ComparisonResult
            switch sortKey {
            case .name:
                order = lhs.name.localizedStandardCompare(rhs.name)
            case .modified:
                order = compareDates(lhs.modificationDate, rhs.modificationDate)
            case .kind:
                let kindOrder = lhs.typeDescription.localizedStandardCompare(rhs.typeDescription)
                order = kindOrder == .orderedSame ? lhs.name.localizedStandardCompare(rhs.name) : kindOrder
            }

            if order == .orderedSame {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return sortAscending ? order == .orderedAscending : order == .orderedDescending
        }
    }

    private func compareDates(_ lhs: Date?, _ rhs: Date?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            if lhs == rhs { return .orderedSame }
            return lhs < rhs ? .orderedAscending : .orderedDescending
        case (nil, nil):
            return .orderedSame
        case (nil, _?):
            return .orderedAscending
        case (_?, nil):
            return .orderedDescending
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
        if renamingFileID != file.id {
            renamingFileID = nil
        }
        guard viewMode == .columns, file.canBrowseInline else { return }
        if expandedContents[file.id] == nil {
            expandedContents[file.id] = try? FileBrowserService.contents(of: file.url)
        }
    }

    private func handleNameClick(_ file: BrowserFileItem) {
        guard selection == file.id, isFocused else {
            select(file)
            return
        }
        beginRename(file)
    }

    private func beginRename(_ file: BrowserFileItem) {
        selection = file.id
        renameDraft = file.name
        renamingFileID = file.id
    }

    private func commitRename(_ file: BrowserFileItem) {
        store.renameFile(file.url, to: renameDraft)
        renamingFileID = nil
        reloadPreservingExpansion()
    }

    private func cancelRename() {
        renamingFileID = nil
        renameDraft = ""
    }

    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let sourceURL = droppedFileURL(from: item) else { return }
            Task { @MainActor in
                onFocus()
                store.move(sourceURL, toDirectory: currentURL)
                reloadPreservingExpansion()
            }
        }
        return true
    }

    nonisolated private func droppedFileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data,
           let value = String(data: data, encoding: .utf8) {
            return URL(string: value)
        }
        if let value = item as? String {
            return URL(string: value)
        }
        return nil
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

private enum BrowserSortKey {
    case name
    case modified
    case kind

    var defaultAscending: Bool {
        switch self {
        case .name, .kind:
            return true
        case .modified:
            return false
        }
    }
}

private struct SortHeaderButton: View {
    let title: String
    let key: BrowserSortKey
    let currentKey: BrowserSortKey
    let isAscending: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if currentKey == key {
                    Image(systemName: isAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(currentKey == key ? .primary : .secondary)
        .help("Sort by \(title)")
    }
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
