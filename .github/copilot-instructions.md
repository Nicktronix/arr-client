# Arr Client - AI Agent Instructions

## Documentation Policy

**Principle: Code Over Documentation Files**
- **README.md**: Primary documentation (overview, setup, features, troubleshooting)
- **RELEASE.md**: GitHub Actions workflow and release process guide
- **.github/copilot-instructions.md**: This file - architecture and development patterns

**DO NOT CREATE**:
- DEPLOYMENT_SUMMARY.md, SETUP_GUIDE.md, ARCHITECTURE_DOC.md, or similar files
- Separate files for every feature or change
- Documentation that duplicates what's already here

**When User Asks for Help**:
- Provide clear instructions **in chat response**
- Update README.md only if it's core user-facing documentation
- Update this file only for new architectural patterns or critical workflow changes

**Documentation Maintenance**:
- Keep README concise and user-focused (setup, features, usage)
- Keep this file focused on development patterns and architecture
- Remove outdated information when refactoring
- Prefer inline code comments for complex logic over external docs

## Architecture Overview

### Centralized State Management Pattern
The app uses a **centralized architecture** with three core components:

**1. AppStateManager** (`lib/services/app_state_manager.dart`)
- **Single source of truth** for active instances
- `ChangeNotifier` singleton that broadcasts instance changes
- Coordinates cache invalidation when instances switch
- Methods: `initialize()`, `reloadInstances()`, `getSonarrCache()`, `setRadarrCache()`
- Automatically manages instance-specific cache keys

**2. CacheManager** (`lib/services/cache_manager.dart`)
- Singleton for global memory cache
- Instance-aware cache keys (e.g., `series_list_instance123`)
- 5-minute validity with stale-while-revalidate pattern
- Methods: `get()`, `set()`, `isValid()`, `isStale()`, `clearInstance()`

**3. CachedDataLoader** (`lib/utils/cached_data_loader.dart`)
- **Mixin** for consistent loading behavior across all data screens
- Standard 3-state pattern: loading → loaded/error/empty
- Automatic cache checking and background refresh
- Abstract methods: `fetchData()`, `onDataLoaded()`, `cacheKey`, `isSonarrScreen`

### Service Layer Pattern
All API communication goes through **singleton service classes** (`SonarrService`, `RadarrService`) that:
- Listen to `AppStateManager` for instance changes
- **Automatically reset** their API client when instance ID changes
- Lazily initialize `ApiClient` instances on first use

```dart
class SonarrService {
  static final SonarrService _instance = SonarrService._internal();
  factory SonarrService() => _instance;
  SonarrService._internal() {
    AppStateManager().addListener(_onInstanceChanged);
  }

  ApiClient? _client;
  String? _currentInstanceId;

  void _onInstanceChanged() {
    final newInstanceId = AppConfig.activeSonarrInstanceId;
    if (_currentInstanceId != newInstanceId) {
      reset();  // Clear stale client
      _currentInstanceId = newInstanceId;
    }
  }

  Future<ApiClient> get _api async {
    if (_client == null) {
      final baseUrl = AppConfig.sonarrBaseUrl;
      final apiKey = AppConfig.sonarrApiKey;
      _client = ApiClient(baseUrl: baseUrl, apiKey: apiKey, ...);
      _currentInstanceId = AppConfig.activeSonarrInstanceId;
    }
    return _client!;
  }

  void reset() => _client = null;
}
```

**Critical**: Services auto-detect instance changes and reset themselves - no manual coordination needed.

### Multi-Instance Management
- `InstanceManager` singleton handles persistent storage (secure + SharedPreferences)
- `AppStateManager` wraps InstanceManager as the app-wide interface
- **Credentials** (API keys, passwords): `flutter_secure_storage` with platform encryption
- **Metadata** (names, URLs): `shared_preferences` (non-sensitive only)
- Active instance selected by ID via radio buttons in settings
- `AppConfig` provides synchronous getters that delegate to AppStateManager

### Data Flow & No Models Pattern
**Critical Difference**: No typed data models - API responses use raw `Map<String, dynamic>` and `List<dynamic>` throughout.

**Only Exception**: `ServiceInstance` model for credential management.

```dart
// Typical data access pattern
final series = await _sonarr.getSeries();  // Returns List<dynamic>
for (var show in series) {
  final title = show['title'] ?? 'Unknown';  // Direct map access
  final monitored = show['monitored'] ?? false;
}
```

