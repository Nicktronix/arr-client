Guide me through creating a new release for arr-client following the release process in `RELEASE.md`. Be explicit at each step and wait for confirmation before making any commits, pushing anything, or pushing a tag.

## Pre-flight checks

1. Verify the current branch is `main`. If not and the tree is clean, check out `main`; otherwise stop and tell the user.
2. Run `git fetch origin --tags` then check that `main` is up to date with `origin/main`. If behind, pull (fast-forward only).
3. Check for uncommitted changes with `git status`. Untracked personal files that `develop`'s `.gitignore` ignores (`.claude/commands/`, `.claude/context/github-project.md`, `android/NOTICE`) can show up on `main` and are fine. Anything else: stop and tell the user to commit or stash it.
4. Check `release.yml` only uses allowed actions: every `uses:` must be GitHub-owned (`actions/*`) or in the allow-list (`gh api repos/Nicktronix/arr-client/actions/permissions/selected-actions`). Anything else fails the tag build with `startup_failure`.

## Show release context

5. Show the current version from `pubspec.yaml` on `main` and on `origin/develop`.
6. Show the last tag with `git describe --tags --abbrev=0` (or note if no tags exist).
7. Show what's unreleased: `git log main..origin/develop --no-merges --oneline`, plus counts by commit type.
8. Ask the user what the new version should be. Remind them: major = breaking change, minor = new features, patch = bug fixes only. Format: `X.Y.Z`

## Create the release branch

9. Create and check out `release/vX.Y.Z` from `main`.
10. Ask how to bring in the work:
    - **All of develop** (usual, recommended): `git merge --ff-only origin/develop`. This keeps commit hashes, so the back-merge is trivial.
    - **Selective**: cherry-pick the chosen commits in order. If any conflict, stop and help the user resolve it.

## Prepare the release

11. `pubspec.yaml`: version `X.Y.Z+N`, where N is the last released build number + 1. It may already be set on develop. If so, leave it.
12. `CHANGELOG.md`: move `[Unreleased]` entries into `## [X.Y.Z] - YYYY-MM-DD` (today's date), leave an empty `[Unreleased]` heading, and update the Version History line. If a `[X.Y.Z]` section already exists, fold the entries in and correct anything the new entries supersede, rather than duplicating it. Show the diff.
13. Ask whether users need an upgrade note (signing-key change, data migration, manual steps). If so, add it at the top of the version's section.
14. After confirmation, commit with message `chore: bump version to X.Y.Z` and push `release/vX.Y.Z`.

## Open the PR

15. Show a final summary of what's in the release and ask for confirmation, then:
    ```
    gh pr create --base main --head release/vX.Y.Z --title "Release vX.Y.Z" --body "Release vX.Y.Z

    See CHANGELOG.md for details."
    ```
16. Watch the required checks (Code Analysis, Unit Tests, Security Scan). The PR also needs an approving review before it can be merged.

## Tag and verify

17. After the user confirms the merge, pull `main`, confirm its tree matches the local release branch, and confirm `vX.Y.Z` doesn't exist yet. Ask before pushing the tag:
    ```
    git tag -a vX.Y.Z -m "Release X.Y.Z"
    git push origin vX.Y.Z
    ```
18. Watch the release run: `gh run list --workflow=release.yml --limit 1`, then `gh run watch <id>`.
    - `startup_failure` means a disallowed action; see "Fixing a failed release" in `RELEASE.md`.
19. When it succeeds, download the APK and verify the signer: `apksigner verify --print-certs`. The DN must not be `CN=Android Debug`.

## Clean up

20. Ask before pushing to develop, then:
    ```
    git checkout develop && git pull
    git merge release/vX.Y.Z && git push origin develop
    git branch -d release/vX.Y.Z   # remote branch is auto-deleted on PR merge
    ```
21. List the issues in **Release Ready** on the board. After confirmation, close each with "Shipped in vX.Y.Z" and move it to **Done**.
