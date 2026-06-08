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

struct StarItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var path: String

    init(id: UUID = UUID(), name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
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
    case single
    case columns2
    case columns3
    case rows3
    case grid
    case mainAndStack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single: "Single"
        case .columns2: "Two Columns"
        case .columns3: "Three Columns"
        case .rows3: "Three Rows"
        case .grid: "Grid"
        case .mainAndStack: "Main + Stack"
        }
    }

    var systemImage: String {
        switch self {
        case .single: "rectangle"
        case .columns2: "rectangle.split.2x1"
        case .columns3: "rectangle.split.3x1"
        case .rows3: "rectangle.stack"
        case .grid: "square.grid.2x2"
        case .mainAndStack: "rectangle.leadinghalf.inset.filled"
        }
    }

    /// How many panes this layout is meant to show. `nil` means "show whatever
    /// folders exist" (Main + Stack adapts to the folder count).
    var preferredPaneCount: Int? {
        switch self {
        case .single: return 1
        case .columns2: return 2
        case .columns3, .rows3: return 3
        case .grid: return 4
        case .mainAndStack: return nil
        }
    }

    /// The layout that best fits a given number of panes — used to auto-adjust
    /// when a pane is closed.
    static func fitting(paneCount: Int) -> WorkspaceLayout {
        switch paneCount {
        case ...1: return .single
        case 2: return .columns2
        case 3: return .columns3
        default: return .grid
        }
    }

    /// Number of columns the pane grid uses.
    var gridColumns: Int {
        switch self {
        case .single, .rows3: return 1
        case .columns2: return 2
        case .columns3: return 3
        case .grid: return 2
        case .mainAndStack: return 1
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
