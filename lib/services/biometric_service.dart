import 'package:injectable/injectable.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class BiometricService {
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricTimeoutLegacyKey = 'biometric_timeout_enabled';
  static const String _biometricTimeoutMinutesKey = 'biometric_timeout_minutes';

  static const int timeoutNever = -1;

  final LocalAuthentication _localAuth;
  final SharedPreferences _prefs;
  DateTime? _lastAuthTime;
  // Tracks when the app was backgrounded. Null means the app has not been
  // backgrounded since last auth (or auth cleared it). needsReAuthentication
  // checks elapsed time since this point, not since _lastAuthTime, so that
  // a successful re-auth clears it and prevents re-prompting on the resumed
  // lifecycle event that fires when the biometric dialog dismisses.
  DateTime? _backgroundTime;

  BiometricService(this._localAuth, this._prefs);

  /// Check if device supports biometric authentication
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  /// Check if device has biometrics enrolled
  Future<bool> isDeviceSupported() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Check if biometric auth is enabled in settings
  Future<bool> isBiometricEnabled() async {
    return _prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Enable or disable biometric authentication
  Future<void> setBiometricEnabled({required bool enabled}) async {
    await _prefs.setBool(_biometricEnabledKey, enabled);
    if (enabled) {
      _lastAuthTime = DateTime.now();
      _backgroundTime = null;
    }
  }

  /// Get the configured re-authentication timeout in minutes.
  ///
  /// Returns [timeoutNever] (-1) to never re-authenticate after backgrounding.
  /// Returns 0 to re-authenticate immediately on every foreground.
  /// Returns a positive integer for a minute-based timeout.
  ///
  /// Migrates from the legacy bool key on first read.
  Future<int> getTimeoutMinutes() async {
    if (_prefs.containsKey(_biometricTimeoutMinutesKey)) {
      return _prefs.getInt(_biometricTimeoutMinutesKey) ?? 5;
    }
    // Migrate from legacy bool: true → 5 min, false → never
    final legacyEnabled = _prefs.getBool(_biometricTimeoutLegacyKey) ?? true;
    return legacyEnabled ? 5 : timeoutNever;
  }

  /// Set the re-authentication timeout. Use [timeoutNever] to disable.
  Future<void> setTimeoutMinutes(int minutes) async {
    await _prefs.setInt(_biometricTimeoutMinutesKey, minutes);
  }

  /// Authenticate with biometrics.
  /// Returns true if authentication succeeded, false otherwise.
  /// Throws PlatformException if the platform reports an auth error.
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = false,
  }) async {
    final didAuthenticate = await _localAuth.authenticate(
      localizedReason: reason,
      biometricOnly: biometricOnly,
      persistAcrossBackgrounding: true, // v3.0.0: replaces stickyAuth
    );

    if (didAuthenticate) {
      _lastAuthTime = DateTime.now();
      // Clear background time so the resumed event that fires when the
      // biometric dialog dismisses does not trigger another re-auth prompt.
      _backgroundTime = null;
    }

    return didAuthenticate;
  }

  /// Check if re-authentication is required based on the configured timeout.
  /// Returns true if the user should be prompted to authenticate again.
  Future<bool> needsReAuthentication() async {
    final timeout = await getTimeoutMinutes();
    if (timeout == timeoutNever) return false;
    if (_lastAuthTime == null) return true; // Never authenticated this session
    if (_backgroundTime == null) {
      return false; // Not backgrounded since last auth
    }
    if (timeout == 0) {
      return true; // Immediately — any background triggers re-auth
    }
    return DateTime.now().difference(_backgroundTime!).inMinutes >= timeout;
  }

  /// Mark that user has just authenticated (called after successful auth)
  void markAuthenticated() {
    _lastAuthTime = DateTime.now();
    _backgroundTime = null;
  }

  /// Record that the app has been backgrounded. Call only on AppLifecycleState.paused
  /// (not inactive — inactive fires for overlays and the biometric dialog itself).
  Future<void> clearAuthenticationTime() async {
    final timeout = await getTimeoutMinutes();
    if (timeout != timeoutNever) {
      _backgroundTime = DateTime.now();
    }
  }

  /// Require authentication for sensitive operation
  /// Shows appropriate error messages
  Future<bool> authenticateForSensitiveOperation({
    required String operation,
  }) async {
    if (!await isBiometricEnabled()) return true;

    return authenticate(
      reason: 'Authentication required to $operation',
      biometricOnly: false,
    );
  }
}
