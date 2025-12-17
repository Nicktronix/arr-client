import '../services/app_state_manager.dart';
import '../services/instance_manager.dart';

/// Configuration getters that delegate to AppStateManager and InstanceManager
/// Uses CURRENT active ID from SharedPreferences, not cached instance object
/// This ensures credentials always match the currently selected instance
class AppConfig {
  static final AppStateManager _appState = AppStateManager();
  static final InstanceManager _instanceManager = InstanceManager();

  // Sonarr Configuration - loads credentials on-demand using current ID
  static String get sonarrBaseUrl {
    final id = _appState.getActiveSonarrId();
    if (id == null) return '';
    final metadata = _instanceManager.getSonarrInstancesMetadata();
    try {
      final instance = metadata.firstWhere((m) => m['id'] == id);
      return instance['baseUrl'] as String? ?? '';
    } catch (e) {
      return '';
    }
  }

  static String get sonarrApiKey {
    // API key must be loaded from secure storage via the cached instance
    // If not loaded yet, return empty (service will throw validation error)
    return _appState.activeSonarrInstance?.apiKey ?? '';
  }

  static String? get sonarrBasicAuthUsername {
    return _appState.activeSonarrInstance?.basicAuthUsername;
  }

  static String? get sonarrBasicAuthPassword {
    return _appState.activeSonarrInstance?.basicAuthPassword;
  }

  static String? get activeSonarrInstanceId {
    return _appState.getActiveSonarrId();
  }

  // Radarr Configuration - loads credentials on-demand using current ID
  static String get radarrBaseUrl {
    final id = _appState.getActiveRadarrId();
    if (id == null) return '';
    final metadata = _instanceManager.getRadarrInstancesMetadata();
    try {
      final instance = metadata.firstWhere((m) => m['id'] == id);
      return instance['baseUrl'] as String? ?? '';
    } catch (e) {
      return '';
    }
  }

  static String get radarrApiKey {
    // API key must be loaded from secure storage via the cached instance
    // If not loaded yet, return empty (service will throw validation error)
    return _appState.activeRadarrInstance?.apiKey ?? '';
  }

  static String? get radarrBasicAuthUsername {
    return _appState.activeRadarrInstance?.basicAuthUsername;
  }

  static String? get radarrBasicAuthPassword {
    return _appState.activeRadarrInstance?.basicAuthPassword;
  }

  static String? get activeRadarrInstanceId {
    return _appState.getActiveRadarrId();
  }
}
