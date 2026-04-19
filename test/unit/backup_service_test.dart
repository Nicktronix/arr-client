import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
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

        addTearDown(() {
          if (tempFile.existsSync()) tempFile.deleteSync();
        });
        await expectLater(
          service.importInstances('wrong-password', tempFile.path),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Invalid password'),
            ),
          ),
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('import with unsupported version throws', () async {
      final tempFile = File(
        '${Directory.systemTemp.path}/arr_client_test_bad_version.json',
      );
      await tempFile.writeAsString('{"version": 99, "encryptedData": "abc"}');

      addTearDown(() {
        if (tempFile.existsSync()) tempFile.deleteSync();
      });
      await expectLater(
        service.importInstances('password', tempFile.path),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Unsupported backup version'),
          ),
        ),
      );
    });

    test('import of non-existent file throws', () async {
      await expectLater(
        service.importInstances('password', '/nonexistent/path/file.json'),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'import updates existing instance when id matches',
      () async {
        when(
          () => mockInstances.getSonarrInstances(),
        ).thenAnswer((_) async => [_sonarrA]);
        when(
          () => mockInstances.getRadarrInstances(),
        ).thenAnswer((_) async => [_radarrA]);
        when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-a');
        when(() => mockInstances.getActiveRadarrId()).thenReturn('radarr-a');

        final bytes = await service.exportInstances('password');
        final tempFile = File(
          '${Directory.systemTemp.path}/arr_client_test_update.json',
        );
        await tempFile.writeAsBytes(bytes);
        addTearDown(() {
          if (tempFile.existsSync()) tempFile.deleteSync();
        });

        // Return existing instances with matching IDs → triggers update path
        when(
          () => mockInstances.getSonarrInstances(),
        ).thenAnswer((_) async => [_sonarrA]);
        when(
          () => mockInstances.getRadarrInstances(),
        ).thenAnswer((_) async => [_radarrA]);
        when(
          () => mockInstances.updateSonarrInstance(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockInstances.updateRadarrInstance(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockInstances.setActiveSonarrId(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockInstances.setActiveRadarrId(any()),
        ).thenAnswer((_) async {});

        final result = await service.importInstances('password', tempFile.path);

        expect(result['sonarr'], 1);
        expect(result['radarr'], 1);
        verify(() => mockInstances.updateSonarrInstance(any())).called(1);
        verify(() => mockInstances.updateRadarrInstance(any())).called(1);
        verifyNever(() => mockInstances.addSonarrInstance(any()));
        verifyNever(() => mockInstances.addRadarrInstance(any()));
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'import v1 CBC backup restores instances',
      () async {
        // Build a v1-format backup using AES-CBC via the cryptography package
        // so we can test the legacy decrypt path without the old encrypt library.
        final password = 'legacy-password';
        final salt = Uint8List.fromList(List.generate(16, (i) => i));
        final iv = Uint8List.fromList(List.generate(16, (i) => i + 16));

        final pbkdf2 = Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: 600000,
          bits: 256,
        );
        final key = await pbkdf2.deriveKeyFromPassword(
          password: password,
          nonce: salt,
        );

        final plaintext = utf8.encode(
          '{"sonarrInstances":[{"id":"sonarr-a","name":"Sonarr A",'
          '"baseUrl":"http://sonarr-a.local","apiKey":"apikey-sonarr-a",'
          '"useBasicAuth":false,"basicAuthUsername":null,'
          '"basicAuthPassword":null}],'
          '"radarrInstances":[],'
          '"activeSonarrId":"sonarr-a","activeRadarrId":null}',
        );

        // AesCbc.with256bits handles PKCS7 padding automatically
        final cbcAlgorithm = AesCbc.with256bits(
          macAlgorithm: MacAlgorithm.empty,
        );
        final secretBox = await cbcAlgorithm.encrypt(
          plaintext,
          secretKey: key,
          nonce: iv,
        );

        final v1Json = jsonEncode({
          'version': 1,
          'exportDate': '2024-01-01T00:00:00.000Z',
          'salt': base64Encode(salt),
          'iv': base64Encode(iv),
          'encryptedData': base64Encode(secretBox.cipherText),
        });

        final tempFile = File(
          '${Directory.systemTemp.path}/arr_client_test_v1.json',
        );
        await tempFile.writeAsString(v1Json);
        addTearDown(() {
          if (tempFile.existsSync()) tempFile.deleteSync();
        });

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
          () => mockInstances.setActiveSonarrId(any()),
        ).thenAnswer((_) async {});

        final result = await service.importInstances(password, tempFile.path);
        expect(result['sonarr'], 1);
        expect(result['radarr'], 0);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });

  group('validateBackup', () {
    test(
      'validateBackup returns counts and exportDate on valid backup',
      () async {
        when(
          () => mockInstances.getSonarrInstances(),
        ).thenAnswer((_) async => [_sonarrA]);
        when(
          () => mockInstances.getRadarrInstances(),
        ).thenAnswer((_) async => [_radarrA]);
        when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-a');
        when(() => mockInstances.getActiveRadarrId()).thenReturn('radarr-a');

        final bytes = await service.exportInstances('validate-pw');
        final tempFile = File(
          '${Directory.systemTemp.path}/arr_client_test_validate.json',
        );
        await tempFile.writeAsBytes(bytes);
        addTearDown(() {
          if (tempFile.existsSync()) tempFile.deleteSync();
        });

        final info = await service.validateBackup('validate-pw', tempFile.path);

        expect(info['valid'], isTrue);
        expect(info['sonarrCount'], 1);
        expect(info['radarrCount'], 1);
        expect(info['exportDate'], isA<String>());
        expect(info['activeSonarrId'], 'sonarr-a');
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'validateBackup with wrong password throws',
      () async {
        when(
          () => mockInstances.getSonarrInstances(),
        ).thenAnswer((_) async => [_sonarrA]);
        when(
          () => mockInstances.getRadarrInstances(),
        ).thenAnswer((_) async => []);
        when(() => mockInstances.getActiveSonarrId()).thenReturn('sonarr-a');
        when(() => mockInstances.getActiveRadarrId()).thenReturn(null);

        final bytes = await service.exportInstances('correct-pw');
        final tempFile = File(
          '${Directory.systemTemp.path}/arr_client_test_validate_bad.json',
        );
        await tempFile.writeAsBytes(bytes);
        addTearDown(() {
          if (tempFile.existsSync()) tempFile.deleteSync();
        });

        await expectLater(
          service.validateBackup('wrong-pw', tempFile.path),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Invalid password'),
            ),
          ),
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test('validateBackup with non-existent file throws', () async {
      await expectLater(
        service.validateBackup('password', '/nonexistent/file.json'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
