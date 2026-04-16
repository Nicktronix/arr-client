# Architecture Reference

Detailed code patterns and examples for the arr-client architecture.
See `CLAUDE.md` for the high-level overview and critical files list.

---

## CachedDataLoader mixin — full example

```dart
class ScreenName extends StatefulWidget { ... }

class _ScreenNameState extends State<ScreenName> with CachedDataLoader {
  final SonarrService _sonarr = SonarrService();
  List<dynamic> _data = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override String get cacheKey => 'unique_screen_key'; // must be globally unique
  @override bool get isSonarrScreen => true;             // false for Radarr screens

  @override
  Future<dynamic> fetchData() => _sonarr.getData();

  @override
  void onDataLoaded(dynamic data) => setState(() => _data = data);

  @override
  Widget buildSuccessBody() {
    if (_data.isEmpty) {
      return Center(child: Column(children: [
        Icon(Icons.inbox, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text('No items', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text('Descriptive empty state message'),
      ]));
    }
    return RefreshIndicator(
      onRefresh: () => loadData(forceRefresh: true),
      child: ListView.builder(...),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Screen Title'),
      actions: [IconButton(icon: Icon(Icons.refresh), onPressed: () => loadData(forceRefresh: true))],
    ),
    body: buildBody(), // mixin handles loading/error/empty/success states
  );
}
```

**Mixin provides**: `loadData({forceRefresh})`, `setLoadingState()`, `buildBody()`,
`buildLoadingIndicator()`, `buildErrorState()`, `buildEmptyState()`.
Override `buildSuccessBody()` for your data UI.

**Instant loading pattern** (for dropdowns/switches with no perceived delay):
```dart
onChanged: (value) async {
  Navigator.pop(context);
  setLoadingState();                        // show loading instantly
  await appState.switchSonarrInstance(value);
}
```

---

## Service singleton pattern

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
    final newId = AppConfig.activeSonarrInstanceId;
    if (_currentInstanceId != newId) { reset(); _currentInstanceId = newId; }
  }

  Future<ApiClient> get _api async {
    if (_client == null) {
      _client = ApiClient(baseUrl: AppConfig.sonarrBaseUrl, apiKey: AppConfig.sonarrApiKey);
      _currentInstanceId = AppConfig.activeSonarrInstanceId;
    }
    return _client!;
  }

  void reset() => _client = null;
}
```

Services auto-detect instance changes — no manual coordination needed.

---

## Legacy three-state pattern (non-cached screens)

For search/detail screens that don't use CachedDataLoader:

```dart
bool _isLoading = true;
String? _error;
List<dynamic> _data = [];

Future<void> _loadData() async {
  setState(() { _isLoading = true; _error = null; });
  try {
    final data = await _service.getData();
    if (!mounted) return;
    setState(() { _data = data; _isLoading = false; });
  } catch (e) {
    if (!mounted) return;
    setState(() { _error = ErrorFormatter.format(e); _isLoading = false; });
  }
}

Widget _buildBody() {
  if (_isLoading) return Center(child: CircularProgressIndicator());
  if (_error != null) return Center(child: Column(children: [
    Icon(Icons.error_outline, size: 64, color: Colors.red),
    Text(_error!),
    ElevatedButton.icon(onPressed: _loadData, icon: Icon(Icons.refresh), label: Text('Retry')),
  ]));
  return RefreshIndicator(onRefresh: _loadData, child: ListView.builder(...));
}
```

---

## Release confirmation dialog pattern

Unified dialog for both series and movies via `_isMovie` flag.
See `lib/screens/release_search_screen.dart` for the full implementation.

Key fields (in display order):
1. Common: Quality, Release Group, Size, Protocol, Languages, Indexer, Seeders, Leechers, Age, Published Date
2. Custom formats as `Chip` widgets with compact density
3. CF Score (colour-coded)
4. Series-only: episode list, season pack indicator
5. Movie-only: edition field
6. Rejections at bottom if present

Date formatting helper:
```dart
String _formatPublishDate(String publishDate) {
  final diff = DateTime.now().difference(DateTime.parse(publishDate));
  if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
  if (diff.inDays > 30)  return '${(diff.inDays / 30).floor()}mo ago';
  if (diff.inDays > 0)   return '${diff.inDays}d ago';
  if (diff.inHours > 0)  return '${diff.inHours}h ago';
  return '${diff.inMinutes}m ago';
}
```

---

## Common API endpoints

```
# Configuration
GET /qualityProfile          → List<dynamic>
GET /rootFolder              → List<dynamic>
GET /tag                     → List<dynamic>

# Library
GET /series                  → List<dynamic>
GET /series/{id}             → Map<String, dynamic>
GET /series/lookup?term=...  → List<dynamic>
GET /movie                   → List<dynamic>
GET /movie/{id}              → Map<String, dynamic>

# Queue & calendar
GET /queue                   → Map with 'records' key
GET /calendar?start=...&end=...

# Episodes
GET /episode?seriesId={id}   → List<dynamic>

# Manual import
GET /manualimport?downloadId=... → List<dynamic>

# Release search
GET /release?episodeId={id}  → List<dynamic>
GET /release?movieId={id}    → List<dynamic>
POST /release                → download a release

# Commands (background tasks)
POST /command  { "name": "EpisodeSearch", "episodeIds": [...] }
POST /command  { "name": "SeriesSearch",  "seriesId": N }
POST /command  { "name": "MoviesSearch",  "movieIds": [...] }
```

ApiClient automatically prepends `/api/v3` to all paths.

---

## Authentication headers

```dart
headers = { 'X-Api-Key': apiKey, 'Content-Type': 'application/json' };
// Optional Basic Auth for proxy-protected instances:
headers['Authorization'] = 'Basic ${base64Encode(utf8.encode('$user:$pass'))}';
```

---

## Backup encryption specs

- Algorithm: AES-256-GCM
- Key derivation: PBKDF2-HMAC-SHA256, 600,000 iterations (OWASP 2023)
- Salt: 128-bit random per backup
- IV/Nonce: 96-bit random (GCM mode)
- All crypto runs in isolates via `compute()` — never on the UI thread
- Isolate functions must be top-level (not class methods)
- Add 50ms delay after showing loading dialog before starting crypto work
