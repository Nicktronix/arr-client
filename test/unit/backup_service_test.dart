import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:arr_client/models/service_instance.dart';
import 'package:arr_client/services/backup_service.dart';
import 'package:arr_client/services/instance_manager.dart';

class MockInstanceManager extends Mock implements InstanceManager {}

const _sonarrA = ServiceInstance(
  id: 'sonarr-a',
  name: 'Sonarr A',
  baseUrl: 'http://sonarr-a.local',
  apiKey: 'apikey-sonarr-a',
);

const _radarrA = ServiceInstance(
  id: 'radarr-a',
  name: 'Radarr A',
  baseUrl: 'http://radarr-a.local',
  apiKey: 'apikey-radarr-a',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      const ServiceInstance(id: '', name: '', baseUrl: '', apiKey: ''),
    );
  });

  late MockInstanceManager mockInstances;
  late BackupService service;

  setUp(() {
    mockInstances = MockInstanceManager();
    service = BackupService(mockInstances);
  });

  group('export', () {
    test('exportInstances returns non-empty bytes', () async {
      when(
        () => mockInstances.getSonarrInstances(),
      ).thenAnswer((_) async => [_sonarrA]);
      when(
        () => mockInstances.getRadarrInstances(),
      ).thenAnswer((_) async => [_radarrA]);
      when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-a');
      when(() => mockInstances.getActiveRadarrId()).thenReturn('radarr-a');

      final bytes = await service.exportInstances('password123');
      expect(bytes, isNotEmpty);
    });

    test('exportInstances produces valid JSON wrapper', () async {
      when(
        () => mockInstances.getSonarrInstances(),
      ).thenAnswer((_) async => [_sonarrA]);
      when(
        () => mockInstances.getRadarrInstances(),
      ).thenAnswer((_) async => []);
      when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-a');
      when(() => mockInstances.getActiveRadarrId()).thenReturn(null);

      final bytes = await service.exportInstances('password123');
      final jsonString = String.fromCharCodes(bytes);

      // Must be parseable JSON with expected structure
      expect(jsonString, contains('"version"'));
      expect(jsonString, contains('"encryptedData"'));
      expect(jsonString, contains('"salt"'));
      expect(jsonString, contains('"iv"'));
    });
  });

  group('import / export roundtrip', () {
    // Note: PBKDF2 uses 600k iterations — this test is intentionally slow (~2–5s)
    test(
      'export then import restores instances with correct data',
      () async {
        when(
          () => mockInstances.getSonarrInstances(),
        ).thenAnswer((_) async => [_sonarrA]);
        when(
          () => mockInstances.getRadarrInstances(),
        ).thenAnswer((_) async => [_radarrA]);
        when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-a');
        when(() => mockInstances.getActiveRadarrId()).thenReturn('radarr-a');

        final bytes = await service.exportInstances('correct-password');

        // Write to a temp file for import
        final tempFile = File(
          '${Directory.systemTemp.path}/arr_client_test_backup.json',
        );
        await tempFile.writeAsBytes(bytes);

        try {
          // Stub import calls
          when(
            () => mockInstances.getSonarrInstances(),
          ).thenAnswer((_) async => []);
          when(
            () => mockInstances.getRadarrInstances(),
          ).thenAnswer((_) async => []);
          when(
            () => mockInstances.addSonarrInstance(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockInstances.addRadarrInstance(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockInstances.setActiveSonarrId(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockInstances.setActiveRadarrId(any()),
          ).thenAnswer((_) async {});

          final result = await service.importInstances(
            'correct-password',
            tempFile.path,
          );

          expect(result['sonarr'], 1);
          expect(result['radarr'], 1);

          // Verify the right instances were imported
          final sonarrCapture = verify(
            () => mockInstances.addSonarrInstance(captureAny()),
          ).captured;
          final imported = sonarrCapture.first as ServiceInstance;
          expect(imported.id, 'sonarr-a');
          expect(imported.name, 'Sonarr A');
          expect(imported.apiKey, 'apikey-sonarr-a');
        } finally {
          await tempFile.delete();
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'import with wrong password throws descriptive error',
      () async {
        when(
          () => mockInstances.getSonarrInstances(),
        ).thenAnswer((_) async => [_sonarrA]);
        when(
          () => mockInstances.getRadarrInstances(),
        ).thenAnswer((_) async => []);
        when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-a');
        when(() => mockInstances.getActiveRadarrId()).thenReturn(null);

        final bytes = await service.exportInstances('correct-password');

        final tempFile = File(
          '${Directory.systemTemp.path}/arr_client_test_backup_wrong.json',
        );
        await tempFile.writeAsBytes(bytes);

        try {
          expect(
            () => service.importInstances('wrong-password', tempFile.path),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('Invalid password'),
              ),
            ),
          );
        } finally {
          await tempFile.delete();
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('import with unsupported version throws', () async {
      final tempFile = File(
        '${Directory.systemTemp.path}/arr_client_test_bad_version.json',
      );
      await tempFile.writeAsString('{"version": 99, "encryptedData": "abc"}');

      try {
        expect(
          () => service.importInstances('password', tempFile.path),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Unsupported backup version'),
            ),
          ),
        );
      } finally {
        await tempFile.delete();
      }
    });

    test('import of non-existent file throws', () {
      expect(
        () =>
            service.importInstances('password', '/nonexistent/path/file.json'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
