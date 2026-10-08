# CleanShare - Development Handoff

**Updated:** 2026-10-02

## Shared Vibe Coding workflow rules (2026-10-08)

### Documentation-only handoff exception
- When the user explicitly requests a documentation-only update, ChatGPT may edit the existing root `VIBECODING_HANDOFF.md` directly through GitHub without requiring a Mac build or a local checkout step.
- First inspect the actual repository, target branch, and existing handoff. Change only the handoff, preserve historical project context, and verify the resulting GitHub file and commit. Do not use this exception for application code, tests, scripts, configuration, workflows, version/build changes, release assets, or other build-affecting files.
- Before the next local development change, fetch the remote branch and reconcile the updated handoff with the local checkout. Never overwrite or silently reset unrelated local changes.
- The normal rule remains: validate the exact executable/build-affecting changes in the real Mac checkout before committing or pushing those changes. Include a current handoff with every meaningful validated development commit.

### Temporary worktrees, releases, and logs
- Create temporary Git worktrees under `/Users/alex/Desktop/tmp/<project>-...` using a project-specific name.
- Put release working folders, temporary release artifacts, staging directories, and build/release logs under `/Users/alex/Desktop/tmp/<project>-release-...`.
- Do not create disposable worktrees inside `/Users/alex/Documents/Vibe Coding`.
- Do not place release artifacts or logs directly on the Desktop root.
- After a successful verified release, remove temporary worktrees and temporary release artifacts when safe. Do not remove active worktrees, uncommitted work, published assets, or permanent project files.
- Retain failure logs only when useful for debugging; remove unnecessary temporary logs.
- These instructions govern future operations and take precedence over historical temporary-path examples elsewhere in this handoff.

### Low-overhead development defaults
- Use ChatGPT plus GitHub inspection and Mac-local Terminal scripts by default; do not use Codex, ChatGPT Work, separately billed API agents, or GitHub Actions runners unless explicitly requested.
- Prefer existing project scripts. Give one local command block to apply, build, test, and launch an executable change, then a separate commit/push block only after required validation is confirmed.
- Documentation-only updates under the exception above do not require a rebuild.

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
