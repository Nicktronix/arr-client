# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-04-19

### Added
- **Queue screen enhancements**
  - Warning message banners for downloads with issues (import failures, etc.)
  - Tap-to-import navigation for downloads with warning/error status
  - Custom format display with visual chips
  - Extended metadata display (download client, indexer, languages, CF score, age)
  - Season-level episode info fallback for better display
- **Manual import screen** (dedicated full-screen workflow)
  - Navigation from queue items with import issues
  - Three-state loading pattern (loading → error/empty → success)
  - Context banner showing queue item title and selection count
  - Alphabetical file sorting by relative path (case-insensitive)
  - File list with expandable cards showing all metadata
  - All files pre-selected by default (user decides what to import)
  - Select all/deselect all toggle checkbox in bottom bar
  - Visual indicators for matched vs unmatched files
  - Rejection reasons shown as informational warnings (can be overridden)
  - Custom format chips with compact styling
  - Full edit dialog for overriding matches (series/movie search, season, episodes, quality, release group, languages)
  - Bottom action bar with toggle selection and import buttons
  - Dual-service support (Sonarr and Radarr)
  - Progress feedback during import operation
  - Automatic queue refresh after successful import
- **Episode detail screen** with comprehensive information
  - Full episode metadata (title, overview, air date, runtime)
  - Status badges (Downloaded/Missing/Upcoming, Monitored/Unmonitored)
  - File information with quality, size, and custom formats
  - Media information grid (video codec, resolution, audio channels, etc.)
  - Release group and language information
  - File path display
  - Tap episode cards in season view to drill down
- **Enhanced movie detail screen**
  - Comprehensive file information with custom format chips and CF score color coding
  - Media information grid
  - Release group, languages, and date added
  - File path display with monospace font
- **Monitoring toggles** for episodes and movies
  - Instant UI feedback with optimistic updates and automatic rollback on API errors
- **File deletion** for episodes and movies with confirmation dialogs
- **Stale data indicator** — visible badge when background refresh fails while cached data is shown
- **Configurable biometric re-auth timeout** — user-adjustable in settings (was hardcoded at 5 minutes)

### Changed
- **Service layer**: new methods for manual import, quality profile schema, episode monitoring, file deletion
- **Queue screen**: Wrap layout for metadata, enhanced status chip logic, improved time remaining display
- **AppStateManager** is now the single mutation point for all instance CRUD — no direct InstanceManager calls from screens

### Fixed
- Calendar and series list screens: runtime crash `List<dynamic> is not a subtype of num?` — `SeasonStatistics.releaseGroups` was typed `double?` (spec: `List<String>`), `SeasonResource.images` was typed `String?` (spec: `List<MediaCover>`)
- API client: `on ApiException { rethrow }` guard prevents double-wrapping of HTTP errors
- Sonarr/Radarr `PUT /series/{id}` and `PUT /movie/{id}` — ID now correctly included in URL
- Episode monitoring uses `PUT /episode/monitor` — no longer fetches full episode to toggle a boolean
- Manual import uses `POST /command` with `ManualImport` — not the candidate-only `POST /manualimport` endpoint
- Queue page size explicitly set to 500 — was silently truncating to 10
- Service client resets on any AppStateManager notification including credential edits
- URL credential sanitization regex tightened
- Mounted guard checks before all `setState` calls after async operations

### Security
- Replaced `encrypt` + `pointycastle` (last updated 2023, pulls in discontinued `js` package) with `cryptography 2.9.0` (pure Dart, actively maintained)
- Backup crypto migrated to async PBKDF2 + AES-256-GCM APIs — v1 AES-CBC legacy import preserved
- Biometric re-auth timeout now configurable — previously could not be reduced below 5 minutes

### Technical
- Dependency injection with `get_it` + `injectable` — services no longer manually constructed singletons
- API response models migrated from `Map<String, dynamic>` to `freezed` + `json_serializable` typed models
- `very_good_analysis` strict lint rules enforced — all warnings treated as errors
- Test suite expanded from 21 to 137 tests (unit + widget)
- CI: 10% line coverage threshold enforced — build fails below baseline
- CI: `google/osv-scanner` replaces `flutter pub outdated` — scans `pubspec.lock` against OSV vulnerability database
- CI: Flutter bumped to 3.41.2 (Dart 3.11.4)
- Dependencies updated: `file_picker 11.x`, `mocktail 1.0.5`, `cupertino_icons 1.0.9`
- Branch protection on `develop`: all 3 CI jobs required before merge

## [1.0.0] - 2025-12-17

### Added
- **Initial Public Release**
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
  - Comprehensive test suite
  - CI/CD pipeline with GitHub Actions
  - Code analysis and formatting checks
  - Coverage reporting
  - Security scanning

### Technical Details
- Flutter SDK 3.38.5 / Dart 3.10.4
- Material Design 3
- Centralized architecture with AppStateManager
- CachedDataLoader mixin pattern for consistent UX

---

## Version History

- **[1.1.0]** - 2026-04-19 - Queue enhancements, manual import, episode/movie detail, DI, typed models, OSV security scanning
- **[1.0.0]** - 2025-12-17 - Initial Public Release

<!-- Link Definitions -->
[Unreleased]: https://github.com/Nicktronix/arr-client/compare/v1.1.0...develop
[1.1.0]: https://github.com/Nicktronix/arr-client/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Nicktronix/arr-client/releases/tag/v1.0.0
