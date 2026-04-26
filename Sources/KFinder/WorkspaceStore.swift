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

    private let persistenceURL: URL
    private let finderController = FinderController()

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = support.appendingPathComponent("KFinder", isDirectory: true)
        let legacyDirectory = support.appendingPathComponent("FinderHub", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        persistenceURL = directory.appendingPathComponent("workspaces.json")
        let legacyPersistenceURL = legacyDirectory.appendingPathComponent("workspaces.json")
        if !FileManager.default.fileExists(atPath: persistenceURL.path),
           FileManager.default.fileExists(atPath: legacyPersistenceURL.path) {
            try? FileManager.default.copyItem(at: legacyPersistenceURL, to: persistenceURL)
        }
        load()
    }

    var selectedWorkspace: Workspace? {
        guard let selectedWorkspaceID else { return nil }
        return workspaces.first { $0.id == selectedWorkspaceID }
    }

    var systemBookmarks: [SystemBookmark] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var bookmarks = [
            SystemBookmark(id: "desktop", title: "Desktop", systemImage: "rectangle", url: home.appendingPathComponent("Desktop")),
            SystemBookmark(id: "downloads", title: "Downloads", systemImage: "arrow.down.circle", url: home.appendingPathComponent("Downloads")),
            SystemBookmark(id: "documents", title: "Documents", systemImage: "doc", url: home.appendingPathComponent("Documents")),
            SystemBookmark(id: "movies", title: "Movies", systemImage: "film", url: home.appendingPathComponent("Movies")),
            SystemBookmark(id: "music", title: "Music", systemImage: "music.note", url: home.appendingPathComponent("Music")),
            SystemBookmark(id: "pictures", title: "Pictures", systemImage: "photo", url: home.appendingPathComponent("Pictures")),
            SystemBookmark(id: "home", title: NSUserName(), systemImage: "house", url: home),
            SystemBookmark(id: "applications", title: "Applications", systemImage: "app.badge", url: URL(fileURLWithPath: "/Applications")),
            SystemBookmark(id: "trash", title: "Trash", systemImage: "trash", url: home.appendingPathComponent(".Trash"))
        ]

        let iCloud = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if FileManager.default.fileExists(atPath: iCloud.path) {
            bookmarks.append(SystemBookmark(id: "icloud", title: "iCloud Drive", systemImage: "icloud", url: iCloud))
        }

        bookmarks.append(SystemBookmark(id: "macintosh-hd", title: "Macintosh HD", systemImage: "internaldrive", url: URL(fileURLWithPath: "/")))
        return bookmarks
    }

    func createWorkspace() {
        let workspace = Workspace(name: nextWorkspaceName())
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
        let additions = urls
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
        updateSelectedWorkspace(workspace)
    }

    func updatePaneLocation(id: UUID, url: URL) {
        paneLocations[id] = url.path
    }

    func paneLocation(for id: UUID?) -> URL? {
        guard let id else { return nil }
        if let path = paneLocations[id] {
            return URL(fileURLWithPath: path)
        }
        return selectedWorkspace?.directories.first { $0.id == id }.map { URL(fileURLWithPath: $0.path) }
    }

    func paneTitle(for id: UUID?) -> String {
        guard let url = paneLocation(for: id) ?? selectedWorkspace?.directories.first.map({ URL(fileURLWithPath: $0.path) }) else {
            return selectedWorkspace?.name ?? "KFinder"
        }
        return url.lastPathComponent.isEmpty ? "Macintosh HD" : url.lastPathComponent
    }

    func openBookmark(_ bookmark: SystemBookmark, in focusedPaneID: UUID?) -> UUID? {
        guard let focusedPaneID,
              var workspace = selectedWorkspace,
              let index = workspace.directories.firstIndex(where: { $0.id == focusedPaneID }) else {
            addDirectories([bookmark.url])
            return selectedWorkspace?.directories.last?.id
        }

        workspace.directories[index].name = bookmark.title
        workspace.directories[index].path = bookmark.url.path
        paneLocations[focusedPaneID] = bookmark.url.path
        updateSelectedWorkspace(workspace)
        statusMessage = "Opened \(bookmark.title)"
        return focusedPaneID
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
        do {
            let target = uniqueDestinationURL(for: sourceURL, in: destination.url)
            try FileManager.default.moveItem(at: sourceURL, to: target)
            fileOperationRevision += 1
            statusMessage = "Moved \(sourceURL.lastPathComponent) to \(destination.name)"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Move failed"
        }
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
            addDirectories(urls)
            statusMessage = "Imported \(urls.count) Finder window\(urls.count == 1 ? "" : "s")"
        } catch {
            lastError = error.localizedDescription
            statusMessage = "Could not import Finder windows"
        }
    }

    private func ensureWorkspaceExists() {
        if selectedWorkspace == nil {
            createWorkspace()
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: persistenceURL),
              let decoded = try? JSONDecoder().decode([Workspace].self, from: data) else {
            let defaultWorkspace = Workspace(
                name: "Daily Desk",
                directories: [
                    DirectoryItem(name: "Desktop", path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path),
                    DirectoryItem(name: "Downloads", path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path)
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
