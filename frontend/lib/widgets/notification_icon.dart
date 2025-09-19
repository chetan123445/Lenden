import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import '../user/session.dart';
import '../admin/notifications_page.dart';
import '../user/notifications_page.dart';

class NotificationIcon extends StatefulWidget {
  @override
  _NotificationIconState createState() => _NotificationIconState();
}

class _NotificationIconState extends State<NotificationIcon> {
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUnreadNotificationCount();
  }

  Future<void> _fetchUnreadNotificationCount() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    if (session.token == null) return;

    final token = session.token;
    final url = '${ApiConfig.baseUrl}/api/notifications/unread-count';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _notificationCount = data['count'];
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, session, _) => Stack(
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () async {
              if (session.token != null && session.user != null) {
                if (session.isAdmin) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminNotificationsPage(),
                    ),
                  );
                } else {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserNotificationsPage(),
                    ),
                  );
                }
                _fetchUnreadNotificationCount();
              } else {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(24),
                    ),
                    backgroundColor:
                        const Color(0xFFF6F7FB),
                    elevation: 12,
                    title: Row(
                      children: [
                        Icon(Icons.lock_outline,
                            color: Color(0xFF00B4D8),
                            size: 28),
                        SizedBox(width: 10),
                        Text('Login Required',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 22)),
                      ],
                    ),
                    content: Text(
                      'Please login to view notifications.',
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87),
                    ),
                    actions: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor:
                              Color(0xFF00B4D8),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.of(context).pop(),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 18, vertical: 6),
                          child: Text('OK',
                              style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
          if (_notificationCount > 0)
            Positioned(
              right: 11,
              top: 11,
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(6),
                ),
                constraints: BoxConstraints(
                  minWidth: 14,
                  minHeight: 14,
                ),
                child: Text(
                  '$_notificationCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