## UI Patterns

### CachedDataLoader Mixin Pattern
**All data-loading screens use the CachedDataLoader mixin** for consistent behavior:

```dart
class ScreenName extends StatefulWidget { ... }

class _ScreenNameState extends State<ScreenName> with CachedDataLoader {
  final SonarrService _sonarr = SonarrService();
  List<dynamic> _data = [];

  @override
  void initState() {
    super.initState();
    loadData(); // Provided by mixin
  }

  @override
  String get cacheKey => 'screen_cache_key';

  @override
  bool get isSonarrScreen => true; // or false for Radarr

  @override
  Future<dynamic> fetchData() async {
    return await _sonarr.getData();
  }

  @override
  void onDataLoaded(dynamic data) {
    setState(() => _data = data);
  }

  @override
  Widget buildSuccessBody() {
    if (_data.isEmpty) {
      return Center(child: Text('No data'));
    }
    
    return RefreshIndicator(
      onRefresh: () => loadData(forceRefresh: true),
      child: ListView.builder(...),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Screen Title'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => loadData(forceRefresh: true),
          ),
        ],
      ),
      body: buildBody(), // Handles all 3 states automatically
    );
  }
}
```

**Mixin provides**:
- `loadData({forceRefresh})` - Automatic cache checking and API calls
- `setLoadingState()` - Manually trigger loading state for instant feedback
- `buildBody()` - Returns loading/error/empty/success widgets
- `buildLoadingIndicator()` - Customizable loading UI
- `buildErrorState()` - Error with retry button
- `buildEmptyState()` - Empty state message
- `buildSuccessBody()` - Override for your data UI

**Instant Loading Pattern** (for dropdowns/switches):
```dart
onChanged: (value) async {
  Navigator.pop(context);
  setLoadingState();  // Show loading instantly (no delay)
  await appState.switchSonarrInstance(value);
}
```

### Legacy Three-State Screen Pattern (For Non-Data Screens)
**Search/detail screens without caching** follow manual pattern (see `lib/screens/series_search_screen.dart`):

```dart
class ScreenName extends StatefulWidget { ... }

class _ScreenNameState extends State<ScreenName> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _data = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Widget _buildBody() {
    // State 1: Loading
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      );
    }
    
    // State 2: Error
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Error message', style: ...),
            Text(_error!),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,  // Retry button always present
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    // State 3: Success with pull-to-refresh
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(...),
    );
  }
}
```

### Empty State Pattern
When data is empty (not error), show icon + descriptive message + CTA:

```dart
if (_series.isEmpty) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.tv_off, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text('No series found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text('Add some series in Sonarr to see them here'),
      ],
    ),
  );
}
```

### Consistent Screen Structure
```dart
Scaffold(
  appBar: AppBar(
    title: Text('Screen Title'),
    actions: [
      IconButton(icon: Icon(Icons.refresh), onPressed: _loadData),
      IconButton(icon: Icon(Icons.settings), onPressed: _openSettings),
    ],
  ),
  body: _buildBody(),  // Contains 3-state logic
  floatingActionButton: FloatingActionButton(...),  // Optional
)
```

### Release Confirmation Dialog Pattern
**Unified dialog for both series and movies** (`release_search_screen.dart`):

