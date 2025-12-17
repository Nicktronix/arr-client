import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing biometric authentication
class BiometricService {
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _biometricTimeoutKey = 'biometric_timeout_enabled';

  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  SharedPreferences? _prefs;
  DateTime? _lastAuthTime;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

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
    final prefs = await _preferences;
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Enable or disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await _preferences;
    await prefs.setBool(_biometricEnabledKey, enabled);
    if (enabled) {
      _lastAuthTime = DateTime.now();
    }
  }

  /// Check if timeout is enabled (re-auth after background)
  Future<bool> isTimeoutEnabled() async {
    final prefs = await _preferences;
    return prefs.getBool(_biometricTimeoutKey) ?? true; // Default true
  }

  /// Enable or disable timeout feature
  Future<void> setTimeoutEnabled(bool enabled) async {
    final prefs = await _preferences;
    await prefs.setBool(_biometricTimeoutKey, enabled);
  }

  /// Authenticate with biometrics
  /// Returns true if authentication succeeded, false otherwise
  /// Throws LocalAuthException with details if authentication fails
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = false,
  }) async {
    final bool didAuthenticate = await _localAuth.authenticate(
      localizedReason: reason,
      biometricOnly: biometricOnly,
      persistAcrossBackgrounding: true, // v3.0.0: replaces stickyAuth
    );

    if (didAuthenticate) {
      _lastAuthTime = DateTime.now();
    }

    return didAuthenticate;
  }

  /// Check if authentication is required based on timeout
  /// Returns true if enough time has passed since last auth
  Future<bool> needsReAuthentication({int timeoutMinutes = 5}) async {
    if (!await isTimeoutEnabled()) return false;
    if (_lastAuthTime == null) return true;

    final now = DateTime.now();
    final difference = now.difference(_lastAuthTime!);
    return difference.inMinutes >= timeoutMinutes;
  }

  /// Mark that user has just authenticated (called after successful auth)
  void markAuthenticated() {
    _lastAuthTime = DateTime.now();
  }

  /// Clear authentication timestamp (call when app is backgrounded)
  Future<void> clearAuthenticationTime() async {
    if (await isTimeoutEnabled()) {
      _lastAuthTime = null;
    }
  }

  /// Require authentication for sensitive operation
  /// Shows appropriate error messages
  Future<bool> authenticateForSensitiveOperation({
    required String operation,
  }) async {
    if (!await isBiometricEnabled()) return true;

    return await authenticate(
      reason: 'Authentication required to $operation',
      biometricOnly: false,
    );
  }
}
