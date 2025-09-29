import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import '../otp_input.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class EmailOtpLogin {
  static Future<Map<String, dynamic>> sendOtp({
    required String email,
    required BuildContext context,
  }) async {
    try {
      final otpSendRes = await _post('/api/users/send-login-otp', {
        'email': email,
      });

      if (otpSendRes['status'] == 200) {
        return {'success': true};
      } else {
        return {
          'success': false,
          'error': otpSendRes['data']['error'] ?? 'User not found'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to send OTP. Please try again.'
      };
    }
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
    required BuildContext context,
    String? deviceId,
  }) async {
    try {
      print('🔐 Attempting OTP verification for email: $email');
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      String deviceName;
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceName = androidInfo.model;
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.utsname.machine;
      } else if (Platform.isLinux) {
        LinuxDeviceInfo linuxInfo = await deviceInfo.linuxInfo;
        deviceName = linuxInfo.name;
      } else if (Platform.isWindows) {
        WindowsDeviceInfo windowsInfo = await deviceInfo.windowsInfo;
        deviceName = windowsInfo.computerName;
      } else if (Platform.isMacOS) {
        MacOsDeviceInfo macOsInfo = await deviceInfo.macOsInfo;
        deviceName = macOsInfo.computerName;
      } else {
        deviceName = 'Unknown Device';
      }
      final otpVerifyRes = await _post('/api/users/verify-login-otp', {
        'email': email,
        'otp': otp,
        'deviceName': deviceName,
        if (deviceId != null) 'deviceId': deviceId,
      });

      print('📥 OTP verification response status: ${otpVerifyRes['status']}');
      print('📥 OTP verification response data: ${otpVerifyRes['data']}');

      if (otpVerifyRes['status'] == 200) {
        final userOrAdmin =
            otpVerifyRes['data']['user'] ?? otpVerifyRes['data']['admin'];
        final userType = otpVerifyRes['data']['userType'] ?? 'user';
        final token = otpVerifyRes['data']['token'];

        print('✅ OTP verification successful');
        print('👤 User data: $userOrAdmin');
        print('🔑 User type: $userType');
        print('🎫 Token: ${token != null ? 'Present' : 'Missing'}');
        print('🎫 Token length: ${token?.length ?? 0}');
        print('📋 Full response data: ${otpVerifyRes['data']}');
        print('📋 Response keys: ${otpVerifyRes['data'].keys.toList()}');

        // Check if userOrAdmin is null or empty
        if (userOrAdmin == null) {
          print('❌ ERROR: userOrAdmin is null!');
          print(
              '❌ Available keys in data: ${otpVerifyRes['data'].keys.toList()}');
        }

        // Check if token is null or empty
        if (token == null || token.isEmpty) {
          print('❌ ERROR: Token is null or empty!');
          print('❌ Token value: "$token"');
        }

        return {
          'success': true,
          'userOrAdmin': userOrAdmin,
          'userType': userType,
          'token': token,
        };
      } else if (otpVerifyRes['status'] == 403 &&
          otpVerifyRes['data']['canRecover'] == true) {
        return {
          'success': false,
          'canRecover': true,
          'error': otpVerifyRes['data']['error'],
          'email': otpVerifyRes['data']['email'],
          'username': otpVerifyRes['data']['username'],
        };
      } else {
        print('❌ OTP verification failed: ${otpVerifyRes['data']['error']}');
        return {
          'success': false,
          'error': otpVerifyRes['data']['error'] ?? 'OTP verification failed.'
        };
      }
    } catch (e) {
      print('❌ OTP verification exception: $e');
      return {
        'success': false,
        'error': 'OTP verification failed. Please try again.'
      };
    }
  }

  static Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + path),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Lenden-Flutter-App/1.0',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return {'status': response.statusCode, 'data': data};
      } else if (response.statusCode == 404) {
        return {
          'status': 404,
          'data': {'error': 'API endpoint not found'}
        };
      } else if (response.statusCode == 500) {
        return {
          'status': 500,
          'data': {'error': 'Server error'}
        };
      } else {
        final data = jsonDecode(response.body);
        return {'status': response.statusCode, 'data': data};
      }
    } catch (e) {
      if (e.toString().contains('SocketException')) {
        return {
          'status': 0,
          'data': {'error': 'No internet connection'}
        };
      } else if (e.toString().contains('HandshakeException')) {
        return {
          'status': 0,
          'data': {'error': 'SSL/TLS connection failed'}
        };
      } else {
        return {
          'status': 500,
          'data': {'error': e.toString()}
        };
      }
    }
  }

  static Future<String?> showOtpInputDialog(BuildContext context) async {
    String? otpValue;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: const Color(0xFFF8F6FA),
          title: Row(
            children: const [
              Icon(Icons.lock_clock, color: Color(0xFF00B4D8), size: 28),
              SizedBox(width: 8),
              Text('Enter OTP', style: TextStyle(color: Colors.black)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the 6-digit OTP sent to your email:',
                  style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              OtpInput(
                onChanged: (val) => otpValue = val,
                enabled: true,
                autoFocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.deepPurple)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Verify',
                  style: TextStyle(
                      color: Color(0xFF00B4D8), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    return otpValue;
  }

  static void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