```dart
Future<void> _showReleaseDetails(Map<String, dynamic> release) async {
  // Extract all fields from release map
  final String title = release['title'] ?? 'Unknown';
  final String quality = release['quality']?['quality']?['name'] ?? 'Unknown';
  final String? releaseGroup = release['releaseGroup'];
  final String? protocol = release['protocol'];
  final List<dynamic>? languages = release['languages'];
  final List<dynamic>? customFormats = release['customFormats'];
  final String? publishDate = release['publishDate'];
  
  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Download Release'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            
            // Common fields (shown for both series and movies)
            _buildDetailRow('Quality', quality),
            if (releaseGroup != null && releaseGroup.isNotEmpty)
              _buildDetailRow('Release Group', releaseGroup),
            _buildDetailRow('Size', _formatBytes(size)),
            if (protocol != null)
              _buildDetailRow('Protocol', protocol.toUpperCase()),
            if (languages != null && languages.isNotEmpty)
              _buildDetailRow('Languages', languages.map((l) => l['name'] ?? 'Unknown').join(', ')),
            _buildDetailRow('Indexer', indexer),
            _buildDetailRow('Seeders', '$seeders'),
            _buildDetailRow('Leechers', '$leechers'),
            _buildDetailRow('Age', '$age days'),
            if (publishDate != null)
              _buildDetailRow('Published', _formatPublishDate(publishDate)),
            
            // Custom formats section with chips
            if (customFormats != null && customFormats.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Custom Formats:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var format in customFormats)
                    Chip(
                      label: Text(format['name'] ?? 'Unknown', style: TextStyle(fontSize: 11)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            _buildDetailRow('CF Score', '$cfScore'),
            
            // Type-specific fields
            if (!_isMovie && release['mappedEpisodeInfo'] != null) ...[
              // Episode list for series
            ],
            if (_isMovie && edition != null && edition.isNotEmpty)
              _buildDetailRow('Edition', edition),
            
            // Rejections section if present
            if (isRejected) ...[
              // Show rejection reasons
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('Download')),
      ],
    ),
  );
}

// Helper for date formatting
String _formatPublishDate(String publishDate) {
  final date = DateTime.parse(publishDate);
  final diff = DateTime.now().difference(date);
  
  if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
  if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
  if (diff.inDays > 0) return '${diff.inDays}d ago';
  if (diff.inHours > 0) return '${diff.inHours}h ago';
  return '${diff.inMinutes}m ago';
}
```

**Field Organization**:
1. **Common fields** (both series & movies): Quality, Release Group, Size, Protocol, Languages, Indexer, Seeders/Leechers, Age, Published Date, Custom Formats, CF Score
2. **Series-specific**: Episodes list, Full Season Pack indicator
3. **Movie-specific**: Edition field
4. **Rejections**: Shown at bottom if present

**Key Features**:
- Single unified dialog handles both content types via `_isMovie` flag
- Chips display custom formats as visual tags with compact density
- Relative time formatting for publish dates (e.g., "3mo ago", "79d ago")
- All optional fields check for null/empty before rendering
- Consistent field ordering ensures predictable UX across types

## State Management

**No state management library** - uses simple `setState()` only:
- Every screen manages its own state
- State lifted only when absolutely necessary (rare)
- No Provider, Bloc, Riverpod, GetX, or any other library

```dart
// Typical state update pattern
Future<void> _loadData() async {
  setState(() {
    _isLoading = true;
    _error = null;
  });

  try {
    final data = await _service.getData();
    setState(() {
      _data = data;
      _isLoading = false;
    });
  } catch (e) {
    setState(() {
      _error = ErrorFormatter.format(e);
      _isLoading = false;
    });
  }
}
```

## Service Layer

### Service Method Naming
- `getSomething()` - GET requests (fetch data)
- `addSomething(data)` - POST to create
- `updateSomething(data)` - PUT to update
- `deleteSomething(id)` - DELETE
- `searchSomething(query)` - Search/lookup operations
- `somethingCommand(params)` - Trigger background commands

### Command Pattern for Actions
Sonarr/Radarr use command API for background tasks:

```dart
// Trigger episode search
await client.post('/command', {
  'name': 'EpisodeSearch',
  'episodeIds': [123, 456],
});

// Trigger series search
await client.post('/command', {
  'name': 'SeriesSearch',
  'seriesId': 789,
});
```

## Error Handling

### Always Use ErrorFormatter
```dart
try {
  final data = await _service.getData();
  // Process data
} catch (e) {
  // For UI display
  setState(() => _error = ErrorFormatter.format(e));
  
  // For SnackBar
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(ErrorFormatter.format(e))),
  );
}
```

`ErrorFormatter.format(e)`:
- Handles `ApiException` with specific messages
- Sanitizes URLs/credentials
- Converts generic errors to user-friendly text
- Limits length to prevent massive errors

### ApiClient Error Handling
`ApiClient` in `lib/services/api_client.dart` handles HTTP status codes:
- 401 → "Unauthorized - check your API key"
- 404 → "Not found"
- 403 → "Access denied"
- 5xx → "Server error - please try again later"
- Network errors → "Network error: ..."

## Navigation

