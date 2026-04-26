import Foundation

struct DirectoryItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var path: String
    var isOpen: Bool

    init(id: UUID = UUID(), name: String, path: String, isOpen: Bool = false) {
        self.id = id
        self.name = name
        self.path = path
        self.isOpen = isOpen
    }
}

struct Workspace: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var layout: WorkspaceLayout
    var directories: [DirectoryItem]

    init(
        id: UUID = UUID(),
        name: String,
        layout: WorkspaceLayout = .grid,
        directories: [DirectoryItem] = []
    ) {
        self.id = id
        self.name = name
        self.layout = layout
        self.directories = directories
    }
}

struct PaneDestination: Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: URL
}

struct SystemBookmark: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let url: URL
}

enum BrowserViewMode: String, CaseIterable, Identifiable {
    case icons
    case list
    case columns

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .icons: "square.grid.2x2"
        case .list: "list.bullet"
        case .columns: "rectangle.split.3x1"
        }
    }

    var title: String {
        switch self {
        case .icons: "Icons"
        case .list: "List"
        case .columns: "Columns"
        }
    }
}

enum WorkspaceLayout: String, CaseIterable, Codable, Identifiable {
    case columns2
    case columns3
    case grid
    case mainAndStack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .columns2: "Two Columns"
        case .columns3: "Three Columns"
        case .grid: "Grid"
        case .mainAndStack: "Main + Stack"
        }
    }

    var systemImage: String {
        switch self {
        case .columns2: "rectangle.split.2x1"
        case .columns3: "rectangle.split.3x1"
        case .grid: "square.grid.2x2"
        case .mainAndStack: "rectangle.leadinghalf.inset.filled"
        }
    }
}

enum WorkspaceStoreError: LocalizedError {
    case noSelectedWorkspace
    case appleScript(String)

    var errorDescription: String? {
        switch self {
        case .noSelectedWorkspace:
            return "No workspace is selected."
        case .appleScript(let message):
            return message
        }
    }
}
