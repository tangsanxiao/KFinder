# Changelog

All notable changes to XFinder are recorded here. Newest first.

## [Unreleased]

### Added
- Recent changes in the project status card: the files git reports as changed (modified / untracked / added), newest-first by modification time, each with its status badge and a relative timestamp. Click one to jump the pane to it and select it — built for reviewing what an agent just touched. Deterministic (no LLM); deleted files are skipped.
- Diff viewer from the recent-changes list: a ± button on each entry opens that file's `git diff` in a sheet with add/delete line coloring (untracked/added files show the whole file as additions). No editor or terminal needed to review an agent's edits.
- "Explain with Claude" in the diff viewer (when Claude integration is on): sends that file's diff to the local `claude` CLI as context so the explanation is about the actual edit — what changed, the likely intent, and any risks — rather than a generic project summary.
- Bilingual UI (Chinese / English) with a Language setting (System / 中文 / English); System follows the OS. Tooltips, toolbar menus, the layout popover, settings, and the filter / go-to-folder dialogs all switch language.
- Settings panel (sidebar gear at bottom-left): Claude integration is opt-in (off by default) with an optional custom `claude` CLI path; a Debug-mode toggle; and the What's New panel. When Claude is off, all Claude actions are hidden so the default file-manager experience stays clean.
- Category quick-filter in each pane toolbar (rule-based, no LLM): narrow the listing to documents / code / data / images / archives / logs / build-and-dependency noise — built for the AI-agent workflow where a run leaves these mixed together. Folders stay visible so you can still navigate while filtering.
- Sidebar toggle moved to the window's top-left next to the traffic lights (Claude-desktop style); it stays put while the sidebar slides and its glyph reflects open/collapsed state.
- Pane toolbar grouped into [filter · view] · [project status] · [⋯ more] · [close]: secondary actions (star, hidden files, reveal, copy path) collapsed into a "⋯" menu so the row stays compact.
- The Activity & Errors trace panel now only appears when Debug mode is enabled in Settings.
- In-app "What's New" panel (now opened from Settings) (clock button in the toolbar): renders the bundled CHANGELOG.md so you can recall the app's features and recent changes without leaving it.
- Activity & Errors trace panel (list button in the toolbar, red dot on new errors): every status message and error, timestamped and copyable, capped at 200 entries — debugging no longer depends on one transient alert.
- Git awareness: when a pane sits inside a git repo, list rows show a status badge after the filename (M modified, U untracked, A added, D deleted, R renamed, ! conflicted; folders get a • when their contents changed). Status loads on a background thread after the file list renders, so git never delays browsing.
- Project status card: a branch button in the pane toolbar (repos only) pops a card with the current branch, uncommitted-change count, and the last 5 commits, plus "用 Claude 分析" and "打开终端" actions.
- Claude Code bridge (all entry points English-labelled, no API keys stored — the CLI owns auth):
  - "Analyze with Claude" (status card / empty-area right-click) runs a preset project-status prompt via headless `claude -p`.
  - "Ask Claude…" opens the same sheet with an empty, editable question; every run is re-runnable with an edited question.
  - "Ask Claude About Selection" (file right-click) prefills the question with the selected files' relative paths and runs.
  - "Open in Claude Code" (status card / empty-area right-click) opens a Terminal window running the interactive `claude` CLI at the pane's directory (AppleScript; first use prompts for Terminal automation permission).