**No named routes** - use `MaterialPageRoute` with direct constructors:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SeriesDetailScreen(
      seriesId: series['id'],
      seriesTitle: series['title'],
    ),
  ),
);
```

### Instance Switching Flow
**All switching paths use the same unified pattern:**

1. **Settings Radio Button** or **List Screen Dropdown** triggers switch
2. Dropdown shows loading instantly via `setLoadingState()` (no delay)
3. `switchSonarrInstance(newId)` executes:
   - Updates active ID in SharedPreferences
   - Loads full credentials from secure storage (~100-200ms)
   - Clears NEW instance cache
   - Calls `notifyListeners()`
4. Services detect ID change → auto-reset API client
5. Screens receive notification → `loadData(forceRefresh: true)`
6. Loading indicator stays visible (no flash)
7. Fresh data fetched with correct credentials
8. Cache stored with new instance ID

**Key Optimization**: `setLoadingState()` called BEFORE `switchInstance()` ensures instant visual feedback with no perceived delay during secure storage access.

## API Integration

### Base URL Construction
- User provides: `https://sonarr.example.com` (no path)
- `ApiClient` automatically adds `/api/v3` prefix
- Final request: `https://sonarr.example.com/api/v3/series`

### Authentication
```dart
Map<String, String> get _headers {
  final headers = {
    'X-Api-Key': apiKey,  // Always required
    'Content-Type': 'application/json',
  };
  
  // Optional HTTP Basic Auth for proxy-protected instances
  if (basicAuthUsername != null && basicAuthPassword != null) {
    final credentials = base64Encode(utf8.encode('$basicAuthUsername:$basicAuthPassword'));
    headers['Authorization'] = 'Basic $credentials';
  }
  
  return headers;
}
```

### Common API Endpoints
```dart
// Configuration
GET /qualityProfile          → List<dynamic> of quality profiles
GET /rootFolder              → List<dynamic> of root folders
GET /tag                     → List<dynamic> of tags

// Library
GET /series                  → List<dynamic> of all series
GET /series/123              → Map<String, dynamic> for series ID 123
GET /series/lookup?term=...  → List<dynamic> search results
GET /movie                   → List<dynamic> of all movies
GET /movie/456               → Map<String, dynamic> for movie ID 456

// Monitoring
GET /queue                   → Map with 'records' key containing List<dynamic>
GET /calendar?start=...&end=...

// Episodes
GET /episode?seriesId=123    → List<dynamic> of episodes

// Release Search
GET /release?episodeId=123   → List<dynamic> of releases
GET /release?movieId=456     → List<dynamic> of releases
POST /release                → Download release
```

## Code Conventions

### Naming Standards
- **Private members**: Always `_prefixed` (fields, methods, widgets)
- **Services**: `ServiceNameService` class (e.g., `SonarrService`)
- **Screens**: `FeatureNameScreen` StatefulWidget
- **State classes**: `_FeatureNameScreenState` (private)
- **Instance variables**: Descriptive names (`_isLoading`, `_series`, `_error`)

### File Organization
- **One widget per file** (main widget)
- **Related helpers in same file** (e.g., `_InstanceListTab` in `settings_screen.dart`)
- **No barrel exports** - direct imports everywhere
- **Absolute imports**: `import '../services/sonarr_service.dart';`

### Widget Keys
Use keys for widgets that depend on instance changes:

```dart
QueueScreen(
  key: ValueKey('queue_${_activeSonarrInstance?.id}_${_activeRadarrInstance?.id}'),
  ...
)
```

## Security Implementation

### Credential Storage Strategy
```dart
// Secure storage (platform keychain/keystore)
await _secureStorage.write(key: 'sonarr_instance1_apiKey', value: apiKey);
await _secureStorage.write(key: 'sonarr_instance1_basicAuthPassword', value: password);

// SharedPreferences (non-sensitive metadata only)
await _prefs.setString('sonarr_instances', jsonEncode([
  {'id': 'instance1', 'name': 'Home Sonarr', 'baseUrl': 'https://...'}
]));
```

**Never store credentials in SharedPreferences** - only IDs, names, and URLs.

### Platform-Specific Encryption
- **iOS**: Keychain with `KeychainAccessibility.first_unlock`
- **Android**: `encryptedSharedPreferences: true` for Keystore integration
- **Web**: Web Cryptography API
- **Desktop**: Platform-specific secure storage (Keychain/DPAPI/libsecret)

### Backup & Restore Service
**BackupService** (`lib/services/backup_service.dart`) provides encrypted backup/restore with isolate-based crypto:

