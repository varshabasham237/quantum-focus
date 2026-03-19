import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// HTTP client for communicating with the FastAPI backend.
class ApiService {
  String? _accessToken;
  String? _refreshToken;

  /// Set tokens after login/register
  void setTokens(String access, String refresh) {
    _accessToken = access;
    _refreshToken = refresh;
  }

  /// Clear tokens on logout
  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  bool get isAuthenticated => _accessToken != null;

  /// Headers with auth token
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  /// POST request
  Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.receiveTimeout);

      if (response.statusCode == 401 && _refreshToken != null) {
        // Try refreshing token
        final refreshed = await _tryRefresh();
        if (refreshed) {
          // Retry request with new token
          final retry = await http
              .post(
                Uri.parse('${ApiConfig.baseUrl}$path'),
                headers: _headers,
                body: jsonEncode(body),
              )
              .timeout(ApiConfig.receiveTimeout);
          return _parseResponse(retry);
        }
      }

      return _parseResponse(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// GET request
  Future<Map<String, dynamic>?> get(String path) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: _headers,
          )
          .timeout(ApiConfig.receiveTimeout);
      return _parseResponse(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// PATCH request
  Future<Map<String, dynamic>?> patch(String path, Map<String, dynamic> body) async {
    try {
      final response = await http
          .patch(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.receiveTimeout);
      return _parseResponse(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// DELETE request
  Future<Map<String, dynamic>?> delete(String path) async {
    try {
      final response = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: _headers,
          )
          .timeout(ApiConfig.receiveTimeout);
      return _parseResponse(response);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Parse HTTP response
  Map<String, dynamic> _parseResponse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body is Map<String, dynamic> ? body : {'data': body};
    } else {
      return {
        'error': body['detail'] ?? 'Request failed',
        'statusCode': response.statusCode,
      };
    }
  }

  /// Try to refresh access token
  Future<bool> _tryRefresh() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        return true;
      }
    } catch (_) {}
    return false;
  }
}
