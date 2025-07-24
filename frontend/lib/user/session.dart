import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';

class SessionProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  String? _token;
  Map<String, dynamic>? _user;
  String? _role;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  String? get role => _role;
  bool get isAdmin => _role == 'admin';

  Future<void> loadToken() async {
    _token = await _storage.read(key: 'token');
    notifyListeners();
  }

  Future<void> saveToken(String token) async {
    _token = token;
    await _storage.write(key: 'token', value: token);
    notifyListeners();
  }

  Future<void> clearToken() async {
    _token = null;
    await _storage.delete(key: 'token');
    notifyListeners();
  }

  Future<void> initSession() async {
    _token = await _storage.read(key: 'token');
    if (_token != null) {
      // Try to fetch user profile
      try {
        // Try user endpoint first
        var response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/users/me'),
          headers: {'Authorization': 'Bearer $_token'},
        );
        if (response.statusCode == 200) {
          var user = jsonDecode(response.body);
          if (user['profileImage'] is Map && user['profileImage']['url'] != null) {
            user['profileImage'] = user['profileImage']['url'];
          }
          _user = user;
          _role = 'user';
          notifyListeners();
          return;
        }
        // Try admin endpoint if user failed
        response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/admins/me'),
          headers: {'Authorization': 'Bearer $_token'},
        );
        if (response.statusCode == 200) {
          var user = jsonDecode(response.body);
          if (user['profileImage'] is Map && user['profileImage']['url'] != null) {
            user['profileImage'] = user['profileImage']['url'];
          }
          _user = user;
          _role = 'admin';
          notifyListeners();
          return;
        }
      } catch (_) {}
    }
    _user = null;
    _role = null;
    notifyListeners();
  }

  void setUser(Map<String, dynamic> user) {
    // Normalize profileImage to always be a String
    if (user['profileImage'] is Map && user['profileImage']['url'] != null) {
      user['profileImage'] = user['profileImage']['url'];
    }
    _user = user;
    _role = user['role'] ?? 'user';
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await clearToken();
    clearUser();
  }
} 