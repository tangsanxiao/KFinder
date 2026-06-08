# Architecture

XFinder is a macOS multi-pane file manager (QSpace-inspired) built as a single
SwiftPM executable using SwiftUI with AppKit interop. This document describes the
stable topology — module boundaries and data flow. Volatile specifics (exact
sizes, counts, lists) live in the code and tests, which can't go stale.

For working conventions and known traps, see [AGENTS.md](AGENTS.md).

## Build & run

- `swift build` — compile.
- `swift test` — swift-testing suite (no XCTest; see AGENTS.md for why).
- `swift format lint --strict --recursive Sources Tests` — style gate (config: `.swift-format`); `swift format format -i ...` to auto-fix.
- `./scripts/build-app.sh` — package `dist/XFinder.app` (ad-hoc signed).
- `./scripts/release.sh` — build + zip + checksum into `release/` (tag-triggered in CI).

`WorkspaceStore` takes an optional `supportDirectory` so tests inject a temp
directory and stay isolated from the real Application Support; file-operation
collision handling is covered by tests against temp directories.

## Process & windowing

- `XFinderApp` (`@main`) hosts a single `WindowGroup` with a hidden titlebar.
- `WindowChromeConfigurator` configures the `NSWindow` once (transparent titlebar,
  full-size content). The app deliberately avoids `NavigationSplitView` and uses a
  custom sidebar/content split to keep titlebar spacing controllable.
- `WindowDragArea` / `WindowZoomController` handle drag-to-move and double-click zoom.

## State: single source of truth

`WorkspaceStore` is a `@MainActor ObservableObject` that owns all app state and
every file-system mutation:

- **Workspaces & panes** — a `Workspace` holds an ordered list of `DirectoryItem`
  (each = one pane root). Persisted as JSON under Application Support.
- **Live pane locations** — `paneLocations[paneID]` tracks where each pane has
  navigated, so navigation survives workspace switches (panes are recreated on
  switch and restore from here).
- **Layout** — `WorkspaceLayout` defines the pane arrangement and a
  `preferredPaneCount`. `applyLayout` only switches the layout; when it wants
  more panes than there are folders, the grid renders greyed "add a pane"
  placeholders for the empty cells instead of auto-creating panes.
- **File operations** — create folder, create Markdown file, copy, move, rename,
  trash, and compress. Each mutation bumps `fileOperationRevision`, which panes
  observe to reload while preserving local expansion state where appropriate.
- **System bookmarks** — Desktop/Documents/Downloads/etc. for the sidebar.

Views never touch the file system directly; they call the store.

## View layer

```
ContentView
├─ Sidebar (SidebarViews)        workspaces list + system bookmarks
└─ WorkspaceDetailView (WorkspaceViews)
   ├─ FinderLikeToolbar          title, Layout control, View mode, restart
   └─ MultiPaneBrowserView       arranges panes per layout (grid / main+stack)
      └─ BrowserPane (BrowserPaneView)   one navigable pane
         ├─ toolbar: back/forward/up, breadcrumbs, reveal, copy path, close
         ├─ list / icons / columns views
         └─ rows (FileItemViews): FileRow, IconFileCell, ColumnFileRow
```

- **View mode is pane-local** (`paneViewModes[paneID]`); focus is tracked by
  `focusedDirectoryID` and drives the toolbar title and bookmark targeting.
- **`FileRowMetrics`** is the single source of truth for list-row geometry
  (height, selection corner radius, alternating tint) shared by rows, the
  selection fill, and the stripe filler.
- **`FileIconView`** renders the real system icon for any URL.

## File browsing

`FileBrowserService` is a stateless enum that reads a directory's contents into
`BrowserFileItem` values (name, dates, size, kind, package/dir flags), hiding
dot/hidden files and sorting folders-first. `BrowserPane` keeps inline expansion
state and reloads expanded subfolders after file operations or FSEvents updates.
`DisplayFormatters` turns dates/sizes into display strings (pure, injectable
clock for testing).

## Persistence

- Workspaces → JSON in `~/Library/Application Support/XFinder/` (migrated from a
  legacy `FinderHub` directory if present).
- `dist/`, `release/`, `.build/`, and `AI_CONTEXT.md` are gitignored.

## CI / distribution

- `.github/workflows/ci.yml` — build + test + package on every push/PR to `main`.
- `.github/workflows/release.yml` — on a `v*` tag, builds and uploads the zip +
  checksum as a GitHub Release.
