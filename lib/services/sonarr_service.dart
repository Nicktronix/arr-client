import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:arr_client/models/shared/disk_space.dart';
import 'package:arr_client/models/shared/health.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality_profile.dart';
import 'package:arr_client/models/shared/root_folder.dart';
import 'package:arr_client/models/shared/tag.dart';
import 'package:arr_client/models/sonarr/history_record.dart';
import 'package:arr_client/models/sonarr/manual_import.dart';
import 'package:arr_client/models/sonarr/queue_item.dart';
import 'package:arr_client/models/sonarr/release.dart';
import 'package:arr_client/models/sonarr/series.dart';
import 'package:arr_client/models/sonarr/system_status.dart';
import 'package:arr_client/services/api_client.dart';
import 'package:arr_client/services/app_state_manager.dart';

@lazySingleton
class SonarrService {
  final AppStateManager _appStateManager;
  final http.Client _httpClient;

  SonarrService(this._appStateManager, this._httpClient) {
    _appStateManager.addListener(_onInstanceChanged);
  }

  ApiClient? _client;

  void _onInstanceChanged() => reset();

  Future<ApiClient> get _api async {
    if (_client == null) {
      final instance = _appStateManager.activeSonarrInstance;
      final baseUrl = instance?.baseUrl ?? '';
      final apiKey = instance?.apiKey ?? '';

      if (baseUrl.isEmpty || apiKey.isEmpty) {
        throw Exception(
          'Sonarr instance not configured. Please add an instance in settings.',
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

  Future<SonarrSystemStatus> getSystemStatus() async {
    final client = await _api;
    return client.getObject('/system/status', SonarrSystemStatus.fromJson);
  }

  Future<List<SeriesResource>> getSeries() async {
    final client = await _api;
    return client.getList('/series', SeriesResource.fromJson);
  }

  Future<SeriesResource> getSeriesById(int id) async {
    if (id <= 0) throw ArgumentError('Invalid series ID: $id');
    final client = await _api;
    return client.getObject('/series/$id', SeriesResource.fromJson);
  }

  Future<List<SeriesResource>> searchSeries(String query) async {
    final client = await _api;
    return client.getList(
      '/series/lookup?term=$query',
      SeriesResource.fromJson,
    );
  }

  Future<List<EpisodeResource>> getCalendar({
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
    return client.getList(endpoint, EpisodeResource.fromJson);
  }

  Future<List<SonarrQueueItem>> getQueue() async {
    final client = await _api;
    return client.getPagedList(
      '/queue?pageSize=500&sortKey=timeleft&sortDirection=ascending',
      SonarrQueueItem.fromJson,
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

  Future<SeriesResource> addSeries(Map<String, dynamic> seriesData) async {
    final client = await _api;
    final data = await client.post('/series', seriesData);
    return SeriesResource.fromJson(data as Map<String, dynamic>);
  }

  Future<SeriesResource> updateSeries(SeriesResource series) async {
    final client = await _api;
    final data = await client.put('/series/${series.id}', series.toJson());
    return SeriesResource.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteSeries(int id, {bool deleteFiles = false}) async {
    if (id <= 0) throw ArgumentError('Invalid series ID: $id');
    final client = await _api;
    await client.delete('/series/$id?deleteFiles=$deleteFiles');
  }

  Future<void> searchSeriesCommand(int seriesId) async {
    final client = await _api;
    await client.post('/command', {
      'name': 'SeriesSearch',
      'seriesId': seriesId,
    });
  }

  Future<List<EpisodeResource>> getEpisodesBySeriesId(int seriesId) async {
    final client = await _api;
    return client.getList(
      '/episode?seriesId=$seriesId',
      EpisodeResource.fromJson,
    );
  }

  Future<List<EpisodeFileResource>> getEpisodeFilesBySeriesId(
    int seriesId,
  ) async {
    final client = await _api;
    return client.getList(
      '/episodeFile?seriesId=$seriesId',
      EpisodeFileResource.fromJson,
    );
  }

  Future<void> setEpisodesMonitored(
    List<int> episodeIds, {
    required bool monitored,
  }) async {
    final client = await _api;
    await client.put('/episode/monitor', {
      'episodeIds': episodeIds,
      'monitored': monitored,
    });
  }

  Future<void> searchEpisode(int episodeId) async {
    final client = await _api;
    await client.post('/command', {
      'name': 'EpisodeSearch',
      'episodeIds': [episodeId],
    });
  }

  Future<void> deleteEpisodeFile(int episodeFileId) async {
    if (episodeFileId <= 0) {
      throw ArgumentError('Invalid episode file ID: $episodeFileId');
    }
    final client = await _api;
    await client.delete('/episodeFile/$episodeFileId');
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

  Future<List<SonarrRelease>> searchEpisodeReleases(int episodeId) async {
    final client = await _api;
    return client.getList(
      '/release?episodeId=$episodeId',
      SonarrRelease.fromJson,
      timeout: const Duration(seconds: 60),
    );
  }

  Future<SonarrRelease> downloadRelease(
    Map<String, dynamic> releaseData,
  ) async {
    final client = await _api;
    final data = await client.post('/release', releaseData);
    return SonarrRelease.fromJson(data as Map<String, dynamic>);
  }

  Future<List<SonarrHistoryRecord>> getHistory({
    int page = 1,
    int pageSize = 50,
  }) async {
    final client = await _api;
    return client.getPagedList(
      '/history?page=$page&pageSize=$pageSize&sortKey=date&sortDirection=descending',
      SonarrHistoryRecord.fromJson,
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

  Future<List<SonarrManualImport>> getManualImport({
    required String downloadId,
    bool filterExistingFiles = false,
  }) async {
    final client = await _api;
    return client.getList(
      '/manualimport?downloadId=$downloadId&filterExistingFiles=$filterExistingFiles',
      SonarrManualImport.fromJson,
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
