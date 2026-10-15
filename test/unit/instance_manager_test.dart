import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arr_client/models/service_instance.dart';
import 'package:arr_client/services/instance_manager.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

const _sonarrA = ServiceInstance(
  id: 'sonarr-a',
  name: 'Sonarr A',
  baseUrl: 'http://sonarr-a.local',
  apiKey: 'apikey-sonarr-a',
);

const _sonarrB = ServiceInstance(
  id: 'sonarr-b',
  name: 'Sonarr B',
  baseUrl: 'http://sonarr-b.local',
  apiKey: 'apikey-sonarr-b',
);

const _radarrA = ServiceInstance(
  id: 'radarr-a',
  name: 'Radarr A',
  baseUrl: 'http://radarr-a.local',
  apiKey: 'apikey-radarr-a',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFlutterSecureStorage mockSecure;
  late SharedPreferences prefs;
  late InstanceManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockSecure = MockFlutterSecureStorage();
    manager = InstanceManager(prefs, mockSecure);

    // Default stub — storage returns null for unknown keys
    when(
      () => mockSecure.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => mockSecure.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockSecure.delete(key: any(named: 'key')),
    ).thenAnswer((_) async {});
  });

  void stubCredentials(ServiceInstance instance, String serviceType) {
    final prefix = '${serviceType}_${instance.id}';
    when(
      () => mockSecure.read(key: '${prefix}_apiKey'),
    ).thenAnswer((_) async => instance.apiKey);
    when(
      () => mockSecure.read(key: '${prefix}_basicAuthUsername'),
    ).thenAnswer((_) async => instance.basicAuthUsername);
    when(
      () => mockSecure.read(key: '${prefix}_basicAuthPassword'),
    ).thenAnswer((_) async => instance.basicAuthPassword);
  }

  group('Sonarr CRUD', () {
    test(
      'getSonarrInstances returns empty list when no instances stored',
      () async {
        final instances = await manager.getSonarrInstances();
        expect(instances, isEmpty);
      },
    );

    test('addSonarrInstance persists to SharedPreferences', () async {
      stubCredentials(_sonarrA, 'sonarr');
      await manager.addSonarrInstance(_sonarrA);

      final metadata = manager.getSonarrInstancesMetadata();
      expect(metadata, hasLength(1));
      expect(metadata.first['id'], 'sonarr-a');
      expect(metadata.first['name'], 'Sonarr A');
    });

    test('addSonarrInstance writes API key to secure storage', () async {
      stubCredentials(_sonarrA, 'sonarr');
      await manager.addSonarrInstance(_sonarrA);

      verify(
        () => mockSecure.write(
          key: 'sonarr_sonarr-a_apiKey',
          value: 'apikey-sonarr-a',
        ),
      ).called(1);
    });

    test('first added Sonarr instance becomes active', () async {
      stubCredentials(_sonarrA, 'sonarr');
      await manager.addSonarrInstance(_sonarrA);

      expect(manager.getActiveSonarrId(), 'sonarr-a');
    });

    test('second added instance does not replace active', () async {
      stubCredentials(_sonarrA, 'sonarr');
      stubCredentials(_sonarrB, 'sonarr');
      await manager.addSonarrInstance(_sonarrA);
      await manager.addSonarrInstance(_sonarrB);

      expect(manager.getActiveSonarrId(), 'sonarr-a');
    });

    test(
      'getSonarrInstances returns instances with credentials loaded',
      () async {
        stubCredentials(_sonarrA, 'sonarr');
        await manager.addSonarrInstance(_sonarrA);

        final instances = await manager.getSonarrInstances();
        expect(instances, hasLength(1));
        expect(instances.first.id, 'sonarr-a');
        expect(instances.first.apiKey, 'apikey-sonarr-a');
      },
    );

    test('updateSonarrInstance replaces existing entry', () async {
      stubCredentials(_sonarrA, 'sonarr');
      await manager.addSonarrInstance(_sonarrA);

      const updated = ServiceInstance(
        id: 'sonarr-a',
        name: 'Sonarr A Updated',
        baseUrl: 'http://sonarr-a-new.local',
        apiKey: 'new-api-key',
      );
      stubCredentials(updated, 'sonarr');
      await manager.updateSonarrInstance(updated);

      final metadata = manager.getSonarrInstancesMetadata();
      expect(metadata.first['name'], 'Sonarr A Updated');
    });

    test('deleteSonarrInstance removes from SharedPreferences', () async {
      stubCredentials(_sonarrA, 'sonarr');
      await manager.addSonarrInstance(_sonarrA);
      await manager.deleteSonarrInstance('sonarr-a');

      expect(manager.getSonarrInstancesMetadata(), isEmpty);
    });

    test(
      'deleteSonarrInstance deletes credentials from secure storage',
      () async {
        stubCredentials(_sonarrA, 'sonarr');
        await manager.addSonarrInstance(_sonarrA);
        await manager.deleteSonarrInstance('sonarr-a');

        verify(
          () => mockSecure.delete(key: 'sonarr_sonarr-a_apiKey'),
        ).called(1);
      },
    );

    test(
      'deleteSonarrInstance clears active ID when deleting active',
      () async {
        stubCredentials(_sonarrA, 'sonarr');
        await manager.addSonarrInstance(_sonarrA);
        expect(manager.getActiveSonarrId(), 'sonarr-a');

        await manager.deleteSonarrInstance('sonarr-a');

        expect(manager.getActiveSonarrId(), isNull);
      },
    );
  });

  group('active instance management', () {
    test('getActiveSonarrId returns null when none set', () {
      expect(manager.getActiveSonarrId(), isNull);
    });

    test('setActiveSonarrId persists to SharedPreferences', () async {
      await manager.setActiveSonarrId('sonarr-a');
      expect(manager.getActiveSonarrId(), 'sonarr-a');
    });

    test('getActiveSonarrInstance returns null when no instances', () async {
      final instance = await manager.getActiveSonarrInstance();
      expect(instance, isNull);
    });

    test('getActiveSonarrInstance returns matching instance', () async {
      stubCredentials(_sonarrA, 'sonarr');
      await manager.addSonarrInstance(_sonarrA);

      final instance = await manager.getActiveSonarrInstance();
      expect(instance?.id, 'sonarr-a');
    });
  });

  group('Radarr CRUD', () {
    test('addRadarrInstance makes it active when first', () async {
      stubCredentials(_radarrA, 'radarr');
      await manager.addRadarrInstance(_radarrA);

      expect(manager.getActiveRadarrId(), 'radarr-a');
    });

    test('Sonarr and Radarr instances are independent', () async {
      stubCredentials(_sonarrA, 'sonarr');
      stubCredentials(_radarrA, 'radarr');
      await manager.addSonarrInstance(_sonarrA);
      await manager.addRadarrInstance(_radarrA);

      expect(manager.getSonarrInstancesMetadata(), hasLength(1));
      expect(manager.getRadarrInstancesMetadata(), hasLength(1));
      expect(manager.getActiveSonarrId(), 'sonarr-a');
      expect(manager.getActiveRadarrId(), 'radarr-a');
    });
  });
}
