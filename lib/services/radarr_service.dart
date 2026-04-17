import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:arr_client/services/api_client.dart';
import 'package:arr_client/services/app_state_manager.dart';

@lazySingleton
class RadarrService {
  final AppStateManager _appStateManager;
  final http.Client _httpClient;

  RadarrService(this._appStateManager, this._httpClient) {
    _appStateManager.addListener(_onInstanceChanged);
  }

  ApiClient? _client;

  void _onInstanceChanged() => reset();

  Future<ApiClient> get _api async {
    if (_client == null) {
      final instance = _appStateManager.activeRadarrInstance;
      final baseUrl = instance?.baseUrl ?? '';
      final apiKey = instance?.apiKey ?? '';

      if (baseUrl.isEmpty || apiKey.isEmpty) {
        throw Exception(
          'Radarr instance not configured. Please add an instance in settings.',
        );
      }

      _client = ApiClient(
        baseUrl: baseUrl,
        apiKey: apiKey,
        basicAuthUsername: instance?.basicAuthUsername,
        basicAuthPassword: instance?.basicAuthPassword,
        httpClient: _httpClient,
      );
    }
    return _client!;
  }

  /// Reset the API client (called automatically when instance changes)
  void reset() {
    _client?.close();
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
    var endpoint = '/calendar';

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
    return await client.get(
      '/queue?pageSize=500&sortKey=timeleft&sortDirection=ascending',
    );
  }

  /// Remove item from queue
  /// removeFromClient: Remove from download client (default true)
  /// blocklist: Add to blocklist to prevent re-downloading (default false)
  Future<void> removeQueueItem(
    int id, {
    bool removeFromClient = true,
    bool blocklist = false,
  }) async {
    final client = await _api;
    await client.delete(
      '/queue/$id?removeFromClient=$removeFromClient&blocklist=$blocklist',
    );
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
    return await client.put('/movie/${movieData['id']}', movieData);
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

  /// Import selected manual import items via the ManualImport command
  Future<void> performManualImport(List<Map<String, dynamic>> imports) async {
    final client = await _api;
    await client.post('/command', {
      'name': 'ManualImport',
      'importMode': 'move',
      'files': imports,
    });
  }

  /// Get available languages
  Future<List<dynamic>> getLanguages() async {
    final client = await _api;
    return await client.get('/language');
  }
}
