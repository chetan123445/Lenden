import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../user/session.dart';
import 'dart:convert';
import '../api_config.dart';

import 'admin_ratings_page_helpers.dart';

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
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      final response = await http.get(
        Uri.parse(ApiConfig.baseUrl + '/api/rating/all'),
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
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 2),
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
                      showDialog(
                        context: context,
                        builder: (ctx) {
                          String formattedMemberSince = '';
                          if (rating['memberSince'] != null &&
                              rating['memberSince'].toString().isNotEmpty) {
                            try {
                              final dt = DateTime.parse(
                                  rating['memberSince'].toString());
                              formattedMemberSince =
                                  DateFormat('MMM d, yyyy, hh:mm a').format(dt);
                            } catch (e) {
                              formattedMemberSince =
                                  rating['memberSince'].toString();
                            }
                          }
                          // Format birthday to show only date
                          String formattedBirthday = '';
                          if (rating['birthday'] != null &&
                              rating['birthday'].toString().isNotEmpty) {
                            try {
                              final dt =
                                  DateTime.parse(rating['birthday'].toString());
                              formattedBirthday =
                                  DateFormat('MMM d, yyyy').format(dt);
                            } catch (e) {
                              formattedBirthday = rating['birthday'].toString();
                            }
                          }
                          final Map<String, dynamic> user = {
                            'Name': rating['userName'],
                            'Email': rating['userEmail'],
                            'Username': rating['username'],
                            'Gender': rating['gender'],
                            'Birthday': formattedBirthday,
                            'Phone': rating['phone'],
                            'Address': rating['address'],
                            'Alt Email': rating['altEmail'],
                            'Member Since': formattedMemberSince,
                            'Average Rating': rating['avgRating'],
                            'Role': rating['role'],
                            'Is Active': rating['isActive'],
                            'Is Verified': rating['isVerified'],
                          };
                          final fields = user.entries
                              .where((e) =>
                                  e.value != null &&
                                  e.value.toString().trim().isNotEmpty)
                              .toList();
                          // Robust profileImage extraction
                          String? profileImageUrl;
                          dynamic img;
                          if (rating['user'] != null && rating['user'] is Map) {
                            img = rating['user']['profileImage'];
                          } else {
                            img = rating['userProfileImage'];
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
                          String gender = rating['gender'] ?? 'Other';
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
                                            rating['userName'] ?? 'User',
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
            const Text('User Ratings', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 16),
              itemCount: _ratings.length,
              itemBuilder: (context, idx) => _buildRatingCard(_ratings[idx]),
            ),
    );
  }
}
