# Release Workflow Guide

## Overview

This project uses GitHub Actions for automated testing, security scanning, and release builds. The workflow automatically creates releases with Android APK and iOS IPA when you merge a release branch to main.

## Workflow Stages

### 1. **Analyze** (Runs on every PR and push to main/develop)
- Code quality analysis via `flutter analyze`
- Code formatting check via `dart format`
- Fails if code has errors or isn't properly formatted

### 2. **Test** (Runs on every PR and push to main/develop)
- Unit tests with coverage reporting
- Coverage uploaded to Codecov (optional)
- Fails if tests don't pass

### 3. **Security** (Runs on every PR and push to main/develop)
- Dependency scanning via `flutter pub outdated`
- Non-blocking (shows warnings but doesn't fail builds)
- GitHub Dependabot automatically creates PRs for security updates

### 4. **Auto-Tag** (Runs ONLY on push to main)
- Extracts version from `pubspec.yaml`
- Creates git tag automatically (e.g., v1.2.3)
- Triggers build workflow when tag is created

### 5. **Build** (Runs ONLY on version tags)
- Android APK build (macOS runner not required)
- iOS IPA build (requires macOS runner, unsigned for sideloading)
- Version embedded from git tag
- Artifacts stored for 90 days

### 6. **Release** (Runs ONLY on version tags)
- Creates GitHub Release automatically
- Attaches APK and IPA as downloadable assets
- Generates release notes with download instructions

## Git Branching Strategy

**Modified Git Flow**: develop for integration, release branches for selective releases.

```
develop (default, protected) ← Integration testing, pipeline runs here
├── feature/new-feature
├── fix/bug-fix
├── optimize/performance
└── fix/integration-issue

main (protected) ← Releases only, auto-tagged on merge
  ├── release/v1.2.3
  └── release/v1.3.0
```

**Workflow Behavior**:
- ✅ Runs on **Pull Requests to develop** (validates before merge)
- ✅ Runs on **develop branch pushes** (validates after merge)
- ✅ Runs on **Pull Requests to main** (validates release branch)
- ✅ **Auto-tags main** when release branch merges (extracts version from pubspec.yaml)
- ✅ Runs on **version tags** (triggers builds and release creation)
- ❌ Does NOT run on feature/fix branches

**Why workflows run twice**:
1. **On PR**: Pre-merge validation (catches issues before they land)
2. **After merge**: Post-merge validation (catches merge conflicts, integration issues)

This is intentional and follows GitHub Actions best practices.

## Release Workflow Examples

These examples show how to work with the branching strategy in practice.

### 1. Feature Development (Isolated Testing)

```bash
# Create feature branch from develop
git checkout develop
git pull
git checkout -b feature/new-filters

# Develop and test in isolation
git commit -m "feat: add series filters"
git push origin feature/new-filters

# Test locally
flutter test
flutter run -d android

# When feature works in isolation, merge to develop for integration
# Create MR: feature/new-filters → develop (triggers CI)
# After approval, merge
```

### 2. Integration Testing (develop)

```bash
# Multiple features merge to develop
git checkout develop
# Now contains: feature A, feature B, optimization C

# Test integration
flutter run
# Oh no! Feature A breaks Feature B

# Create fix branch
git checkout -b fix/feature-a-b-conflict develop
# Fix the issue...
git commit -m "fix: resolve feature A/B conflict"
# MR: fix/feature-a-b-conflict → develop
```

### 3. Selective Release (Release Branch)

```bash
# You want to release: optimization C + old fix D
# But NOT: feature A, feature B (still broken)

# Create release branch from main (last stable release)
git checkout main
git pull
git checkout -b release/v1.2.3

# Cherry-pick what's ready (EXPLICITLY ADD, don't remove)
git cherry-pick <optimize-C-commits>
git cherry-pick <fix-D-commits>

# Update version
# Edit pubspec.yaml: version: 1.2.3+4
git add pubspec.yaml
git commit -m "chore: bump version to 1.2.3"
git push origin release/v1.2.3

# Test release candidate
flutter test
flutter run -d android
flutter run -d ios

# Create PR: release/v1.2.3 → main (triggers CI)
# After approval and merge:
#   1. Workflow runs on main
#   2. Auto-tags main with v1.2.3
#   3. Tag triggers build workflow (APK/IPA)
#   4. Release created on GitHub

# Important: Merge release branch back to develop
git checkout develop
git merge release/v1.2.3  # Brings version bump back
git push origin develop

# Delete release branch (tag preserves it)
git branch -d release/v1.2.3
git push origin :release/v1.2.3
```

### 4. Next Release

```bash
# Later, when feature A/B conflict is fixed
git checkout develop
# Now contains: optimization C, fix D (already released),
#               feature A, feature B (now working together)

# Create next release
git checkout main
git pull
git checkout -b release/v1.3.0

# Cherry-pick features A and B
git cherry-pick <feature-A-commits>
git cherry-pick <feature-B-commits>

# Update version and repeat release process
```

## Key Advantages

✅ **develop = integration testing** - find issues early  
✅ **Release branch from main** - start from stable state  
✅ **Explicitly add, don't remove** - clear intent, no mistakes  
✅ **Ship what works** - unblocked releases  
✅ **Auto-tagging** - no manual tag step, can't forget  
✅ **main always stable** - only contains releases  

---

## Release Process

This section covers everything you need to create and distribute a release.

### Version Management

### Update Version in pubspec.yaml

Before creating a release tag, update the version in `pubspec.yaml`:

```yaml
version: 1.2.3+456
#        │ │ │  └── Build number (auto-incremented by CI)
#        │ │ └──── Patch version
#        │ └────── Minor version
#        └──────── Major version
```

**Version Numbering**:
- **Major** (1.x.x): Breaking changes
- **Minor** (x.1.x): New features, backwards compatible
- **Patch** (x.x.1): Bug fixes only

### Release Checklist

- [ ] All tests passing on main branch
- [ ] Version updated in `pubspec.yaml`
- [ ] CHANGELOG updated (optional but recommended)
- [ ] Merge develop into main
- [ ] Create and push version tag

### Creating a Release

**Step-by-Step Process:**

1. **Update Version**
   ```bash
   # Edit pubspec.yaml
   version: 1.2.3+1
   
   git add pubspec.yaml
   git commit -m "chore: bump version to 1.2.3"
   git push origin main
   ```

2. **Create Tag**
   ```bash
   git tag -a v1.2.3 -m "Release 1.2.3 - Description of changes"
   git push origin v1.2.3
   ```

3. **Monitor Workflow**
   - Go to Actions tab in GitHub
   - Watch the workflow progress
   - Auto-tag job runs immediately after merge
   - Build jobs trigger when tag is created
   - Android build takes ~5-10 minutes
   - iOS build takes ~10-15 minutes (on GitHub's macOS runners)

4. **Access Release**
   - Once complete, go to Releases section
   - Download APK/IPA from release assets
   - Share release URL with users

### Distributing Builds

Once the release is created, you can distribute builds to users.

#### Android Distribution

**Direct Download**:
1. Share GitHub release URL with users
2. They download the APK
3. Enable "Install from Unknown Sources" in Android settings
4. Install APK

**Example release URL**:
```
https://github.com/Nicktronix/arr-client/releases/latest
```

#### iOS Distribution (More Complex)

iOS doesn't allow direct IPA installation. Friends need one of these tools:

**Option 1: AltStore** (Free, requires computer)
- Install AltStore on computer
- Connect iPhone
- Sideload the IPA (valid for 7 days, needs renewal)

**Option 2: Sideloadly** (Free, easier)
- Install Sideloadly on computer
- Connect iPhone
- Drag IPA to Sideloadly (valid for 7 days)

**Option 3: TestFlight** (Best for iOS, requires Apple Developer account)
- Requires $99/year Apple Developer Program
- Upload to TestFlight
- Share invite link (100 testers max)
- No 7-day expiration
- (Not configured in current workflow)

---

## Workflow Configuration Details

### Required GitHub Secrets

For basic setup, no secrets needed! The workflow works out of the box.

**Optional**:
- `CODECOV_TOKEN`: For test coverage reporting (free for public repos)

**For future app store releases**:
- `ANDROID_KEYSTORE_FILE`: Base64-encoded keystore for signing
- `ANDROID_KEYSTORE_PASSWORD`: Keystore password
- `ANDROID_KEY_ALIAS`: Key alias
- `ANDROID_KEY_PASSWORD`: Key password

### GitHub Runners

**GitHub-Hosted Runners** (Free for public repos):
- ✅ Android builds work on Ubuntu runners
- ✅ iOS builds work on macOS runners (included!)
- ✅ 2,000 minutes/month free for private repos
- ✅ Unlimited for public repos

No self-hosted runner needed for this project!

## Security Scanning

### GitHub Security Features (Free)

GitHub provides **FREE security features**:

1. **Dependabot**: Automatically scans for vulnerable dependencies
2. **Security Advisories**: CVE database integration
3. **Dependency Graph**: Visualize all dependencies
4. **Code Scanning** (Advanced Security): SAST for Dart code (free for public repos)

### Workflow Security Checks

The workflow includes:

1. **`flutter pub outdated`**: Lists packages with available updates (non-blocking)
2. **Dependabot PRs**: Automatic security update pull requests
3. **Version verification**: Checks pubspec.yaml consistency

### When Scans Run

- **Pull Requests**: Non-blocking, shows warnings
- **Main/Develop Branch**: Non-blocking, informational only
- **Dependabot**: Runs daily, creates PRs automatically

### Manual Security Review

1. Review Dependabot PRs in the Security tab
2. Check workflow output for `flutter pub outdated` warnings
3. Update `pubspec.yaml` and run `flutter pub upgrade`
4. For security advisories, check: https://github.com/advisories

**Recommended**: Enable Dependabot alerts in Settings → Security & analysis.

---

## Best Practices

### Before Every Release

1. ✅ Run `flutter analyze` locally
2. ✅ Run `flutter test` locally
3. ✅ Test on at least one physical device
4. ✅ Update version in `pubspec.yaml`
5. ✅ Update [CHANGELOG.md](CHANGELOG.md)

### For Testing Builds

Use pre-release versions: `v1.2.0-beta.1`, `v1.2.0-rc.1`
- Don't use these for production releases
- Tag pattern still matches and triggers builds

### Managing Artifact Storage

- Artifacts expire after 90 days (configurable in workflow)
- Public repos have unlimited storage
- Private repos have storage limits
- Delete old releases if needed

---

## Troubleshooting

### Workflow Fails on Analyze

```
Error: flutter analyze found issues
```

**Fix**: Run locally before pushing:
```bash
flutter analyze
flutter format lib/ test/
```

### Workflow Fails on Test

```
Error: Tests failed
```

**Fix**: Run tests locally:
```bash
flutter test
```

### Auto-Tag Not Created

```
Error: Tag already exists
```

**Check**:
- Version in `pubspec.yaml` must be incremented
- Tag must not already exist
- Verify you pushed to `main` branch

### Android APK Won't Install on Phone

```
Error: App not installed
```

**Fix**: 
1. Uninstall old version first
2. Enable "Install from Unknown Sources"
3. Check Android version compatibility (minSdkVersion in android/app/build.gradle)

### Release Not Created

**Check**:
- Tag must exist and match pattern: `v1.2.3`
- Android and iOS builds must complete successfully
- Check Actions tab for workflow status
- Verify workflow has `contents: write` permission

---

## Quick Reference

### Tag and Release (Most Common)
```bash
# Update version in pubspec.yaml first!
git add pubspec.yaml
git commit -m "chore: bump version to X.Y.Z"
git push origin main

git tag -a vX.Y.Z -m "Release X.Y.Z"
git push origin vX.Y.Z
```

### Delete a Tag (if mistake)
```bash
git tag -d v1.2.3
git push origin :refs/tags/v1.2.3
```

### View All Tags
```bash
git tag -l
```

### Check Workflow Status
```bash
# GitHub UI: Actions tab
# Or via CLI with GitHub CLI:
gh run list
gh run view
```