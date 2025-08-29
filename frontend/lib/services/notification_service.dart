import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../api_config.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  static Future<void> initialize() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      await registerToken();
      _messaging.onTokenRefresh.listen(registerToken);
    }
  }
  
  static Future<void> registerToken([String? newToken]) async {
    try {
      final String? token = newToken ?? await _messaging.getToken();
      print('FCM Token: $token');
      
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('userId');
        final authToken = prefs.getString('token');
        
        if (userId != null && authToken != null) {
          await _sendTokenToServer(userId, token, authToken);
        } else {
          print('User not logged in, storing token for later');
          await prefs.setString('pending_fcm_token', token);
        }
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }
  
  static Future<void> registerTokenAfterLogin(String userId, String authToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = await _messaging.getToken();
      
      token = token ?? prefs.getString('pending_fcm_token');
      
      if (token != null) {
        await _sendTokenToServer(userId, token, authToken);
        await prefs.remove('pending_fcm_token');
      }
    } catch (e) {
      print('Error registering token after login: $e');
    }
  }
  
  static Future<void> _sendTokenToServer(String userId, String token, String authToken) async {
    try {
      print('Sending token to server: userId=$userId');
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/notification/register-token'), // FIXED: Added /api
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: json.encode({
          'userId': userId,
          'token': token,
        }),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        print('✅ FCM token registered successfully');
      } else {
        print('❌ Failed to register FCM token: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending token to server: $e');
    }
  }
}