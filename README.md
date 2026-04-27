# KFinder

KFinder is a macOS multi-pane file manager built for a personal workflow: viewing, comparing, copying, moving, renaming, and organizing files across several directories at the same time.

The project started from a simple need: Finder is great for one folder at a time, but day-to-day work often involves multiple active directories. KFinder keeps those folders visible in one workspace so file management can happen without constantly switching Finder windows.

This tool was designed and implemented with help from an LLM. The goal is not to replace Finder completely, but to create a focused, personal file management workspace that feels close to native macOS behavior where it matters.

## What KFinder Does

- Groups multiple folders into one workspace.
- Shows folders as multiple file-management panes in one window.
- Lets each pane navigate independently with back, forward, parent-folder, and breadcrumb controls.
- Supports list, icon, and column-style pane views.
- Supports two-column, three-column, grid, and main-plus-stack workspace layouts.
- Provides Finder-style bookmarks such as Desktop, Downloads, Documents, Applications, Trash, iCloud Drive, and Macintosh HD.
- Opens files and `.app` bundles through macOS.
- Supports inline rename after selecting a file and clicking its name.
- Supports moving files by dragging them into another pane.
- Supports context-menu copy/move to another pane's current path.
- Supports moving files to Trash.
- Supports sorting by modified date and kind.
- Supports adaptive/resizable list columns for Name, Modified, Size, and Kind.
- Can reveal files or folders in native Finder.
- Can import currently open Finder windows as KFinder panes.

## Why Not Embed Finder?

macOS does not provide a stable public API for embedding native Finder windows inside another app. KFinder therefore implements its own file browser UI with SwiftUI/AppKit and uses Finder only for optional system integrations such as reveal and importing open Finder window paths.

## Architecture

KFinder is a Swift Package Manager macOS app with a SwiftUI interface and selected AppKit integrations.

Key modules:

- `KFinderApp.swift`: app entry point and scene setup.
- `ContentView.swift`: top-level shell, sidebar/content split, global state wiring.
- `SidebarViews.swift`: workspace list, system bookmarks, sidebar interactions.
- `WorkspaceViews.swift`: top toolbar, layout picker, multi-pane workspace layout.
- `BrowserPaneView.swift`: pane navigation, file loading, sorting, rename state, drag/drop, breadcrumbs.
- `FileItemViews.swift`: list rows, icon cells, column rows, selection and rename UI.
- `WorkspaceStore.swift`: workspace persistence, pane locations, file operations, Finder import.
- `FileBrowserService.swift`: file-system listing and metadata extraction.
- `FinderController.swift`: AppleScript bridge for reading open Finder window paths.
- `SharedViews.swift`: window chrome and AppKit helper views.

Build and release scripts:

- `scripts/build-app.sh`: builds `dist/KFinder.app`.
- `scripts/release.sh`: builds, ad-hoc signs, zips, and generates SHA-256 checksums.
- `.github/workflows/release.yml`: creates a GitHub Release when a `v*` tag is pushed.

## Download From GitHub Releases

Download the latest `KFinder-*-macOS-*.zip` from the repository's Releases page, unzip it, then move `KFinder.app` to `/Applications`.

Current test builds use ad-hoc signing. On first launch, macOS may block the app because it is not Developer ID signed or notarized yet. If that happens:

1. Right-click `KFinder.app`.
2. Choose `Open`.
3. Confirm the system prompt.

When using `Import Finder Windows`, macOS may ask for Automation permission so KFinder can read the paths of currently open Finder windows.

## Run From Source

```bash
swift run KFinder
```

## Build a macOS App Bundle

```bash
./scripts/build-app.sh
open dist/KFinder.app
```

## Build a GitHub Release Artifact

```bash
./scripts/release.sh
```

This creates:

- `release/KFinder-<version>-macOS-<arch>.zip`
- `release/KFinder-<version>-macOS-<arch>.zip.sha256`

The release artifact is ad-hoc signed for test distribution. For public distribution, use Developer ID signing and Apple notarization.

## Publish With GitHub Releases

After pushing the project to GitHub, create and push a version tag:

```bash
git tag v0.1.0
git push origin main --tags
```

GitHub Actions will build the app, create a Release, and upload the zip plus checksum.

## Current Limitations

- Not Developer ID signed or notarized yet.
- Current packaged build is arm64-focused.
- File operations are intentionally simple; advanced conflict resolution is limited.
- No file-system watcher yet, so external changes may require refresh/navigation to appear.
- No full Finder feature parity: tags, smart folders, server browsing, advanced preview, sidebar customization, and rich metadata editing are not implemented.
- Drag/drop is focused on moving files between KFinder panes.
- No automated test suite yet.

## Roadmap

- Developer ID signing and notarization.
- Universal build for Intel and Apple Silicon Macs.
- File-system watching and automatic pane refresh.
- Keyboard shortcuts for common file actions.
- Richer copy/move conflict handling.
- More complete drag/drop behavior.
- Better preview support.
- Persisted live pane paths and column settings.
- Unit/UI tests around file operations and workspace persistence.

## Project Status

KFinder is currently a usable personal tool and a GitHub-ready early release. It is suitable for experimentation and small-scope personal use, but should still be treated as an early-stage macOS file manager.

## License

No license has been selected yet. Add a `LICENSE` file before publishing if you want others to use, modify, or redistribute the project under clear terms.
