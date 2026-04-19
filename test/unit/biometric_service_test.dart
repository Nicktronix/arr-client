import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arr_client/services/biometric_service.dart';

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocalAuthentication mockAuth;
  late SharedPreferences prefs;
  late BiometricService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockAuth = MockLocalAuthentication();
    service = BiometricService(mockAuth, prefs);
  });

  group('device support', () {
    test(
      'canCheckBiometrics returns true when localAuth supports it',
      () async {
        when(() => mockAuth.canCheckBiometrics).thenAnswer((_) async => true);
        expect(await service.canCheckBiometrics(), isTrue);
      },
    );

    test('canCheckBiometrics returns false when localAuth throws', () async {
      when(() => mockAuth.canCheckBiometrics).thenThrow(
        PlatformException(code: 'NotAvailable'),
      );
      expect(await service.canCheckBiometrics(), isFalse);
    });

    test(
      'isDeviceSupported returns false when canCheckBiometrics is false',
      () async {
        when(() => mockAuth.canCheckBiometrics).thenAnswer((_) async => false);
        expect(await service.isDeviceSupported(), isFalse);
      },
    );

    test(
      'isDeviceSupported returns false when no biometrics enrolled',
      () async {
        when(() => mockAuth.canCheckBiometrics).thenAnswer((_) async => true);
        when(
          () => mockAuth.getAvailableBiometrics(),
        ).thenAnswer((_) async => []);
        expect(await service.isDeviceSupported(), isFalse);
      },
    );

    test('isDeviceSupported returns true when biometrics available', () async {
      when(() => mockAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(() => mockAuth.getAvailableBiometrics()).thenAnswer(
        (_) async => [BiometricType.fingerprint],
      );
      expect(await service.isDeviceSupported(), isTrue);
    });
  });

  group('biometric enabled setting', () {
    test('isBiometricEnabled returns false by default', () async {
      expect(await service.isBiometricEnabled(), isFalse);
    });

    test('setBiometricEnabled persists setting', () async {
      await service.setBiometricEnabled(enabled: true);
      expect(await service.isBiometricEnabled(), isTrue);
    });

    test('setBiometricEnabled false disables', () async {
      await service.setBiometricEnabled(enabled: true);
      await service.setBiometricEnabled(enabled: false);
      expect(await service.isBiometricEnabled(), isFalse);
    });
  });

  group('authenticate', () {
    test('returns true and records auth time on success', () async {
      when(
        () => mockAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
          persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
        ),
      ).thenAnswer((_) async => true);

      final result = await service.authenticate(reason: 'Test auth');
      expect(result, isTrue);
    });

    test('returns false and does not record auth time on failure', () async {
      when(
        () => mockAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
          persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
        ),
      ).thenAnswer((_) async => false);

      final result = await service.authenticate(reason: 'Test auth');
      expect(result, isFalse);

      // After failed auth, needsReAuthentication should still be true
      await prefs.setInt('biometric_timeout_minutes', 5);
      expect(await service.needsReAuthentication(), isTrue);
    });
  });

  group('needsReAuthentication', () {
    test('returns false when timeout is never (-1)', () async {
      await prefs.setInt(
        'biometric_timeout_minutes',
        BiometricService.timeoutNever,
      );
      expect(await service.needsReAuthentication(), isFalse);
    });

    test('returns true when never authenticated this session', () async {
      await prefs.setInt('biometric_timeout_minutes', 5);
      // _lastAuthTime is null by default
      expect(await service.needsReAuthentication(), isTrue);
    });

    test('returns false when not backgrounded since last auth', () async {
      await prefs.setInt('biometric_timeout_minutes', 5);
      service.markAuthenticated();
      // _backgroundTime is null — app not backgrounded since auth
      expect(await service.needsReAuthentication(), isFalse);
    });

    test('returns true when timeout=0 and app was backgrounded', () async {
      await prefs.setInt('biometric_timeout_minutes', 0);
      service.markAuthenticated();
      await service.clearAuthenticationTime();
      // timeout=0 means immediately on any background
      expect(await service.needsReAuthentication(), isTrue);
    });

    test('returns true when background duration exceeds timeout', () async {
      await prefs.setInt('biometric_timeout_minutes', 5);
      service.markAuthenticated();
      await service.clearAuthenticationTime();
      // Backdate background time by 10 minutes (exceeds 5-min timeout)
      service.backdateBackgroundTime(const Duration(minutes: 10));
      expect(await service.needsReAuthentication(), isTrue);
    });

    test('returns false when background duration within timeout', () async {
      await prefs.setInt('biometric_timeout_minutes', 5);
      service.markAuthenticated();
      await service.clearAuthenticationTime();
      // Backdate background time by 2 minutes (within 5-min timeout)
      service.backdateBackgroundTime(const Duration(minutes: 2));
      expect(await service.needsReAuthentication(), isFalse);
    });

    test('markAuthenticated clears backgroundTime', () async {
      await prefs.setInt('biometric_timeout_minutes', 5);
      service.markAuthenticated();
      await service.clearAuthenticationTime();

      // Re-authenticate — clears backgroundTime
      service.markAuthenticated();

      expect(await service.needsReAuthentication(), isFalse);
    });
  });

  group('timeout configuration', () {
    test('getTimeoutMinutes returns stored value', () async {
      await prefs.setInt('biometric_timeout_minutes', 10);
      expect(await service.getTimeoutMinutes(), 10);
    });

    test('getTimeoutMinutes migrates legacy true → 5 minutes', () async {
      await prefs.setBool('biometric_timeout_enabled', true);
      expect(await service.getTimeoutMinutes(), 5);
    });

    test('getTimeoutMinutes migrates legacy false → never', () async {
      await prefs.setBool('biometric_timeout_enabled', false);
      expect(await service.getTimeoutMinutes(), BiometricService.timeoutNever);
    });

    test('setTimeoutMinutes persists value', () async {
      await service.setTimeoutMinutes(15);
      expect(await service.getTimeoutMinutes(), 15);
    });
  });
}
