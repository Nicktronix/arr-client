# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Episode detail screen** with comprehensive information
  - Full episode metadata (title, overview, air date, runtime)
  - Status badges (Downloaded/Missing/Upcoming, Monitored/Unmonitored)
  - File information with quality, size, and custom formats
  - Custom format chips with visual tags
  - Media information grid (video codec, resolution, audio channels, etc.)
  - Release group and language information
  - File path display
  - Tap episode cards in season view to drill down into details
- **Enhanced movie detail screen**
  - Comprehensive file information display
  - Custom format chips with CF score color coding
  - Media information grid
  - Release group, languages, and date added
  - File path display with monospace font
- **Monitoring toggles** for episodes and movies
  - Instant UI feedback with optimistic updates
  - Automatic rollback on API errors
  - Visual icons (eye/eye-off) in app bar
- **File deletion** capabilities
  - Delete episode files with confirmation dialog
  - Delete movie files with confirmation dialog
  - Automatic detail refresh after deletion
- **Enhanced action menus** in detail screens
  - PopupMenuButton pattern for organized actions
  - Conditional menu items based on file status
  - Color-coded destructive actions (red delete buttons)
  - Automatic/interactive search options

### Changed
- Season detail screen episode cards now tappable for navigation to episode details
- Movie detail screen uses PopupMenuButton for actions (replaces action section)
- API client now supports custom timeout parameter for slow endpoints
- Release searches use extended 60-second timeout (improved for slow indexers)

### Improved
- **Code quality and maintainability**
  - Added input validation to service methods (ID checks)
  - Refactored InstanceManager with generic methods to reduce duplication
  - Improved error message sanitization in API client
  - Enhanced cache overflow protection with debug logging
  - Safer iteration patterns (replaced `.firstWhere()` with for loops)
- **Service layer enhancements**
  - `SonarrService.updateEpisode()` - Full object fetch/merge pattern
  - `SonarrService.deleteEpisodeFile()` - Delete episode files
  - `SonarrService.searchEpisode()` - Trigger automatic episode search
  - `RadarrService.deleteMovieFile()` - Delete movie files
  - Extended timeout support in API methods

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

- **[Unreleased]** - Development branch (not yet released)
- **[1.0.0]** - 2025-12-17 - Initial Public Release

<!-- Link Definitions -->
[Unreleased]: https://github.com/Nicktronix/arr-client/compare/v1.0.0...develop
[1.0.0]: https://github.com/Nicktronix/arr-client/releases/tag/v1.0.0