```dart
// Export returns encrypted bytes for UI to save
final encryptedBytes = await _backupService.exportInstances(password);
await FilePicker.platform.saveFile(
  fileName: 'arr_backup_${timestamp}.enc',
  bytes: encryptedBytes,  // Required on Android/iOS
);

// Import reads file and decrypts
await _backupService.importInstances(password, filePath);
```

**Critical Architecture**:
- **All crypto operations run in isolates** using `compute()` function
- Top-level functions: `_encryptInIsolate()`, `_decryptInIsolate()`, `_deriveKeySync()`
- PBKDF2 600k iterations don't block UI thread
- Loading spinners animate smoothly during 1-2 second key derivation
- Mobile file_picker: `saveFile()` requires `bytes` parameter on Android/iOS
- Desktop file_picker: `saveFile()` returns path for manual writing

**Encryption Specs**:
- **Algorithm**: AES-256-GCM (authenticated encryption)
- **Key Derivation**: PBKDF2-HMAC-SHA256 with 600,000 iterations (OWASP 2023 standard)
- **Salt**: 128-bit random (unique per backup)
- **IV/Nonce**: 96-bit random for GCM mode
- **Compliance**: NIST SP 800-38D (AES-GCM), NIST SP 800-132 (PBKDF2)
- **Password Encoding**: UTF-8 for cross-platform compatibility

**UX Pattern for Expensive Operations**:
```dart
// Show loading dialog
showDialog(context, barrierDismissible: false, builder: (_) => LoadingDialog());

// Small delay to ensure dialog renders
await Future.delayed(Duration(milliseconds: 50));

// Run expensive crypto in isolate (UI stays responsive)
final result = await compute(_expensiveFunction, params);

// Close dialog
Navigator.pop(context);
```

**Common Pitfalls**:
1. **Never run PBKDF2 directly** - always use `compute()` to spawn isolate
2. **Mobile saveFile() needs bytes** - desktop version ignores it
3. **Add 50ms delay** after showing dialog before crypto work
4. **Isolate functions must be top-level** - can't be class methods
5. **Pass all data in params map** - isolates have separate memory

## Security & Secrets Management

**CRITICAL - NEVER COMMIT**:
- API keys, tokens, passwords (stored in `flutter_secure_storage` only)
- Personal data or user credentials
- Real instance URLs with embedded credentials
- SSH keys, certificates, or backup encryption passwords
- Any sensitive homelab information

**Platform-Specific Security**:
- **iOS**: Keychain with `KeychainAccessibility.first_unlock`
- **Android**: `encryptedSharedPreferences: true` for Keystore integration
- **Web**: Web Cryptography API
- **Desktop**: Platform-specific secure storage (Keychain/DPAPI/libsecret)

**What Goes Where**:
```dart
// ✅ flutter_secure_storage (encrypted)
await _secureStorage.write(key: 'sonarr_instance1_apiKey', value: apiKey);
await _secureStorage.write(key: 'sonarr_instance1_basicAuthPassword', value: password);

// ✅ SharedPreferences (non-sensitive metadata only)
await _prefs.setString('sonarr_instances', jsonEncode([
  {'id': 'instance1', 'name': 'Home Sonarr', 'baseUrl': 'https://...'}
]));

// ❌ NEVER in version control
// ❌ NEVER in SharedPreferences (credentials)
// ❌ NEVER hardcoded in source files
```

**Error Message Security**:
- `ErrorFormatter` automatically sanitizes credentials from error messages
- Redacts: username:password, API keys, Bearer tokens, Basic auth tokens
- See `lib/utils/error_formatter.dart` for implementation details

## Testing Standards

**Test Organization**:
- **Widget Tests**: Screen navigation, UI state, empty states
- **Unit Tests**: Data models, utility functions, error formatting
- **Integration Tests**: (Future) Service layer, API communication, state management

**Current Coverage** (21 tests passing):
- **HomeScreen** (4 tests): Navigation, tab switching, empty states, drawer
- **ServiceInstance** (6 tests): JSON serialization, copyWith, null handling
- **ErrorFormatter** (11 tests): Error formatting and security sanitization

