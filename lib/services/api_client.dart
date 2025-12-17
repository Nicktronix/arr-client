import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final String apiKey;
  final String? basicAuthUsername;
  final String? basicAuthPassword;

  // HTTP client with connection pooling and timeout
  static final http.Client _httpClient = http.Client();
  static const Duration _timeout = Duration(seconds: 30);

  ApiClient({
    required this.baseUrl,
    required this.apiKey,
    this.basicAuthUsername,
    this.basicAuthPassword,
  });

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

  /// Make a GET request to the API
  Future<dynamic> get(String endpoint) async {
    final uri = Uri.parse('$baseUrl/api/v3$endpoint');

    try {
      final response = await _httpClient
          .get(uri, headers: _headers)
          .timeout(_timeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw ApiException('Request timed out - please try again');
    } on http.ClientException catch (e) {
      throw ApiException('Connection error: ${e.message}');
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  /// Make a POST request to the API
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/v3$endpoint');

    try {
      final response = await _httpClient
          .post(uri, headers: _headers, body: json.encode(data))
          .timeout(_timeout);

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw ApiException('Connection error: ${e.message}');
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  /// Make a PUT request to the API
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/api/v3$endpoint');

    try {
      final response = await _httpClient
          .put(uri, headers: _headers, body: json.encode(data))
          .timeout(_timeout);

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw ApiException('Connection error: ${e.message}');
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  /// Make a DELETE request to the API
  Future<dynamic> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl/api/v3$endpoint');

    try {
      final response = await _httpClient
          .delete(uri, headers: _headers)
          .timeout(_timeout);

      return _handleResponse(response);
    } on http.ClientException catch (e) {
      throw ApiException('Connection error: ${e.message}');
    } catch (e) {
      throw ApiException('Network error: $e');
    }
  }

  /// Handle API response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return null;
      }
      return json.decode(response.body);
    }

    // Parse error message from response body if available
    String errorMessage = 'Request failed';

    try {
      if (response.body.isNotEmpty) {
        final errorBody = json.decode(response.body);

        // Try common error message fields
        if (errorBody is Map) {
          errorMessage =
              errorBody['message'] ??
              errorBody['error'] ??
              errorBody['errorMessage'] ??
              errorMessage;
        }
      }
    } catch (e) {
      // If parsing fails, use status-based message
      errorMessage = _getStatusMessage(response.statusCode);
    }

    if (response.statusCode == 401) {
      throw ApiException('Unauthorized - check your API key');
    } else if (response.statusCode == 404) {
      throw ApiException('Not found');
    } else if (response.statusCode == 403) {
      throw ApiException('Access denied');
    } else if (response.statusCode >= 500) {
      throw ApiException('Server error - please try again later');
    } else {
      throw ApiException(errorMessage);
    }
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
