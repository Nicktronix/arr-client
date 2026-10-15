# Branching Strategy

## Branch model: Modified Git Flow

```
main (protected)          ← Releases only — every commit here is a shipped version
  └── release/v1.2.3      ← Release branch: fast-forward to develop (or cherry-pick), bump version, PR → main

develop (protected)       ← Integration branch — default branch, CI always runs here
  ├── feature/short-name  ← New features
  ├── fix/short-name      ← Bug fixes
  ├── chore/short-name    ← Tooling, deps, config, docs
  └── optimize/short-name ← Performance improvements
```

---

## Rules

### Branch naming
- Always prefix with type: `feature/`, `fix/`, `chore/`, `optimize/`
- Optionally include issue number: `fix/31-instance-manager-deletion`
- Use kebab-case, keep it short but descriptive

### Where to branch from
- Feature/fix/chore branches → branch from `develop`
- Release branches → branch from `main` (last stable release)

### Where to PR to
- Feature/fix/chore branches → PR to `develop`
- Release branches → PR to `main`

### What triggers CI
- PRs to `develop` — validates before merge
- Pushes to `develop` — validates after merge
- PRs to `main` — validates release candidate
- Version tags `v*.*.*` on `main` — triggers Android build + GitHub release

### What does NOT trigger CI
- Feature/fix/chore branches (test locally before opening PR)

---

## Release flow

1. Create `release/vX.Y.Z` from `main`
2. Bring in the work: `git merge --ff-only origin/develop` to ship all of develop, or cherry-pick ready commits for a selective release
3. Bump `pubspec.yaml` version (`X.Y.Z+buildNumber`)
4. Update `CHANGELOG.md` (move `[Unreleased]` entries into `[X.Y.Z] - YYYY-MM-DD`, using the actual release date)
5. Push branch, open PR to `main`, merge with admin bypass once the required checks pass
6. Tag manually: `git tag -a vX.Y.Z` on `main` and push it. Nothing is auto-tagged. The tag triggers the build and GitHub release
7. Verify the release run and that the APK is signed with the release key
8. Merge `release/vX.Y.Z` back to `develop` (brings version bump back); the remote branch is deleted on merge
9. Close all issues whose fixes are included in this release (move to Done on board)

See `RELEASE.md` for full detail and the `/release` command for guided execution.

---

## Issue → branch → PR lifecycle

```
Issue created (Backlog)
  → Moved to Up Next
  → Branch created from develop
  → Issue moved to In Progress
  → PR opened to develop: "Related #N" in body
  → Issue moved to In Review
  → PR merged to develop
  → Issue moved to Release Ready
  → Feature ships in a release
  → Issue closed + moved to Done
```
