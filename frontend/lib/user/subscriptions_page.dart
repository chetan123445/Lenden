import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../api_config.dart';
import '../user/session.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({Key? key}) : super(key: key);

  @override
  _SubscriptionsPageState createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
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
          'userId': user['_id'],
          'subscriptionPlan': plan['name'],
          'duration': plan['duration'],
        }),
      );

      if (response.statusCode == 200) {
        // Update the session provider
        final session = Provider.of<SessionProvider>(context, listen: false);
        await session.checkSubscriptionStatus();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription successful!')),
        );
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Go Premium', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<SessionProvider>(
        builder: (context, session, child) {
          return Stack(
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
                  child: session.isSubscribed
                      ? _buildSubscribedView(session)
                      : _buildSubscribeView(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubscribedView(SessionProvider session) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.white, Colors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'You are a Premium Member!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildInfoRow('Subscription Plan:', session.subscriptionPlan ?? 'N/A'),
            const SizedBox(height: 10),
            _buildInfoRow('Expires On:', session.subscriptionEndDate?.toLocal().toString().split(' ')[0] ?? 'N/A'),
            const SizedBox(height: 20),
            const Text(
              'You have unlocked all premium features:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildBenefitItem(Icons.all_inclusive, 'Unlimited Transactions', ''),
            _buildBenefitItem(Icons.group_add, 'Unlimited Groups', ''),
            _buildBenefitItem(Icons.message, 'Unlimited Messaging', ''),
            _buildBenefitItem(Icons.star, 'View User Ratings', ''),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
    );
  }

  Widget _buildSubscribeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        ..._plans.map((plan) => _buildPlanSelector(plan['name']!)),
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
              onPressed: _subscribe,
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