**Writing New Tests**:
```dart
// Widget tests - use proper setup
setUp(() async {
  SharedPreferences.setMockInitialValues({});
  await InstanceManager().init();
  await AppStateManager().initialize();
});

// Unit tests - group by component
group('ComponentName Tests', () {
  test('specific behavior', () {
    // Arrange, Act, Assert
  });
});
```

**Running Tests Locally** (BEFORE committing):
```bash
flutter test                      # Run all tests (must pass)
flutter test --coverage          # Generate coverage report
flutter analyze                   # Lint checks (0 issues required)
dart format .                     # Auto-format code
```

**CI/CD Integration**:
- GitHub Actions workflow runs: `analyze`, `test`, `security` jobs before building
- All tests must pass before merge/release
- See `.github/workflows/ci.yml` and `RELEASE.md` for complete workflow details

## Development Workflows

### Daily Development
```bash
# 1. Start development
flutter devices                    # List available devices
flutter run -d <device-id>        # Run on specific device
flutter run -d windows            # Desktop (fastest for development)
flutter run -d chrome             # Web
flutter run -d R5CX11GGGLR        # Android device ID

# 2. Hot reload during development
# Press 'r' in terminal for hot reload (preserves state)
# Press 'R' in terminal for hot restart (resets state)

# 3. Test before committing
flutter test                       # All tests must pass
flutter analyze                    # No issues allowed
dart format .                      # Auto-format code

# 4. Git workflow (feature → develop → release → main)
# Feature development (test in isolation)
git checkout develop
git pull
git checkout -b feature/new-feature
git add .
git commit -m "feat: descriptive message"
git push origin feature/new-feature
# Create PR to develop (triggers CI workflow)
# After approval, merge (workflow runs again on develop)

# When ready to release (see RELEASE.md for full process)
# Create release branch from main, cherry-pick ready features
```

### Adding a New Feature
1. **Add service method** if needed in `lib/services/sonarr_service.dart` or `radarr_service.dart`
2. **Create screen** in `lib/screens/` following 3-state pattern (or use CachedDataLoader mixin)
3. **Add navigation** from existing screens via `Navigator.push` with `MaterialPageRoute`
4. **Write tests** for new functionality (widget tests for screens, unit tests for utilities)
5. **Test error states** by temporarily breaking API calls
6. **Test empty states** by returning empty lists
7. **Add pull-to-refresh** if showing lists
8. **Run test suite** before committing

### Testing Instance Configuration
- First run shows empty states with "Open Settings" CTA
- Settings icon in top-right always accessible
- Test both HTTP Basic Auth and API-key-only flows
- Verify instance switching updates active instance name in AppBar
- Test with multiple instances configured
- Test backup/restore with encryption

### Building Releases
**Semantic Versioning** (v1.2.3 format):
- **Major**: Breaking changes (rare)
- **Minor**: New features, screen additions
- **Patch**: Bug fixes, small improvements

**Release Process** (selective release via release branch):
```bash
# 1. Create release branch from main (last stable release)
git checkout main
git pull
git checkout -b release/v1.2.3

# 2. Cherry-pick only what's ready from develop
git cherry-pick <feature-commits>
git cherry-pick <fix-commits>
git cherry-pick <optimize-commits>

# 3. Update version in pubspec.yaml
version: 1.2.3+4  # version+build_number
git add pubspec.yaml
git commit -m "chore: bump version to 1.2.3"

# 4. Test release candidate
flutter test
flutter run -d android

# 5. Create PR: release/v1.2.3 → main (triggers CI)
# After approval and merge:
#    - Workflow validates on main
#    - Auto-tags main with v1.2.3
#    - Tag triggers build workflow:
#      - analyze: dart format, flutter analyze
#      - test: flutter test with coverage
#      - security: flutter pub outdated
#      - build-android: APK artifact
#      - create-release: GitHub Release with APK
# Note: iOS builds not in CI/CD - users build locally

# 6. Merge release branch back to develop
git checkout develop
git merge release/v1.2.3
git push origin develop

# 7. Delete release branch (tag preserves it)
git branch -d release/v1.2.3
git push origin :release/v1.2.3
```

See `RELEASE.md` for complete workflow and examples.

## Version Control

