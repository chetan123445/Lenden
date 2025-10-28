import 'dart:convert';
import 'package:flutter/material.dart';
import '../api_config.dart';
import '../otp_input.dart';
import '../utils/api_client.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class EmailOtpLogin {
  static Future<Map<String, dynamic>> sendOtp({
    required String email,
    required BuildContext context,
  }) async {
    try {
      final response = await ApiClient.post('/api/users/send-login-otp', body: {
        'email': email,
      });

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        final responseData = jsonDecode(response.body);
        return {
          'success': false,
          'error': responseData['error'] ?? 'User not found'
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
      if (kIsWeb) {
        deviceName = 'Web Browser';
      } else {
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
      }
      final response = await ApiClient.post('/api/users/verify-login-otp', body: {
        'email': email,
        'otp': otp,
        'deviceName': deviceName,
        if (deviceId != null) 'deviceId': deviceId,
      });

      final responseData = jsonDecode(response.body);
      print('📥 OTP verification response status: ${response.statusCode}');
      print('📥 OTP verification response data: $responseData');

      if (response.statusCode == 200) {
        final userOrAdmin =
            responseData['user'] ?? responseData['admin'];
        final userType = responseData['userType'] ?? 'user';
        final accessToken = responseData['accessToken'];
        final refreshToken = responseData['refreshToken'];

        print('✅ OTP verification successful');
        print('👤 User data: $userOrAdmin');
        print('🔑 User type: $userType');
        print('🎫 Access Token: ${accessToken != null ? 'Present' : 'Missing'}');
        print('🎫 Refresh Token: ${refreshToken != null ? 'Present' : 'Missing'}');
        print('🎫 Access Token length: ${accessToken?.length ?? 0}');
        print('🎫 Refresh Token length: ${refreshToken?.length ?? 0}');
        print('📋 Full response data: $responseData');
        print('📋 Response keys: ${responseData.keys.toList()}');

        // Check if userOrAdmin is null or empty
        if (userOrAdmin == null) {
          print('❌ ERROR: userOrAdmin is null!');
          print(
              '❌ Available keys in data: ${responseData.keys.toList()}');
        }

        // Check if tokens are null or empty
        if (accessToken == null || accessToken.isEmpty) {
          print('❌ ERROR: Access token is null or empty!');
          print('❌ Access token value: "$accessToken"');
        }

        if (refreshToken == null || refreshToken.isEmpty) {
          print('❌ ERROR: Refresh token is null or empty!');
          print('❌ Refresh token value: "$refreshToken"');
        }

        return {
          'success': true,
          'userOrAdmin': userOrAdmin,
          'userType': userType,
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        };
      } else if (response.statusCode == 403 &&
          responseData['canRecover'] == true) {
        return {
          'success': false,
          'canRecover': true,
          'error': responseData['error'],
          'email': responseData['email'],
          'username': responseData['username'],
        };
      } else {
        print('❌ OTP verification failed: ${responseData['error']}');
        return {
          'success': false,
          'error': responseData['error'] ?? 'OTP verification failed.'
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
