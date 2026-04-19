import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:arr_client/services/api_client.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockHttpClient mockHttp;
  late ApiClient client;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockHttp = MockHttpClient();
    client = ApiClient(
      baseUrl: 'http://localhost:7878',
      apiKey: 'testapikey1234567890',
      httpClient: mockHttp,
    );
  });

  http.Response jsonResponse(dynamic body, {int statusCode = 200}) =>
      http.Response(
        json.encode(body),
        statusCode,
        headers: {'content-type': 'application/json'},
      );

  http.Response emptyResponse({int statusCode = 200}) =>
      http.Response('', statusCode);

  void stubGet(dynamic body, {int statusCode = 200}) {
    when(
      () => mockHttp.get(any(), headers: any(named: 'headers')),
    ).thenAnswer((_) async => jsonResponse(body, statusCode: statusCode));
  }

  void stubGetEmpty({int statusCode = 200}) {
    when(
      () => mockHttp.get(any(), headers: any(named: 'headers')),
    ).thenAnswer((_) async => emptyResponse(statusCode: statusCode));
  }

  group('HTTP GET success', () {
    test('200 with body returns decoded JSON', () async {
      stubGet({'id': 1, 'title': 'Sonarr'});
      final result = await client.get('/system/status');
      expect(result, {'id': 1, 'title': 'Sonarr'});
    });

    test('200 with empty body returns null', () async {
      stubGetEmpty();
      final result = await client.get('/command');
      expect(result, isNull);
    });

    test('200 with list body returns list', () async {
      stubGet([
        {'id': 1},
        {'id': 2},
      ]);
      final result = await client.get('/series');
      expect(result, hasLength(2));
    });
  });

  group('HTTP error responses', () {
    test('401 throws Unauthorized', () async {
      stubGet(<String, dynamic>{}, statusCode: 401);
      expect(
        () => client.get('/series'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Unauthorized - check your API key',
          ),
        ),
      );
    });

    test('403 throws Access denied', () async {
      stubGet(<String, dynamic>{}, statusCode: 403);
      expect(
        () => client.get('/series'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Access denied',
          ),
        ),
      );
    });

    test('404 throws Not found', () async {
      stubGet(<String, dynamic>{}, statusCode: 404);
      expect(
        () => client.get('/series/99'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Not found',
          ),
        ),
      );
    });

    test('500 throws server error', () async {
      stubGet(<String, dynamic>{}, statusCode: 500);
      expect(
        () => client.get('/series'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Server error'),
          ),
        ),
      );
    });

    test('error body message field used over status default', () async {
      when(
        () => mockHttp.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response(
          json.encode({'message': 'Series already exists'}),
          400,
        ),
      );
      expect(
        () => client.get('/series'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Series already exists'),
          ),
        ),
      );
    });

    test('list error body uses errorMessage from first item', () async {
      when(
        () => mockHttp.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response(
          json.encode([
            {'errorMessage': 'Invalid quality profile'},
          ]),
          422,
        ),
      );
      expect(
        () => client.get('/series'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('Invalid quality profile'),
          ),
        ),
      );
    });
  });

  group('typed helpers', () {
    test('getList decodes each element via fromJson', () async {
      stubGet([
        {'id': 1, 'title': 'Breaking Bad'},
        {'id': 2, 'title': 'The Wire'},
      ]);
      final results = await client.getList(
        '/series',
        (json) => json['title'] as String,
      );
      expect(results, ['Breaking Bad', 'The Wire']);
    });

    test('getObject decodes map via fromJson', () async {
      stubGet({'version': '4.0.0', 'appName': 'Sonarr'});
      final result = await client.getObject(
        '/system/status',
        (json) => json['version'] as String,
      );
      expect(result, '4.0.0');
    });

    test('getPagedList unwraps records field', () async {
      stubGet({
        'page': 1,
        'totalRecords': 3,
        'records': [
          {'id': 10},
          {'id': 20},
          {'id': 30},
        ],
      });
      final results = await client.getPagedList(
        '/queue',
        (json) => json['id'] as int,
      );
      expect(results, [10, 20, 30]);
    });

    test('getPagedList returns empty list when records is null', () async {
      stubGet({'page': 1, 'totalRecords': 0});
      final results = await client.getPagedList('/queue', (json) => json['id']);
      expect(results, isEmpty);
    });
  });

  group('request headers', () {
    test('includes X-Api-Key on every GET', () async {
      stubGet(<String, dynamic>{});
      await client.get('/test');
      final captured = verify(
        () => mockHttp.get(any(), headers: captureAny(named: 'headers')),
      ).captured;
      final headers = captured.first as Map<String, String>;
      expect(headers['X-Api-Key'], 'testapikey1234567890');
    });

    test('no Authorization header without basic auth credentials', () async {
      stubGet(<String, dynamic>{});
      await client.get('/test');
      final captured = verify(
        () => mockHttp.get(any(), headers: captureAny(named: 'headers')),
      ).captured;
      final headers = captured.first as Map<String, String>;
      expect(headers.containsKey('Authorization'), isFalse);
    });

    test('includes Basic Authorization when credentials provided', () async {
      final authClient = ApiClient(
        baseUrl: 'http://localhost:7878',
        apiKey: 'key',
        basicAuthUsername: 'admin',
        basicAuthPassword: 'secret',
        httpClient: mockHttp,
      );
      stubGet(<String, dynamic>{});
      await authClient.get('/test');
      final captured = verify(
        () => mockHttp.get(any(), headers: captureAny(named: 'headers')),
      ).captured;
      final headers = captured.first as Map<String, String>;
      expect(headers['Authorization'], startsWith('Basic '));
      // Verify it encodes admin:secret correctly
      final encoded = base64Encode(utf8.encode('admin:secret'));
      expect(headers['Authorization'], 'Basic $encoded');
    });

    test('builds URL with correct base path', () async {
      stubGet(<String, dynamic>{});
      await client.get('/series');
      final captured = verify(
        () => mockHttp.get(captureAny(), headers: any(named: 'headers')),
      ).captured;
      final uri = captured.first as Uri;
      expect(uri.toString(), 'http://localhost:7878/api/v3/series');
    });
  });

  group('network error handling', () {
    test('TimeoutException wraps as ApiException', () async {
      when(
        () => mockHttp.get(any(), headers: any(named: 'headers')),
      ).thenThrow(TimeoutException('timed out'));
      expect(
        () => client.get('/series'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
    });

    test('ClientException retried up to maxRetries then throws', () async {
      var callCount = 0;
      when(
        () => mockHttp.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        callCount++;
        throw http.ClientException('connection refused');
      });
      await expectLater(
        () => client.get('/series'),
        throwsA(isA<ApiException>()),
      );
      // maxRetries = 2 means 3 total attempts (0, 1, 2)
      expect(callCount, 3);
    });

    test('ApiException not retried — thrown immediately', () async {
      var callCount = 0;
      when(
        () => mockHttp.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        callCount++;
        return jsonResponse(<String, dynamic>{}, statusCode: 401);
      });
      await expectLater(
        () => client.get('/series'),
        throwsA(isA<ApiException>()),
      );
      expect(callCount, 1);
    });
  });

  group('POST / PUT / DELETE', () {
    setUp(() {
      when(
        () => mockHttp.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
          encoding: any(named: 'encoding'),
        ),
      ).thenAnswer((_) async => jsonResponse({'id': 1}));

      when(
        () => mockHttp.put(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
          encoding: any(named: 'encoding'),
        ),
      ).thenAnswer((_) async => jsonResponse({'id': 1}));

      when(
        () => mockHttp.delete(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => emptyResponse());
    });

    test('POST sends JSON body and returns decoded response', () async {
      final result = await client.post('/series', {'title': 'test'});
      expect(result, {'id': 1});
    });

    test('DELETE returns null on empty 200', () async {
      final result = await client.delete('/series/1');
      expect(result, isNull);
    });
  });
}
