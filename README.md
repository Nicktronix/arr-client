# Arr Client

[![Flutter CI](https://github.com/Nicktronix/arr-client/actions/workflows/ci.yml/badge.svg)](https://github.com/Nicktronix/arr-client/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.38.5-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Desktop%20%7C%20Web-brightgreen)]()

Mobile-friendly Flutter application for managing your Sonarr and Radarr media servers. Provides a native mobile interface as an alternative to the web UI.

> **Note**: This is a third-party client and is not affiliated with Sonarr or Radarr.

## 📸 Screenshots

> **Coming Soon**: Screenshots will be added in a future update. The app features a Material Design 3 interface with dark/light theme support.

## ✨ Features

### Sonarr Integration
- Browse and search TV series library
- Add new series with quality profiles, root folders, and tags
- View series details with seasons and episodes
- Edit series settings (monitoring, quality profile, tags)
- Interactive search for specific episodes
- Manual season searches

### Radarr Integration
- Browse and search movie library
- Add new movies with quality profiles, root folders, and tags
- View movie details with file information
- Edit movie settings (monitoring, quality profile, minimum availability, tags)
- Interactive search for specific movies
- Manual movie searches

### Download Management
- Unified queue view for both Sonarr and Radarr downloads
- Real-time download progress tracking
- Interactive release search with filters and sorting
- Detailed release confirmation dialog with:
  - Quality, size, and seeders/leechers
  - Release group and protocol (Usenet/Torrent)
  - Languages and indexer information
  - Custom Format tags (displayed as chips)
  - Custom Format Score
  - Relative publish dates (e.g., "3mo ago")
  - Episode lists for series or edition info for movies
- Reject reason visibility for blocked releases

### Multi-Instance Support
- Manage multiple Sonarr and Radarr instances
- Switch between instances from settings
- Credentials stored in secure platform storage (Keychain/Keystore)
- Optional HTTP Basic Authentication for proxy-protected instances
- No configuration files needed

### User Experience
- Mobile-first responsive UI
- User-friendly error messages
- Settings screen for instance management
- Cross-platform support (Android, iOS, Linux, Windows, macOS, Web)

## Prerequisites

- **Flutter SDK**: Version 3.38.5 or higher
- **Dart**: Version 3.10.4 or higher (included with Flutter)
- **Sonarr**: v3 API with API key
- **Radarr**: v3 API with API key
- **Network Access**: Ability to reach your Sonarr/Radarr instances

## Configuration

The app uses a settings screen for all configuration (no environment files needed):

1. **Launch the app** - You'll see an empty state on first run
2. **Tap the settings icon** in the top-right corner
3. **Add Sonarr and/or Radarr instances**:
   - Instance name (e.g., "Home Sonarr")
   - Base URL (e.g., `https://sonarr.example.com`)
   - API Key from Settings → General → Security → API Key in Sonarr/Radarr
   - **Optional**: Enable "Use Basic Authentication" for proxy-protected instances
     - Username and password for HTTP Basic Auth
4. **Select active instance** using the radio button
5. **Credentials are automatically saved** to secure storage (platform keychain/keystore)

## Project Structure

```
lib/
├── config/
│   └── app_config.dart              # Environment/instance configuration
├── models/
│   └── service_instance.dart        # Instance data model
├── services/
│   ├── api_client.dart              # HTTP client with error handling
│   ├── app_state_manager.dart       # Centralized state management
│   ├── backup_service.dart          # Encrypted backup/restore
│   ├── biometric_service.dart       # Biometric authentication
│   ├── cache_manager.dart           # In-memory LRU cache
│   ├── instance_manager.dart        # Persistent instance storage
│   ├── sonarr_service.dart          # Sonarr API v3 wrapper
│   └── radarr_service.dart          # Radarr API v3 wrapper
├── screens/
│   ├── home_screen.dart             # Main UI with bottom navigation
│   ├── settings_screen.dart         # Instance management UI
│   ├── series_list_screen.dart      # Sonarr: Series library
│   ├── series_detail_screen.dart    # Sonarr: Series details & seasons
│   ├── series_search_screen.dart    # Sonarr: Add new series
│   ├── season_detail_screen.dart    # Sonarr: Season episodes
│   ├── movie_list_screen.dart       # Radarr: Movie library
│   ├── movie_detail_screen.dart     # Radarr: Movie details
│   ├── movie_search_screen.dart     # Radarr: Add new movies
│   ├── queue_screen.dart            # Combined download queue
│   └── release_search_screen.dart   # Unified release browser with detailed confirmation
├── utils/
│   ├── cached_data_loader.dart      # Mixin for consistent loading
│   └── error_formatter.dart         # User-friendly error messages
└── main.dart                        # App entry & initialization
```

## Setup Instructions

### 1. Install Dependencies

```bash
cd arr_client
flutter pub get
```

### 2. Run the Application

**Desktop (Linux/Windows/macOS)**:
```bash
flutter run -d linux    # or windows, macos
```

**Web**:
```bash
flutter run -d chrome
```

**Android** (requires Android Studio):
```bash
flutter run -d android
```

**iOS** (requires Xcode on macOS):
```bash
flutter run -d ios
```

### 4. Hot Reload During Development

When the app is running, press `r` to hot reload changes or `R` to hot restart.

## API Integration

### SonarrService Methods

**Library Management**:
- `getSeries()` - List all series
- `getSeriesById(id)` - Get series details
- `searchSeries(query)` - Search TVDB for series
- `addSeries(data)` - Add new series
- `updateSeries(data)` - Update series settings
- `deleteSeries(id)` - Remove series

**Season & Episode**:
- `getEpisodesBySeriesId(id)` - Get all episodes
- `getEpisode(id)` - Get episode details
- `searchEpisodeCommand(ids)` - Trigger episode search
- `searchSeasonCommand(seriesId, seasonNumber)` - Search season

**Release Management**:
- `searchEpisodeReleases(id)` - Get available releases
- `downloadRelease(guid, indexerId)` - Download release

**Configuration**:
- `getQualityProfiles()` - List quality profiles
- `getRootFolders()` - List root folders
- `getTags()` - List available tags

**Monitoring**:
- `getQueue()` - View download queue
- `getCalendar()` - Upcoming episodes

### RadarrService Methods

**Library Management**:
- `getMovies()` - List all movies
- `getMovieById(id)` - Get movie details
- `searchMovies(query)` - Search TMDB for movies
- `addMovie(data)` - Add new movie
- `updateMovie(data)` - Update movie settings
- `deleteMovie(id)` - Remove movie

**Release Management**:
- `searchMovieReleases(id)` - Get available releases
- `downloadRelease(guid, indexerId)` - Download release
- `searchMovieCommand(id)` - Trigger automatic search

**Configuration**:
- `getQualityProfiles()` - List quality profiles
- `getRootFolders()` - List root folders
- `getTags()` - List available tags

**Monitoring**:
- `getQueue()` - View download queue
- `getCalendar()` - Upcoming releases

## Development Workflow

1. **Make Changes**: Edit Dart files in `lib/`
2. **Hot Reload**: Press `r` in the terminal running Flutter
3. **Test**: Verify changes on your target platform
4. **Commit**: Use Git to track changes

## Troubleshooting

### No Instances Configured

If app shows empty state on launch:
- Tap settings icon (top-right)
- Add at least one Sonarr or Radarr instance
- Ensure instance is marked as active (radio button selected)

### Connection Errors

Common API error messages:
- **"Unauthorized"**: Invalid API key - check Settings → General → Security in Sonarr/Radarr
- **"Not found"**: Wrong base URL - ensure URL ends at domain (no `/api` path)
- **"Server error - please try again later"**: Service may be down or restarting
- **"Network error - please check your connection"**: Can't reach server - check firewall/network

### API Configuration Tips

- Base URL should be just the domain: `https://sonarr.example.com` (not `/api/v3`)
- Test URL in browser first - should show Sonarr/Radarr login page
- API keys are 32-character hex strings (no spaces)
- HTTPS required if using remote instances with valid certificates

### First Run

If the app shows empty screens on first launch:
- This is expected! No instances are configured yet
- Tap the settings icon (top-right) to add your first instance
- After adding an instance, return to the home screen to see your content

## Architecture

### Centralized State Management

The app uses a **three-tier centralized architecture** designed for performance, consistency, and maintainability:

#### Core Components

**1. AppStateManager** (`lib/services/app_state_manager.dart`)
- **Single source of truth** for all active instance state
- `ChangeNotifier` singleton pattern for reactive UI updates
- Automatically coordinates cache invalidation when users switch instances
- Key Methods:
  - `initialize()` - Load instances on app start
  - `reloadInstances()` - Refresh after settings changes
  - `getSonarrCache(key)` / `setRadarrCache(key, data)` - Instance-aware cache access
- **Integration Point**: All screens and services access instances through this manager

**2. CacheManager** (`lib/services/cache_manager.dart`)
- Singleton in-memory cache with time-based expiration
- **Instance-specific cache keys** - Each instance maintains isolated cache
- **5-minute validity period** with stale-while-revalidate pattern
- Key Methods:
  - `get(key)` / `set(key, data)` - Basic cache operations
  - `isValid(key)` - Check if cache is fresh
  - `isStale(key)` - Check if cache exists but expired
  - `clearInstance(instanceId)` - Invalidate all caches for an instance
- **Performance**: Instant data display with background refresh

**3. CachedDataLoader** (`lib/utils/cached_data_loader.dart`)
- **Mixin pattern** enforces consistent loading behavior across all data screens
- **Three-state pattern**: `loading` → `loaded` / `error` / `empty`
- Automatic cache checking with fallback to API
- Abstract methods screens must implement:
  - `fetchData()` - API call to retrieve data
  - `onDataLoaded(data)` - Handle successful data load
  - `cacheKey` - Unique identifier for this screen's cache
  - `isSonarrScreen` - Whether this is Sonarr or Radarr screen
- **Standard UI Builders**:
  - `buildBody()` - Routes to correct state widget
  - `buildLoadingIndicator()` - Customizable spinner
  - `buildErrorState()` - Error with retry button
  - `buildSuccessBody()` - Override for your UI

#### Data Flow

```
User Action → Screen with CachedDataLoader Mixin
    ↓
Check AppStateManager for active instance
    ↓
Check CacheManager for cached data
    ↓
If valid cache → Display instantly
If stale cache → Display while refreshing in background
If no cache → Show loading, fetch from API
    ↓
Store in CacheManager with instance-specific key
    ↓
Update UI via setState()
```

#### Instance Switching Flow

```
User switches instance in Settings
    ↓
SettingsScreen calls AppStateManager.reloadInstances()
    ↓
AppStateManager notifies all listeners (ChangeNotifier)
    ↓
HomeScreen listener rebuilds tabs with new instance
    ↓
All screens automatically use new instance's cache
    ↓
Services reset their API clients for new credentials
```

### Performance Optimizations

- ✅ **Instance-aware caching** - Each instance has completely isolated cache
- ✅ **Stale-while-revalidate** - Shows cached data instantly, refreshes in background
- ✅ **LRU Cache Eviction** - Automatic memory management with 100-entry limit
- ✅ **Tab state preservation** - IndexedStack keeps all tabs alive during navigation
- ✅ **Optimized image loading** - 2x resolution with progress indicators and error fallback
- ✅ **Smart refresh** - Pull-to-refresh and manual refresh bypass cache
- ✅ **Automatic cache invalidation** - Switching instances clears relevant caches
- ✅ **Connection pooling** - Reusable HTTP client for better network performance
- ✅ **HTTP timeouts** - 30-second timeout prevents hanging requests
- ✅ **Lazy API client initialization** - Services only create clients when needed
- ✅ **Single source of truth** - No duplicate state management or conflicting data
- ✅ **Fast metadata loading** - Settings screen bypasses secure storage for instant display
- ✅ **Optimistic UI updates** - Instant feedback before async operations complete
- ✅ **Background crypto operations** - PBKDF2/AES encryption runs in isolates for smooth UI

### Design Patterns

**Singleton Pattern**
- `AppStateManager`, `CacheManager`, `InstanceManager`
- Ensures single instance across entire app
- Prevents state duplication and memory waste

**Mixin Pattern**
- `CachedDataLoader` mixin enforces consistent behavior
- Reduces code duplication across 20+ screens
- Makes adding new screens trivial (< 50 lines)

**Observer Pattern**
- `ChangeNotifier` for reactive updates
- HomeScreen listens to AppStateManager
- UI automatically updates when instances change

**Strategy Pattern**
- Services encapsulate API communication logic
- Screens don't know about HTTP, JSON parsing, error codes
- Easy to swap implementations or add new services

## Best Practices for Development

### Adding a New Data Screen

All screens that load API data should use the `CachedDataLoader` mixin:

```dart
class NewScreen extends StatefulWidget {
  const NewScreen({super.key});
  @override
  State<NewScreen> createState() => _NewScreenState();
}

class _NewScreenState extends State<NewScreen> with CachedDataLoader {
  final SonarrService _sonarr = SonarrService();
  List<dynamic> _data = [];

  @override
  void initState() {
    super.initState();
    loadData(); // Provided by mixin
  }

  @override
  String get cacheKey => 'unique_cache_key'; // Must be unique!

  @override
  bool get isSonarrScreen => true; // or false for Radarr

  @override
  Future<dynamic> fetchData() async {
    return await _sonarr.getSomeData();
  }

  @override
  void onDataLoaded(dynamic data) {
    setState(() => _data = data);
  }

  @override
  Widget buildSuccessBody() {
    if (_data.isEmpty) {
      return Center(child: Text('No data available'));
    }
    
    return RefreshIndicator(
      onRefresh: () => loadData(forceRefresh: true),
      child: ListView.builder(
        itemCount: _data.length,
        itemBuilder: (context, index) {
          return ListTile(title: Text(_data[index]['title'] ?? 'Unknown'));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Screen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => loadData(forceRefresh: true),
          ),
        ],
      ),
      body: buildBody(), // Automatically handles loading/error/empty/success
    );
  }
}
```

### Modifying Instance Management

When adding features that change instances:

1. **Always call** `AppStateManager().reloadInstances()` after changes
2. **Never access** `InstanceManager` directly from screens
3. **Use** `AppStateManager().activeSonarrInstance` for current state
4. **Listen** to AppStateManager if your screen needs to react to changes

Example:
```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  final AppStateManager _appState = AppStateManager();

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onInstanceChanged);
  }

  @override
  void dispose() {
    _appState.removeListener(_onInstanceChanged);
    super.dispose();
  }

  void _onInstanceChanged() {
    setState(() {}); // Rebuild when instances change
  }
}
```

### Error Handling Guidelines

**Always use ErrorFormatter**:
```dart
try {
  final data = await _service.getData();
  // Process data
} catch (e) {
  setState(() => _error = ErrorFormatter.format(e));
  // Or for SnackBar:
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(ErrorFormatter.format(e))),
  );
}
```

### Avoiding Common Mistakes

❌ **DON'T**:
- Access `InstanceManager` directly from screens
- Implement manual loading states (use `CachedDataLoader`)
- Forget to handle empty states (different from errors)
- Use `setState()` after screen is disposed (mixin handles this)
- Create duplicate cache keys across screens
- Skip the `RefreshIndicator` on list views

✅ **DO**:
- Use `AppStateManager` as single source of truth
- Use `CachedDataLoader` mixin for all data screens
- Show empty states with helpful messages and CTAs
- Always check `mounted` before async `setState()` in manual code
- Use descriptive unique cache keys
- Add pull-to-refresh to all scrollable lists
- Handle null with `??` operators: `item['title'] ?? 'Unknown'`

## Known Limitations

- No queue item deletion/management
- No calendar view for upcoming content
- Release download requires manual selection (no "grab first" option)
- Detail screens don't use caching (always fetch fresh data)

## Future Enhancements

- [ ] Persistent disk caching for offline viewing
- [ ] Queue management (pause, delete items)
- [ ] Calendar view for upcoming episodes/movies
- [ ] Push notifications for completed downloads
- [ ] Dark/light theme toggle
- [ ] Bulk operations (delete multiple, mass edit)
- [ ] Statistics and dashboard
- [ ] Custom filters and saved searches

## Security

### Credential Storage

All credentials are stored securely using platform-specific secure storage:

- ✅ **API Keys**: Platform keychain/keystore (hardware-encrypted)
- ✅ **Basic Auth Credentials**: Same secure storage as API keys
- ✅ **Instance Metadata**: Only non-sensitive data (names, URLs) in SharedPreferences
- ✅ **Platform Security**:
  - **iOS**: Keychain (hardware-encrypted)
  - **Android**: Android Keystore with EncryptedSharedPreferences
  - **Web**: Web Cryptography API
  - **Desktop**: Platform-specific secure storage (Keychain/DPAPI/libsecret)

### Network Security

- ✅ **HTTPS Required**: Use HTTPS URLs for all production instances
- ✅ **Certificate Validation**: Flutter validates SSL/TLS certificates
- ✅ **Basic Auth Support**: Properly encoded HTTP Basic Authentication headers
- ✅ **API Key Transmission**: Sent in `X-Api-Key` header (not URL parameters)

### Biometric Authentication

Optional biometric protection available in Settings → Security tab:

- **App Launch Protection**: Require Face ID/Touch ID/Fingerprint to unlock app
- **Background Timeout**: Re-authenticate when returning from background (5 minute timeout)
- **Sensitive Operation Protection**: Automatic re-authentication required for:
  - Disabling biometric authentication
  - Viewing or editing instance credentials
  - Deleting instances
- **Platform Support**:
  - **iOS**: Face ID and Touch ID
  - **Android**: Fingerprint, Face Unlock, Iris
  - **Desktop/Web**: Not supported (biometric features hidden)

### Backup & Restore

Secure encrypted backup of all your instance configurations in Settings → Security tab:

- **Export**: Creates password-protected encrypted JSON file with all instances
  - Includes all Sonarr and Radarr instances
  - Contains API keys, Basic Auth credentials, URLs, and settings
  - Active instance selection is preserved
  - Uses **AES-256-GCM** authenticated encryption (prevents tampering)
  - **PBKDF2-HMAC-SHA256** key derivation with 600,000 iterations (OWASP 2023 standard)
- **Import**: Restore instances from backup file
  - Validates backup and password before importing
  - Shows preview of instances to be imported
  - Existing instances with same ID are overwritten
  - Creates new instances for unknown IDs
- **Use Cases**:
  - Testing from scratch - export before testing, import to restore
  - Moving to new device - export on old device, import on new one
  - Disaster recovery - keep encrypted backup of your configurations
  - Instance templates - share configurations between users (be careful with credentials!)
- **Security**:
  - **Password**: Minimum 12 characters required
  - **Encryption**: AES-256-GCM (authenticated encryption prevents tampering)
  - **Key Derivation**: PBKDF2-HMAC-SHA256 with 600,000 iterations (OWASP 2023 standard)
  - **Salt**: 128-bit cryptographically random salt (unique per backup)
  - **IV/Nonce**: 96-bit random nonce for GCM mode
  - **Authentication**: GCM provides built-in message authentication
  - **Performance**: All crypto operations run in isolates (background threads) for responsive UI
  - **Backward Compatible**: Can still import v1 backups (CBC mode)
  - **No password recovery** - if you forget it, backup cannot be restored
  - **Store backup files securely** - they contain encrypted credentials

**Security Standards Compliance**:
- ✅ **OWASP 2023**: Meets password hashing recommendations (600k PBKDF2 iterations)
- ✅ **NIST SP 800-38D**: AES-GCM authenticated encryption
- ✅ **NIST SP 800-132**: PBKDF2 key derivation with proper salt and iterations
- ✅ **Industry Best Practice**: Authenticated encryption prevents tampering attacks

### Security Audit Results (December 2025)

**Comprehensive security review completed** with following findings:

**🔒 Credential Protection**:
- ✅ Platform keychain/keystore with hardware encryption
- ✅ API keys stored separately from metadata
- ✅ Credentials sanitized from all error messages
- ✅ No logging of sensitive data anywhere in codebase

**🌐 Network Security**:
- ✅ HTTP client with 30-second timeout
- ✅ Connection pooling for performance
- ✅ SSL/TLS certificate validation (Flutter default)
- ✅ HTTPS warnings for non-localhost HTTP URLs
- ✅ API keys sent in headers (not URL parameters)
- ✅ Proper Basic Auth encoding

**💾 Memory Management**:
- ✅ LRU cache eviction prevents memory leaks
- ✅ 100-entry cache limit with automatic cleanup
- ✅ Stale entry removal (5-minute validity)
- ✅ Access frequency tracking for intelligent eviction

**🛡️ Input Sanitization**:
- ✅ URL credential sanitization in error messages
- ✅ API key redaction from logs
- ✅ Bearer/Basic token removal from errors
- ✅ All user inputs validated and trimmed

**🔐 Authentication**:
- ✅ Biometric authentication with platform APIs
- ✅ Re-authentication for sensitive operations
- ✅ Configurable timeout (5 minutes default)
- ✅ Secure session management

**📦 Backup Encryption**:
- ✅ AES-256-GCM authenticated encryption
- ✅ 600,000 PBKDF2 iterations (OWASP 2023)
- ✅ Cryptographically random salt (128-bit)
- ✅ 12-character minimum password

**Zero Critical Vulnerabilities Found**

### Best Practices

1. **Always use HTTPS** for remote instances (required for security)
2. **Rotate API keys** periodically from Sonarr/Radarr settings
3. **Use Basic Auth** only when required by your proxy setup
4. **Test locally first** before adding remote instances
5. **Review permissions** - API keys have full admin access to your *arr services
6. **Delete unused instances** - removes credentials from secure storage

## Future Improvements

### Security & UX Enhancements

**Completed**:
- ✅ **HTTPS Warning**: Display warning dialog when user enters `http://` URL for remote instances
- ✅ **Connection Test**: Add "Test Connection" button in instance form to verify credentials before saving
- ✅ **Biometric Authentication**: Optional Face ID/Touch ID/fingerprint lock for app access with timeout toggle
- ✅ **Export/Import Instances**: Password-protected encrypted backup and restore of all instance configurations
- ✅ **Isolate-Based Encryption**: All crypto operations run in background threads for responsive UI

**Medium Priority**:
- [ ] **Certificate Pinning**: For enterprise deployments (optional - overkill for personal use)

**Low Priority**:
- [ ] **Audit Log**: Track instance additions, deletions, and configuration changes
- [ ] **Custom Certificate Support**: Allow self-signed certificates for local instances

### Feature Enhancements

**High Priority** (Core Functionality):
- [ ] **History/Activity Log**: View recent downloads, imports, and failed actions
- [ ] **Queue Management**: Pause, remove, or re-prioritize downloads
- [ ] **Wanted/Missing Episodes**: List monitored but missing episodes with bulk search
- [ ] **Cutoff Unmet**: Show items that don't meet quality cutoff with upgrade search
- [ ] **Manual Import**: Import files from filesystem with quality/episode matching
- [ ] **File Management**: Delete, rename, or relocate existing media files
- [ ] **Blocklist Management**: View and remove blocked releases

**Medium Priority** (User Experience):
- [ ] **Calendar View**: Upcoming episodes/movies with date filtering
- [ ] **Grid View Option**: Poster grid layout alternative to list view
- [ ] **System Status**: Health checks, disk space, indexer status
- [ ] **Quick Actions**: Search all missing, update library, refresh all series/movies
- [ ] **Dark/Light Theme**: User-selectable theme with system default
- [ ] **Saved Search Presets**: Save and restore custom filter combinations
- [ ] **Statistics Dashboard**: Library size, storage usage, download trends

**Low Priority** (Nice to Have):
- [ ] **Persistent Disk Cache**: Full offline viewing support (images already cached in memory)
- [ ] **Bulk Operations**: Select multiple items for delete/edit/monitor changes
- [ ] **Push Notifications**: Alerts for completed downloads and errors
- [ ] **Indexer Management**: Add, edit, test indexers
- [ ] **Download Client Management**: Configure download clients
- [ ] **Quality Profile Editor**: Create and modify quality profiles in-app
- [ ] **Tag Management**: Create and delete tags within app

## Resources

- [🤝 Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting a PR.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed development guidelines.

## 📋 Code of Conduct

Please read our [Code of Conduct](CODE_OF_CONDUCT.md) to understand the community expectations.

## 🔒 Security

For security vulnerabilities, please see our [Security Policy](SECURITY.md) for responsible disclosure.

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes in each version.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**TL;DR**: You can use, modify, and distribute this code freely. Just keep the copyright notice.

## ⭐ Support

If you find this project helpful, please consider:
- Starring this repository
- Reporting bugs and suggesting features
- Contributing code improvements
- Sharing with others who might find it useful

## 🙏 Acknowledgments

- [Sonarr](https://sonarr.tv/) - TV series management
- [Radarr](https://radarr.video/) - Movie management
- [Flutter](https://flutter.dev/) - Cross-platform framework
- All contributors and users of this project

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**TL;DR**: You can use, modify, and distribute this code freely. Just keep the copyright notice.
