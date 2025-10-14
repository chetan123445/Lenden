import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../api_config.dart';
import '../user/session.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({Key? key}) : super(key: key);

  @override
  _SubscriptionPageState createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  String? _selectedPlan;

  final List<Map<String, dynamic>> _plans = [
    {'name': '1 month', 'duration': 1},
    {'name': '2 months', 'duration': 2},
    {'name': '3 months', 'duration': 3},
    {'name': '6 months', 'duration': 6},
    {'name': '1 year', 'duration': 12},
  ];

  Future<void> _subscribe() async {
    if (_selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subscription plan.')),
      );
      return;
    }

    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final user = session.user;

    if (token == null || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to subscribe.')),
      );
      return;
    }

    final plan = _plans.firstWhere((p) => p['name'] == _selectedPlan);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/subscription/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'subscriptionPlan': plan['name'],
          'duration': plan['duration'],
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription successful!')),
        );
        // Update subscription status in SessionProvider
        await session.checkSubscriptionStatus();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to subscribe: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Provider.of<SessionProvider>(context, listen: false).checkSubscriptionStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final session = Provider.of<SessionProvider>(context);
        final isSubscribed = session.isSubscribed;
        final currentPlan = session.subscriptionPlan;
        final endDate = session.subscriptionEndDate;
        final subscriptionHistory = session.subscriptionHistory;

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Go Premium', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipPath(
                  clipper: TopWaveClipper(),
                  child: Container(
                    height: 150,
                    color: const Color(0xFF00B4D8),
                  ),
                ),
              ),
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (subscriptionHistory != null && subscriptionHistory.isNotEmpty)
                        _buildSubscriptionHistory(subscriptionHistory),
                      const SizedBox(height: 60),
                      _buildBenefitItem(Icons.all_inclusive, 'Unlimited Transactions', 'Create as many transactions as you need without any limits.'),
                      _buildBenefitItem(Icons.group_add, 'Unlimited Groups', 'Create and manage an unlimited number of groups for your transactions.'),
                      _buildBenefitItem(Icons.message, 'Unlimited Messaging', 'Enjoy unlimited messaging in both one-to-one and group chats.'),
                      _buildBenefitItem(Icons.star, 'View User Ratings', 'See the ratings of other users to build a trusted network.'),
                      const SizedBox(height: 30),
                      const Text(
                        'Select a Plan',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),

                      if (isSubscribed && currentPlan != null && endDate != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            'You are already subscribed to $currentPlan until ${endDate.toLocal().toString().substring(0, 10)}.',
                            style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ] else ...[
                        ..._plans.map((plan) => RadioListTile<String>(
                          title: Text(plan['name']!),
                          value: plan['name']!,
                          groupValue: _selectedPlan,
                          onChanged: isSubscribed ? null : (value) {
                            setState(() {
                              _selectedPlan = value;
                            });
                          },
                          activeColor: const Color(0xFF00B4D8),
                        )),
                        const SizedBox(height: 30),
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.orange, Colors.white, Colors.green],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: ElevatedButton(
                              onPressed: isSubscribed ? null : _subscribe,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text(
                                'Subscribe Now',
                                style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionHistory(List<Map<String, dynamic>> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Subscription History',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...history.map((sub) => Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(
              width: 2,
              color: Color(0xFF00B4D8),
            ),
          ),
          child: ListTile(
            title: Text(sub['subscriptionPlan'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Expired on: ${DateTime.parse(sub['endDate']).toLocal().toString().substring(0, 10)}'),
          ),
        )),
      ],
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(
          width: 2,
          color: Color(0xFF00B4D8),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF00B4D8), size: 40),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget _buildPlanSelector(String planName) {
    return RadioListTile<String>(
      title: Text(planName),
      value: planName,
      groupValue: _selectedPlan,
      onChanged: (value) {
        setState(() {
          _selectedPlan = value;
        });
      },
      activeColor: const Color(0xFF00B4D8),
    );
  }
}

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    // Reduce wave depth to roughly half
    path.lineTo(0, size.height * 0.35);
    path.quadraticBezierTo(
        size.width * 0.25, size.height * 0.5, size.width * 0.5, size.height * 0.35);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.2, size.width, size.height * 0.35);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.6,
        size.width * 0.5, size.height * 0.4);
    path.quadraticBezierTo(size.width * 0.75, 0, size.width, size.height * 0.4);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}