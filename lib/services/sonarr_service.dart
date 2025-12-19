import 'api_client.dart';
import '../config/app_config.dart';
import 'app_state_manager.dart';

class SonarrService {
  // Singleton pattern
  static final SonarrService _instance = SonarrService._internal();
  factory SonarrService() => _instance;
  SonarrService._internal() {
    // Listen to instance changes and auto-reset
    AppStateManager().addListener(_onInstanceChanged);
  }

  ApiClient? _client;
  String? _currentInstanceId;

  void _onInstanceChanged() {
    final newInstanceId = AppConfig.activeSonarrInstanceId;
    if (_currentInstanceId != newInstanceId) {
      reset();
      _currentInstanceId = newInstanceId;
    }
  }

  Future<ApiClient> get _api async {
    if (_client == null) {
      final baseUrl = AppConfig.sonarrBaseUrl;
      final apiKey = AppConfig.sonarrApiKey;

      // Validate configuration before creating client
      if (baseUrl.isEmpty || apiKey.isEmpty) {
        throw Exception(
          'Sonarr instance not configured. Please add an instance in settings.',
        );
      }

      final basicAuthUsername = AppConfig.sonarrBasicAuthUsername;
      final basicAuthPassword = AppConfig.sonarrBasicAuthPassword;
      _client = ApiClient(
        baseUrl: baseUrl,
        apiKey: apiKey,
        basicAuthUsername: basicAuthUsername,
        basicAuthPassword: basicAuthPassword,
      );
      _currentInstanceId = AppConfig.activeSonarrInstanceId;
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

  /// Get all series
  Future<List<dynamic>> getSeries() async {
    final client = await _api;
    return await client.get('/series');
  }

  /// Get series by ID
  Future<Map<String, dynamic>> getSeriesById(int id) async {
    if (id <= 0) {
      throw ArgumentError('Invalid series ID: $id');
    }
    final client = await _api;
    return await client.get('/series/$id');
  }

  /// Search for series
  Future<List<dynamic>> searchSeries(String query) async {
    final client = await _api;
    return await client.get('/series/lookup?term=$query');
  }

  /// Get calendar (upcoming episodes)
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

  /// Add a new series
  Future<Map<String, dynamic>> addSeries(
    Map<String, dynamic> seriesData,
  ) async {
    final client = await _api;
    return await client.post('/series', seriesData);
  }

  /// Update series
  Future<Map<String, dynamic>> updateSeries(
    Map<String, dynamic> seriesData,
  ) async {
    final client = await _api;
    return await client.put('/series', seriesData);
  }

  /// Delete series
  Future<void> deleteSeries(int id, {bool deleteFiles = false}) async {
    if (id <= 0) {
      throw ArgumentError('Invalid series ID: $id');
    }
    final client = await _api;
    await client.delete('/series/$id?deleteFiles=$deleteFiles');
  }

  /// Trigger series search
  Future<void> searchSeriesCommand(int seriesId) async {
    final client = await _api;
    await client.post('/command', {
      'name': 'SeriesSearch',
      'seriesId': seriesId,
    });
  }

  /// Get episodes for a series
  Future<List<dynamic>> getEpisodesBySeriesId(int seriesId) async {
    final client = await _api;
    return await client.get('/episode?seriesId=$seriesId');
  }

  /// Get episode files for a series
  Future<List<dynamic>> getEpisodeFilesBySeriesId(int seriesId) async {
    final client = await _api;
    return await client.get('/episodeFile?seriesId=$seriesId');
  }

  /// Update an episode (e.g., toggle monitoring)
  /// Sonarr v3 requires sending the full episode object, not partial updates
  Future<Map<String, dynamic>> updateEpisode(
    int episodeId,
    Map<String, dynamic> updates,
  ) async {
    final client = await _api;

    // Fetch current episode data
    final episodes = await client.get(
      '/episode?seriesId=${updates['seriesId']}',
    );
    final episode = (episodes as List).firstWhere(
      (ep) => ep['id'] == episodeId,
      orElse: () => throw ApiException('Episode not found'),
    );

    // Merge updates into full episode object
    final updatedEpisode = Map<String, dynamic>.from(episode);
    updatedEpisode.addAll(updates);

    // Send full object to API
    return await client.put('/episode/$episodeId', updatedEpisode);
  }

  /// Search for a specific episode
  Future<void> searchEpisode(int episodeId) async {
    final client = await _api;
    await client.post('/command', {
      'name': 'EpisodeSearch',
      'episodeIds': [episodeId],
    });
  }

  /// Delete an episode file
  Future<void> deleteEpisodeFile(int episodeFileId) async {
    if (episodeFileId <= 0) {
      throw ArgumentError('Invalid episode file ID: $episodeFileId');
    }
    final client = await _api;
    await client.delete('/episodeFile/$episodeFileId');
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

  /// Search for releases for a specific episode (interactive search)
  /// Uses extended 60s timeout as release searches can be slow
  Future<List<dynamic>> searchEpisodeReleases(int episodeId) async {
    final client = await _api;
    return await client.get(
      '/release?episodeId=$episodeId',
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
}
