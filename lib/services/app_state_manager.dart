import 'package:flutter/foundation.dart';
import '../models/service_instance.dart';
import 'instance_manager.dart';
import 'cache_manager.dart';

/// Centralized app state manager that coordinates instance switching and cache invalidation
/// This is the single source of truth for active instances across the app
class AppStateManager extends ChangeNotifier {
  static final AppStateManager _instance = AppStateManager._internal();
  factory AppStateManager() => _instance;
  AppStateManager._internal();

  final InstanceManager _instanceManager = InstanceManager();
  final CacheManager _cacheManager = CacheManager();

  ServiceInstance? _activeSonarrInstance;
  ServiceInstance? _activeRadarrInstance;
  bool _isInitialized = false;

  ServiceInstance? get activeSonarrInstance => _activeSonarrInstance;
  ServiceInstance? get activeRadarrInstance => _activeRadarrInstance;
  bool get isInitialized => _isInitialized;

  /// Initialize by loading active instances from storage
  Future<void> initialize() async {
    _activeSonarrInstance = await _instanceManager.getActiveSonarrInstance();
    _activeRadarrInstance = await _instanceManager.getActiveRadarrInstance();
    _isInitialized = true;
    notifyListeners();
  }

  /// Switch the active Sonarr instance
  Future<void> switchSonarrInstance(String instanceId) async {
    await _instanceManager.setActiveSonarrId(instanceId);
    // Load full instance WITH credentials before notifying
    // This ensures AppConfig returns correct credentials when services initialize
    _activeSonarrInstance = await _instanceManager.getActiveSonarrInstance();
    // Clear the new instance's cache to force fresh data load
    clearSonarrCache();
    // Now notify - services will have correct credentials
    notifyListeners();
  }

  /// Switch the active Radarr instance
  Future<void> switchRadarrInstance(String instanceId) async {
    await _instanceManager.setActiveRadarrId(instanceId);
    // Load full instance WITH credentials before notifying
    // This ensures AppConfig returns correct credentials when services initialize
    _activeRadarrInstance = await _instanceManager.getActiveRadarrInstance();
    // Clear the new instance's cache to force fresh data load
    clearRadarrCache();
    // Now notify - services will have correct credentials
    notifyListeners();
  }

  /// Reload instances (called after settings changes or import)
  Future<void> reloadInstances() async {
    _activeSonarrInstance = await _instanceManager.getActiveSonarrInstance();
    _activeRadarrInstance = await _instanceManager.getActiveRadarrInstance();

    // Clear NEW instances' caches to force fresh data load
    clearSonarrCache();
    clearRadarrCache();

    notifyListeners();
  }

  /// Get cache for the active Sonarr instance
  CachedData? getSonarrCache(String cacheKey) {
    final instanceId = getActiveSonarrId();
    if (instanceId == null) return null;
    final fullKey = '${cacheKey}_$instanceId';

    if (!_cacheManager.exists(fullKey)) return null;

    return CachedData(
      data: _cacheManager.get(fullKey),
      isValid: _cacheManager.isValid(fullKey),
      isStale: _cacheManager.isStale(fullKey),
    );
  }

  /// Get cache for the active Radarr instance
  CachedData? getRadarrCache(String cacheKey) {
    final instanceId = getActiveRadarrId();
    if (instanceId == null) return null;
    final fullKey = '${cacheKey}_$instanceId';

    if (!_cacheManager.exists(fullKey)) return null;

    return CachedData(
      data: _cacheManager.get(fullKey),
      isValid: _cacheManager.isValid(fullKey),
      isStale: _cacheManager.isStale(fullKey),
    );
  }

  /// Set cache for the active Sonarr instance
  void setSonarrCache(String cacheKey, dynamic data) {
    final instanceId = getActiveSonarrId();
    if (instanceId == null) return;
    final fullKey = '${cacheKey}_$instanceId';
    _cacheManager.set(fullKey, data);
  }

  /// Set cache for the active Radarr instance
  void setRadarrCache(String cacheKey, dynamic data) {
    final instanceId = getActiveRadarrId();
    if (instanceId == null) return;
    final fullKey = '${cacheKey}_$instanceId';
    _cacheManager.set(fullKey, data);
  }

  /// Clear all Sonarr cache for active instance
  void clearSonarrCache() {
    final instanceId = getActiveSonarrId();
    if (instanceId != null) {
      _cacheManager.clearInstance(instanceId);
    }
  }

  /// Clear all Radarr cache for active instance
  void clearRadarrCache() {
    final instanceId = getActiveRadarrId();
    if (instanceId != null) {
      _cacheManager.clearInstance(instanceId);
    }
  }

