# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-17

### Added
- **Initial Public Release** 🎉
- Sonarr v3 API integration
  - Browse and search series library
  - Add new series with quality profiles, root folders, and tags
  - View series details with seasons and episodes
  - Edit series settings (monitoring, quality, tags)
  - Interactive episode and season search
- Radarr v3 API integration
  - Browse and search movie library
  - Add new movies with quality profiles, root folders, and tags
  - View movie details with file information
  - Edit movie settings (monitoring, quality, minimum availability, tags)
  - Interactive movie search
- Unified download queue
  - Real-time progress tracking for both Sonarr and Radarr
  - Combined view of all active downloads
- Release search and management
  - Detailed release information dialog
  - Custom format tags displayed as chips
  - Quality, size, seeders, and indexer information
  - Rejection reason visibility
  - One-tap download with confirmation
- Multi-instance support
  - Manage multiple Sonarr and Radarr instances
  - Switch between instances from settings
  - Independent configuration per instance
- Security features
  - Encrypted credential storage (Keychain/Keystore)
  - HTTP Basic Authentication support
  - Biometric app lock (Face ID/Touch ID/Fingerprint)
  - Encrypted backup and restore
  - AES-256-GCM encryption with PBKDF2 (600k iterations)
- Performance optimizations
  - Instance-aware in-memory caching (5-minute validity)
  - Stale-while-revalidate pattern
  - Pull-to-refresh on all list screens
  - Lazy API client initialization
  - Background crypto operations in isolates
- Cross-platform support
  - Android (5.0+)
  - iOS (12.0+)
  - Linux
  - Windows
  - macOS
  - Web
- Developer experience
  - Comprehensive test suite (21 tests)
  - CI/CD pipeline with GitLab CI
  - Code analysis and formatting checks
  - Coverage reporting
  - Security scanning

### Technical Details
- Flutter SDK 3.38.5
- Dart 3.10.4
- Material Design 3
- No external state management libraries
- Centralized architecture with AppStateManager
- CachedDataLoader mixin pattern for consistent UX

---

## Release Notes Format

Each version should document:

### Added
New features, capabilities, or additions to the app.

### Changed
Changes to existing functionality or behavior.

### Deprecated
Features that will be removed in upcoming releases.

### Removed
Features that have been removed.

### Fixed
Bug fixes and corrections.

### Security
Security vulnerability fixes and improvements.

---

## Version History

- **[1.0.0]** - 2025-12-17 - Initial Public Release

<!-- Link Definitions -->
[1.0.0]: https://github.com/Nicktronix/arr-client/releases/tag/v1.0.0