**Git Workflow** (Modified Git Flow with Release Branches):
- **develop branch**: Default branch, integration testing (protected)
- **main branch**: Release-only branch, stable code (protected)
- **Feature branches**: Create from develop for isolated testing
- **Release branches**: Create from main for selective releases
- **Pull Requests**: Required for develop and main
- **Meaningful commits**: Use conventional commit format
  - `feat:` - New feature
  - `fix:` - Bug fix
  - `docs:` - Documentation changes
  - `test:` - Test additions/changes
  - `refactor:` - Code restructuring
  - `chore:` - Build/config changes

**GitHub Actions CI/CD**:
- **Pull Requests to develop**: Triggers analyze, test, security (validates integration)
- **After merge to develop**: Workflow runs again (validates merged state)
- **Pull Requests to main**: Triggers analyze, test, security (validates release)
- **After merge to main**: Auto-tags with version from pubspec.yaml
- **Version Tags on main** (v1.2.3): Triggers Android build + GitHub release creation
- **Feature branches**: No workflow runs (test locally with `flutter test` and `flutter analyze`)
- **iOS Builds**: Not in CI/CD - users build locally with Xcode (requires code signing)

**.gitignore Coverage**:
```gitignore
# Build outputs
build/
*.apk
*.ipa  # Local iOS builds only (not in CI/CD)
*.aab

# Flutter/Dart
.dart_tool/
.packages
.flutter-plugins
.flutter-plugins-dependencies

# IDE
.vscode/
.idea/
*.swp

# Platform-specific
.gradle/
*.iml
Pods/
```

**Secrets Management**:
- Credentials stored via `flutter_secure_storage` (never committed)
- No `.env` files (mobile apps use secure storage instead)
- API base URLs are non-sensitive (can be in SharedPreferences metadata)
- Backup passwords never stored (user must remember them)

## Common Pitfalls

1. **Use CachedDataLoader for data screens**: Don't implement manual loading states
2. **AppStateManager is single source of truth**: Never access InstanceManager directly in screens
3. **Always handle null**: Use `??` operators extensively - `series['title'] ?? 'Unknown'`
4. **Check lists before accessing**: `(series['seasons'] as List?)?.length ?? 0`
5. **RefreshIndicator needs scrollable**: ListView, CustomScrollView, etc.
6. **Error state needs retry button**: Users expect to retry failed operations
7. **Empty state ≠ error state**: Different messages and icons
8. **Don't forget mounted checks**: Mixin handles this, but manual code needs it
9. **Cache keys must be unique**: Use descriptive names per screen
10. **Service reset automatic**: AppStateManager calls reset() on instance changes

## Critical Files Reference

### Core Services & State Management
- `lib/main.dart` - App entry, Material3 theme, AppStateManager initialization
- `lib/services/app_state_manager.dart` - **Single source of truth**, ChangeNotifier for instances
- `lib/services/backup_service.dart` - Encrypted backup/restore with isolate-based crypto
- `lib/services/biometric_service.dart` - Biometric authentication wrapper
- `lib/services/cache_manager.dart` - Singleton cache with instance-specific keys
- `lib/services/instance_manager.dart` - Persistent storage (secure + SharedPreferences)
- `lib/utils/cached_data_loader.dart` - Mixin for consistent loading patterns
- `lib/config/app_config.dart` - Synchronous getters delegating to AppStateManager

### API Layer
- `lib/services/api_client.dart` - HTTP client with v3 API prefix, auth headers, error handling
- `lib/services/sonarr_service.dart` - All Sonarr API methods, lazy client initialization
- `lib/services/radarr_service.dart` - All Radarr API methods, lazy client initialization
- `lib/utils/error_formatter.dart` - User-friendly error messages, URL sanitization

### Data Models
- `lib/models/service_instance.dart` - **Only data model in entire app**

### UI Screens
- `lib/screens/home_screen.dart` - Bottom navigation, AppStateManager listener, IndexedStack
- `lib/screens/settings_screen.dart` - Instance management, calls reloadInstances()
- `lib/screens/series_list_screen.dart` - **Reference implementation** of CachedDataLoader mixin
- `lib/screens/movie_list_screen.dart` - CachedDataLoader pattern for Radarr
- `lib/screens/queue_screen.dart` - Dual-service screen with CachedDataLoader
- `lib/screens/series_search_screen.dart` - Legacy pattern for non-cached screens
- `lib/screens/series_detail_screen.dart` - Detail view without caching
- `lib/screens/release_search_screen.dart` - **Unified release confirmation dialog** for both series/movies, custom format chips, relative date formatting
