import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api_config.dart';

class ApiClient {
  static final http.Client _client = http.Client();
  static String get _baseUrl => ApiConfig.baseUrl;

  // Secure storage keys
  static const _storage = FlutterSecureStorage();
  static const String _kAccessToken = 'access_token';
  static const String _kRefreshToken = 'refresh_token';

  // Store tokens (call from your auth flow)
  static Future<void> setTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }

  static Future<String?> _getAccessToken() async {
    return await _storage.read(key: _kAccessToken);
  }

  static Future<String?> _getRefreshToken() async {
    return await _storage.read(key: _kRefreshToken);
  }

  // Low-level request with auto-refresh on 401
  static Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    String? token = await _getAccessToken();

    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      if (extraHeaders != null) ...extraHeaders,
    };

    http.Response resp;
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          resp = await _client.get(uri, headers: headers);
          break;
        case 'POST':
          resp = await _client.post(uri,
              headers: headers, body: jsonEncode(body ?? {}));
          break;
        case 'PUT':
          resp = await _client.put(uri,
              headers: headers, body: jsonEncode(body ?? {}));
          break;
        case 'PATCH':
          resp = await _client.patch(uri,
              headers: headers, body: jsonEncode(body ?? {}));
          break;
        case 'DELETE':
          resp = await _client.delete(uri, headers: headers);
          break;
        default:
          throw UnsupportedError('Unsupported HTTP method: $method');
      }
    } catch (e) {
      rethrow;
    }

    // If unauthorized, try refresh and retry once
    if (resp.statusCode == 401) {
      final refreshed = await _refreshTokens();
      if (refreshed) {
        token = await _getAccessToken();
        final retryHeaders = <String, String>{
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          if (extraHeaders != null) ...extraHeaders,
        };
        switch (method.toUpperCase()) {
          case 'GET':
            resp = await _client.get(uri, headers: retryHeaders);
            break;
          case 'POST':
            resp = await _client.post(uri,
                headers: retryHeaders, body: jsonEncode(body ?? {}));
            break;
          case 'PUT':
            resp = await _client.put(uri,
                headers: retryHeaders, body: jsonEncode(body ?? {}));
            break;
          case 'PATCH':
            resp = await _client.patch(uri,
                headers: retryHeaders, body: jsonEncode(body ?? {}));
            break;
          case 'DELETE':
            resp = await _client.delete(uri, headers: retryHeaders);
            break;
        }
      }
    }

    return resp;
  }

  // Refresh tokens using refresh token stored in storage. Returns true if refreshed.
  static Future<bool> _refreshTokens() async {
    final refreshToken = await _getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final uri =
          Uri.parse('$_baseUrl/api/users/refresh-token'); // adjust if endpoint differs
      final response = await _client.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final access =
            data['accessToken'] ?? data['token'] ?? data['access_token'];
        final refresh =
            data['refreshToken'] ?? data['refresh_token'] ?? refreshToken;
        if (access != null) {
          await setTokens(access.toString(), refresh.toString());
          return true;
        }
      } else {
        await clearTokens();
      }
    } catch (_) {
      // ignore
    }
    return false;
  }

  // Public methods
  static Future<http.Response> get(String path,
      {Map<String, String>? headers}) {
    return _request('GET', path, extraHeaders: headers);
  }

  static Future<http.Response> post(String path,
      {Map<String, dynamic>? body, Map<String, String>? headers}) {
    return _request('POST', path, body: body, extraHeaders: headers);
  }

  static Future<http.Response> put(String path,
      {Map<String, dynamic>? body, Map<String, String>? headers}) {
    return _request('PUT', path, body: body, extraHeaders: headers);
  }

  static Future<http.Response> patch(String path,
      {Map<String, dynamic>? body, Map<String, String>? headers}) {
    return _request('PATCH', path, body: body, extraHeaders: headers);
  }

  static Future<http.Response> delete(String path,
      {Map<String, String>? headers}) {
    return _request('DELETE', path, extraHeaders: headers);
  }
}
