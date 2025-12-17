# Contributing to Arr Client

Thank you for considering contributing to Arr Client! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before contributing.

## How Can I Contribute?

### Reporting Bugs

Before creating a bug report, please check the existing issues to avoid duplicates. When creating a bug report, include:

- **Clear title and description** of the issue
- **Steps to reproduce** the problem
- **Expected behavior** vs actual behavior
- **Screenshots** if applicable
- **Environment details**:
  - App version
  - Platform (Android/iOS)
  - OS version
  - Sonarr/Radarr version
- **Error messages or logs** (redact sensitive information)

### Suggesting Features

Feature suggestions are welcome! Please:

- Check existing issues/discussions first
- Clearly describe the use case and benefit
- Explain how it fits with existing functionality
- Provide mockups or examples if possible

### Pull Requests

#### Before You Start

1. **Check existing issues/PRs** to avoid duplicate work
2. **Discuss significant changes** by opening an issue first
3. **Fork the repository** and create a feature branch
4. **Follow the existing code style** and architecture patterns

#### Development Workflow

1. **Clone and setup**:
   ```bash
   git clone https://github.com/Nicktronix/arr-client.git
   cd arr-client
   flutter pub get
   ```

2. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes** following the coding standards below

4. **Test your changes**:
   ```bash
   flutter test                    # Run all tests
   flutter analyze                 # Check for issues
   dart format .                   # Auto-format code
   flutter run -d <device>         # Test on real device
   ```

5. **Commit with meaningful messages**:
   ```bash
   git commit -m "feat: add movie poster grid view"
   ```
   
   Use conventional commit format:
   - `feat:` - New features
   - `fix:` - Bug fixes
   - `docs:` - Documentation changes
   - `test:` - Test additions/changes
   - `refactor:` - Code restructuring
   - `chore:` - Build/config changes
   - `style:` - Code formatting

6. **Push and create a PR**:
   ```bash
   git push origin feature/your-feature-name
   ```

#### PR Requirements

Before submitting, ensure:

- ✅ Code follows the project's architecture patterns (see `.github/copilot-instructions.md`)
- ✅ All tests pass (`flutter test`)
- ✅ No analyzer warnings (`flutter analyze`)
- ✅ Code is properly formatted (`dart format .`)
- ✅ New features have tests
- ✅ Documentation is updated if needed
- ✅ No secrets or personal data committed
- ✅ PR description clearly explains the changes

## Coding Standards

### Architecture Patterns

This project follows specific architectural patterns. **Please read** [.github/copilot-instructions.md](.github/copilot-instructions.md) for:

- Centralized state management pattern
- CachedDataLoader mixin usage
- Service layer conventions
- UI patterns and three-state loading
- Security best practices

### Key Conventions

**File Organization**:
- One main widget per file
- Related helpers in the same file
- No barrel exports - use direct imports
- Use absolute imports from `lib/`

**Naming Standards**:
- Classes: `PascalCase` (e.g., `SeriesListScreen`)
- Files: `snake_case.dart` (e.g., `series_list_screen.dart`)
- Private members: `_prefixed` (e.g., `_isLoading`)
- Services: `ServiceNameService` (e.g., `SonarrService`)
- Screens: `FeatureNameScreen` (StatefulWidget)
- State: `_FeatureNameScreenState` (private)

**State Management**:
- Use simple `setState()` - no state management libraries
- All data screens use `CachedDataLoader` mixin
- Services are singletons listening to `AppStateManager`
- Never access `InstanceManager` directly from screens

**Data Handling**:
- No typed models except `ServiceInstance`
- Use `Map<String, dynamic>` and `List<dynamic>` for API responses
- Always check for null: `data['field'] ?? 'default'`
- Check lists before access: `(data['list'] as List?)?.length ?? 0`

**Error Handling**:
- Always use `ErrorFormatter.format(e)` for user-facing messages
- Provide retry buttons on error states
- Show empty states with clear CTAs
- Test error scenarios during development

**UI Patterns**:
- Three-state pattern: loading → loaded/error/empty
- Include pull-to-refresh on list screens
- Empty state ≠ error state (different icons and messages)
- Always check `mounted` before `setState()` after async operations

### Writing Tests

**Test Organization**:
```dart
group('ComponentName Tests', () {
  setUp(() async {
    // Setup code
  });

  test('specific behavior description', () {
    // Arrange
    // Act
    // Assert
  });
});
```

**What to Test**:
- Widget rendering and state transitions
- Data model serialization
- Utility functions
- Error handling and formatting
- Navigation flows
- Empty/error states

**Before Committing**:
```bash
flutter test                    # All tests must pass
flutter test --coverage        # Generate coverage report
flutter analyze                 # Zero issues required
dart format .                   # Auto-format all code
```

## Project Structure

```
lib/
├── config/          # Configuration (app_config.dart)
├── models/          # Data models (only ServiceInstance)
├── services/        # API clients, state management, storage
├── screens/         # UI screens
├── utils/           # Utilities (error formatting, cached loader)
└── main.dart        # App entry point

test/
└── widget_test.dart # All tests

.github/
├── workflows/       # CI/CD workflows
├── ISSUE_TEMPLATE/  # Issue templates
└── PULL_REQUEST_TEMPLATE.md
```

## Security Considerations

**Never commit**:
- API keys, tokens, or passwords
- Personal data or real instance URLs
- SSH keys or certificates
- Backup encryption passwords

**Secure storage**:
- Use `flutter_secure_storage` for credentials
- Store metadata in `shared_preferences`
- Use `ErrorFormatter` to sanitize error messages

**Review checklist**:
- [ ] No hardcoded credentials
- [ ] Error messages don't leak sensitive data
- [ ] API keys properly secured
- [ ] HTTPS enforced for remote instances

## Getting Help

- **Questions**: Open a [Discussion](../../discussions)
- **Bugs**: Open an [Issue](../../issues)
- **Security Issues**: See [SECURITY.md](SECURITY.md)

## Recognition

Contributors are recognized in:
- Git commit history
- GitHub contributor graph
- Release notes (for significant contributions)

Thank you for contributing to Arr Client! 🎉
