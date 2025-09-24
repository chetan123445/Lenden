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
  bool _userDataManuallySet = false; // Flag to track if user data was set manually
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  String? get role => _role;
  bool get isAdmin => _role == 'admin';

  Future<void> loadToken() async {
    _token = await _storage.read(key: 'token');
    notifyListeners();
  }

  Future<void> saveToken(String token) async {
    print('💾 SessionProvider.saveToken called with token: ${token != null ? 'Present' : 'Missing'}');
    _token = token;
    await _storage.write(key: 'token', value: token);
    print('💾 Token saved to storage');
    notifyListeners();
    print('💾 SessionProvider.notifyListeners() called');
  }

  Future<void> clearToken() async {
    _token = null;
    _user = null;
    _role = null;
    _userDataManuallySet = false;
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user_data');
    notifyListeners();
  }

  Future<void> initSession() async {
    print('🔄 SessionProvider.initSession() called');
    _token = await _storage.read(key: 'token');
    print('🔄 Token from storage: ${_token != null ? 'Present' : 'Missing'}');
    
    if (_token != null) {
      // First try to load saved user data
      await _loadUserData();
      print('🔄 After loading user data: _user = ${_user != null ? 'Present' : 'Missing'}, _role = $_role');
      
      // Only try to fetch user profile if we don't already have user data and it wasn't manually set
      if (_user == null && !_userDataManuallySet) {
        print('🔄 No user data found and not manually set, fetching from API...');
      } else {
        print('🔄 Skipping API fetch - user data already available or manually set');
        print('🔄 _user: ${_user != null ? 'Present' : 'Missing'}');
        print('🔄 _userDataManuallySet: $_userDataManuallySet');
      }
      
      if (_user == null && !_userDataManuallySet) {
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
      } else {
        // We already have user data, just notify listeners
        notifyListeners();
        return;
      }
    }
    _user = null;
    _role = null;
    notifyListeners();
  }

  void setUser(Map<String, dynamic> user) {
    print('🔧 SessionProvider.setUser called with: $user');
    
    // Normalize profileImage to always be a String
    if (user['profileImage'] is Map && user['profileImage']['url'] != null) {
      user['profileImage'] = user['profileImage']['url'];
    }
    _user = user;
    _role = user['role'] ?? 'user';
    _userDataManuallySet = true; // Mark that user data was set manually
    
    print('🔧 SessionProvider: _user set to: $_user');
    print('🔧 SessionProvider: _role set to: $_role');
    print('🔧 SessionProvider: _userDataManuallySet set to: $_userDataManuallySet');
    
    // Save user data to secure storage
    _saveUserData(user);
    
    notifyListeners();
    print('🔧 SessionProvider: notifyListeners() called');
    
    // Verify the session state after setting
    print('🔍 Session state after setUser:');
    print('   _token: ${_token != null ? 'Present' : 'Missing'}');
    print('   _user: ${_user != null ? 'Present' : 'Missing'}');
    print('   _role: $_role');
    print('   isAdmin: $isAdmin');
  }

  Future<void> _saveUserData(Map<String, dynamic> user) async {
    try {
      print('💾 Saving user data to secure storage: $user');
      await _storage.write(key: 'user_data', value: jsonEncode(user));
      print('✅ User data saved successfully');
    } catch (e) {
      print('❌ Error saving user data: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _storage.read(key: 'user_data');
      if (userData != null) {
        final user = jsonDecode(userData);
        _user = user;
        _role = user['role'] ?? 'user';
        _userDataManuallySet = true; // Mark that user data was loaded from storage
        print('📱 Loaded saved user data: $_user');
        print('📱 User role: $_role');
        print('📱 _userDataManuallySet: $_userDataManuallySet');
      } else {
        print('📱 No saved user data found');
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
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

  void clearUser() async {
    _user = null;
    _role = null;
    _userDataManuallySet = false;
    await _storage.delete(key: 'user_data');
    notifyListeners();
  }

  Future<void> logout() async {
    await clearToken();
    clearUser();
  }

  void updateNotificationSettings(Map<String, dynamic> settings) {
    if (_user != null) {
      _user!['notificationSettings'] = settings;
      _saveUserData(_user!);
      notifyListeners();
    }
  }
} 