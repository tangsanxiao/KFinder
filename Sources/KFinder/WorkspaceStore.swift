import AppKit
import Foundation

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var selectedWorkspaceID: UUID?
    @Published var statusMessage = "Ready"
    @Published var lastError: String?
    @Published var fileOperationRevision = 0
    @Published private var paneLocations: [UUID: String] = [:]
    @Published var stars: [StarItem] = []
    /// The currently focused pane (nil = a "待添加" placeholder is the target).
    /// Single source of truth so the sidebar and panes never disagree.
    @Published var focusedPaneID: UUID?

    private let persistenceURL: URL
    private let starsURL: URL
    private let finderController = FinderController()

    /// - Parameter supportDirectory: base directory for persistence. Defaults to
    ///   the real Application Support location; tests pass a temp directory to
    ///   stay isolated and deterministic. Legacy migration runs only for the
    ///   real location.
    init(supportDirectory: URL? = nil) {
        let support =
            supportDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = support.appendingPathComponent("KFinder", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        persistenceURL = directory.appendingPathComponent("workspaces.json")
        starsURL = directory.appendingPathComponent("stars.json")

        if supportDirectory == nil {
            let legacyPersistenceURL =
                support
                .appendingPathComponent("FinderHub", isDirectory: true)
                .appendingPathComponent("workspaces.json")
            if !FileManager.default.fileExists(atPath: persistenceURL.path),
                FileManager.default.fileExists(atPath: legacyPersistenceURL.path)
            {
                try? FileManager.default.copyItem(at: legacyPersistenceURL, to: persistenceURL)
            }
        }
        load()
        loadStars()
    }

    var selectedWorkspace: Workspace? {
        guard let selectedWorkspaceID else { return nil }
        return workspaces.first { $0.id == selectedWorkspaceID }
    }

    var systemBookmarks: [SystemBookmark] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var bookmarks = [
            SystemBookmark(
                id: "desktop", title: "Desktop", systemImage: "rectangle", url: home.appendingPathComponent("Desktop")),
            SystemBookmark(
                id: "downloads", title: "Downloads", systemImage: "arrow.down.circle",
                url: home.appendingPathComponent("Downloads")),
            SystemBookmark(
                id: "documents", title: "Documents", systemImage: "doc", url: home.appendingPathComponent("Documents")),
            SystemBookmark(
                id: "movies", title: "Movies", systemImage: "film", url: home.appendingPathComponent("Movies")),
            SystemBookmark(
                id: "music", title: "Music", systemImage: "music.note", url: home.appendingPathComponent("Music")),
            SystemBookmark(
                id: "pictures", title: "Pictures", systemImage: "photo", url: home.appendingPathComponent("Pictures")),
            SystemBookmark(id: "home", title: NSUserName(), systemImage: "house", url: home),
            SystemBookmark(
                id: "applications", title: "Applications", systemImage: "app.badge",
                url: URL(fileURLWithPath: "/Applications")),
            SystemBookmark(
                id: "trash", title: "Trash", systemImage: "trash", url: home.appendingPathComponent(".Trash")),
        ]

        let iCloud = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if FileManager.default.fileExists(atPath: iCloud.path) {
            bookmarks.append(SystemBookmark(id: "icloud", title: "iCloud Drive", systemImage: "icloud", url: iCloud))
        }

        bookmarks.append(
            SystemBookmark(
                id: "macintosh-hd", title: "Macintosh HD", systemImage: "internaldrive", url: URL(fileURLWithPath: "/"))
        )
        return bookmarks
    }

    /// A brand-new workspace starts empty with the Single layout — one pane
    /// showing the "add a folder" placeholder, no directory written in yet.
    func createWorkspace() {
        appendWorkspace(directories: [], layout: .single)
    }

    private func appendWorkspace(directories: [DirectoryItem], layout: WorkspaceLayout = .single) {
        let workspace = Workspace(name: nextWorkspaceName(), layout: layout, directories: directories)
        workspaces.append(workspace)
        selectedWorkspaceID = workspace.id
        save()
    }

    func deleteSelectedWorkspace() {
        guard let selectedWorkspaceID else { return }
        deleteWorkspace(id: selectedWorkspaceID)
    }

    func deleteWorkspace(id: UUID) {
        paneLocations = paneLocations.filter { paneID, _ in
            workspaces.first(where: { $0.id == id })?.directories.contains(where: { $0.id == paneID }) != true
        }
        workspaces.removeAll { $0.id == id }
        if selectedWorkspaceID == id {
            selectedWorkspaceID = workspaces.first?.id
        }
        save()
    }

    /// Switches the layout. Panes are NOT auto-created: when the layout wants
    /// more panes than there are folders, the grid shows greyed "add a pane"
    /// placeholders for the empty cells instead (see `MultiPaneBrowserView`).
    func applyLayout(_ layout: WorkspaceLayout) {
        guard var workspace = selectedWorkspace else { return }
        workspace.layout = layout
        updateSelectedWorkspace(workspace)
    }

    func updateSelectedWorkspace(_ workspace: Workspace) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
        workspaces[index] = workspace
        save()
    }

    func renameWorkspace(id: UUID, to name: String) {
        guard let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[index].name = name
        save()
    }

    func addDirectoriesFromOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"

        guard panel.runModal() == .OK else { return }
        addDirectories(panel.urls)
    }

    func addDirectories(_ urls: [URL]) {
        ensureWorkspaceExists()
        guard var workspace = selectedWorkspace else { return }

        let existingPaths = Set(workspace.directories.map(\.path))
        let additions =
            urls
            .filter { existingPaths.contains($0.path) == false }
            .map { DirectoryItem(name: $0.lastPathComponent.isEmpty ? $0.path : $0.lastPathComponent, path: $0.path) }

        workspace.directories.append(contentsOf: additions)
        updateSelectedWorkspace(workspace)
        statusMessage = "Added \(additions.count) folder\(additions.count == 1 ? "" : "s")"
    }

    func removeDirectory(_ item: DirectoryItem) {
        guard var workspace = selectedWorkspace else { return }
        workspace.directories.removeAll { $0.id == item.id }
        paneLocations[item.id] = nil
        // Auto-fit the layout to the remaining pane count so closing a pane
        // re-flows the rest instead of leaving an empty placeholder cell.
        workspace.layout = WorkspaceLayout.fitting(paneCount: workspace.directories.count)
        updateSelectedWorkspace(workspace)
    }

    func updatePaneLocation(id: UUID, url: URL) {
        let path = url.path
        guard paneLocations[id] != path else { return }
        paneLocations[id] = path
    }

    func paneLocation(for id: UUID?) -> URL? {
        guard let id else { return nil }
        if let path = paneLocations[id] {
            return URL(fileURLWithPath: path)
        }
        return selectedWorkspace?.directories.first { $0.id == id }.map { URL(fileURLWithPath: $0.path) }
    }

    func paneTitle(for id: UUID?) -> String {
        guard
            let url = paneLocation(for: id)
                ?? selectedWorkspace?.directories.first.map({ URL(fileURLWithPath: $0.path) })
        else {
            return selectedWorkspace?.name ?? "KFinder"
        }
        return url.lastPathComponent.isEmpty ? "Macintosh HD" : url.lastPathComponent
    }

    @discardableResult
    func openLocation(url: URL, title: String, in focusedPaneID: UUID?) -> UUID? {
        guard var workspace = selectedWorkspace else {
            return openInNewPane(url, title: title)
        }
        // Retarget the focused pane, or the first pane if none is focused — never
        // append (that caused panes to pile up on every sidebar click).
        let targetID = focusedPaneID ?? workspace.directories.first?.id
        guard let targetID,
            let index = workspace.directories.firstIndex(where: { $0.id == targetID })
        else {
            return openInNewPane(url, title: title)
        }

        workspace.directories[index].name = title
        workspace.directories[index].path = url.path
        paneLocations[targetID] = url.path
        updateSelectedWorkspace(workspace)
        self.focusedPaneID = targetID
        statusMessage = "Opened \(title)"
        return targetID
    }

    /// Adds a brand-new pane at `url` (no de-duplication) — used to fill a
    /// selected "待添加" placeholder from the sidebar.
    @discardableResult
    func openInNewPane(_ url: URL, title: String) -> UUID? {
        ensureWorkspaceExists()
        guard var workspace = selectedWorkspace else { return nil }
        let item = DirectoryItem(name: title, path: url.path)
        workspace.directories.append(item)
        updateSelectedWorkspace(workspace)
        focusedPaneID = item.id
        statusMessage = "Opened \(title)"
        return item.id
    }

    /// Opens Terminal.app with its working directory set to `url`.
    func openTerminal(at url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", url.path]
        do {
            try process.run()
            statusMessage = "Opened Terminal at \(url.lastPathComponent)"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Could not open Terminal"
        }
    }

    // MARK: - Stars (favourite directories)

    func isStarred(_ url: URL) -> Bool {
        stars.contains { $0.path == url.path }
    }

    func toggleStar(_ url: URL) {
        if let existing = stars.first(where: { $0.path == url.path }) {
            removeStar(existing)
        } else {
            let name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
            stars.append(StarItem(name: name, path: url.path))
            saveStars()
            statusMessage = "Starred \(name)"
        }
    }

    func removeStar(_ star: StarItem) {
        stars.removeAll { $0.id == star.id }
        saveStars()
    }

    private func loadStars() {
        guard let data = try? Data(contentsOf: starsURL),
            let decoded = try? JSONDecoder().decode([StarItem].self, from: data)
        else { return }
        stars = decoded
    }

    private func saveStars() {
        do {
            let data = try JSONEncoder.pretty.encode(stars)
            try data.write(to: starsURL, options: .atomic)
        } catch {
            lastError = "Could not save stars: \(error.localizedDescription)"
        }
    }

    func paneDestinations(excluding id: UUID) -> [PaneDestination] {
        guard let workspace = selectedWorkspace else { return [] }
        return workspace.directories
            .filter { $0.id != id }
            .map { directory in
                let path = paneLocations[directory.id] ?? directory.path
                return PaneDestination(id: directory.id, name: path, url: URL(fileURLWithPath: path))
            }
    }

    func copy(_ sourceURL: URL, to destination: PaneDestination) {
        do {
            let target = uniqueDestinationURL(for: sourceURL, in: destination.url)
            try FileManager.default.copyItem(at: sourceURL, to: target)
            fileOperationRevision += 1
            statusMessage = "Copied \(sourceURL.lastPathComponent) to \(destination.name)"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Copy failed"
        }
    }

    func move(_ sourceURL: URL, to destination: PaneDestination) {
        move(sourceURL, toDirectory: destination.url, destinationName: destination.name)
    }

    func move(_ sourceURL: URL, toDirectory destinationURL: URL, destinationName: String? = nil) {
        do {
            guard sourceURL.deletingLastPathComponent().standardizedFileURL != destinationURL.standardizedFileURL else {
                statusMessage = "\(sourceURL.lastPathComponent) is already in this folder"
                return
            }
            let target = uniqueDestinationURL(for: sourceURL, in: destinationURL)
            try FileManager.default.moveItem(at: sourceURL, to: target)
            fileOperationRevision += 1
            statusMessage = "Moved \(sourceURL.lastPathComponent) to \(destinationName ?? destinationURL.path)"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Move failed"
        }
    }

    func renameFile(_ sourceURL: URL, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName != sourceURL.lastPathComponent else { return }

        do {
            let target = sourceURL.deletingLastPathComponent().appendingPathComponent(trimmedName)
            guard !FileManager.default.fileExists(atPath: target.path) else {
                lastError = "A file named \(trimmedName) already exists."
                statusMessage = "Rename failed"
                return
            }
            try FileManager.default.moveItem(at: sourceURL, to: target)
            fileOperationRevision += 1
            statusMessage = "Renamed \(sourceURL.lastPathComponent) to \(trimmedName)"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Rename failed"
        }
    }

    @discardableResult
    func createFolder(in directory: URL, named name: String = "新建文件夹") -> URL? {
        let target = uniqueDestinationURL(for: directory.appendingPathComponent(name), in: directory)
        do {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
            fileOperationRevision += 1
            statusMessage = "Created \(target.lastPathComponent)"
            return target
        } catch {
            lastError = error.localizedDescription
            statusMessage = "New folder failed"
            return nil
        }
    }

    /// Zips `urls` into `<archiveName>.zip` placed in `outputDirectory`. Archive
    /// entries are stored relative to `baseDirectory` (the pane's current folder)
    /// so the zip keeps clean, nested paths. Runs `/usr/bin/zip` asynchronously so
    /// the UI never blocks; completion updates state via `fileOperationRevision`.
    func compress(_ urls: [URL], relativeTo baseDirectory: URL, archiveName: String, into outputDirectory: URL) {
        guard !urls.isEmpty else { return }

        let target = uniqueDestinationURL(
            for: outputDirectory.appendingPathComponent("\(archiveName).zip"),
            in: outputDirectory
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = baseDirectory
        process.arguments = ["-r", "-X", target.path] + urls.map { relativePath(of: $0, under: baseDirectory) }

        let count = urls.count
        let finalName = target.lastPathComponent
        process.terminationHandler = { finished in
            let status = finished.terminationStatus
            Task { @MainActor in
                if status == 0 {
                    self.fileOperationRevision += 1
                    self.statusMessage = "Compressed \(count) item\(count == 1 ? "" : "s") to \(finalName)"
                } else {
                    self.lastError = "Compression failed (zip exited with code \(status))."
                    self.statusMessage = "Compress failed"
                }
            }
        }

        do {
            try process.run()
            statusMessage = "Compressing \(count) item\(count == 1 ? "" : "s")…"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Compress failed"
        }
    }

    private func relativePath(of url: URL, under base: URL) -> String {
        let basePath = base.path.hasSuffix("/") ? base.path : base.path + "/"
        if url.path.hasPrefix(basePath) {
            return String(url.path.dropFirst(basePath.count))
        }
        return url.lastPathComponent
    }

    func moveToTrash(_ sourceURL: URL) {
        do {
            var resultingURL: NSURL?
            try FileManager.default.trashItem(at: sourceURL, resultingItemURL: &resultingURL)
            fileOperationRevision += 1
            statusMessage = "Moved \(sourceURL.lastPathComponent) to Trash"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Move to Trash failed"
        }
    }

    func importOpenFinderWindows() {
        do {
            let urls = try finderController.currentFinderWindowDirectories()
            guard !urls.isEmpty else {
                statusMessage = "No open Finder windows to import"
                lastError = "没有找到已打开的 Finder 窗口可导入。请先在 Finder 中打开窗口；首次使用时请在弹出的授权框里允许 KFinder 控制 Finder。"
                return
            }
            addDirectories(urls)
            statusMessage = "Imported \(urls.count) Finder window\(urls.count == 1 ? "" : "s")"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Could not import Finder windows"
        }
    }

    private func ensureWorkspaceExists() {
        if selectedWorkspace == nil {
            appendWorkspace(directories: [])
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: persistenceURL),
            let decoded = try? JSONDecoder().decode([Workspace].self, from: data)
        else {
            let defaultWorkspace = Workspace(
                name: "Daily Desk",
                layout: .columns2,
                directories: [
                    DirectoryItem(
                        name: "Desktop",
                        path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path),
                    DirectoryItem(
                        name: "Downloads",
                        path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path),
                ]
            )
            workspaces = [defaultWorkspace]
            selectedWorkspaceID = defaultWorkspace.id
            save()
            return
        }

        workspaces = decoded
        selectedWorkspaceID = decoded.first?.id
    }

    private func save() {
        do {
            let data = try JSONEncoder.pretty.encode(workspaces)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            lastError = "Could not save workspaces: \(error.localizedDescription)"
        }
    }

    private func nextWorkspaceName() -> String {
        let base = "Workspace"
        var index = workspaces.count + 1
        var candidate = "\(base) \(index)"
        let names = Set(workspaces.map(\.name))
        while names.contains(candidate) {
            index += 1
            candidate = "\(base) \(index)"
        }
        return candidate
    }

    private func uniqueDestinationURL(for sourceURL: URL, in destinationDirectory: URL) -> URL {
        let fileManager = FileManager.default
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let pathExtension = sourceURL.pathExtension
        var candidate = destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        var index = 2

        while fileManager.fileExists(atPath: candidate.path) {
            let name = pathExtension.isEmpty ? "\(baseName) \(index)" : "\(baseName) \(index).\(pathExtension)"
            candidate = destinationDirectory.appendingPathComponent(name)
            index += 1
        }

        return candidate
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
