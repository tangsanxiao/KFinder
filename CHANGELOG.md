# Changelog

All notable changes to KFinder are recorded here. Newest first.

## [Unreleased]

### Added
- Multi-selection in the list/icons views: Command/Option-click toggles individual files, Shift-click selects a contiguous range from the anchor.
- Compress in the file right-click menu: zips the selected files into `<current-folder-name>.zip`, placed in the directory of the shallowest selected item. Runs `zip` asynchronously so the UI never blocks; archive name de-duplicates on collision.
- Real Finder system icons in every view via `NSWorkspace.icon(forFile:)`; icons keep their colour when a row is selected.
- Relative modified dates: 今天 / 昨天 / 前天 + time for recent edits.
- Right-click an empty pane area to create a New Folder (auto-selects and enters inline rename).
- Layout drives the pane grid (Two Columns / Three Columns / Grid = 2 / 3 / 4 cells). Empty cells — from switching layout or closing a pane — show a greyed placeholder with a "点击添加文件面板" button instead of auto-creating panes.
- Main + Stack layout: draggable divider to resize the main pane width.
- Debug "Restart app" button in the toolbar.
- Per-folder macOS privacy (TCC) usage-description strings.
- CI workflow: `swift build` + `swift test` + `./scripts/build-app.sh` on every push / PR to `main`.
- Test target using swift-testing (Command Line Tools have no XCTest).
- Developer/AI guardrails: `swift-format` config (`.swift-format`) with a CI lint gate; `WorkspaceStore` takes an injectable `supportDirectory` so it's testable in isolation; tests covering file-operation collision handling (copy/move/rename/createFolder) and `FileBrowserService`.
- `AGENTS.md` (collaboration rules) and `ARCHITECTURE.md`.

### Changed
- List rows redone for Finder parity: compact row height, full-bleed rounded selection that covers one alternating-stripe band exactly.
- Alternating stripes are painted per row inside a lazy list so they scroll with the content; the empty area below the last file is filled by a viewport-bounded canvas.
- New workspaces open the Documents folder by default.
- A pane restores its last-visited path when its workspace is reselected (path no longer resets on workspace switch).
- Pane layout uses flexible stacks instead of absolute frames; panes fill their grid cells evenly.

### Fixed
- Import Finder Windows did nothing because `build-app.sh` produced an **unsigned** app, which macOS won't grant Apple Events automation. The dev build is now ad-hoc signed (matching `release.sh`).
- Main + Stack layout no longer collapses to a single pane: the stack region shows an "add a pane" placeholder when it has no side panes.
- `scripts/build-app.sh` aborted (and silently left a stale `dist/`) when HEAD had no exact tag, because `git describe --exact-match` returns non-zero under `set -e`. Git calls now tolerate failure.
- Restart crashed (SIGTRAP) under Swift 6: the relaunch ran inside a MainActor-isolated completion handler on a background queue. It is now a synchronous `open -n` on the main actor.
- Columns (Miller) view no longer vertically centers shorter columns; columns top-align and fill height.

## [0.1.5]
- Baseline tagged release: multi-pane browsing, rename, drag-move between panes, sorting, adaptive resizable columns, toolbar double-click zoom, GitHub Release distribution.
