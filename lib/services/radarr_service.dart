import 'api_client.dart';
import '../config/app_config.dart';
import 'app_state_manager.dart';

class RadarrService {
  // Singleton pattern
  static final RadarrService _instance = RadarrService._internal();
  factory RadarrService() => _instance;
  RadarrService._internal() {
    // Listen to instance changes and auto-reset
    AppStateManager().addListener(_onInstanceChanged);
  }

  ApiClient? _client;
  String? _currentInstanceId;

  void _onInstanceChanged() {
    final newInstanceId = AppConfig.activeRadarrInstanceId;
    if (_currentInstanceId != newInstanceId) {
      reset();
      _currentInstanceId = newInstanceId;
    }
  }

  Future<ApiClient> get _api async {
    if (_client == null) {
      final baseUrl = AppConfig.radarrBaseUrl;
      final apiKey = AppConfig.radarrApiKey;

      // Validate configuration before creating client
      if (baseUrl.isEmpty || apiKey.isEmpty) {
        throw Exception(
          'Radarr instance not configured. Please add an instance in settings.',
        );
      }

      final basicAuthUsername = AppConfig.radarrBasicAuthUsername;
      final basicAuthPassword = AppConfig.radarrBasicAuthPassword;
      _client = ApiClient(
        baseUrl: baseUrl,
        apiKey: apiKey,
        basicAuthUsername: basicAuthUsername,
        basicAuthPassword: basicAuthPassword,
      );
      _currentInstanceId = AppConfig.activeRadarrInstanceId;
    }
    return _client!;
  }

  /// Reset the API client (called automatically when instance changes)
  void reset() {
    _client = null;
  }

  /// Get system status
  Future<Map<String, dynamic>> getSystemStatus() async {
    final client = await _api;
    return await client.get('/system/status');
  }

  /// Get all movies
  Future<List<dynamic>> getMovies() async {
    final client = await _api;
    return await client.get('/movie');
  }

  /// Get movie by ID
  Future<Map<String, dynamic>> getMovieById(int id) async {
    if (id <= 0) {
      throw ArgumentError('Invalid movie ID: $id');
    }
    final client = await _api;
    return await client.get('/movie/$id');
  }

  /// Search for movies
  Future<List<dynamic>> searchMovies(String query) async {
    final client = await _api;
    return await client.get('/movie/lookup?term=$query');
  }

  /// Get calendar (upcoming releases)
  Future<List<dynamic>> getCalendar({DateTime? start, DateTime? end}) async {
    final client = await _api;
    String endpoint = '/calendar';

    if (start != null && end != null) {
      final startStr = start.toIso8601String().split('T')[0];
      final endStr = end.toIso8601String().split('T')[0];
      endpoint += '?start=$startStr&end=$endStr';
    }

    return await client.get(endpoint);
  }

  /// Get queue (current downloads)
  Future<Map<String, dynamic>> getQueue() async {
    final client = await _api;
    return await client.get('/queue');
  }

  /// Add a new movie
  Future<Map<String, dynamic>> addMovie(Map<String, dynamic> movieData) async {
    final client = await _api;
    return await client.post('/movie', movieData);
  }

  /// Update movie
  Future<Map<String, dynamic>> updateMovie(
    Map<String, dynamic> movieData,
  ) async {
    final client = await _api;
    return await client.put('/movie', movieData);
  }

  /// Delete movie
  Future<void> deleteMovie(int id, {bool deleteFiles = false}) async {
    if (id <= 0) {
      throw ArgumentError('Invalid movie ID: $id');
    }
    final client = await _api;
    await client.delete('/movie/$id?deleteFiles=$deleteFiles');
  }

  /// Trigger movie search
  Future<void> searchMovieCommand(int movieId) async {
    final client = await _api;
    await client.post('/command', {
      'name': 'MoviesSearch',
      'movieIds': [movieId],
    });
  }

  /// Get quality profiles
  Future<List<dynamic>> getQualityProfiles() async {
    final client = await _api;
    return await client.get('/qualityProfile');
  }

  /// Get root folders
  Future<List<dynamic>> getRootFolders() async {
    final client = await _api;
    return await client.get('/rootFolder');
  }

  /// Get tags
  Future<List<dynamic>> getTags() async {
    final client = await _api;
    return await client.get('/tag');
  }

  /// Get tag details by ID
  Future<Map<String, dynamic>> getTagById(int id) async {
    final client = await _api;
    return await client.get('/tag/$id');
  }

  /// Search for releases for a specific movie (interactive search)
  /// Uses extended 60s timeout as release searches can be slow
  Future<List<dynamic>> searchMovieReleases(int movieId) async {
    final client = await _api;
    return await client.get(
      '/release?movieId=$movieId',
      timeout: const Duration(seconds: 60),
    );
  }

  /// Download a specific release
  Future<Map<String, dynamic>> downloadRelease(
    Map<String, dynamic> releaseData,
  ) async {
    final client = await _api;
    return await client.post('/release', releaseData);
  }

  /// Get activity history (downloads, imports, failures)
  Future<Map<String, dynamic>> getHistory({
    int page = 1,
    int pageSize = 50,
  }) async {
    final client = await _api;
    return await client.get(
      '/history?page=$page&pageSize=$pageSize&sortKey=date&sortDirection=descending',
    );
  }

  /// Get system health status
  Future<List<dynamic>> getHealth() async {
    final client = await _api;
    return await client.get('/health');
  }

  /// Get disk space information
  Future<List<dynamic>> getDiskspace() async {
    final client = await _api;
    return await client.get('/diskspace');
  }

  /// Test all indexers
  Future<void> testAllIndexers() async {
    final client = await _api;
    await client.post('/indexer/testall', {});
  }

  /// Delete a movie file by ID
  Future<void> deleteMovieFile(int movieFileId) async {
    final client = await _api;
    await client.delete('/moviefile/$movieFileId');
  }

  /// Get manual import candidates for a download
  Future<List<dynamic>> getManualImport({
    required String downloadId,
    bool filterExistingFiles = false,
  }) async {
    final client = await _api;
    return await client.get(
      '/manualimport?downloadId=$downloadId&filterExistingFiles=$filterExistingFiles',
    );
  }

  /// Import selected manual import items
  Future<void> performManualImport(List<Map<String, dynamic>> imports) async {
    final client = await _api;
    await client.post('/command', {'name': 'ManualImport', 'files': imports});
  }
}
