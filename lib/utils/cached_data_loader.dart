import 'package:flutter/material.dart';
import '../services/app_state_manager.dart';

/// Standardized loading states for all screens
enum LoadingState {
  initial, // First load, show spinner
  loading, // Loading with no data, show spinner
  loaded, // Data loaded successfully
  error, // Error occurred
  empty, // No data available (different from error)
}

/// Base mixin for screens that load data with caching support
/// Provides consistent loading, empty state, and error handling
mixin CachedDataLoader<T extends StatefulWidget> on State<T> {
  LoadingState _loadingState = LoadingState.initial;
  String? _errorMessage;
  final AppStateManager _appState = AppStateManager();

  LoadingState get loadingState => _loadingState;
  String? get errorMessage => _errorMessage;
  AppStateManager get appState => _appState;

  /// Override to specify the cache key for this screen
  String get cacheKey;

  /// Manually set loading state (for instant feedback before async operations)
  void setLoadingState() {
    if (mounted) {
      setState(() {
        _loadingState = LoadingState.loading;
        _errorMessage = null;
      });
    }
  }

  /// Override to specify if this is a Sonarr or Radarr screen
  bool get isSonarrScreen;

  /// Override to implement the actual data fetching
  Future<dynamic> fetchData();

  /// Override to handle the fetched data
  void onDataLoaded(dynamic data);

  /// Load data with automatic cache checking
  Future<void> loadData({bool forceRefresh = false}) async {
    CachedData? cachedData;

    // If forcing refresh (e.g., instance switch), show loading state immediately
    if (forceRefresh) {
      if (mounted) {
        setState(() {
          _loadingState = LoadingState.loading;
          _errorMessage = null;
        });
      }
    } else {
      // Check cache first when not forcing refresh
      cachedData = isSonarrScreen
          ? _appState.getSonarrCache(cacheKey)
          : _appState.getRadarrCache(cacheKey);

      // If cache is valid and not forcing refresh, use it
      if (cachedData != null && cachedData.isValid) {
        if (mounted) {
          setState(() {
            _loadingState = LoadingState.loaded;
            _errorMessage = null;
          });
          onDataLoaded(cachedData.data);
          return;
        }
      }

      // If cache is stale, show it while refreshing
      if (cachedData != null && cachedData.isStale) {
        if (mounted) {
          setState(() {
            _loadingState = LoadingState.loaded;
            _errorMessage = null;
          });
          onDataLoaded(cachedData.data);
          // Continue to fetch in background
        }
      } else if (_loadingState == LoadingState.initial) {
        // Only show loading on first load
        if (mounted) {
          setState(() {
            _loadingState = LoadingState.loading;
            _errorMessage = null;
          });
        }
      }
    }

    try {
      final data = await fetchData();

      // Update cache
      if (isSonarrScreen) {
        _appState.setSonarrCache(cacheKey, data);
      } else {
        _appState.setRadarrCache(cacheKey, data);
      }

      if (mounted) {
        setState(() {
          _loadingState = LoadingState.loaded;
          _errorMessage = null;
        });
        onDataLoaded(data);
      }
    } catch (e) {
      if (mounted) {
        // Only show error if we don't have cached data
        if (cachedData == null) {
          setState(() {
            _loadingState = LoadingState.error;
            _errorMessage = e.toString();
          });
        }
      }
    }
  }

  /// Build loading indicator
  Widget buildLoadingIndicator({String message = 'Loading...'}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }

  /// Build error state
  Widget buildErrorState({required VoidCallback onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error loading data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state
  Widget buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Standard body builder that handles all states
  Widget buildBody({
    required Widget Function() buildContent,
    required bool isEmpty,
    required Widget emptyStateWidget,
  }) {
    switch (_loadingState) {
      case LoadingState.initial:
      case LoadingState.loading:
        return buildLoadingIndicator();

      case LoadingState.error:
        return buildErrorState(onRetry: () => loadData(forceRefresh: true));

      case LoadingState.loaded:
        if (isEmpty) {
          return emptyStateWidget;
        }
        return buildContent();

      case LoadingState.empty:
        return emptyStateWidget;
    }
  }
}
