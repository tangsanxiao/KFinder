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
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = false
        window.toolbar = nil
    }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        DraggableWindowView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct CursorOnHover: ViewModifier {
    let cursor: NSCursor
    @State private var isCursorPushed = false

    func body(content: Content) -> some View {
        content
            .onHover { isHovering in
                if isHovering, !isCursorPushed {
                    cursor.push()
                    isCursorPushed = true
                } else if !isHovering, isCursorPushed {
                    NSCursor.pop()
                    isCursorPushed = false
                }
            }
            .onDisappear {
                if isCursorPushed {
                    NSCursor.pop()
                    isCursorPushed = false
                }
            }
    }
}

extension View {
    func hoverCursor(_ cursor: NSCursor) -> some View {
        modifier(CursorOnHover(cursor: cursor))
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
