import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FoxyApiClient {
  static final String defaultBaseUrl =
      dotenv.env['FOXY_API_URL'] ?? 'http://10.0.2.2:19080/api';

  final String baseUrl;
  final http.Client _httpClient;

  static const String _accessTokenKey = 'foxy_access_token';
  static const String _refreshTokenKey = 'foxy_refresh_token';

  FoxyApiClient({String? baseUrl, http.Client? httpClient})
      : baseUrl = (baseUrl ?? defaultBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _httpClient = httpClient ?? http.Client();

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  Future<Map<String, String>> _getHeaders({bool auth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (auth) {
      final token = await getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> request({
    required String method,
    required String path,
    Map<String, dynamic>? queryParams,
    dynamic body,
    bool requiresAuth = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: queryParams?.map((k, v) => MapEntry(k, v.toString())),
    );

    final headers = await _getHeaders(auth: requiresAuth);
    http.Response response;

    final encodedBody = body != null ? jsonEncode(body) : null;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await _httpClient.get(uri, headers: headers);
        break;
      case 'POST':
        response = await _httpClient.post(uri, headers: headers, body: encodedBody);
        break;
      case 'PATCH':
        response = await _httpClient.patch(uri, headers: headers, body: encodedBody);
        break;
      case 'DELETE':
        response = await _httpClient.delete(uri, headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    // Auto-refresh token on 401
    if (response.statusCode == 401 && requiresAuth) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        return request(
          method: method,
          path: path,
          queryParams: queryParams,
          body: body,
          requiresAuth: requiresAuth,
        );
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.statusCode == 204 || response.body.isEmpty) {
        return null;
      }
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'HTTP ${response.statusCode}';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] != null) {
          errorMessage = decoded['error'].toString();
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final uri = Uri.parse('$baseUrl/auth/refresh');
      final res = await _httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
        );
        return true;
      }
    } catch (_) {}

    await clearTokens();
    return false;
  }

  // Convenience methods
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams, bool requiresAuth = false}) {
    return request(method: 'GET', path: path, queryParams: queryParams, requiresAuth: requiresAuth);
  }

  Future<dynamic> post(String path, {dynamic body, bool requiresAuth = false}) {
    return request(method: 'POST', path: path, body: body, requiresAuth: requiresAuth);
  }

  Future<dynamic> patch(String path, {dynamic body, bool requiresAuth = true}) {
    return request(method: 'PATCH', path: path, body: body, requiresAuth: requiresAuth);
  }

  Future<dynamic> delete(String path, {bool requiresAuth = true}) {
    return request(method: 'DELETE', path: path, requiresAuth: requiresAuth);
  }
}
