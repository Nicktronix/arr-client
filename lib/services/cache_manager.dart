/// Centralized cache manager for API responses
/// Handles instance-specific caching with time-based invalidation and memory management
class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, int> _accessCount = {}; // Track access frequency for LRU

  static const Duration cacheValidity = Duration(minutes: 5);
  static const int maxCacheEntries = 100; // Prevent unlimited memory growth

  /// Get cached data for a given key
  dynamic get(String key) {
    if (_cache.containsKey(key)) {
      _accessCount[key] = (_accessCount[key] ?? 0) + 1;
    }
    return _cache[key];
  }

  /// Check if cache exists and is valid for a given key
  bool isValid(String key) {
    if (!_cache.containsKey(key) || !_cacheTimestamps.containsKey(key)) {
      return false;
    }

    final age = DateTime.now().difference(_cacheTimestamps[key]!);
    return age < cacheValidity;
  }

  /// Check if cache exists but is stale (older than validity period)
  bool isStale(String key) {
    if (!_cache.containsKey(key) || !_cacheTimestamps.containsKey(key)) {
      return false;
    }

    final age = DateTime.now().difference(_cacheTimestamps[key]!);
    return age >= cacheValidity;
  }

  /// Check if cache exists (regardless of validity)
  bool exists(String key) {
    return _cache.containsKey(key);
  }

  /// Set cached data for a given key
  void set(String key, dynamic data) {
    // Evict old entries if cache is full
    if (_cache.length >= maxCacheEntries && !_cache.containsKey(key)) {
      _evictLeastRecentlyUsed();
    }

    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
    _accessCount[key] = 0;
  }

  /// Evict least recently used cache entry to prevent memory leaks
  void _evictLeastRecentlyUsed() {
    if (_cache.isEmpty) return;

    // Find entries older than validity period first
    final now = DateTime.now();
    final staleKeys = _cacheTimestamps.entries
        .where((e) => now.difference(e.value) > cacheValidity)
        .map((e) => e.key)
        .toList();

    if (staleKeys.isNotEmpty) {
      // Remove stale entries
      for (final key in staleKeys) {
        _cache.remove(key);
        _cacheTimestamps.remove(key);
        _accessCount.remove(key);
      }
      return;
    }

    // If no stale entries, remove least accessed
    String? lruKey;
    int minAccess = double.maxFinite.toInt();

    for (final entry in _accessCount.entries) {
      if (entry.value < minAccess) {
        minAccess = entry.value;
        lruKey = entry.key;
      }
    }

    if (lruKey != null) {
      _cache.remove(lruKey);
      _cacheTimestamps.remove(lruKey);
      _accessCount.remove(lruKey);
    }
  }

  /// Clear specific cache entry
  void clear(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
    _accessCount.remove(key);
  }

  /// Clear all cache entries
  void clearAll() {
    _cache.clear();
    _cacheTimestamps.clear();
    _accessCount.clear();
  }

  /// Clear all cache entries for a specific instance
  void clearInstance(String instanceId) {
    final keysToRemove = _cache.keys
        .where((key) => key.contains(instanceId))
        .toList();

    for (final key in keysToRemove) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
      _accessCount.remove(key);
    }
  }

  /// Get cache statistics for monitoring
  Map<String, dynamic> getStats() {
    return {
      'totalEntries': _cache.length,
      'maxEntries': maxCacheEntries,
      'memoryUsage':
          '${(_cache.length / maxCacheEntries * 100).toStringAsFixed(1)}%',
      'validEntries': _cache.keys.where((k) => isValid(k)).length,
      'staleEntries': _cache.keys.where((k) => isStale(k)).length,
    };
  }
}
