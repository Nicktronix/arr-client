Guide me through creating a new release for arr-client following the documented release branch process. Be explicit at each step and wait for confirmation before making any commits or pushing anything.

## Pre-flight checks

1. Verify the current branch is `main`. If not, stop and tell the user.
2. Run `git fetch origin` then check that `main` is up to date with `origin/main`. If behind, stop and tell the user to pull first.
3. Check for uncommitted changes with `git status`. If any exist, stop and tell the user to commit or stash them first.

## Show release context

4. Show the current version from `pubspec.yaml`.
5. Show the last tag with `git describe --tags --abbrev=0` (or note if no tags exist).
6. Show the git log since the last tag with `git log <last-tag>..HEAD --oneline`. This is the pool of commits available to cherry-pick into the release.
7. Ask the user what the new version should be. Remind them: major = breaking change, minor = new features, patch = bug fixes only. Format: `X.Y.Z`

## Create the release branch

8. Create and checkout a release branch: `git checkout -b release/vX.Y.Z`
9. Ask the user which commits to cherry-pick from develop (show the log from step 6 as reference). Cherry-pick them in order.
10. If any cherry-pick conflicts occur, stop and help the user resolve them before continuing.

## Prepare the release

11. Update the version in `pubspec.yaml`. Format is `X.Y.Z+N` where N is the build number — increment the existing build number by 1.
12. Check whether `CHANGELOG.md` has an entry for the new version. If it does not, tell the user to add one before continuing and stop. Do not proceed until the changelog is updated.
13. Stage and commit `pubspec.yaml` (and `CHANGELOG.md` if it was modified) with message: `chore: bump version to X.Y.Z`
14. Push the release branch: `git push origin release/vX.Y.Z`
15. Show a final summary of what's in the release and ask for confirmation before creating the PR.

## Open the PR

16. Create a PR from `release/vX.Y.Z` → `main` using:
    ```
    gh pr create --base main --head release/vX.Y.Z --title "Release vX.Y.Z" --body "Release vX.Y.Z\n\nSee CHANGELOG.md for details."
    ```
17. Tell the user to wait for CI to pass on the PR before merging.
18. Remind the user: after merging, pull main locally and push the tag:
    ```
    git checkout main && git pull
    git tag -a vX.Y.Z -m "Release X.Y.Z"
    git push origin vX.Y.Z
    ```
19. Remind the user to merge the release branch back to develop and delete it:
    ```
    git checkout develop && git merge release/vX.Y.Z && git push origin develop
    git branch -d release/vX.Y.Z && git push origin :release/vX.Y.Z
    ```