  /// Get all Sonarr instances (metadata only - fast)
  List<Map<String, dynamic>> getSonarrInstancesMetadata() {
    return _instanceManager.getSonarrInstancesMetadata();
  }

  /// Get all Radarr instances (metadata only - fast)
  List<Map<String, dynamic>> getRadarrInstancesMetadata() {
    return _instanceManager.getRadarrInstancesMetadata();
  }

  /// Get active Sonarr instance ID (synchronous)
  String? getActiveSonarrId() {
    return _instanceManager.getActiveSonarrId();
  }

  /// Get active Radarr instance ID (synchronous)
  String? getActiveRadarrId() {
    return _instanceManager.getActiveRadarrId();
  }

  // --- Instance CRUD ---
  // All mutations go through AppStateManager so persistence, in-memory state,
  // and listener notifications are always kept in sync atomically.

  Future<void> addSonarrInstance(ServiceInstance instance) async {
    await _instanceManager.addSonarrInstance(instance);
    if (_instanceManager.getActiveSonarrId() == instance.id) {
      _activeSonarrInstance = await _instanceManager.getActiveSonarrInstance();
    }
    notifyListeners();
  }

  Future<void> updateSonarrInstance(ServiceInstance instance) async {
    await _instanceManager.updateSonarrInstance(instance);
    if (_instanceManager.getActiveSonarrId() == instance.id) {
      _activeSonarrInstance = await _instanceManager.getActiveSonarrInstance();
      clearSonarrCache();
    }
    notifyListeners();
  }

  Future<void> deleteSonarrInstance(String id) async {
    final wasActive = _instanceManager.getActiveSonarrId() == id;
    await _instanceManager.deleteSonarrInstance(id);
    _cacheManager.clearInstance(id);
    if (wasActive) {
      final remaining = _instanceManager.getSonarrInstancesMetadata();
      if (remaining.isNotEmpty) {
        await _instanceManager.setActiveSonarrId(
          remaining.first['id'] as String,
        );
        _activeSonarrInstance = await _instanceManager
            .getActiveSonarrInstance();
        clearSonarrCache();
      } else {
        _activeSonarrInstance = null;
      }
    }
    notifyListeners();
  }

  Future<void> addRadarrInstance(ServiceInstance instance) async {
    await _instanceManager.addRadarrInstance(instance);
    if (_instanceManager.getActiveRadarrId() == instance.id) {
      _activeRadarrInstance = await _instanceManager.getActiveRadarrInstance();
    }
    notifyListeners();
  }

  Future<void> updateRadarrInstance(ServiceInstance instance) async {
    await _instanceManager.updateRadarrInstance(instance);
    if (_instanceManager.getActiveRadarrId() == instance.id) {
      _activeRadarrInstance = await _instanceManager.getActiveRadarrInstance();
      clearRadarrCache();
    }
    notifyListeners();
  }

  Future<void> deleteRadarrInstance(String id) async {
    final wasActive = _instanceManager.getActiveRadarrId() == id;
    await _instanceManager.deleteRadarrInstance(id);
    _cacheManager.clearInstance(id);
    if (wasActive) {
      final remaining = _instanceManager.getRadarrInstancesMetadata();
      if (remaining.isNotEmpty) {
        await _instanceManager.setActiveRadarrId(
          remaining.first['id'] as String,
        );
        _activeRadarrInstance = await _instanceManager
            .getActiveRadarrInstance();
        clearRadarrCache();
      } else {
        _activeRadarrInstance = null;
      }
    }
    notifyListeners();
  }

  /// Get active Sonarr instance name (fast, from SharedPreferences metadata)
  String? getActiveSonarrName() {
    final id = getActiveSonarrId();
    if (id == null) return null;
    final metadata = _instanceManager.getSonarrInstancesMetadata();
    for (final instance in metadata) {
      if (instance['id'] == id) {
        return instance['name'] as String?;
      }
    }
    return null;
  }

  /// Get active Radarr instance name (fast, from SharedPreferences metadata)
  String? getActiveRadarrName() {
    final id = getActiveRadarrId();
    if (id == null) return null;
    final metadata = _instanceManager.getRadarrInstancesMetadata();
    for (final instance in metadata) {
      if (instance['id'] == id) {
        return instance['name'] as String?;
      }
    }
    return null;
  }

  /// Manually trigger listeners (use when active ID changed but full instance not loaded yet)
  void triggerRefresh() {
    notifyListeners();
  }
}

/// Container for cached data with metadata
class CachedData {
  final dynamic data;
  final bool isValid;
  final bool isStale;

  CachedData({
    required this.data,
    required this.isValid,
    required this.isStale,
  });
}
