import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import '../user/session.dart';
import 'dart:convert';
import '../api_config.dart';
import 'admin_ratings_page_helpers.dart';

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
                          String formattedMemberSince = '';
                          if (feedback['memberSince'] != null &&
                              feedback['memberSince'].toString().isNotEmpty) {
                            try {
                              final dt = DateTime.parse(
                                  feedback['memberSince'].toString());
                              formattedMemberSince =
                                  DateFormat('MMM d, yyyy, hh:mm a').format(dt);
                            } catch (e) {
                              formattedMemberSince =
                                  feedback['memberSince'].toString();
                            }
                          }
                          // Format birthday to show only date
                          String formattedBirthday = '';
                          if (feedback['birthday'] != null &&
                              feedback['birthday'].toString().isNotEmpty) {
                            try {
                              final dt = DateTime.parse(
                                  feedback['birthday'].toString());
                              formattedBirthday =
                                  DateFormat('MMM d, yyyy').format(dt);
                            } catch (e) {
                              formattedBirthday =
                                  feedback['birthday'].toString();
                            }
                          }
                          final Map<String, dynamic> user = {
                            'Name': feedback['userName'],
                            'Email': feedback['userEmail'],
                            'Username': feedback['username'],
                            'Gender': feedback['gender'],
                            'Birthday': formattedBirthday,
                            'Phone': feedback['phone'],
                            'Address': feedback['address'],
                            'Alt Email': feedback['altEmail'],
                            'Member Since': formattedMemberSince,
                            'Average Rating': feedback['avgRating'],
                            'Role': feedback['role'],
                            'Is Active': feedback['isActive'],
                            'Is Verified': feedback['isVerified'],
                          };
                          final fields = user.entries
                              .where((e) =>
                                  e.value != null &&
                                  e.value.toString().trim().isNotEmpty)
                              .toList();
                          // Robust profileImage extraction
                          String? profileImageUrl;
                          dynamic img;
                          if (feedback['user'] != null &&
                              feedback['user'] is Map) {
                            img = feedback['user']['profileImage'];
                          } else {
                            img = feedback['userProfileImage'];
                          }
                          if (img != null) {
                            if (img is String &&
                                img.trim().isNotEmpty &&
                                img != 'null') {
                              profileImageUrl = img;
                            } else if (img is Map) {
                              if (img['url'] is String &&
                                  img['url'].trim().isNotEmpty &&
                                  img['url'] != 'null') {
                                profileImageUrl = img['url'];
                              } else if (img['data'] is String &&
                                  img['data'].trim().isNotEmpty &&
                                  img['data'] != 'null') {
                                profileImageUrl = img['data'];
                              }
                            }
                          }
                          // Add cache busting if needed
                          if (profileImageUrl != null &&
                              profileImageUrl.trim().isNotEmpty &&
                              profileImageUrl != 'null') {
                            profileImageUrl = profileImageUrl +
                                '?v=${DateTime.now().millisecondsSinceEpoch}';
                          }
                          String gender = feedback['gender'] ?? 'Other';
                          ImageProvider avatarProvider;
                          if (profileImageUrl != null &&
                              profileImageUrl.trim().isNotEmpty &&
                              profileImageUrl != 'null') {
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
                                borderRadius: BorderRadius.circular(32)),
                            child: Stack(
                              children: [
                                // Top wave
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
                                // Bottom wave
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: ClipPath(
                                    clipper: BottomWaveClipper(),
                                    child: Container(
                                      height: 50,
                                      color: const Color(0xFF00B4D8),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 24),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 10),
                                        Center(
                                          child: CircleAvatar(
                                            radius: 44,
                                            backgroundColor:
                                                const Color(0xFF00B4D8),
                                            backgroundImage: avatarProvider,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        Center(
                                          child: Text(
                                            feedback['userName'] ?? 'User',
                                            style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black),
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        ...fields.map((e) => Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.05),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(getIconForField(e.key),
                                                      color: const Color(
                                                          0xFF00B4D8)),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Text.rich(
                                                      TextSpan(
                                                        children: [
                                                          TextSpan(
                                                            text: '${e.key}: ',
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16),
                                                          ),
                                                          TextSpan(
                                                            text: e.value
                                                                .toString(),
                                                            style: const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )),
                                        const SizedBox(height: 18),
                                        TextButton(
                                          child: const Text('Close',
                                              style: TextStyle(
                                                  color: Color(0xFF6C63FF))),
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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
