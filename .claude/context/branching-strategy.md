# Branching Strategy

## Branch model: Modified Git Flow

```
main (protected)          ← Releases only — every commit here is a shipped version
  └── release/v1.2.3      ← Release branch: cherry-pick from develop, bump version, PR → main

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
2. Cherry-pick ready commits from develop
3. Bump `pubspec.yaml` version (`X.Y.Z+buildNumber`)
4. Update `CHANGELOG.md` (rename `[Unreleased]` → `[X.Y.Z] - YYYY-MM-DD`)
5. Push branch, open PR to `main`
6. After merge: `main` is auto-tagged `vX.Y.Z` → triggers build + GitHub release
7. Merge `release/vX.Y.Z` back to `develop` (brings version bump back)
8. Delete release branch
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
