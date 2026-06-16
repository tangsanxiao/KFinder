import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title2.weight(.semibold))

            Text(description)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WindowChromeConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configureIfNeeded(window: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else {
            DispatchQueue.main.async {
                configureIfNeeded(window: nsView.window, coordinator: context.coordinator)
            }
            return
        }
        configureIfNeeded(window: window, coordinator: context.coordinator)
    }

    private func configureIfNeeded(window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        guard coordinator.configuredWindow !== window else { return }

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = false
        window.toolbar = nil
        coordinator.configuredWindow = window
    }

    final class Coordinator {
        weak var configuredWindow: NSWindow?
    }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DraggableWindowView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Sets the mouse cursor over a region using an AppKit tracking area on a
/// persistent NSView, instead of SwiftUI `.onHover` + cursor push/pop. The
/// push/pop approach lost its pairing during SwiftUI re-renders (the resizable
/// header rebuilds while dragging or scrolling), so the resize cursor
/// flickered or never appeared. A tracking area fires enter/exit purely on
/// geometry (independent of hit testing), and the NSView isn't recreated on
/// SwiftUI re-renders, so the cursor stays stable. `hitTest` returns nil so
/// the overlay never steals the drag gesture beneath it.
private struct CursorRectView: NSViewRepresentable {
    let cursor: NSCursor

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.cursor = cursor
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.cursor = cursor
    }

    static func dismantleNSView(_ nsView: TrackingView, coordinator: ()) {
        nsView.balancePop()
    }

    final class TrackingView: NSView {
        var cursor: NSCursor = .arrow
        private var pushed = false

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(
                NSTrackingArea(
                    rect: bounds,
                    options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                    owner: self
                ))
        }

        override func mouseEntered(with event: NSEvent) {
            guard !pushed else { return }
            cursor.push()
            pushed = true
        }

        override func mouseExited(with event: NSEvent) {
            balancePop()
        }

        func balancePop() {
            guard pushed else { return }
            NSCursor.pop()
            pushed = false
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

extension View {
    func hoverCursor(_ cursor: NSCursor) -> some View {
        overlay(CursorRectView(cursor: cursor))
    }
}

enum ResizePhase {
    case began
    case changed
    case ended
}

extension View {
    /// Left–right column-resize cursor for a divider. Uses SwiftUI's native
    /// `pointerStyle` (macOS 15+), which integrates with SwiftUI's own cursor
    /// management so it doesn't flicker. AppKit overlays inside the SwiftUI
    /// host can't win against NSHostingView's cursor handling, which is why the
    /// earlier tracking-area / cursor-rect attempts flickered or didn't show.
    @ViewBuilder
    func columnResizeCursor() -> some View {
        if #available(macOS 15.0, *) {
            pointerStyle(.frameResize(position: .trailing))
        } else {
            hoverCursor(.resizeLeftRight)
        }
    }
}

private final class DraggableWindowView: NSView {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            WindowZoomController.toggle(window: window)
            return
        }
        window?.performDrag(with: event)
    }
}

/// Icon button with an immediate tooltip bubble rendered directly beneath the
/// button itself — so the tip always appears at the hovered control, never at
/// a fixed toolbar corner. Used by both the pane toolbar and the top window
/// toolbar so hover feedback feels identical. The owning toolbar must sit at a
/// higher zIndex than the content below it, or the bubble gets covered.
struct PaneToolbarActionButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let tooltip: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(isHovering ? 0.2 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .help(tooltip)
        .toolbarTip(tooltip, isPresented: isHovering)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.08)) {
                isHovering = hovering
            }
        }
    }
}

extension View {
    /// Attaches the immediate tooltip bubble below the view, centered on it.
    /// Non-interactive and unclipped, so it never swallows clicks on
    /// neighbouring controls.
    func toolbarTip(_ text: String, isPresented: Bool) -> some View {
        overlay(alignment: .top) {
            if isPresented {
                // Fixed offset below the 26pt button (not alignment-guide
                // math, which rendered the bubble over the button itself).
                ToolbarTooltipBubble(text: text)
                    .offset(y: 34)
                    .zIndex(10)
            }
        }
    }
}

/// The tooltip bubble shown while a toolbar control is hovered.
struct ToolbarTooltipBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.black.opacity(0.82))
            )
            .fixedSize()
            .transition(.opacity.combined(with: .move(edge: .top)))
            .allowsHitTesting(false)
    }
}

@MainActor
enum AppRelauncher {
    /// Launches a fresh instance of this app bundle via `open -n`, then
    /// terminates the current one. Debug convenience — only meaningful when
    /// running the packaged `.app`.
    ///
    /// Stays fully synchronous on the main actor on purpose: routing through
    /// `NSWorkspace.openApplication`'s completion handler crashes under Swift 6,
    /// because that handler fires on a background LaunchServices queue while the
    /// closure is MainActor-isolated, tripping `dispatch_assert_queue` (SIGTRAP).
    static func relaunch() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", Bundle.main.bundlePath]
        do {
            try process.run()
        } catch {
            NSSound.beep()
            return
        }
        NSApp.terminate(nil)
    }
}

@MainActor
enum WindowZoomController {
    private static var restoreFrames: [ObjectIdentifier: NSRect] = [:]

    static func toggle(window: NSWindow? = NSApp.keyWindow) {
        guard let window, let screen = window.screen else { return }

        let key = ObjectIdentifier(window)
        if let restoreFrame = restoreFrames[key] {
            window.setFrame(restoreFrame, display: true, animate: true)
            restoreFrames[key] = nil
            return
        }

        restoreFrames[key] = window.frame
        window.setFrame(screen.visibleFrame, display: true, animate: true)
    }
}
