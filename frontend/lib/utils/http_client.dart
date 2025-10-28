import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api_config.dart';

class AuthenticatedHttpClient {
  static const _storage = FlutterSecureStorage();

  static Uri _buildUri(String endpoint) {
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return Uri.parse(endpoint);
    }
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse(ApiConfig.baseUrl + path);
  }

  static Future<http.Response> get(String endpoint,
      {Map<String, String>? headers}) async {
    return await _makeRequest(() async =>
        http.get(_buildUri(endpoint), headers: await _getHeaders(headers)));
  }

  static Future<http.Response> post(String endpoint,
      {Map<String, String>? headers, Object? body}) async {
    return await _makeRequest(() async => http.post(
          _buildUri(endpoint),
          headers: await _getHeaders(headers),
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  static Future<http.Response> put(String endpoint,
      {Map<String, String>? headers, Object? body}) async {
    return await _makeRequest(() async => http.put(
          _buildUri(endpoint),
          headers: await _getHeaders(headers),
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  static Future<http.Response> delete(String endpoint,
      {Map<String, String>? headers}) async {
    return await _makeRequest(() async =>
        http.delete(_buildUri(endpoint), headers: await _getHeaders(headers)));
  }

  static Future<Map<String, String>> _getHeaders(
      Map<String, String>? additionalHeaders) async {
    final accessToken = await _storage.read(key: 'access_token');

    Map<String, String> headers = {
      'Accept': 'application/json',
      'User-Agent': 'Lenden-Flutter-App/1.0',
      'Content-Type': 'application/json',
    };

    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  static Future<http.Response> _makeRequest(
      Future<http.Response> Function() request) async {
    http.Response response = await request();

    if (response.statusCode == 401) {
      final refreshToken = await _storage.read(key: 'refresh_token');

      if (refreshToken != null) {
        final candidates = [
          {
            'path': '/api/users/refresh-token',
            'body': {'refreshToken': refreshToken}
          },
          {
            'path': '/api/auth/refresh',
            'body': {'refreshToken': refreshToken}
          },
        ];

        for (final c in candidates) {
          try {
            final refreshResponse = await http.post(
              _buildUri(c['path'] as String),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: jsonEncode(c['body']),
            );

            if (refreshResponse.statusCode == 200) {
              final data = jsonDecode(refreshResponse.body);
              final newAccess =
                  (data['accessToken'] ?? data['token'] ?? data['access'])
                      ?.toString();
              final newRefresh =
                  (data['refreshToken'] ?? data['refresh'])?.toString();
              if (newAccess != null && newAccess.isNotEmpty) {
                await _storage.write(key: 'access_token', value: newAccess);
                if (newRefresh != null && newRefresh.isNotEmpty) {
                  await _storage.write(key: 'refresh_token', value: newRefresh);
                }
                response = await request();
                break;
              }
            }
          } catch (_) {
            continue;
          }
        }
      }
    }

    return response;
  }
}
