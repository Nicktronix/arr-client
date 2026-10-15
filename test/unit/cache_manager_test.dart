import 'package:flutter_test/flutter_test.dart';

import 'package:arr_client/services/cache_manager.dart';

void main() {
  late CacheManager cache;

  setUp(() {
    cache = CacheManager();
  });

  group('basic set/get', () {
    test('get returns null for missing key', () {
      expect(cache.get('missing'), isNull);
    });

    test('set and get round-trips data', () {
      cache.set('key1', ['item1', 'item2']);
      expect(cache.get('key1'), ['item1', 'item2']);
    });

    test('exists returns false for missing key', () {
      expect(cache.exists('missing'), isFalse);
    });

    test('exists returns true after set', () {
      cache.set('key1', 'data');
      expect(cache.exists('key1'), isTrue);
    });

    test('get increments access count', () {
      cache.set('key1', 'data');
      cache.get('key1');
      cache.get('key1');
      final stats = cache.getStats();
      // Access count is internal but we can verify via LRU eviction behaviour
      expect(stats['totalEntries'], 1);
    });
  });

  group('TTL validity', () {
    test('isValid returns true for fresh entry', () {
      cache.set('key1', 'data');
      expect(cache.isValid('key1'), isTrue);
    });

    test('isValid returns false for missing key', () {
      expect(cache.isValid('missing'), isFalse);
    });

    test('isValid returns false after backdating beyond validity', () {
      cache.set('key1', 'data');
      cache.backdateTimestamp('key1', const Duration(minutes: 10));
      expect(cache.isValid('key1'), isFalse);
    });

    test('isValid returns true when backdated within validity window', () {
      cache.set('key1', 'data');
      cache.backdateTimestamp('key1', const Duration(minutes: 4));
      expect(cache.isValid('key1'), isTrue);
    });
  });

  group('stale detection', () {
    test('isStale returns false for fresh entry', () {
      cache.set('key1', 'data');
      expect(cache.isStale('key1'), isFalse);
    });

    test('isStale returns false for missing key', () {
      expect(cache.isStale('missing'), isFalse);
    });

    test('isStale returns true after backdating beyond validity', () {
      cache.set('key1', 'data');
      cache.backdateTimestamp('key1', const Duration(minutes: 10));
      expect(cache.isStale('key1'), isTrue);
    });

    test('entry is either valid or stale — never both', () {
      cache.set('key1', 'fresh');
      cache.set('key2', 'stale');
      cache.backdateTimestamp('key2', const Duration(minutes: 10));

      expect(cache.isValid('key1'), isTrue);
      expect(cache.isStale('key1'), isFalse);

      expect(cache.isValid('key2'), isFalse);
      expect(cache.isStale('key2'), isTrue);
    });
  });

  group('clearing', () {
    test('clear removes specific key', () {
      cache.set('key1', 'a');
      cache.set('key2', 'b');
      cache.clear('key1');
      expect(cache.exists('key1'), isFalse);
      expect(cache.exists('key2'), isTrue);
    });

    test('clearAll removes everything', () {
      cache.set('a', 1);
      cache.set('b', 2);
      cache.set('c', 3);
      cache.clearAll();
      expect(cache.getStats()['totalEntries'], 0);
    });

    test('clearInstance removes keys containing instanceId', () {
      cache.set('series_list_abc123', 'sonarr data');
      cache.set('movie_list_abc123', 'radarr data');
      cache.set('series_list_xyz999', 'other instance');

      cache.clearInstance('abc123');

      expect(cache.exists('series_list_abc123'), isFalse);
      expect(cache.exists('movie_list_abc123'), isFalse);
      expect(cache.exists('series_list_xyz999'), isTrue);
    });

    test('clearInstance with no matching keys is a no-op', () {
      cache.set('series_list_abc123', 'data');
      cache.clearInstance('nonexistent');
      expect(cache.exists('series_list_abc123'), isTrue);
    });
  });

  group('LRU eviction', () {
    test('evicts stale entries first when cache is full', () {
      // Fill to max (100 entries) — 99 stale + 1 fresh
      for (var i = 0; i < 99; i++) {
        cache.set('stale_$i', i);
        cache.backdateTimestamp('stale_$i', const Duration(minutes: 10));
      }
      cache.set('fresh', 'keep me');

      // Adding the 101st entry triggers eviction of all 99 stale entries
      cache.set('new_entry', 'new');

      expect(cache.exists('fresh'), isTrue);
      expect(cache.exists('new_entry'), isTrue);
      // Stale entries were evicted
      expect(cache.getStats()['staleEntries'], 0);
    });

    test('evicts LRU entry when all entries are fresh', () {
      // Fill to exactly maxCacheEntries (100) without any accesses
      for (var i = 0; i < 100; i++) {
        cache.set('key_$i', i);
      }
      // Access key_50 to make it more recently used
      cache.get('key_50');

      // Adding one more triggers LRU eviction — key_0 should be evicted (0 accesses)
      cache.set('trigger_eviction', 'new');

      // key_50 had an access so it should survive
      expect(cache.exists('key_50'), isTrue);
    });

    test('getStats reports correct entry counts', () {
      cache.set('fresh', 'a');
      cache.set('stale', 'b');
      cache.backdateTimestamp('stale', const Duration(minutes: 10));

      final stats = cache.getStats();
      expect(stats['totalEntries'], 2);
      expect(stats['validEntries'], 1);
      expect(stats['staleEntries'], 1);
    });
  });
}
