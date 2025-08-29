
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';

class NotificationService {
  Future<void> registerDeviceToken(String userId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/notification/register-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'token': token}),
      );
      if (response.statusCode == 200) {
        print('Device token registered successfully');
      } else {
        print('Failed to register device token: ${response.body}');
      }
    } catch (e) {
      print('Error registering device token: $e');
    }
  }
}
