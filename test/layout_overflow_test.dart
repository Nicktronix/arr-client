import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arr_client/di/injection.dart';
import 'package:arr_client/models/radarr/movie.dart';
import 'package:arr_client/models/service_instance.dart';
import 'package:arr_client/models/shared/language.dart';
import 'package:arr_client/models/shared/quality_profile.dart';
import 'package:arr_client/models/shared/root_folder.dart';
import 'package:arr_client/models/shared/tag.dart';
import 'package:arr_client/models/sonarr/queue_item.dart';
import 'package:arr_client/models/sonarr/series.dart';
import 'package:arr_client/screens/movie_detail_screen.dart';
import 'package:arr_client/screens/movie_search_screen.dart';
import 'package:arr_client/screens/queue_screen.dart';
import 'package:arr_client/screens/series_search_screen.dart';
import 'package:arr_client/services/app_state_manager.dart';
import 'package:arr_client/services/cache_manager.dart';
import 'package:arr_client/services/instance_manager.dart';
import 'package:arr_client/services/radarr_service.dart';
import 'package:arr_client/services/sonarr_service.dart';

class MockSonarrService extends Mock implements SonarrService {}

class MockRadarrService extends Mock implements RadarrService {}

class MockInstanceManager extends Mock implements InstanceManager {}

// The test font draws every glyph as a full-width square, so text is wider
// than on a real device; that makes these checks stricter, not looser.

// Longer than the ~28 characters that fit in the dialog's dropdown.
const _longRootFolder = '/mnt/main_store/Apps/media/library/television';
const _longProfileName = 'HD Bluray + WEB (1080p) Preferred Remux';

const _profiles = [QualityProfileResource(id: 1, name: _longProfileName)];
const _rootFolders = [RootFolderResource(id: 1, path: _longRootFolder)];

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    await configureDependencies();
    await getIt<AppStateManager>().initialize();
    getIt.allowReassignment = true;
  });

  tearDown(() => getIt.allowReassignment = false);

  // Galaxy S24 Ultra at default display size: 1440px wide at 3.5x ≈ 411dp.
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.5;
    addTearDown(tester.view.reset);
  }

  testWidgets('Add Series dialog fits long root folder and profile names', (
    tester,
  ) async {
    usePhoneSize(tester);
    final sonarr = MockSonarrService();
    when(sonarr.getSeries).thenAnswer((_) async => []);
    when(() => sonarr.searchSeries(any())).thenAnswer(
      (_) async => [const SeriesResource(title: 'Some Show', tvdbId: 1)],
    );
    when(sonarr.getQualityProfiles).thenAnswer((_) async => _profiles);
    when(sonarr.getRootFolders).thenAnswer((_) async => _rootFolders);
    when(sonarr.getTags).thenAnswer((_) async => <TagResource>[]);
    getIt.registerSingleton<SonarrService>(sonarr);

    await tester.pumpWidget(const MaterialApp(home: SeriesSearchScreen()));
    await tester.enterText(find.byType(TextField), 'some show');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Some Show'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(_longRootFolder), findsOneWidget);
  });

  testWidgets('Add Movie dialog fits long root folder and profile names', (
    tester,
  ) async {
    usePhoneSize(tester);
    final radarr = MockRadarrService();
    when(radarr.getMovies).thenAnswer((_) async => []);
    when(() => radarr.searchMovies(any())).thenAnswer(
      (_) async => [const MovieResource(title: 'Some Movie', tmdbId: 1)],
    );
    when(radarr.getQualityProfiles).thenAnswer((_) async => _profiles);
    when(radarr.getRootFolders).thenAnswer((_) async => _rootFolders);
    when(radarr.getTags).thenAnswer((_) async => <TagResource>[]);
    getIt.registerSingleton<RadarrService>(radarr);

    await tester.pumpWidget(const MaterialApp(home: MovieSearchScreen()));
    await tester.enterText(find.byType(TextField), 'some movie');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Some Movie'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(_longRootFolder), findsOneWidget);
  });

  testWidgets('queue card fits long language list, client and indexer', (
    tester,
  ) async {
    usePhoneSize(tester);
    final instances = MockInstanceManager();
    when(instances.getActiveSonarrInstance).thenAnswer(
      (_) async => const ServiceInstance(
        id: 'sonarr-1',
        name: 'Sonarr',
        baseUrl: 'http://sonarr.local',
        apiKey: 'key',
      ),
    );
    when(instances.getActiveRadarrInstance).thenAnswer((_) async => null);
    when(instances.getActiveSonarrId).thenReturn('sonarr-1');
    when(instances.getActiveRadarrId).thenReturn(null);
    final appState = AppStateManager(instances, getIt<CacheManager>());
    await appState.initialize();
    getIt.registerSingleton<AppStateManager>(appState);

    final sonarr = MockSonarrService();
    when(sonarr.getQueue).thenAnswer(
      (_) async => [
        const SonarrQueueItem(
          id: 1,
          title: 'Some.Show.S01E01.1080p.WEB.H264',
          status: 'downloading',
          size: 1000,
          sizeleft: 500,
          downloadClient: 'qBittorrent (Seedbox, VPN, priority queue)',
          indexer: 'A Very Long Private Indexer Name (Prowlarr)',
          languages: [
            Language(id: 1, name: 'English'),
            Language(id: 2, name: 'Japanese'),
            Language(id: 3, name: 'French'),
            Language(id: 4, name: 'German'),
            Language(id: 5, name: 'Spanish'),
          ],
        ),
      ],
    );
    getIt.registerSingleton<SonarrService>(sonarr);

    await tester.pumpWidget(const MaterialApp(home: QueueScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Some.Show.S01E01'), findsOneWidget);
  });

  testWidgets('movie detail status row fits monitored and downloaded labels', (
    tester,
  ) async {
    usePhoneSize(tester);
    final radarr = MockRadarrService();
    when(() => radarr.getMovieById(1)).thenAnswer(
      (_) async => const MovieResource(
        id: 1,
        title: 'Some Movie',
        monitored: false,
        hasFile: true,
      ),
    );
    when(radarr.getTags).thenAnswer((_) async => <TagResource>[]);
    getIt.registerSingleton<RadarrService>(radarr);

    await tester.pumpWidget(
      const MaterialApp(
        home: MovieDetailScreen(movieId: 1, movieTitle: 'Some Movie'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not Monitored'), findsOneWidget);
    expect(find.text('Downloaded'), findsOneWidget);
  });
}
