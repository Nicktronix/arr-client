# Development Workflows

Quick reference for common development tasks.
See `RELEASE.md` for the full release process and `CLAUDE.md` for architecture.

---

## Daily development

```bash
flutter devices                         # list available devices
flutter run -d <device-id>             # run on specific device
flutter run -d windows                  # desktop (fastest iteration)
flutter run -d chrome                   # web
# Hot reload: r | Hot restart: R
```

## Before every commit

```bash
flutter test                            # must pass
flutter analyze                         # zero issues
dart format .                           # auto-format
```

## Adding a new feature

1. Add service method to `sonarr_service.dart` or `radarr_service.dart` if needed
2. Create screen in `lib/screens/` using CachedDataLoader mixin (see `architecture.md`)
3. Add navigation via `Navigator.push` + `MaterialPageRoute`
4. Write widget tests for the new screen
5. Test loading, error, and empty states
6. Add pull-to-refresh if showing a list

## Running tests

```bash
flutter test                            # all tests (137)
flutter test --coverage                 # with coverage report
flutter test test/unit/                 # unit tests only
flutter test test/widget_test.dart      # widget tests only
```

## Checking security

```bash
flutter pub upgrade --dry-run           # preview upgrades
# Vulnerability scanning runs automatically in CI via google/osv-scanner
# against pubspec.lock — no local tool needed
```

## Instance switching — test checklist

- [ ] Switching instances shows loading instantly (no delay)
- [ ] New instance data loads correctly after switch
- [ ] Active instance name updates in AppBar
- [ ] Test with both Sonarr and Radarr instances
- [ ] Test with multiple instances configured
- [ ] Test backup/restore with encryption

## Testing error states

Temporarily throw in a service method to verify error UI:
```dart
Future<List<dynamic>> getSeries() async {
  throw Exception('Test error');  // remove after testing
  ...
}
```

## Branch workflow

```bash
git checkout develop && git pull
git checkout -b feature/my-feature   # or fix/, chore/, optimize/
# ... make changes ...
flutter test && flutter analyze
dart format .
git add <files>
git commit -m "feat: short description of change"
git push origin feature/my-feature
# Open PR to develop via /pr command
```

See `.claude/context/branching-strategy.md` for the full branch model.
