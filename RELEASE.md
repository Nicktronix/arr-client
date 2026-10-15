# Release Workflow Guide

## Overview

GitHub Actions runs analysis, tests, and security scanning on every PR and push to `develop`/`main`. Releases are intentional: you push a version tag by hand, and the release workflow builds a signed Android APK and publishes a GitHub Release.

iOS builds are not part of CI/CD and must be built locally (see [iOS Build Instructions](#ios-build-instructions)).

The `/release` Claude command walks through every step below with confirmation before each commit or push.

---

## CI Pipeline (`.github/workflows/ci.yml`)

Runs on PRs to `develop`/`main`, pushes to `develop`/`main`, and manual dispatch. Markdown-only changes, `LICENSE`, `.gitignore`, and `.github/dependabot.yml` are ignored on push; PR runs consider the whole PR diff.

| Job | What it does | Required check |
|-----|--------------|----------------|
| **Code Analysis** | `build_runner` code generation, `dart format --set-exit-if-changed lib/ test/`, `flutter analyze --no-fatal-infos` | Yes |
| **Unit Tests** | `flutter test --coverage`, fails below 10% line coverage, uploads to Codecov | Yes |
| **Security Scan** | Google OSV scanner against `pubspec.lock` | Yes |

`codecov/patch` also reports on PRs but is informational only.

### Flutter version

The Flutter version is pinned in three places and must match:
- `.github/workflows/ci.yml` (both jobs)
- `.github/workflows/release.yml`
- `README.md` (badge and prerequisites)

Bump all three together, and use the same version locally (`fvm`).

---

## Release Pipeline (`.github/workflows/release.yml`)

Runs **only** when a tag matching `v*.*.*` is pushed. Nothing is tagged automatically.

1. **Build Android APK**: sets up JDK 21 and the pinned Flutter version, runs `build_runner` (generated files are gitignored), writes `android/key.properties` from secrets, then runs `flutter build apk --release --obfuscate --split-debug-info`.
   - `versionName` comes from the tag (`v1.2.3` → `1.2.3`)
   - `versionCode` is the workflow run number (`github.run_number`), not the `+N` in `pubspec.yaml`, so it always increases between releases
   - Uploads the APK and the obfuscation debug symbols (kept 90 days) as artifacts
2. **Create GitHub Release**: `gh release create` publishes the release for the tag, with the APK attached and standard install notes. `--verify-tag` aborts if the tag doesn't exist.

The workflow file that runs is the one **in the tagged commit**. A fix to `release.yml` only applies once it's on `main` and the tag points at a commit that includes it.

### Actions policy

The repo only allows GitHub-owned actions, verified creators, and an explicit allow-list (`subosito/flutter-action`, `google/osv-scanner-action`). A workflow that references anything else fails with `startup_failure` before any job runs, and produces no logs.

- Prefer GitHub-owned actions (`actions/*`) and the preinstalled `gh` CLI over third-party actions, especially in jobs with write permissions.
- If a third-party action is unavoidable, pin it to a commit SHA and add it to the allow-list (Settings → Actions → General).
- Pass `${{ github.* }}` values into `run:` scripts through `env:`, not inline.

---

## Branching Model

```
main (protected)          ← Releases only; every commit is a shipped version
  └── release/vX.Y.Z      ← Branched from main, PR → main

develop (default, protected) ← Integration branch
  ├── feature/short-name
  ├── fix/short-name
  ├── chore/short-name
  └── optimize/short-name
```

Feature, fix, and chore branches branch from `develop` and PR back to `develop`. See [`.claude/context/branching-strategy.md`](.claude/context/branching-strategy.md) for naming and the issue → branch → PR lifecycle.

`main`, `develop`, and `release/*` are protected by rulesets: changes go through PRs, the three required checks must pass, and 1 approving review is required. Since you can't approve your own PR, the repo owner merges with the admin bypass. Version tags can only be created, not updated or deleted, without bypass. Merged branches are deleted from the remote automatically.

---

## Release Process

### 1. Create the release branch

```bash
git checkout main && git pull
git checkout -b release/vX.Y.Z
```

Bring in the work being released:

- **Shipping everything on `develop`** (the usual case): fast-forward. This keeps the original commit hashes, so the back-merge in step 6 is trivial.
  ```bash
  git fetch origin
  git merge --ff-only origin/develop
  ```
- **Selective release**: cherry-pick only what's ready, in order. Explicitly add; don't remove.
  ```bash
  git cherry-pick <commit>...
  ```

### 2. Version and changelog

- `pubspec.yaml`: `version: X.Y.Z+N`. Increment `N` by 1 over the last release.
  - **Major**: breaking changes · **Minor**: new features · **Patch**: bug fixes only
- `CHANGELOG.md`: move the `[Unreleased]` entries into `## [X.Y.Z] - YYYY-MM-DD` (the actual release date), leave an empty `[Unreleased]` heading, and update the Version History list.
- If users must do anything special to upgrade, put a note at the top of the version's section. The release page links to the changelog.

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "chore: bump version to X.Y.Z"
git push -u origin release/vX.Y.Z
```

### 3. PR to main

```bash
gh pr create --base main --head release/vX.Y.Z --title "Release vX.Y.Z" \
  --body "Release vX.Y.Z

See CHANGELOG.md for details."
```

Wait for the three required checks, then merge (merge commit) with the admin bypass.

### 4. Tag

```bash
git checkout main && git pull
git tag -a vX.Y.Z -m "Release X.Y.Z"
git push origin vX.Y.Z
```

### 5. Verify the release

```bash
gh run list --workflow=release.yml --limit 1
gh run watch <run-id>
```

The Android build takes about 5–10 minutes. Then check the published APK is signed with the release key, not a debug key:

```bash
gh release download vX.Y.Z --pattern '*.apk' --dir /tmp/arr-release
apksigner verify --print-certs /tmp/arr-release/*.apk   # DN must not be "CN=Android Debug"
```

### 6. Back-merge and clean up

```bash
git checkout develop && git pull
git merge release/vX.Y.Z      # brings the version/changelog commit back
git push origin develop
git branch -d release/vX.Y.Z  # the remote branch is deleted on PR merge
```

### 7. Close shipped issues

Close each issue included in the release with "Shipped in vX.Y.Z" and move it from **Release Ready** to **Done** on the project board. Issues are never closed by PR merges.

### Fixing a failed release

If the tag build fails, nothing was published:

1. Fix the cause on `develop` (fix branch → PR), then bring it to `main` through a release branch and PR.
2. Move the tag to the new `main` commit (needs the tag-ruleset bypass):
   ```bash
   git push origin :refs/tags/vX.Y.Z
   git tag -d vX.Y.Z
   git checkout main && git pull
   git tag -a vX.Y.Z -m "Release X.Y.Z"
   git push origin vX.Y.Z
   ```

Only move a tag that never produced a published release. Once users have downloaded a version, ship a fix as a new patch version instead.

---

## Distributing Builds

### Android

Share the release page (`https://github.com/Nicktronix/arr-client/releases/latest`). Users download the APK, allow installs from unknown sources, and install it.

### Signing key

Releases from v1.1.0 onward are signed with the release keystore stored in repo secrets. **v1.0.0 was signed with a CI-generated debug key**, so v1.0.0 installs can't be updated in place: users must export a backup, uninstall, install the new version, and import. Losing the keystore would force the same reinstall on every user, so keep a secure copy outside GitHub.

### iOS Build Instructions

iOS builds require code signing and are not provided in GitHub releases. Users must build locally:

**Prerequisites**:
- macOS with Xcode installed
- Flutter SDK installed
- Apple ID (free or paid Apple Developer account)

**Build Steps**:

1. **Clone at release tag**:
   ```bash
   git clone https://github.com/Nicktronix/arr-client.git
   cd arr-client
   git checkout v1.2.3  # Replace with desired version
   ```

2. **Install dependencies and generate code** (generated files aren't committed):
   ```bash
   flutter pub get
   flutter pub run build_runner build
   ```

3. **Open Xcode workspace**:
   ```bash
   open ios/Runner.xcworkspace
   ```

4. **Configure signing** (in Xcode):
   - Select "Runner" project in navigator
   - Select "Runner" target
   - Go to "Signing & Capabilities" tab
   - Select your Development Team (sign in with Apple ID if needed)
   - Xcode will automatically create provisioning profile

5. **Build**:
   ```bash
   flutter build ios --release
   ```

6. **Install options**:
   - **Direct Install**: Use Xcode to install on connected device
   - **Create IPA for Sideloading**:
     ```bash
     # Create Payload directory
     mkdir -p Payload
     cp -r build/ios/iphoneos/Runner.app Payload/
     zip -r arr-client.ipa Payload
     ```
     Then use AltStore or Sideloadly to install the IPA

**Notes**:
- Free Apple ID: Apps expire after 7 days, need re-signing
- Paid Developer Account ($99/year): Apps valid for 1 year

---

## Configuration

### Required GitHub Secrets

**For release builds** (releases fail without these):
- `ANDROID_KEYSTORE_FILE`: Base64-encoded keystore (`base64 -w 0 your-keystore.jks`)
- `ANDROID_KEYSTORE_PASSWORD`: Keystore password
- `ANDROID_KEY_ALIAS`: Key alias
- `ANDROID_KEY_PASSWORD`: Key password

**For CI**:
- `CODECOV_TOKEN`: Coverage upload (`fail_ci_if_error: true`, so the Unit Tests job fails without it)

**Generating a keystore** (one-time setup):
```bash
keytool -genkey -v -keystore arr-client.jks -keyalg RSA -keysize 2048 -validity 10000 -alias arr-client
# Store this file securely — losing it means you cannot update the app for existing installs
base64 -w 0 arr-client.jks  # paste output into ANDROID_KEYSTORE_FILE secret
```

Local release builds without `android/key.properties` fall back to debug signing.

### Dependency updates

Dependabot (`.github/dependabot.yml`) opens PRs weekly for pub packages and monthly for GitHub Actions. Review them like any PR to `develop`. When doing a bulk update instead, close the superseded Dependabot PRs with a link to the replacing PR.

---

## Troubleshooting

### Analyze or format check fails in CI

```bash
dart format lib/ test/
flutter analyze
```

Check that your local Flutter matches the pinned version. A different formatter or lint set gives different results.

### Tests fail in CI

```bash
flutter pub run build_runner build
flutter test
```

### Release workflow shows `startup_failure`

A referenced action isn't allowed by the repo's actions policy (see [Actions policy](#actions-policy)). There are no logs. Check every `uses:` in `release.yml` against the allow-list, then follow [Fixing a failed release](#fixing-a-failed-release).

### Android APK won't install ("App not installed")

The installed app is signed with a different key (for example, upgrading from v1.0.0 or from a local debug build). Export a backup, uninstall, install, then import the backup.

---

## Quick Reference

```bash
# Release (after release PR is merged)
git checkout main && git pull
git tag -a vX.Y.Z -m "Release X.Y.Z"
git push origin vX.Y.Z

# Watch release build
gh run list --workflow=release.yml --limit 1

# List tags
git tag -l
```
