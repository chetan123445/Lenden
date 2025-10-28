import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../api_config.dart';
import '../utils/http_interceptor.dart';

class SessionProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>>? _counterparties;
  DateTime? _counterpartiesLastFetched;
  String? _role;
  bool _userDataManuallySet =
      false; // Flag to track if user data was set manually
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get token => _accessToken; // For backward compatibility
  Map<String, dynamic>? get user => _user;
  List<Map<String, dynamic>>? get counterparties => _counterparties;
  DateTime? get counterpartiesLastFetched => _counterpartiesLastFetched;
  String? get role => _role;
  bool get isAdmin => _role == 'admin';

  bool _isSubscribed = false;
  String? _subscriptionPlan;
  DateTime? _subscriptionEndDate;
  List<Map<String, dynamic>>? _subscriptionHistory;
  int? _free;

  bool get isSubscribed => _isSubscribed;
  String? get subscriptionPlan => _subscriptionPlan;
  DateTime? get subscriptionEndDate => _subscriptionEndDate;
  List<Map<String, dynamic>>? get subscriptionHistory => _subscriptionHistory;
  int? get free => _free;

  static const String _deviceIdKey = 'device_id';

  Future<void> loadTokens() async {
    _accessToken = await _storage.read(key: 'access_token');
    _refreshToken = await _storage.read(key: 'refresh_token');
    notifyListeners();
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    print(
        '💾 SessionProvider.saveTokens called with accessToken: ${accessToken != null ? 'Present' : 'Missing'}, refreshToken: ${refreshToken != null ? 'Present' : 'Missing'}');
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
    print('💾 Tokens saved to storage');
    notifyListeners();
    print('💾 SessionProvider.notifyListeners() called');
  }

  Future<void> saveToken(String token) async {
    // For backward compatibility - treat as access token
    await saveTokens(token, _refreshToken ?? '');
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    _role = null;
    _userDataManuallySet = false;
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user_data');
    clearCounterparties();
    notifyListeners();
  }

  Future<void> clearToken() async {
    // For backward compatibility
    await clearTokens();
  }

  Future<void> initSession() async {
    print('🔄 SessionProvider.initSession() called');
    await loadTokens();
    print('🔄 Access token from storage: ${_accessToken != null ? 'Present' : 'Missing'}');
    print('🔄 Refresh token from storage: ${_refreshToken != null ? 'Present' : 'Missing'}');

    if (_accessToken != null) {
      await _loadUserData();
      print(
          '🔄 After loading user data: _user = ${_user != null ? 'Present' : 'Missing'}, _role = $_role');

      if (_user == null && !_userDataManuallySet) {
        print(
            '🔄 No user data found and not manually set, fetching from API...');
        
        var response = await HttpInterceptor.get('/api/users/me');

        if (response.statusCode != 200) {
          response = await HttpInterceptor.get('/api/admins/me');
        }

        if (response.statusCode == 200) {
          var user = jsonDecode(response.body);
          if (user['profileImage'] is Map &&
              user['profileImage']['url'] != null) {
            user['profileImage'] = user['profileImage']['url'];
          }
          _user = user;
          _role = response.request?.url.path.contains('/admins/') ?? false ? 'admin' : 'user';
          await checkSubscriptionStatus();
          notifyListeners();
        } else {
          print('Both user and admin endpoints failed, clearing tokens');
          await clearTokens();
        }
      } else {
        // We already have user data, just notify listeners
        await checkSubscriptionStatus();
        notifyListeners();
      }
    } else {
        _user = null;
        _role = null;
        notifyListeners();
    }
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
    print(
        '🔧 SessionProvider: _userDataManuallySet set to: $_userDataManuallySet');

    // Save user data to secure storage
    _saveUserData(user);

    notifyListeners();
    print('🔧 SessionProvider: notifyListeners() called');

    // Verify the session state after setting
    print('🔍 Session state after setUser:');
    print('   _accessToken: ${_accessToken != null ? 'Present' : 'Missing'}');
    print('   _user: ${_user != null ? 'Present' : 'Missing'}');
    print('   _role: $_role');
    print('   isAdmin: $isAdmin');
  }

  Future<void> checkSubscriptionStatus() async {
    if (_accessToken == null) {
      print('Subscription check: No access token');
      return;
    }

    print('Subscription check: Fetching status...');
    try {
        final response = await HttpInterceptor.get('/api/subscription/status');

        if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            print('Subscription check: Data received: $data');
            _isSubscribed = data['subscribed'] ?? false;
            if (_isSubscribed) {
                _subscriptionPlan = data['subscriptionPlan'];
                _subscriptionEndDate = DateTime.parse(data['endDate']);
                _free = data['free'];
            } else {
                _subscriptionPlan = null;
                _subscriptionEndDate = null;
                _free = null;
            }
            await fetchSubscriptionHistory();
            print('Subscription check: isSubscribed set to $_isSubscribed');
            notifyListeners();
        } else {
            print('Subscription check: Failed with status ${response.statusCode}');
        }
    } catch (e) {
        print('Error checking subscription status: $e');
    }
}

