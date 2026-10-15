import 'package:arr_client/services/api_client.dart';

class ErrorFormatter {
  /// Format an error for display to the user
  static String format(dynamic error) {
    if (error is ApiException) {
      return error.message;
    }

    // Convert error to string and clean it up
    var errorStr = error.toString();

    // Remove "Exception: " prefix if present
    errorStr = errorStr.replaceFirst('Exception: ', '');

    // Remove stack traces (anything after newline)
    if (errorStr.contains('\n')) {
      errorStr = errorStr.split('\n').first;
    }

    // Sanitize URLs that might contain credentials
    errorStr = _sanitizeUrls(errorStr);

    // If it's a generic error, make it more friendly
    if (errorStr.toLowerCase().contains('xmlhttprequest')) {
      return 'Network error - please check your connection';
    }

    if (errorStr.toLowerCase().contains('socket')) {
      return 'Connection error - unable to reach server';
    }

    if (errorStr.toLowerCase().contains('timeout')) {
      return 'Request timed out - please try again';
    }

    // Limit length to prevent massive error messages
    if (errorStr.length > 200) {
      return '${errorStr.substring(0, 197)}...';
    }

    return errorStr;
  }

  /// Sanitize URLs to remove any credentials that might be exposed
  static String _sanitizeUrls(String text) {
    var result = text;
    // Replace username:password in URLs with [CREDENTIALS]
    // [^/\s]* with backtracking correctly handles @ and : in passwords
    final urlPattern = RegExp(r'https?://[^/\s]*@');
    result = result.replaceAll(urlPattern, 'https://[CREDENTIALS]@');

    // Remove API keys from URLs (if accidentally included)
    final apiKeyPattern = RegExp(
      '[?&]apikey=[a-zA-Z0-9]{20,}',
      caseSensitive: false,
    );
    result = result.replaceAll(apiKeyPattern, '?apikey=[REDACTED]');

    // Remove 32-char hex API keys (Sonarr/Radarr format)
    final hexKeyPattern = RegExp(r'\b[a-f0-9]{32}\b', caseSensitive: false);
    result = result.replaceAllMapped(hexKeyPattern, (match) => '[API-KEY]');

    // Remove Bearer tokens
    final bearerPattern = RegExp(
      r'Bearer\s+[A-Za-z0-9\-._~+/]+=*',
      caseSensitive: false,
    );
    result = result.replaceAll(bearerPattern, 'Bearer [TOKEN]');

    // Remove Basic auth tokens
    final basicAuthPattern = RegExp(
      r'Basic\s+[A-Za-z0-9+/]+=*',
      caseSensitive: false,
    );
    result = result.replaceAll(basicAuthPattern, 'Basic [TOKEN]');

    return result;
  }
}
