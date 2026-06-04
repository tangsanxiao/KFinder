import AppKit
import SwiftUI

/// Shared geometry for list rows so the alternating stripe background, the
/// selection highlight, and the row height all stay in lockstep.
enum FileRowMetrics {
    static let height: CGFloat = 21
    /// The selection fill spans the whole row — same rect as one stripe band — so
    /// it covers the alternating tint exactly, like Finder. A soft radius keeps
    /// the edges rounded without leaving the band peeking out.
    static let selectionCornerRadius: CGFloat = 9

    /// Finder's own subtle alternating-row tint, so light/dark mode and
    /// accessibility settings stay consistent with the rest of the system.
    static var alternateRowColor: Color {
        let colors = NSColor.alternatingContentBackgroundColors
        return Color(nsColor: colors.count > 1 ? colors[1] : .controlBackgroundColor)
    }
}

/// Renders the exact icon Finder shows for a file or folder (custom folder
/// icons, app icons, document-type icons, QuickLook thumbnails the system has
/// cached) by asking the system for it. Full-colour, so it stays itself when the
/// row is selected. LazyVStack only builds visible rows, and NSWorkspace caches
/// its icons, so this stays cheap while scrolling.
struct FileIconView: View {
    let url: URL
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}

struct FileListColumnWidths: Equatable {
    var name: CGFloat = 260
    var modified: CGFloat = 150
    var size: CGFloat = 114
    var kind: CGFloat = 136

    static let minName: CGFloat = 72
    static let minModified: CGFloat = 82
    static let minSize: CGFloat = 54
    static let minKind: CGFloat = 58
}

struct FileRow: View {
    let file: BrowserFileItem
    let depth: Int
    let isExpanded: Bool
    let isSelected: Bool
    let isActivePane: Bool
    let isAlternate: Bool
    let isRenaming: Bool
    let columnWidths: FileListColumnWidths
    @Binding var renameDraft: String
    let destinations: [PaneDestination]
    let select: () -> Void
    let nameClick: () -> Void
    let commitRename: () -> Void
    let cancelRename: () -> Void
    let open: () -> Void
    let toggleExpansion: () -> Void
    let copy: () -> Void
    let reveal: () -> Void
    let trash: () -> Void
    let copyTo: (PaneDestination) -> Void
    let moveTo: (PaneDestination) -> Void
    @FocusState private var isRenameFieldFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                if file.canBrowseInline {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected && isActivePane ? Color.white : Color.secondary)
                        .frame(width: 22, height: FileRowMetrics.height)
                        .contentShape(Rectangle())
                        .highPriorityGesture(TapGesture().onEnded {
                            toggleExpansion()
                        })
                } else {
                    Color.clear.frame(width: 22)
                }

                FileIconView(url: file.url, size: 16)

                nameContent
            }
            .frame(width: columnWidths.name, alignment: .leading)
            .padding(.leading, CGFloat(depth) * 18)

            Text(DisplayFormatters.date(file.modificationDate))
                .foregroundStyle(secondaryTextColor)
                .frame(width: columnWidths.modified, alignment: .leading)

            Text(DisplayFormatters.size(file.size))
                .foregroundStyle(secondaryTextColor)
                .frame(width: columnWidths.size, alignment: .trailing)
                .padding(.trailing, 18)

            Text(file.typeDescription)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .frame(width: columnWidths.kind, alignment: .leading)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 14)
        .frame(height: FileRowMetrics.height)
        .background(rowBackground)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { select() })
        .simultaneousGesture(TapGesture(count: 2).onEnded { open() })
        .onDrag {
            NSItemProvider(object: file.url as NSURL)
        }
        .onChange(of: isRenaming) { newValue in
            if newValue {
                DispatchQueue.main.async {
                    isRenameFieldFocused = true
                }
            }
        }
        .contextMenu {
            Button(file.canBrowseInline ? "Enter Folder" : "Open") { open() }
            Button("Reveal in Finder") { reveal() }
            Button("Copy Path") { copy() }
            Button("Move to Trash", role: .destructive) { trash() }

            if !destinations.isEmpty {
                Divider()
                Menu("Copy To") {
                    ForEach(destinations) { destination in
                        Button(destination.url.path) { copyTo(destination) }
                    }
                }
                Menu("Move To") {
                    ForEach(destinations) { destination in
                        Button(destination.url.path) { moveTo(destination) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var nameContent: some View {
        if isRenaming {
            TextField("Name", text: $renameDraft)
                .textFieldStyle(.plain)
                .focused($isRenameFieldFocused)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor, lineWidth: 1)
                )
                .onSubmit(commitRename)
                .onExitCommand(perform: cancelRename)
                .onChange(of: isRenameFieldFocused) { isFocused in
                    if !isFocused, isRenaming {
                        commitRename()
                    }
                }
        } else {
            Text(file.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(primaryTextColor)
                .contentShape(Rectangle())
                .onTapGesture(perform: nameClick)
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        ZStack {
            if isAlternate {
                FileRowMetrics.alternateRowColor
            }
            selectionBackground
        }
    }

    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: FileRowMetrics.selectionCornerRadius)
                .fill(selectionColor)
        }
    }

    private var selectionColor: Color {
        isActivePane ? Color(nsColor: .selectedContentBackgroundColor) : Color(nsColor: .separatorColor).opacity(0.55)
    }

    private var primaryTextColor: Color {
        isSelected && isActivePane ? .white : .primary
    }

    private var secondaryTextColor: Color {
        isSelected && isActivePane ? .white.opacity(0.86) : .secondary
    }

}

struct IconFileCell: View {
    let file: BrowserFileItem
    let isSelected: Bool
    let isActivePane: Bool
    let isRenaming: Bool
    @Binding var renameDraft: String
    let select: () -> Void
    let nameClick: () -> Void
    let commitRename: () -> Void
    let cancelRename: () -> Void
    let open: () -> Void
    let trash: () -> Void
    @FocusState private var isRenameFieldFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            FileIconView(url: file.url, size: 40)

            iconNameContent
        }
        .frame(width: 88, height: 86)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(iconSelectionColor)
        )
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { select() })
        .simultaneousGesture(TapGesture(count: 2).onEnded { open() })
        .onDrag {
            NSItemProvider(object: file.url as NSURL)
        }
        .onChange(of: isRenaming) { newValue in
            if newValue {
                DispatchQueue.main.async {
                    isRenameFieldFocused = true
                }
            }
        }
        .contextMenu {
            Button("Open") { open() }
            Button("Move to Trash", role: .destructive) { trash() }
        }
    }

    @ViewBuilder
    private var iconNameContent: some View {
        if isRenaming {
            TextField("Name", text: $renameDraft)
                .font(.system(size: 12))
                .textFieldStyle(.plain)
                .focused($isRenameFieldFocused)
                .multilineTextAlignment(.center)
                .frame(height: 34)
                .padding(.horizontal, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor, lineWidth: 1)
                )
                .onSubmit(commitRename)
                .onExitCommand(perform: cancelRename)
                .onChange(of: isRenameFieldFocused) { isFocused in
                    if !isFocused, isRenaming {
                        commitRename()
                    }
                }
        } else {
            Text(file.name)
                .font(.system(size: 12))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 34)
                .foregroundStyle(textColor)
                .contentShape(Rectangle())
                .onTapGesture(perform: nameClick)
        }
    }

    private var iconSelectionColor: Color {
        guard isSelected else { return Color.clear }
        return isActivePane ? Color(nsColor: .selectedContentBackgroundColor) : Color(nsColor: .separatorColor).opacity(0.55)
    }

    private var textColor: Color {
        isSelected && isActivePane ? .white : .primary
    }
}

