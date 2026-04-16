import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final String apiKey;
  final String? basicAuthUsername;
  final String? basicAuthPassword;
  final String apiVersion;

  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxRetries = 2;

  // Instance-level client — closing it cancels in-flight requests (e.g. on instance switch)
  final http.Client _httpClient = http.Client();

  ApiClient({
    required this.baseUrl,
    required this.apiKey,
    this.basicAuthUsername,
    this.basicAuthPassword,
    this.apiVersion = 'v3',
  });

  /// Release resources. Called by services when the active instance changes.
  void close() {
    _httpClient.close();
  }

  Map<String, String> get _headers {
    final headers = {'X-Api-Key': apiKey, 'Content-Type': 'application/json'};

    if (basicAuthUsername != null && basicAuthPassword != null) {
      final credentials = base64Encode(
        utf8.encode('$basicAuthUsername:$basicAuthPassword'),
      );
      headers['Authorization'] = 'Basic $credentials';
    }

    return headers;
  }

  String _url(String endpoint) => '$baseUrl/api/$apiVersion$endpoint';

  /// Execute [request] with up to [_maxRetries] retries on connection errors.
  /// Timeouts and HTTP errors are not retried — they either indicate a slow
  /// server (retrying wastes time) or a client mistake (retrying won't help).
  Future<dynamic> _withRetry(
    Future<http.Response> Function() request,
  ) async {
    int attempt = 0;
    while (true) {
      try {
        final response = await request();
        return _handleResponse(response);
      } on ApiException {
        rethrow;
      } on TimeoutException {
        throw ApiException('Request timed out - please try again');
      } on http.ClientException catch (e) {
        if (attempt >= _maxRetries) {
          throw ApiException('Connection error: ${_sanitizeMessage(e.message)}');
        }
        await Future.delayed(Duration(seconds: attempt + 1));
        attempt++;
      } catch (e) {
        throw ApiException('Network error: ${_sanitizeMessage(e.toString())}');
      }
    }
  }

  /// Make a GET request to the API
  Future<dynamic> get(String endpoint, {Duration? timeout}) async {
    return _withRetry(
      () => _httpClient
          .get(Uri.parse(_url(endpoint)), headers: _headers)
          .timeout(timeout ?? _timeout),
    );
  }

  /// Make a POST request to the API
  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> data, {
    Duration? timeout,
  }) async {
    return _withRetry(
      () => _httpClient
          .post(
            Uri.parse(_url(endpoint)),
            headers: _headers,
            body: json.encode(data),
          )
          .timeout(timeout ?? _timeout),
    );
  }

  /// Make a PUT request to the API
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    return _withRetry(
      () => _httpClient
          .put(
            Uri.parse(_url(endpoint)),
            headers: _headers,
            body: json.encode(data),
          )
          .timeout(_timeout),
    );
  }

  /// Make a PUT request with a list body to the API
  Future<dynamic> putList(String endpoint, List<dynamic> data) async {
    return _withRetry(
      () => _httpClient
          .put(
            Uri.parse(_url(endpoint)),
            headers: _headers,
            body: json.encode(data),
          )
          .timeout(_timeout),
    );
  }

  /// Make a DELETE request to the API
  Future<dynamic> delete(String endpoint) async {
    return _withRetry(
      () => _httpClient
          .delete(Uri.parse(_url(endpoint)), headers: _headers)
          .timeout(_timeout),
    );
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    }

    // Default to status-based message so empty bodies still produce useful text
    String errorMessage = _getStatusMessage(response.statusCode);

    try {
      if (response.body.isNotEmpty) {
        final errorBody = json.decode(response.body);

        if (errorBody is Map) {
          errorMessage =
              errorBody['message'] ??
              errorBody['error'] ??
              errorBody['errorMessage'] ??
              errorMessage;
        } else if (errorBody is List && errorBody.isNotEmpty) {
          final first = errorBody.first;
          if (first is Map) {
            errorMessage =
                first['errorMessage'] ??
                first['message'] ??
                first['error'] ??
                errorMessage;
          }
        }
      }
    } catch (_) {
      // JSON parse failed — status-based default already set
    }

    if (response.statusCode == 401) {
      throw ApiException('Unauthorized - check your API key');
    } else if (response.statusCode == 403) {
      throw ApiException('Access denied');
    } else if (response.statusCode == 404) {
      throw ApiException('Not found');
    } else if (response.statusCode >= 500) {
      throw ApiException('Server error - please try again later');
    } else {
      throw ApiException('$errorMessage (HTTP ${response.statusCode})');
    }
  }

  String _sanitizeMessage(String message) {
    return message
        .replaceAll(RegExp(r'://[^/\s]*@'), '://***@')
        .replaceAll(
          RegExp(r'apikey=[^&\s]+', caseSensitive: false),
          'apikey=***',
        )
        .replaceAll(
          RegExp(r'api_key=[^&\s]+', caseSensitive: false),
          'api_key=***',
        )
        .replaceAll(
          RegExp(r'X-Api-Key:\s*[^\s]+', caseSensitive: false),
          'X-Api-Key: ***',
        );
  }

  String _getStatusMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not found';
      case 405:
        return 'Method not allowed';
      case 409:
        return 'Conflict';
      case 429:
        return 'Too many requests';
      case 500:
        return 'Internal server error';
      case 502:
        return 'Bad gateway';
      case 503:
        return 'Service unavailable';
      case 504:
        return 'Gateway timeout';
      default:
        return 'Request failed (HTTP $statusCode)';
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
