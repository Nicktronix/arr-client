Run the following release process for arr-client. Be explicit at each step and wait for confirmation before making any commits or pushing anything.

## Pre-flight checks

1. Verify the current branch is `main`. If not, stop and tell the user.
2. Run `git fetch origin` then check that `main` is up to date with `origin/main`. If behind, stop and tell the user to pull first.
3. Check for uncommitted changes with `git status`. If any exist, stop and tell the user to commit or stash them first.
4. Run `flutter test` and `flutter analyze`. If either fails, stop — do not proceed with a broken build.

## Show release context

5. Show the current version from `pubspec.yaml`.
6. Show the last tag with `git describe --tags --abbrev=0` (or note if no tags exist).
7. Show the git log since the last tag with `git log <last-tag>..HEAD --oneline`. This is what will be in the release.
8. Ask the user what the new version should be. Remind them: major = breaking change, minor = new features, patch = bug fixes only. Format: `X.Y.Z`

## Prepare the release

9. Check whether `CHANGELOG.md` has an entry for the new version. If it does not, tell the user to add one before continuing and stop. Do not proceed until the changelog is updated.
10. Update the version in `pubspec.yaml`. The format is `X.Y.Z+N` where N is the build number — increment the existing build number by 1.
11. Show a final diff of `pubspec.yaml` and ask the user to confirm before continuing.

## Commit, tag, and push

12. Stage and commit `pubspec.yaml` (and `CHANGELOG.md` if it was modified) with message: `chore: bump version to X.Y.Z`
13. Push the commit to `main`.
14. Create an annotated tag: `git tag -a vX.Y.Z -m "Release X.Y.Z"`
15. Push the tag: `git push origin vX.Y.Z`
16. Confirm the release workflow has been triggered by running `gh run list --workflow=release.yml --limit=3` and show the output.
