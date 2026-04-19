import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arr_client/di/injection.dart';
import 'package:arr_client/services/app_state_manager.dart';
import 'package:arr_client/services/cache_manager.dart';
import 'package:arr_client/screens/home_screen.dart';
import 'package:arr_client/models/service_instance.dart';
import 'package:arr_client/utils/cached_data_loader.dart';
import 'package:arr_client/utils/error_formatter.dart' as error_utils;
import 'package:arr_client/services/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home Screen Widget Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await getIt.reset();
      await configureDependencies();
      await getIt<AppStateManager>().initialize();
    });

    testWidgets('displays all navigation tabs and icons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      // Verify bottom navigation bar has all 4 tabs
      expect(find.text('Sonarr'), findsAtLeast(1));
      expect(find.text('Radarr'), findsAtLeast(1));
      expect(find.text('Queue'), findsAtLeast(1));
      expect(find.text('History'), findsAtLeast(1));

      // Verify navigation icons
      expect(find.byIcon(Icons.tv), findsAtLeast(1));
      expect(find.byIcon(Icons.movie), findsAtLeast(1));
      expect(find.byIcon(Icons.download), findsAtLeast(1));
      expect(find.byIcon(Icons.history), findsAtLeast(1));

      // Verify settings button in AppBar
      expect(find.byIcon(Icons.settings), findsAtLeast(1));
    });

    testWidgets('switches between tabs correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      // Start on Sonarr tab - verify title changes
      expect(find.text('Sonarr'), findsAtLeast(1));

      // Switch to Radarr tab
      await tester.tap(find.text('Radarr').last);
      await tester.pumpAndSettle();
      // AppBar title should update to "Radarr"
      expect(find.widgetWithText(AppBar, 'Radarr'), findsOneWidget);

      // Switch to Queue tab
      await tester.tap(find.text('Queue').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Queue'), findsOneWidget);

      // Switch to History tab
      await tester.tap(find.text('History').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'History'), findsOneWidget);
    });

    testWidgets('shows empty state when no instances configured', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      // Verify empty state for Sonarr (default first tab)
      expect(find.text('No Sonarr Instance'), findsOneWidget);
      expect(
        find.text('Add a Sonarr instance in Settings to manage your TV series'),
        findsOneWidget,
      );

      // Verify "Open Settings" button is present
      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('drawer opens and contains menu items', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      // Open drawer by tapping menu icon
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // Verify drawer content
      expect(find.text('Arr Client'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('System Status'), findsOneWidget);
      expect(find.text('Settings'), findsAtLeast(1));
    });
  });

  group('Service Instance Model Tests', () {
    test('creates instance with required fields', () {
      const instance = ServiceInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'test-api-key-1234567890abcdef',
      );

      expect(instance.id, 'test-id');
      expect(instance.name, 'Test Instance');
      expect(instance.baseUrl, 'https://sonarr.example.com');
      expect(instance.apiKey, 'test-api-key-1234567890abcdef');
      expect(instance.basicAuthUsername, isNull);
      expect(instance.basicAuthPassword, isNull);
    });

    test('creates instance with optional basic auth', () {
      const instance = ServiceInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'test-api-key',
        basicAuthUsername: 'user',
        basicAuthPassword: 'pass',
      );

      expect(instance.basicAuthUsername, 'user');
      expect(instance.basicAuthPassword, 'pass');
    });

    test('serializes to JSON correctly', () {
      const instance = ServiceInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'test-api-key',
        basicAuthUsername: 'user',
        basicAuthPassword: 'pass',
      );

      final json = instance.toJson();

      expect(json['id'], 'test-id');
      expect(json['name'], 'Test Instance');
      expect(json['baseUrl'], 'https://sonarr.example.com');
      expect(json['apiKey'], 'test-api-key');
      expect(json['basicAuthUsername'], 'user');
      expect(json['basicAuthPassword'], 'pass');
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Instance',
        'baseUrl': 'https://sonarr.example.com',
        'apiKey': 'test-api-key',
        'basicAuthUsername': 'user',
        'basicAuthPassword': 'pass',
      };

      final instance = ServiceInstance.fromJson(json);

      expect(instance.id, 'test-id');
      expect(instance.name, 'Test Instance');
      expect(instance.baseUrl, 'https://sonarr.example.com');
      expect(instance.apiKey, 'test-api-key');
      expect(instance.basicAuthUsername, 'user');
      expect(instance.basicAuthPassword, 'pass');
    });

    test('copyWith updates only specified fields', () {
      const instance = ServiceInstance(
        id: 'test-id',
        name: 'Test Instance',
        baseUrl: 'https://sonarr.example.com',
        apiKey: 'test-api-key',
      );

      final updated = instance.copyWith(name: 'Updated Name');

      expect(updated.id, 'test-id');
      expect(updated.name, 'Updated Name');
      expect(updated.baseUrl, 'https://sonarr.example.com');
      expect(updated.apiKey, 'test-api-key');
    });
  });

  group('Error Formatter Tests', () {
    test('formats ApiException correctly', () {
      final error = ApiException('Custom error message');
      final formatted = error_utils.ErrorFormatter.format(error);
      expect(formatted, 'Custom error message');
    });

    test('removes "Exception: " prefix', () {
      final formatted = error_utils.ErrorFormatter.format(
        'Exception: Something went wrong',
      );
      expect(formatted, 'Something went wrong');
    });

    test('removes stack traces', () {
      const error = 'Error message\nStack trace line 1\nStack trace line 2';
      final formatted = error_utils.ErrorFormatter.format(error);
      expect(formatted, 'Error message');
    });

    test('converts XMLHttpRequest errors to friendly message', () {
      final formatted = error_utils.ErrorFormatter.format(
        'XMLHttpRequest error occurred',
      );
      expect(formatted, 'Network error - please check your connection');
    });

    test('converts socket errors to friendly message', () {
      final formatted = error_utils.ErrorFormatter.format(
        'Socket connection failed',
      );
      expect(formatted, 'Connection error - unable to reach server');
    });

    test('converts timeout errors to friendly message', () {
      final formatted = error_utils.ErrorFormatter.format(
        'Request timeout exceeded',
      );
      expect(formatted, 'Request timed out - please try again');
    });

    test('truncates long error messages', () {
      final longError = 'Error: ${'x' * 300}';
      final formatted = error_utils.ErrorFormatter.format(longError);
      expect(formatted.length, 200);
      expect(formatted.endsWith('...'), isTrue);
    });

    test('sanitizes URLs with credentials', () {
      const error = 'Failed to connect to https://user:pass@sonarr.example.com';
      final formatted = error_utils.ErrorFormatter.format(error);
      expect(formatted, contains('https://[CREDENTIALS]@'));
      expect(formatted, isNot(contains('user:pass')));
    });

    test('redacts API keys in URLs (20+ chars)', () {
      const error =
          'Request failed: https://sonarr.example.com?apikey=abcdef1234567890ghijkl';
      final formatted = error_utils.ErrorFormatter.format(error);
      expect(formatted, contains('?apikey=[REDACTED]'));
      expect(formatted, isNot(contains('abcdef1234567890ghijkl')));
    });

    test('redacts 32-character hex API keys', () {
      const error = 'API error with key: 1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d';
      final formatted = error_utils.ErrorFormatter.format(error);
      expect(formatted, contains('[API-KEY]'));
      expect(formatted, isNot(contains('1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d')));
    });

    test('redacts Bearer tokens', () {
      const error = 'Authorization failed: Bearer abcd1234.efgh5678.ijkl9012';
      final formatted = error_utils.ErrorFormatter.format(error);
      expect(formatted, contains('Bearer [TOKEN]'));
      expect(formatted, isNot(contains('abcd1234.efgh5678.ijkl9012')));
    });

    test('redacts Basic auth tokens', () {
      const error = 'Authorization: Basic dXNlcjpwYXNzd29yZA==';
      final formatted = error_utils.ErrorFormatter.format(error);
      expect(formatted, contains('Basic [TOKEN]'));
      expect(formatted, isNot(contains('dXNlcjpwYXNzd29yZA==')));
    });
  });

  group('CachedDataLoader', () {
    const testInstanceId = 'test-sonarr-id';
    const testCacheKey = 'test_screen';
    const fullCacheKey = '${testCacheKey}_$testInstanceId';

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'active_sonarr_id': testInstanceId,
      });
      await getIt.reset();
      await configureDependencies();
      await getIt<AppStateManager>().initialize();
      getIt<CacheManager>().clearAll();
    });

    Widget buildScreen(Future<dynamic> Function() fetchFuture) {
      return MaterialApp(home: _TestScreen(fetchFuture: fetchFuture));
    }

    group('state transitions', () {
      testWidgets('shows spinner before first fetch completes', (
        tester,
      ) async {
        final completer = Completer<dynamic>();
        addTearDown(() {
          if (!completer.isCompleted) completer.complete(<dynamic>[]);
        });

        await tester.pumpWidget(buildScreen(() => completer.future));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        completer.complete(['item1']);
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('item1'), findsOneWidget);
      });

      testWidgets('loading → loaded: shows content after successful first fetch',
          (tester) async {
        await tester.pumpWidget(
          buildScreen(() async => ['item1', 'item2']),
        );
        await tester.pumpAndSettle();

        expect(find.text('item1'), findsOneWidget);
        expect(find.text('item2'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('loading → error: shows error state when first fetch fails', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildScreen(() => Future.error(Exception('Network error'))),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      });

      testWidgets('cache hit: valid cache shows content without calling fetch',
          (tester) async {
        getIt<AppStateManager>().setSonarrCache(testCacheKey, ['cached_item']);

        var fetchCallCount = 0;
        await tester.pumpWidget(
          buildScreen(() async {
            fetchCallCount++;
            return ['fresh_item'];
          }),
        );
        await tester.pumpAndSettle();

        expect(fetchCallCount, 0);
        expect(find.text('cached_item'), findsOneWidget);
      });

      testWidgets('force refresh calls fetch even with valid cache', (
        tester,
      ) async {
        getIt<AppStateManager>().setSonarrCache(testCacheKey, ['cached_item']);

        var fetchCallCount = 0;
        await tester.pumpWidget(
          buildScreen(() async {
            fetchCallCount++;
            return ['fresh_item'];
          }),
        );
        await tester.pumpAndSettle();

        expect(fetchCallCount, 0);
        expect(find.text('cached_item'), findsOneWidget);

        await tester.tap(find.byKey(const Key('force_refresh')));
        await tester.pumpAndSettle();

        expect(fetchCallCount, 1);
        expect(find.text('fresh_item'), findsOneWidget);
      });

      testWidgets(
          'mounted guard prevents setState crash when disposed during fetch',
          (tester) async {
        final completer = Completer<dynamic>();
        addTearDown(() {
          if (!completer.isCompleted) completer.complete(<dynamic>[]);
        });

        await tester.pumpWidget(buildScreen(() => completer.future));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Dispose widget before fetch completes
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        // Complete after disposal — mounted guard prevents crash
        completer.complete(['data']);
        await tester.pump();
      });
    });

    group('stale data', () {
      testWidgets('shows stale banner when background refresh fails', (
        tester,
      ) async {
        getIt<AppStateManager>().setSonarrCache(testCacheKey, ['cached_item']);
        getIt<CacheManager>().backdateTimestamp(
          fullCacheKey,
          const Duration(minutes: 10),
        );

        await tester.pumpWidget(
          buildScreen(() => Future.error(Exception('Network error'))),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('cached_item'), findsOneWidget);
      });

      testWidgets('banner clears after successful retry', (tester) async {
        getIt<AppStateManager>().setSonarrCache(testCacheKey, ['cached_item']);
        getIt<CacheManager>().backdateTimestamp(
          fullCacheKey,
          const Duration(minutes: 10),
        );

        var shouldThrow = true;
        await tester.pumpWidget(
          buildScreen(
            () => shouldThrow
                ? Future.error(Exception('Network error'))
                : Future.value(['fresh_item']),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

        shouldThrow = false;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
        expect(find.text('fresh_item'), findsOneWidget);
      });

      testWidgets('shows full error state when no cache exists', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildScreen(() => Future.error(Exception('Network error'))),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      });
    });
  });
}

class _TestScreen extends StatefulWidget {
  final Future<dynamic> Function() fetchFuture;

  const _TestScreen({required this.fetchFuture});

  @override
  State<_TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<_TestScreen>
    with CachedDataLoader<_TestScreen> {
  List<dynamic> _items = [];

  @override
  String get cacheKey => 'test_screen';

  @override
  bool get isSonarrScreen => true;

  @override
  Future<dynamic> fetchData() => widget.fetchFuture();

  @override
  void onDataLoaded(dynamic data) {
    _items = (data as List<dynamic>).map((e) => '$e').toList();
  }

  @override
  void initState() {
    super.initState();
    unawaited(loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        key: const Key('force_refresh'),
        onPressed: () => loadData(forceRefresh: true),
        child: const Icon(Icons.refresh),
      ),
      body: buildBody(
        buildContent: () => ListView(
          children: _items
              .map((e) => ListTile(title: Text(e as String)))
              .toList(),
        ),
        isEmpty: _items.isEmpty,
        emptyStateWidget: const Text('empty'),
      ),
    );
  }
}
