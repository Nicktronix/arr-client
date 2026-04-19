import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:arr_client/models/service_instance.dart';
import 'package:arr_client/services/app_state_manager.dart';
import 'package:arr_client/services/cache_manager.dart';
import 'package:arr_client/services/instance_manager.dart';

class MockInstanceManager extends Mock implements InstanceManager {}

const _sonarrA = ServiceInstance(
  id: 'sonarr-a',
  name: 'Sonarr A',
  baseUrl: 'http://sonarr-a.local',
  apiKey: 'key-a',
);

const _sonarrB = ServiceInstance(
  id: 'sonarr-b',
  name: 'Sonarr B',
  baseUrl: 'http://sonarr-b.local',
  apiKey: 'key-b',
);

const _radarrA = ServiceInstance(
  id: 'radarr-a',
  name: 'Radarr A',
  baseUrl: 'http://radarr-a.local',
  apiKey: 'key-ra',
);

void main() {
  late MockInstanceManager mockInstances;
  late CacheManager cache;
  late AppStateManager manager;

  setUp(() {
    mockInstances = MockInstanceManager();
    cache = CacheManager();
    manager = AppStateManager(mockInstances, cache);
  });

  group('initialization', () {
    test('isInitialized is false before initialize()', () {
      expect(manager.isInitialized, isFalse);
    });

    test('initialize loads active Sonarr instance', () async {
      when(
        () => mockInstances.getActiveSonarrInstance(),
      ).thenAnswer((_) async => _sonarrA);
      when(
        () => mockInstances.getActiveRadarrInstance(),
      ).thenAnswer((_) async => null);

      await manager.initialize();

      expect(manager.activeSonarrInstance, _sonarrA);
      expect(manager.isInitialized, isTrue);
    });

    test('initialize loads active Radarr instance', () async {
      when(
        () => mockInstances.getActiveSonarrInstance(),
      ).thenAnswer((_) async => null);
      when(
        () => mockInstances.getActiveRadarrInstance(),
      ).thenAnswer((_) async => _radarrA);

      await manager.initialize();

      expect(manager.activeRadarrInstance, _radarrA);
    });

    test('initialize with no instances leaves both null', () async {
      when(
        () => mockInstances.getActiveSonarrInstance(),
      ).thenAnswer((_) async => null);
      when(
        () => mockInstances.getActiveRadarrInstance(),
      ).thenAnswer((_) async => null);

      await manager.initialize();

      expect(manager.activeSonarrInstance, isNull);
      expect(manager.activeRadarrInstance, isNull);
    });

    test('initialize notifies listeners', () async {
      when(
        () => mockInstances.getActiveSonarrInstance(),
      ).thenAnswer((_) async => null);
      when(
        () => mockInstances.getActiveRadarrInstance(),
      ).thenAnswer((_) async => null);

      var notified = false;
      void listener() => notified = true;
      manager.addListener(listener);
      addTearDown(() => manager.removeListener(listener));

      await manager.initialize();

      expect(notified, isTrue);
    });
  });

  group('instance switching', () {
    test('switchSonarrInstance updates activeSonarrInstance', () async {
      when(
        () => mockInstances.setActiveSonarrId('sonarr-b'),
      ).thenAnswer((_) async {});
      when(
        () => mockInstances.getActiveSonarrInstance(),
      ).thenAnswer((_) async => _sonarrB);
      when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-b');

      await manager.switchSonarrInstance('sonarr-b');

      expect(manager.activeSonarrInstance, _sonarrB);
    });

    test('switchSonarrInstance clears cache for active instance', () async {
      when(
        () => mockInstances.setActiveSonarrId(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockInstances.getActiveSonarrInstance(),
      ).thenAnswer((_) async => _sonarrB);
      when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-b');

      // Pre-populate cache
      cache.set('series_list_sonarr-b', ['cached data']);
      expect(cache.exists('series_list_sonarr-b'), isTrue);

      await manager.switchSonarrInstance('sonarr-b');

      expect(cache.exists('series_list_sonarr-b'), isFalse);
    });

    test('switchSonarrInstance notifies listeners', () async {
      when(
        () => mockInstances.setActiveSonarrId(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockInstances.getActiveSonarrInstance(),
      ).thenAnswer((_) async => _sonarrB);
      when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-b');

      var notifyCount = 0;
      void listener() => notifyCount++;
      manager.addListener(listener);
      addTearDown(() => manager.removeListener(listener));

      await manager.switchSonarrInstance('sonarr-b');

      expect(notifyCount, 1);
    });
  });

  group('cache operations', () {
    test('getSonarrCache returns null when no active instance', () {
      when(() => mockInstances.getActiveSonarrId()).thenReturn(null);

      final result = manager.getSonarrCache('series_list');
      expect(result, isNull);
    });

    test('setSonarrCache and getSonarrCache round-trip with instance key', () {
      when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-a');

      manager.setSonarrCache('series_list', ['item1']);
      final cached = manager.getSonarrCache('series_list');

      expect(cached, isNotNull);
      expect(cached!.data, ['item1']);
      expect(cached.isValid, isTrue);
    });

    test('getSonarrCache returns null when cache entry missing', () {
      when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-a');

      final result = manager.getSonarrCache('series_list');
      expect(result, isNull);
    });

    test('getSonarrCache isStale when entry backdated', () {
      when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-a');

      manager.setSonarrCache('series_list', ['old data']);
      cache.backdateTimestamp(
        'series_list_sonarr-a',
        const Duration(minutes: 10),
      );

      final cached = manager.getSonarrCache('series_list');
      expect(cached!.isValid, isFalse);
      expect(cached.isStale, isTrue);
    });
  });

  group('instance deletion', () {
    test('deleteSonarrInstance clears cache for deleted instance', () async {
      when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-a');
      when(
        () => mockInstances.deleteSonarrInstance('sonarr-a'),
      ).thenAnswer((_) async {});
      when(
        () => mockInstances.getSonarrInstancesMetadata(),
      ).thenReturn([]);

      cache.set('series_list_sonarr-a', 'cached');

      await manager.deleteSonarrInstance('sonarr-a');

      expect(cache.exists('series_list_sonarr-a'), isFalse);
    });

    test(
      'deleteSonarrInstance auto-selects next when deleting active',
      () async {
        when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-a');
        when(
          () => mockInstances.deleteSonarrInstance('sonarr-a'),
        ).thenAnswer((_) async {});
        when(() => mockInstances.getSonarrInstancesMetadata()).thenReturn([
          {'id': 'sonarr-b', 'name': 'Sonarr B', 'baseUrl': 'http://b.local'},
        ]);
        when(
          () => mockInstances.setActiveSonarrId('sonarr-b'),
        ).thenAnswer((_) async {});
        when(
          () => mockInstances.getActiveSonarrInstance(),
        ).thenAnswer((_) async => _sonarrB);

        await manager.deleteSonarrInstance('sonarr-a');

        expect(manager.activeSonarrInstance, _sonarrB);
      },
    );

    test(
      'deleteSonarrInstance sets activeSonarrInstance to null when last deleted',
      () async {
        when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-a');
        when(
          () => mockInstances.deleteSonarrInstance('sonarr-a'),
        ).thenAnswer((_) async {});
        when(() => mockInstances.getSonarrInstancesMetadata()).thenReturn([]);

        await manager.deleteSonarrInstance('sonarr-a');

        expect(manager.activeSonarrInstance, isNull);
      },
    );

    test('deleteSonarrInstance notifies listeners', () async {
      when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-a');
      when(
        () => mockInstances.deleteSonarrInstance('sonarr-a'),
      ).thenAnswer((_) async {});
      when(() => mockInstances.getSonarrInstancesMetadata()).thenReturn([]);

      var notifyCount = 0;
      void listener() => notifyCount++;
      manager.addListener(listener);
      addTearDown(() => manager.removeListener(listener));

      await manager.deleteSonarrInstance('sonarr-a');

      expect(notifyCount, 1);
    });
  });

  group('addSonarrInstance', () {
    test('notifies listeners after add', () async {
      when(
        () => mockInstances.addSonarrInstance(_sonarrA),
      ).thenAnswer((_) async {});
      when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-a');
      when(
        () => mockInstances.getActiveSonarrInstance(),
      ).thenAnswer((_) async => _sonarrA);

      var notified = false;
      void listener() => notified = true;
      manager.addListener(listener);
      addTearDown(() => manager.removeListener(listener));

      await manager.addSonarrInstance(_sonarrA);

      expect(notified, isTrue);
    });
  });
}