- The Layout popover now shows the live state ("3 面板 · Three Columns", with real rows×columns when panes overflow the preset) and a checkmark on the current layout; grid geometry is computed by one shared `PaneGridGeometry` so the control can never drift from what the panes render.
- Keyboard navigation in the focused pane: ↑/↓ move the selection (Shift extends), →/← expand/collapse the selected folder inline, Return renames, Cmd+↓ opens, Cmd+↑ goes to the parent folder, Cmd+Delete moves the selection to Trash. Keys pass through while renaming or typing in any text field.
- Cmd+Shift+G "Go to Folder": type a path (with `~` expansion) to jump the focused pane there.
- Cmd+F per-pane filter bar: case-insensitive name filtering of the current directory (and expanded subfolders); Esc or 完成 closes it, and the filter clears automatically on navigation.
- Double-click an empty pane area to go up one directory (rows keep their own double-click-to-open).
- Pane locations persist across app restarts (`pane-locations.json`); entries are pruned when a pane or workspace is removed.
- Per-pane hidden mode in the pane toolbar: show/hide dotfiles and hidden folders, and browse app package contents when enabled. Hidden mode is off by default.
- Renamed the project, SwiftPM package, app bundle, binary, resources, CI paths, release artifacts, and documentation to XFinder.
- "New MD" in the pane empty-area right-click menu — creates `New.md`, then `New 1.md`, `New 2.md`, etc. on name collisions.
- "Open Terminal" in the pane's empty-area right-click menu — opens Terminal.app at the pane's current directory.
- Live auto-refresh: panes watch their folder (and expanded subfolders) via FSEvents and reload when files are added, removed, renamed, or edited externally — no manual refresh needed. Events are coalesced (~0.4s) and the watch is torn down when the pane navigates away.
- Sidebar "Stars": star the current folder from a pane's toolbar; starred folders appear in a sidebar section (blue outline icon) and open into the focused/placeholder pane; remove via hover ✕ or context menu. Bookmarks are collapsed by default; both sections are collapsible.
- Layouts: "Single" (one pane, the new-workspace default) and "Three Rows" (vertical stack). New workspaces start empty (a "待添加" placeholder, no auto-directory).
- Pane add-placeholders: empty grid cells show a greyed, selectable "待添加" slot. Selecting one and clicking a sidebar folder opens it there; choosing a larger layout tops the grid up with placeholders; closing panes auto-fits the layout to the remaining count.
- Breadcrumb path is capped to the last 4 components (with a leading "…" that navigates up) and never overlaps the toolbar action buttons.
- Per-button hover state + brief tooltips on the pane toolbar actions; a debug Restart button.
- Multi-selection in the list/icons views: Command/Option-click toggles individual files, Shift-click selects a contiguous range from the anchor.
- Compress in the file right-click menu: zips the selected files into `<selected-item-folder-name>.zip`, placed in the selected item's containing directory. Runs `zip` asynchronously so the UI never blocks; archive name de-duplicates on collision.
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
- The Layout popover dropped "Import Finder Windows"; "Restart App (debug)" now appears only when Debug mode is enabled.
- README rewritten: separate English / 中文 sections, features split into "AI agent workflow" vs "basic file management", removed the acknowledgements section.
- View mode control moved from the top toolbar into each pane's own toolbar (a menu button showing the current mode) — it always was pane-local state; the top-level segmented picker implied a global switch and dominated the toolbar's width.
- Top toolbar buttons (sidebar, layout, activity, what's new) are now uniform 26pt icon buttons with the same immediate hover tips as the pane toolbar.
- The Layout popover header shows just the layout name (plus real rows×columns only when panes overflow the preset); the pane-count prefix was noise.
- Toolbar cleanup: the redundant "Layout"/"View" text labels are gone (icons + tooltips remain), and the debug Restart button moved into the Layout popover.
- Right-side toolbar, pane container, and empty placeholder backgrounds now use the same system background as the sidebar and file panes.
- Compression now selects the newly created zip archive after it appears.
- List rows redone for Finder parity: compact row height, full-bleed rounded selection that covers one alternating-stripe band exactly.
- Alternating stripes are painted per row inside a lazy list so they scroll with the content; the empty area below the last file is filled by a viewport-bounded canvas.
- New workspaces open the Documents folder by default.
- A pane restores its last-visited path when its workspace is reselected (path no longer resets on workspace switch).
- Pane layout uses flexible stacks instead of absolute frames; panes fill their grid cells evenly.

### Fixed
- The resize cursor over column dividers (and the Main+Stack divider) is now stable and no longer flickers: AppKit overlays can't win against SwiftUI's `NSHostingView` cursor management, so it now uses SwiftUI's native `pointerStyle` (macOS 15+, falling back to the AppKit cursor below that).
- Dragging a column divider no longer jitters the next column: the drag now measures translation in the global coordinate space, so the moving handle no longer feeds back on its own position.
- Drag-and-drop overhaul: dragging a multi-selection now moves every selected file (not just one); files move by dropping ONTO a folder row (folders highlight as drop targets); dropping in the pane's empty space does nothing (a drag released in place no longer relocates the file), and dropping a file into the folder it's already in is a no-op instead of duplicating. In-app drags carry the whole selection via a store payload (SwiftUI `.onDrag` only carries one item); Finder drags still drop into the current folder.
- Sidebar row icons are tighter (smaller glyph, 16pt column) for a more compact Claude-desktop-style list; the workspace row's delete button is gone (delete via right-click) so long workspace names render fully.
- Row context-menu actions on a multi-selection now apply to every selected file: Move to Trash, Copy To, and Move To previously acted only on the right-clicked row. They route through the same selection-aware target list that Compress and Ask Claude already used.
- A pane's sort order (column + direction) now survives workspace switches and app restarts (persisted per pane in `pane-sort-orders.json`); it was `@State` that reset whenever switching workspaces recreated the panes.
- Keyboard navigation keeps a selection across directory jumps, Finder-style: Cmd+↑ selects the folder you came from after going up (also via the toolbar Up button and empty-area double-click), and Cmd+↓ into a folder selects its first item — previously both landed with nothing selected, so the next arrow press had no anchor and keyboard flow broke.
- Keyboard selection now auto-scrolls into view (list and icons views): ↑/↓ could move the highlight outside the viewport — especially ↑ with nothing selected, which jumps to the last row — making the "cursor" seem to vanish.
- Keyboard navigation no longer acts on the wrong pane: the per-pane key monitor froze the focus flag from when it was installed, so the originally-focused (e.g. left) pane kept consuming arrow keys after you clicked another pane. Focus is now read live from the store on every key press, and the same stale-capture fix applies to the pane's view mode. Focus changes are also traced in the Activity & Errors panel ("Focus → …") so routing issues are diagnosable.
- Toolbar tooltips are now consistent and correctly positioned: they use the native macOS help tooltip, so they appear on every control (including the menu-style view / filter / ⋯ buttons and the sidebar toggle & settings gear, which previously had none) and never clip at the window's right edge. (Supersedes the earlier custom hover bubble, which overflowed the window and didn't attach to menus.)
- Adding a pane now upgrades the workspace layout when the pane count exceeds what the layout can show (e.g. a second pane in Single no longer stacks into an unrepresented extra row). Roomier layouts keep their placeholders — the layout only auto-upgrades, mirroring the existing auto-fit on pane close.
- Directory reads no longer block the main thread: pane reloads, folder expansion, and column drill-down load contents on a background thread (large folders such as `node_modules` no longer freeze the UI). Overlapping reloads are generation-guarded so a slow folder can't overwrite a newer result.
- Dropping multiple files onto a pane now moves all of them — previously only the first dropped file was moved and the rest were silently ignored.
- Moving a file to Trash from the context menu no longer collapses expanded folders in the current pane.
- Deeply expanded list rows no longer let long filenames overflow into the Modified column.
- Focus no longer jumps to the first pane after filling a placeholder from the sidebar. Root cause: a method called from `.onChange(of:)` read `self`'s stale (pre-update) directories, so the just-added pane looked "missing" and focus was reset. Focus is now a single source of truth in the store and `onChange` uses the new value.
- Sidebar clicks no longer pile up panes endlessly: a nil-focus click adds one pane and focuses it; a focused-pane click retargets that pane.
- Pane toolbar buttons (Reveal/Copy/Close) were unclickable — the breadcrumb's horizontal `ScrollView` hit-area (and the tooltip bubble) covered them; the breadcrumb is now a plain HStack and the tooltip is non-interactive.
- Restart button no longer crashes (SIGTRAP) under Swift 6.
- Import Finder Windows did nothing because `build-app.sh` produced an **unsigned** app, which macOS won't grant Apple Events automation. The dev build is now ad-hoc signed (matching `release.sh`).
- Main + Stack layout no longer collapses to a single pane: the stack region shows an "add a pane" placeholder when it has no side panes.
- `scripts/build-app.sh` aborted (and silently left a stale `dist/`) when HEAD had no exact tag, because `git describe --exact-match` returns non-zero under `set -e`. Git calls now tolerate failure.
- Restart crashed (SIGTRAP) under Swift 6: the relaunch ran inside a MainActor-isolated completion handler on a background queue. It is now a synchronous `open -n` on the main actor.
- Columns (Miller) view no longer vertically centers shorter columns; columns top-align and fill height.

## [0.1.5]
- Baseline tagged release: multi-pane browsing, rename, drag-move between panes, sorting, adaptive resizable columns, toolbar double-click zoom, GitHub Release distribution.
