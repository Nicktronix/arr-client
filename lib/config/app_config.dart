import 'package:arr_client/di/injection.dart';
import 'package:arr_client/services/app_state_manager.dart';

class AppConfig {
  static AppStateManager get _appState => getIt<AppStateManager>();

  static String get sonarrBaseUrl =>
      _appState.activeSonarrInstance?.baseUrl ?? '';

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

  static String get radarrBaseUrl =>
      _appState.activeRadarrInstance?.baseUrl ?? '';

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
