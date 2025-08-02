import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';

class EmailPasswordLogin {
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required BuildContext context,
  }) async {
    try {
      final userRes = await _loginUser(username: email, password: password, isEmail: true);
      final adminRes = await _loginAdmin(email: email, password: password);
      
      if (userRes['success']) {
        return {
          'success': true,
          'userOrAdmin': userRes['data'],
          'userType': 'user',
          'token': userRes['token'],
        };
      } else if (adminRes['success']) {
        return {
          'success': true,
          'userOrAdmin': adminRes['data'],
          'userType': 'admin',
          'token': adminRes['token'],
        };
      } else {
        String? error;
        if (userRes['error'] != null && userRes['error'] != 'User not found') {
          error = userRes['error'];
        } else if (adminRes['error'] != null && adminRes['error'] != 'User not found') {
          error = adminRes['error'];
        } else {
          error = 'User not found';
        }
        return {'success': false, 'error': error};
      }
    } catch (e) {
      return {'success': false, 'error': 'Login failed. Please try again.'};
    }
  }

  static Future<Map<String, dynamic>> _loginAdmin({String? email, String? username, required String password}) async {
    try {
      print('🔐 Attempting admin login for username/email: ${email ?? username}');
      final res = await _post('/api/admins/login', {
        if (email != null) 'username': email,
        if (username != null) 'username': username,
        'password': password,
      });
      print('📥 Admin login response status: ${res['status']}');
      print('📥 Admin login response data: ${res['data']}');
      
      if (res['status'] == 200 && res['data']['admin'] != null) {
        print('✅ Admin login successful');
        return {'success': true, 'data': res['data']['admin'], 'token': res['data']['token']};
      }
      print('❌ Admin login failed: ${res['data']['error']}');
      return {'success': false, 'error': res['data']['error']};
    } catch (e) {
      print('❌ Admin login exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _loginUser({String? username, required String password, bool isEmail = false}) async {
    try {
      print('🔐 Attempting user login for username: $username');
      final res = await _post('/api/users/login', {
        'username': username,
        'password': password,
      });
      print('📥 User login response status: ${res['status']}');
      print('📥 User login response data: ${res['data']}');
      
      if (res['status'] == 200 && res['data']['user'] != null) {
        print('✅ User login successful');
        return {'success': true, 'data': res['data']['user'], 'token': res['data']['token']};
      }
      print('❌ User login failed: ${res['data']['error']}');
      return {'success': false, 'error': res['data']['error']};
    } catch (e) {
      print('❌ User login exception: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      print('🌐 Making API call to: ${ApiConfig.baseUrl + path}');
      print('📤 Request body: ${jsonEncode(body)}');
      
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + path),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Lenden-Flutter-App/1.0',
        },
        body: jsonEncode(body),
      );
      
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response headers: ${response.headers}');
      print('📥 Response body: ${response.body}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return {'status': response.statusCode, 'data': data};
      } else if (response.statusCode == 404) {
        return {'status': 404, 'data': {'error': 'API endpoint not found'}};
      } else if (response.statusCode == 500) {
        return {'status': 500, 'data': {'error': 'Server error'}};
      } else {
        final data = jsonDecode(response.body);
        return {'status': response.statusCode, 'data': data};
      }
    } catch (e) {
      print('❌ API call error: $e');
      if (e.toString().contains('SocketException')) {
        return {'status': 0, 'data': {'error': 'No internet connection'}};
      } else if (e.toString().contains('HandshakeException')) {
        return {'status': 0, 'data': {'error': 'SSL/TLS connection failed'}};
      } else {
        return {'status': 500, 'data': {'error': e.toString()}};
      }
    }
  }

  static void showIncorrectPasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: const Color(0xFFF8F6FA),
        title: Row(
          children: const [
            Icon(Icons.lock_outline, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Incorrect Password', style: TextStyle(color: Colors.black)),
          ],
        ),
        content: const Text(
          'The password you entered is incorrect.',
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.deepPurple)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/forgot-password');
            },
            child: const Text('Forgot Password', style: TextStyle(color: Color(0xFF00B4D8), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showUserNotFoundDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: const Color(0xFFF8F6FA),
        title: Row(
          children: const [
            Icon(Icons.person_off, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text('User Not Found', style: TextStyle(color: Colors.black)),
          ],
        ),
        content: const Text(
          'No user found with these credentials. Would you like to register?',
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.deepPurple)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacementNamed(context, '/register');
            },
            child: const Text('Register', style: TextStyle(color: Color(0xFF00B4D8), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
} 