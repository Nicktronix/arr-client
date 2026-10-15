import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:arr_client/models/service_instance.dart';
import 'package:arr_client/services/app_state_manager.dart';
import 'package:arr_client/services/cache_manager.dart';
import 'package:arr_client/services/instance_manager.dart';
import 'package:arr_client/services/radarr_service.dart';
import 'package:arr_client/services/sonarr_service.dart';

class MockInstanceManager extends Mock implements InstanceManager {}

/// Mirrors package:http's IOClient: requests after close() throw.
class ClosableFakeClient extends http.BaseClient {
  bool isClosed = false;
  final List<Uri> requested = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (isClosed) {
      throw http.ClientException(
        'HTTP request failed. Client is already closed.',
        request.url,
      );
    }
    requested.add(request.url);
    return http.StreamedResponse(Stream.value('[]'.codeUnits), 200);
  }

  @override
  void close() => isClosed = true;
}

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
  late MockInstanceManager instances;
  late AppStateManager appState;
  late ClosableFakeClient sharedClient;
  late SonarrService sonarr;
  late RadarrService radarr;

  setUp(() async {
    instances = MockInstanceManager();
    when(
      () => instances.getActiveSonarrInstance(),
    ).thenAnswer((_) async => _sonarrA);
    when(
      () => instances.getActiveRadarrInstance(),
    ).thenAnswer((_) async => _radarrA);
    when(() => instances.setActiveSonarrId(any())).thenAnswer((_) async {});

    appState = AppStateManager(instances, CacheManager());
    await appState.initialize();

    sharedClient = ClosableFakeClient();
    sonarr = SonarrService(appState, sharedClient);
    radarr = RadarrService(appState, sharedClient);
  });

  Future<void> switchToSonarrB() async {
    when(
      () => instances.getActiveSonarrInstance(),
    ).thenAnswer((_) async => _sonarrB);
    await appState.switchSonarrInstance(_sonarrB.id);
  }

  test('Sonarr requests reach the new instance after a switch', () async {
    await sonarr.getSeries();

    await switchToSonarrB();
    await sonarr.getSeries();

    expect(sharedClient.requested.last.host, 'sonarr-b.local');
  });

  test('switching Sonarr instance does not break Radarr requests', () async {
    await sonarr.getSeries();
    await radarr.getMovies();

    await switchToSonarrB();

    await expectLater(radarr.getMovies(), completes);
  });
}
