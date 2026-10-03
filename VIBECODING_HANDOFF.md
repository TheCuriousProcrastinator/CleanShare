# CleanShare - Development Handoff

**Updated:** 2026-10-02

## Project

CleanShare is a native macOS app for sharing a clean cropped region of the screen during presentations and video calls.

It creates a separate output window containing only the selected region so the user can share that window while keeping the rest of the desktop private.

## Repository

- GitHub: `TheCuriousProcrastinator/CleanShare`
- Default branch: `main`
- Source baseline before this policy migration: `3cceea00f024b1f57257b1cd2366936a67f9ba37`
- Marketing version: **1.0**
- Build: **1**
- Latest verified GitHub Release: **v1.0**
- Release asset: `CleanShare-1.0.zip`

Always verify the current repository HEAD before changing source.

## Architecture

CleanShare is a native macOS Xcode project with no third-party dependencies.

Important files include:

- `CleanShare.xcodeproj`
- `CleanShare/CleanShareApp.swift`
- `CleanShare/AppModel.swift`
- `CleanShare/ContentView.swift`
- `CleanShare/CaptureConfiguration.swift`
- `CleanShare/DisplayCatalog.swift`
- `CleanShare/GlobalHotKey.swift`
- `CleanShare/LaunchAtLoginManager.swift`
- `CleanShare/MenuBarView.swift`
- `CleanShare/OutputWindowController.swift`
- `CleanShare/RegionSelectionController.swift`
- `CleanShare/ScreenCaptureManager.swift`
- `CleanShare/SettingsView.swift`
- `CleanShare/ShortcutRecorderView.swift`

The app uses ScreenCaptureKit and requires Screen Recording permission.

## Known product behavior

Current repository documentation describes:

- custom screen-region selection
- multi-display support
- ScreenCaptureKit capture
- pause/resume
- Black Screen mode
- global panic shortcut
- menu bar controls
- Launch at Login
- remembered capture area
- fully local screen processing

Preserve existing working behavior unless a change is explicitly requested.

## GitHub Actions policy

Normal development and release validation is authoritative only when performed locally on the user's Mac.

The repository contains:

`.github/workflows/manual-validation.yml`

It is intentionally manual-only through `workflow_dispatch`.

GitHub Actions must not run automatically for:

- feature-branch pushes
- `main` pushes
- pull requests
- release/version tags
- schedules
- other repository events

GitHub Actions is optional clean-environment verification only and may be run only when the user explicitly requests it.

Development and releases do not depend on GitHub Actions.

## Development workflow

Before modifying the local checkout:

1. `git fetch origin`
2. verify the expected branch and HEAD
3. inspect `git status --short`
4. stop rather than overwrite, reset, stash, or merge unrelated local changes
5. make the smallest reliable change
6. validate locally
7. for executable or UI changes, build locally and launch the new development app
8. wait for explicit user validation for interaction/UI behavior
9. commit and push only the exact locally tested files
10. update this handoff with every meaningful development commit

GitHub remains read-only until the exact change passes required local validation.

## Release policy

Release validation, build, signing, packaging, and verification happen locally on the Mac when applicable.

GitHub is used for:

- committed source/history
- branches and tags
- GitHub Releases
- downloadable release assets
- optional manually requested clean-environment verification

A release must not depend on hosted GitHub Actions.

GitHub does not back up signing identities, private keys, Keychain credentials, local secrets, ignored files, or uncommitted work.

## Policy migration scope

This migration changes only:

- `.github/workflows/manual-validation.yml`
- `VIBECODING_HANDOFF.md`

It does not change app source, Xcode project settings, version/build, runtime behavior, permissions, or release assets.

## Next development task

Verify the current repository and this handoff before selecting the next product change.
