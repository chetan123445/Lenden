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
        // If both endpoints fail, clear the invalid token
        print('Both user and admin endpoints failed, clearing invalid token');
        await clearToken();
      } catch (e) {
        print('Error during session initialization: $e');
        // If there's an error, clear the token to be safe
        await clearToken();
      }
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

  Future<void> refreshUserProfile() async {
    if (_token == null) return;
    
    try {
      final isAdmin = _role == 'admin';
      final url = isAdmin
          ? '${ApiConfig.baseUrl}/api/admins/me'
          : '${ApiConfig.baseUrl}/api/users/me';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $_token'},
      );
      
      if (response.statusCode == 200) {
        final user = jsonDecode(response.body);
        setUser(user);
      }
    } catch (e) {
      print('Error refreshing user profile: $e');
    }
  }

  // Method to force clear image cache and refresh profile
  Future<void> forceRefreshProfile() async {
    if (_token == null) return;
    
    try {
      final isAdmin = _role == 'admin';
      final url = isAdmin
          ? '${ApiConfig.baseUrl}/api/admins/me'
          : '${ApiConfig.baseUrl}/api/users/me';
      
      // Add cache busting parameter
      final cacheBustingUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      
      final response = await http.get(
        Uri.parse(cacheBustingUrl),
        headers: {
          'Authorization': 'Bearer $_token',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );
      
      if (response.statusCode == 200) {
        final user = jsonDecode(response.body);
        setUser(user);
      }
    } catch (e) {
      print('Error force refreshing user profile: $e');
    }
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