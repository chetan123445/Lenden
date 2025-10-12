import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import '../api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../main.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({Key? key}) : super(key: key);

  @override
  _SubscriptionPageState createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool _isLoading = false;

  Future<void> _updateSubscription(bool isSubscribed) async {
    setState(() {
      _isLoading = true;
    });

    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final userId = session.user!['_id'];

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/users/subscription'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'isSubscribed': isSubscribed,
        }),
      );

      if (response.statusCode == 200) {
        // Update the session provider
        session.updateSubscription(isSubscribed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update subscription.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF8F6FA),
      body: Stack(
        children: [
          // Top blue wave
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopWaveClipper(),
              child: Container(
                height: 120,
                color: const Color(0xFF00B4D8),
              ),
            ),
          ),
          // Bottom blue wave
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipPath(
              clipper: BottomWaveClipper(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.13,
                color: const Color(0xFF00B4D8),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Do you want to subscribe?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 30),
                  _isLoading
                      ? CircularProgressIndicator()
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.orange, Colors.white, Colors.green],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.all(2.5),
                              child: ElevatedButton(
                                onPressed: () => _updateSubscription(true),
                                child: Text('Yes'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00B4D8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(21.5),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 20),
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.orange, Colors.white, Colors.green],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.all(2.5),
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('No'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF00B4D8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(21.5),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}