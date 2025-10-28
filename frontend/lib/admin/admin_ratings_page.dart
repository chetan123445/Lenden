import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import 'dart:convert';
import 'admin_ratings_page_helpers.dart';
import '../profile/profile_page.dart' hide TopWaveClipper, BottomWaveClipper;
import '../utils/api_client.dart';

class AdminRatingsPage extends StatefulWidget {
  const AdminRatingsPage({Key? key}) : super(key: key);

  @override
  State<AdminRatingsPage> createState() => _AdminRatingsPageState();
}

class _AdminRatingsPageState extends State<AdminRatingsPage> {
  List<Map<String, dynamic>> _ratings = [];
  bool _isLoading = false;

  Future<void> _fetchRatings() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await ApiClient.get('/api/rating/all');
      print('DEBUG: Status code: [33m${response.statusCode}[0m');
      print('DEBUG: Response body: [36m${response.body}[0m');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _ratings = List<Map<String, dynamic>>.from(data['ratings'] ?? []);
        });
      } else {
        print('DEBUG: Non-200 response received');
      }
    } catch (e) {
      print('DEBUG: Exception in _fetchRatings: $e');
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchRatings();
  }

  Widget _buildRatingCard(Map<String, dynamic> rating) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(0xFF00B4D8), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF00B4D8),
              child: Icon(Icons.star, color: Colors.white),
              radius: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rating['userName'] ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (rating['userEmail'] != null)
                    Text(rating['userEmail'],
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey)),
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < (rating['rating'] ?? 0)
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 20,
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.person, size: 18),
                    label: const Text('View Profile'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ProfilePage(email: rating['userEmail']),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(rating['createdAt']?.toString().substring(0, 10) ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00B4D8),
        title:
            const Text('User Ratings', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
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
                height: 70,
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
                height: 50,
                color: const Color(0xFF00B4D8),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80, top: 48),
                    itemCount: _ratings.length,
                    itemBuilder: (context, idx) =>
                        _buildRatingCard(_ratings[idx]),
                  ),
          ),
        ],
      ),
    );
  }
}
