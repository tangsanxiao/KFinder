import SwiftUI

@main
struct XFinderApp: App {
    @StateObject private var store = WorkspaceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Folder") { PaneCommandCenter.post(.newFolder) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button("New Markdown File") { PaneCommandCenter.post(.newMarkdown) }
                    .keyboardShortcut("n", modifiers: [.command, .option])
            }

            CommandGroup(replacing: .undoRedo) {
                Button("Undo File Operation") { store.undoLastFileOperation() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!store.canUndoFileOperation)
                Button("Redo File Operation") { store.redoLastFileOperation() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!store.canRedoFileOperation)
            }

            CommandGroup(after: .pasteboard) {
                Button("Select All in Pane") { PaneCommandCenter.post(.selectAll) }
                    .keyboardShortcut("a", modifiers: .command)
                Button("Copy Files") { PaneCommandCenter.post(.copySelection) }
                    .keyboardShortcut("c", modifiers: .command)
                Button("Paste Files") { PaneCommandCenter.post(.paste) }
                    .keyboardShortcut("v", modifiers: .command)
            }

            CommandMenu("File Actions") {
                Button("Open") { PaneCommandCenter.post(.openSelection) }
                Button("Quick Look") { PaneCommandCenter.post(.quickLook) }
                Button("Get Info") { PaneCommandCenter.post(.getInfo) }
                    .keyboardShortcut("i", modifiers: .command)
                Button("Search Folder…") { PaneCommandCenter.post(.recursiveSearch) }
                    .keyboardShortcut("f", modifiers: [.command, .option])
                Divider()
                Button("Rename") { PaneCommandCenter.post(.renameSelection) }
                Button("Duplicate") { PaneCommandCenter.post(.duplicateSelection) }
                    .keyboardShortcut("d", modifiers: .command)
                Button("Compress") { PaneCommandCenter.post(.compressSelection) }
                Button("Reveal in Finder") { PaneCommandCenter.post(.revealSelection) }
                Divider()
                Button("Move to Trash") { PaneCommandCenter.post(.moveToTrash) }
                    .keyboardShortcut(.delete, modifiers: .command)
            }
        }
    }
}
