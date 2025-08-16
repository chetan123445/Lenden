import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import '../user/session.dart';
import 'dart:convert';
import '../api_config.dart';

class AdminFeedbacksPage extends StatefulWidget {
  const AdminFeedbacksPage({Key? key}) : super(key: key);

  @override
  State<AdminFeedbacksPage> createState() => _AdminFeedbacksPageState();
}

class _AdminFeedbacksPageState extends State<AdminFeedbacksPage> {
  List<Map<String, dynamic>> _feedbacks = [];
  bool _isLoading = false;

  Future<void> _fetchFeedbacks() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      final response = await http.get(
        Uri.parse(ApiConfig.baseUrl + '/api/feedbacks/all'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      print('DEBUG: Status code: [33m${response.statusCode}[0m');
      print('DEBUG: Response body: [36m${response.body}[0m');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _feedbacks = List<Map<String, dynamic>>.from(data['feedbacks'] ?? []);
        });
      } else {
        print('DEBUG: Non-200 response received');
      }
    } catch (e) {
      print('DEBUG: Exception in _fetchFeedbacks: $e');
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchFeedbacks();
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.2), width: 2),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF00B4D8),
              child: Icon(Icons.feedback, color: Colors.white),
              radius: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(feedback['userName'] ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (feedback['userEmail'] != null)
                    Text(feedback['userEmail'],
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(feedback['feedback'] ?? '',
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.person, size: 18),
                    label: const Text('View Profile'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) {
                          // Collect all user fields except password and nulls
                          final Map<String, dynamic> user = {
                            'Name': feedback['userName'],
                            'Email': feedback['userEmail'],
                            'Username': feedback['username'],
                            'Gender': feedback['gender'],
                            'Birthday': feedback['birthday'],
                            'Phone': feedback['phone'],
                          };
                          // Remove null/empty fields
                          final fields = user.entries
                              .where((e) =>
                                  e.value != null &&
                                  e.value.toString().trim().isNotEmpty)
                              .toList();
                          // Profile image logic
                          String? profileImageUrl;
                          final img = feedback['userProfileImage'];
                          if (img != null) {
                            if (img is String &&
                                img.trim().isNotEmpty &&
                                img != 'null') {
                              profileImageUrl = img;
                            } else if (img is Map &&
                                img['url'] is String &&
                                img['url'].trim().isNotEmpty) {
                              profileImageUrl = img['url'];
                            }
                          }
                          // Gender-based default avatar
                          String gender = feedback['gender'] ?? 'Other';
                          ImageProvider avatarProvider;
                          if (profileImageUrl != null) {
                            avatarProvider = NetworkImage(profileImageUrl);
                          } else {
                            avatarProvider = AssetImage(
                              gender == 'Male'
                                  ? 'assets/Male.png'
                                  : gender == 'Female'
                                      ? 'assets/Female.png'
                                      : 'assets/Other.png',
                            );
                          }
                          return Dialog(
                            backgroundColor: const Color(0xFFF8F6FA),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 38,
                                    backgroundColor: const Color(0xFF00B4D8),
                                    backgroundImage: avatarProvider,
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    feedback['userName'] ?? 'User',
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black),
                                  ),
                                  const SizedBox(height: 18),
                                  ...fields.map((e) => Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.04),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              '${e.key}: ',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15),
                                            ),
                                            Expanded(
                                              child: Text(
                                                e.value.toString(),
                                                style: const TextStyle(
                                                    fontSize: 15),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                  const SizedBox(height: 10),
                                  TextButton(
                                    child: const Text('Close',
                                        style: TextStyle(
                                            color: Color(0xFF6C63FF))),
                                    onPressed: () => Navigator.of(ctx).pop(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(feedback['createdAt']?.toString().substring(0, 10) ?? '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(feedback['createdAt']?.toString().substring(11, 16) ?? '',
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
        backgroundColor: Colors.deepPurple,
        title:
            const Text('User Feedbacks', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 16),
              itemCount: _feedbacks.length,
              itemBuilder: (context, idx) =>
                  _buildFeedbackCard(_feedbacks[idx]),
            ),
    );
  }
}