struct ColumnFileRow: View {
    let file: BrowserFileItem
    let isSelected: Bool
    let isActivePane: Bool
    let isRenaming: Bool
    @Binding var renameDraft: String
    let destinations: [PaneDestination]
    let select: () -> Void
    let nameClick: () -> Void
    let commitRename: () -> Void
    let cancelRename: () -> Void
    let open: () -> Void
    let copy: () -> Void
    let reveal: () -> Void
    let trash: () -> Void
    let copyTo: (PaneDestination) -> Void
    let moveTo: (PaneDestination) -> Void
    @FocusState private var isRenameFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            FileIconView(url: file.url, size: 16)

            columnNameContent

            Spacer(minLength: 8)

            if file.canBrowseInline {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected && isActivePane ? .white.opacity(0.8) : .secondary)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Rectangle().fill(selectionColor))
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { select() })
        .simultaneousGesture(TapGesture(count: 2).onEnded { open() })
        .onDrag {
            NSItemProvider(object: file.url as NSURL)
        }
        .onChange(of: isRenaming) { newValue in
            if newValue {
                DispatchQueue.main.async {
                    isRenameFieldFocused = true
                }
            }
        }
        .contextMenu {
            Button(file.canBrowseInline ? "Enter Folder" : "Open") { open() }
            Button("Reveal in Finder") { reveal() }
            Button("Copy Path") { copy() }
            Button("Move to Trash", role: .destructive) { trash() }

            if !destinations.isEmpty {
                Divider()
                Menu("Copy To") {
                    ForEach(destinations) { destination in
                        Button(destination.url.path) { copyTo(destination) }
                    }
                }
                Menu("Move To") {
                    ForEach(destinations) { destination in
                        Button(destination.url.path) { moveTo(destination) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var columnNameContent: some View {
        if isRenaming {
            TextField("Name", text: $renameDraft)
                .textFieldStyle(.plain)
                .focused($isRenameFieldFocused)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.accentColor, lineWidth: 1)
                )
                .onSubmit(commitRename)
                .onExitCommand(perform: cancelRename)
                .onChange(of: isRenameFieldFocused) { isFocused in
                    if !isFocused, isRenaming {
                        commitRename()
                    }
                }
        } else {
            Text(file.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(textColor)
                .contentShape(Rectangle())
                .onTapGesture(perform: nameClick)
        }
    }

    private var selectionColor: Color {
        guard isSelected else { return Color(nsColor: .controlBackgroundColor) }
        return isActivePane ? Color(nsColor: .selectedContentBackgroundColor) : Color(nsColor: .separatorColor).opacity(0.55)
    }

    private var textColor: Color {
        isSelected && isActivePane ? .white : .primary
    }
}
