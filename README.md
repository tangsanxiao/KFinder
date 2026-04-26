# KFinder

KFinder is a macOS Finder-like workspace prototype. It groups folders into workspaces and shows them as multiple file browser panes inside one app window, while still letting you reveal folders in native Finder when needed.

## Download From GitHub Releases

Download the latest `KFinder-*-macOS-*.zip` from the repository's Releases page, unzip it, then move `KFinder.app` to `/Applications`.

Current test builds use ad-hoc signing. On first launch, macOS may block the app because it is not Developer ID signed or notarized yet. If that happens:

1. Right-click `KFinder.app`.
2. Choose `Open`.
3. Confirm the system prompt.

When using `Import Finder Windows`, macOS may ask for Automation permission so KFinder can read the paths of currently open Finder windows.

## Run

```bash
swift run KFinder
```

If you import open Finder windows, macOS may ask for Automation permission.

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

The repository includes `.github/workflows/release.yml`. After pushing the project to GitHub, create and push a version tag:

```bash
git tag v0.1.0
git push origin main --tags
```

GitHub Actions will build the app, create a Release, and upload the zip plus checksum.

## MVP Features

- Create and delete workspaces.
- Add multiple folders to a workspace.
- Browse multiple folders inside one window as Finder-like panes.
- Use two-column, three-column, grid, or main-plus-stack layouts.
- Navigate each pane independently with back, forward, parent folder, and breadcrumb controls.
- Double-click folders to enter them inside the current pane, or click the disclosure chevron to expand them inline.
- Switch between list, icon, and column-style view controls from the top toolbar.
- Use Finder-style system bookmarks in the sidebar.
- Right-click files or folders to copy/move them to another pane's current folder.
- Copy folder paths and reveal folders/files in native Finder.
- Import open Finder windows as panes when needed.

## Notes

macOS does not provide a stable public API for embedding Finder windows inside another app window. KFinder therefore implements its own multi-pane file browser and uses native Finder only for optional reveal/import actions.