Future<void> fetchSubscriptionHistory() async {
    if (_accessToken == null) {
      print('Subscription history: No access token');
      return;
    }

    print('Subscription history: Fetching history...');
    try {
        final response = await HttpInterceptor.get('/api/subscription/history');

        if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            print('Subscription history: Data received: $data');
            _subscriptionHistory = List<Map<String, dynamic>>.from(data);
            notifyListeners();
        } else {
            print('Subscription history: Failed with status ${response.statusCode}');
        }
    } catch (e) {
        print('Error fetching subscription history: $e');
    }
}

  void setCounterparties(List<Map<String, dynamic>> counterparties) {
    _counterparties = counterparties;
    _counterpartiesLastFetched = DateTime.now();
    notifyListeners();
  }

  void clearCounterparties() {
    _counterparties = null;
    _counterpartiesLastFetched = null;
    notifyListeners();
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
        _userDataManuallySet =
            true; // Mark that user data was loaded from storage
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
    if (_accessToken == null) return;

    try {
      final isAdmin = _role == 'admin';
      final url = isAdmin
          ? '/api/admins/me'
          : '/api/users/me';

      final response = await HttpInterceptor.get(url);

      if (response.statusCode == 200) {
        final user = jsonDecode(response.body);
        setUser(user);
      } else if (response.statusCode == 401) {
        await logout();
      }
    } catch (e) {
      print('Error refreshing user profile: $e');
    }
  }

  // Method to force clear image cache and refresh profile
  Future<void> forceRefreshProfile() async {
    if (_accessToken == null) return;

    try {
      final isAdmin = _role == 'admin';
      final url = isAdmin
          ? '/api/admins/me'
          : '/api/users/me';

      // Add cache busting parameter
      final cacheBustingUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';

      final response = await HttpInterceptor.get(cacheBustingUrl, headers: {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        });

      if (response.statusCode == 200) {
        final user = jsonDecode(response.body);
        setUser(user);
      } else if (response.statusCode == 401) {
        await logout();
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

  void clearSubscription() {
    _isSubscribed = false;
    _subscriptionPlan = null;
    _subscriptionEndDate = null;
    _subscriptionHistory = null;
    _free = null;
    notifyListeners();
  }

  Future<void> logout() async {
    if (_refreshToken != null) {
      try {
        await HttpInterceptor.post('/api/users/logout', body: {'refreshToken': _refreshToken});
      } catch (e) {
        print('Error logging out on server: $e');
      }
    }
    await clearTokens();
    clearUser();
    clearCounterparties();
    clearSubscription();
  }

  void updateNotificationSettings(Map<String, dynamic> settings) {
    if (_user != null) {
      _user!['notificationSettings'] = settings;
      _saveUserData(_user!);
      notifyListeners();
    }
  }

  Future<void> saveDeviceId(String deviceId) async {
    await _storage.write(key: _deviceIdKey, value: deviceId);
  }

  Future<String?> getDeviceId() async {
    return await _storage.read(key: _deviceIdKey);
  }
}