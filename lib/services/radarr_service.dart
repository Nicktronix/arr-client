import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:arr_client/models/shared/disk_space.dart';
import 'package:arr_client/models/shared/health.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality_profile.dart';
import 'package:arr_client/models/shared/root_folder.dart';
import 'package:arr_client/models/shared/tag.dart';
import 'package:arr_client/models/radarr/history_record.dart';
import 'package:arr_client/models/radarr/manual_import.dart';
import 'package:arr_client/models/radarr/movie.dart';
import 'package:arr_client/models/radarr/queue_item.dart';
import 'package:arr_client/models/radarr/release.dart';
import 'package:arr_client/models/radarr/system_status.dart';
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

  void reset() {
    _client?.close();
    _client = null;
  }

  Future<RadarrSystemStatus> getSystemStatus() async {
    final client = await _api;
    return client.getObject('/system/status', RadarrSystemStatus.fromJson);
  }

  Future<List<MovieResource>> getMovies() async {
    final client = await _api;
    return client.getList('/movie', MovieResource.fromJson);
  }

  Future<MovieResource> getMovieById(int id) async {
    if (id <= 0) throw ArgumentError('Invalid movie ID: $id');
    final client = await _api;
    return client.getObject('/movie/$id', MovieResource.fromJson);
  }

  Future<List<MovieResource>> searchMovies(String query) async {
    final client = await _api;
    return client.getList('/movie/lookup?term=$query', MovieResource.fromJson);
  }

  Future<List<MovieResource>> getCalendar({
    DateTime? start,
    DateTime? end,
  }) async {
    final client = await _api;
    var endpoint = '/calendar';
    if (start != null && end != null) {
      final startStr = start.toIso8601String().split('T')[0];
      final endStr = end.toIso8601String().split('T')[0];
      endpoint += '?start=$startStr&end=$endStr';
    }
    return client.getList(endpoint, MovieResource.fromJson);
  }

  Future<List<RadarrQueueItem>> getQueue() async {
    final client = await _api;
    return client.getPagedList(
      '/queue?pageSize=500&sortKey=timeleft&sortDirection=ascending',
      RadarrQueueItem.fromJson,
    );
  }

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

  Future<MovieResource> addMovie(Map<String, dynamic> movieData) async {
    final client = await _api;
    final data = await client.post('/movie', movieData);
    return MovieResource.fromJson(data as Map<String, dynamic>);
  }

  Future<MovieResource> updateMovie(MovieResource movie) async {
    final client = await _api;
    final data = await client.put('/movie/${movie.id}', movie.toJson());
    return MovieResource.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteMovie(int id, {bool deleteFiles = false}) async {
    if (id <= 0) throw ArgumentError('Invalid movie ID: $id');
    final client = await _api;
    await client.delete('/movie/$id?deleteFiles=$deleteFiles');
  }

  Future<void> searchMovieCommand(int movieId) async {
    final client = await _api;
    await client.post('/command', {
      'name': 'MoviesSearch',
      'movieIds': [movieId],
    });
  }

  Future<List<QualityProfileResource>> getQualityProfiles() async {
    final client = await _api;
    return client.getList('/qualityProfile', QualityProfileResource.fromJson);
  }

  Future<List<RootFolderResource>> getRootFolders() async {
    final client = await _api;
    return client.getList('/rootFolder', RootFolderResource.fromJson);
  }

  Future<List<TagResource>> getTags() async {
    final client = await _api;
    return client.getList('/tag', TagResource.fromJson);
  }

  Future<TagResource> getTagById(int id) async {
    final client = await _api;
    return client.getObject('/tag/$id', TagResource.fromJson);
  }

  Future<List<RadarrRelease>> searchMovieReleases(int movieId) async {
    final client = await _api;
    return client.getList(
      '/release?movieId=$movieId',
      RadarrRelease.fromJson,
      timeout: const Duration(seconds: 60),
    );
  }

  Future<RadarrRelease> downloadRelease(
    Map<String, dynamic> releaseData,
  ) async {
    final client = await _api;
    final data = await client.post('/release', releaseData);
    return RadarrRelease.fromJson(data as Map<String, dynamic>);
  }

  Future<List<RadarrHistoryRecord>> getHistory({
    int page = 1,
    int pageSize = 50,
  }) async {
    final client = await _api;
    return client.getPagedList(
      '/history?page=$page&pageSize=$pageSize&sortKey=date&sortDirection=descending',
      RadarrHistoryRecord.fromJson,
    );
  }

  Future<List<HealthResource>> getHealth() async {
    final client = await _api;
    return client.getList('/health', HealthResource.fromJson);
  }

  Future<List<DiskSpaceResource>> getDiskspace() async {
    final client = await _api;
    return client.getList('/diskspace', DiskSpaceResource.fromJson);
  }

  Future<void> testAllIndexers() async {
    final client = await _api;
    await client.post('/indexer/testall', {});
  }

  Future<void> deleteMovieFile(int movieFileId) async {
    final client = await _api;
    await client.delete('/moviefile/$movieFileId');
  }

  Future<List<RadarrManualImport>> getManualImport({
    required String downloadId,
    bool filterExistingFiles = false,
  }) async {
    final client = await _api;
    return client.getList(
      '/manualimport?downloadId=$downloadId&filterExistingFiles=$filterExistingFiles',
      RadarrManualImport.fromJson,
    );
  }

  Future<void> performManualImport(List<Map<String, dynamic>> imports) async {
    final client = await _api;
    await client.post('/command', {
      'name': 'ManualImport',
      'importMode': 'move',
      'files': imports,
    });
  }

  Future<List<LanguageResource>> getLanguages() async {
    final client = await _api;
    return client.getList('/language', LanguageResource.fromJson);
  }
}
