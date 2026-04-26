import SwiftUI

struct FileRow: View {
    let file: BrowserFileItem
    let depth: Int
    let isExpanded: Bool
    let isSelected: Bool
    let isActivePane: Bool
    let destinations: [PaneDestination]
    let select: () -> Void
    let open: () -> Void
    let toggleExpansion: () -> Void
    let copy: () -> Void
    let reveal: () -> Void
    let trash: () -> Void
    let copyTo: (PaneDestination) -> Void
    let moveTo: (PaneDestination) -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                if file.canBrowseInline {
                    Button {
                        toggleExpansion()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 14, height: 20)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 14)
                }

                Image(systemName: file.iconName)
                    .foregroundStyle(iconColor)
                    .frame(width: 20)

                Text(file.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(primaryTextColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, CGFloat(depth) * 18)

            Text(DisplayFormatters.date(file.modificationDate))
                .foregroundStyle(secondaryTextColor)
                .frame(width: 150, alignment: .leading)

            Text(DisplayFormatters.size(file.size))
                .foregroundStyle(secondaryTextColor)
                .frame(width: 90, alignment: .trailing)

            Text(file.typeDescription)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 14)
        .frame(height: 30)
        .background(Rectangle().fill(selectionColor))
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { select() })
        .simultaneousGesture(TapGesture(count: 2).onEnded { open() })
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

    private var selectionColor: Color {
        guard isSelected else { return Color(nsColor: .controlBackgroundColor) }
        return isActivePane ? Color(nsColor: .selectedContentBackgroundColor) : Color(nsColor: .separatorColor).opacity(0.55)
    }

    private var primaryTextColor: Color {
        isSelected && isActivePane ? .white : .primary
    }

    private var secondaryTextColor: Color {
        isSelected && isActivePane ? .white.opacity(0.86) : .secondary
    }

    private var iconColor: Color {
        if isSelected && isActivePane { return .white }
        if file.canBrowseInline { return .blue }
        if file.isPackage { return .primary }
        return .secondary
    }
}

struct IconFileCell: View {
    let file: BrowserFileItem
    let isSelected: Bool
    let isActivePane: Bool
    let select: () -> Void
    let open: () -> Void
    let trash: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: file.iconName)
                .font(.system(size: 32))
                .foregroundStyle(iconColor)

            Text(file.name)
                .font(.system(size: 12))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 34)
                .foregroundStyle(textColor)
        }
        .frame(width: 88, height: 86)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(iconSelectionColor)
        )
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { select() })
        .simultaneousGesture(TapGesture(count: 2).onEnded { open() })
        .contextMenu {
            Button("Open") { open() }
            Button("Move to Trash", role: .destructive) { trash() }
        }
    }

    private var iconSelectionColor: Color {
        guard isSelected else { return Color.clear }
        return isActivePane ? Color(nsColor: .selectedContentBackgroundColor) : Color(nsColor: .separatorColor).opacity(0.55)
    }

    private var textColor: Color {
        isSelected && isActivePane ? .white : .primary
    }

    private var iconColor: Color {
        if isSelected && isActivePane { return .white }
        if file.canBrowseInline { return .blue }
        if file.isPackage { return .primary }
        return .secondary
    }
}

struct ColumnFileRow: View {
    let file: BrowserFileItem
    let isSelected: Bool
    let isActivePane: Bool
    let destinations: [PaneDestination]
    let select: () -> Void
    let open: () -> Void
    let copy: () -> Void
    let reveal: () -> Void
    let trash: () -> Void
    let copyTo: (PaneDestination) -> Void
    let moveTo: (PaneDestination) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: file.iconName)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            Text(file.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(textColor)

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

    private var selectionColor: Color {
        guard isSelected else { return Color(nsColor: .controlBackgroundColor) }
        return isActivePane ? Color(nsColor: .selectedContentBackgroundColor) : Color(nsColor: .separatorColor).opacity(0.55)
    }

    private var textColor: Color {
        isSelected && isActivePane ? .white : .primary
    }

    private var iconColor: Color {
        if isSelected && isActivePane { return .white }
        if file.canBrowseInline { return .blue }
        if file.isPackage { return .primary }
        return .secondary
    }
}
