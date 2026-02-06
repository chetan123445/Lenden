import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import 'dart:convert';
import '../api_config.dart';
import '../utils/api_client.dart';
import 'friends_page.dart';

class UserNotificationsPage extends StatefulWidget {
  const UserNotificationsPage({Key? key}) : super(key: key);

  @override
  _UserNotificationsPageState createState() => _UserNotificationsPageState();
}

class _UserNotificationsPageState extends State<UserNotificationsPage> {
  List<dynamic> _notifications = [];
  List<Map<String, dynamic>> _incomingRequests = [];
  final Set<String> _removingRequestIds = {};
  bool _isLoading = true;
  bool _isShowingAll = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
    _fetchFriendRequests();
    _markNotificationsAsRead();
  }

  Color _getNoteColor(int index) {
    final colors = [
      Color(0xFFFFF4E6), // Cream
      Color(0xFFE8F5E9), // Light green
      Color(0xFFFCE4EC), // Light pink
      Color(0xFFE3F2FD), // Light blue
      Color(0xFFFFF9C4), // Light yellow
      Color(0xFFF3E5F5), // Light purple
    ];
    return colors[index % colors.length];
  }

  void _calculateUnreadCount() {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final userId = session.user!['_id'];
    _unreadCount = _notifications
        .where((notification) => !notification['readBy'].contains(userId))
        .length;
  }

  Future<void> _fetchNotifications({bool viewAll = false}) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final url = viewAll
        ? '/api/notifications?viewAll=true'
        : '/api/notifications';
    final response = await ApiClient.get(url);

    if (response.statusCode == 200) {
      setState(() {
        _notifications = json.decode(response.body);
        _isLoading = false;
        if (viewAll) {
          _isShowingAll = true;
        }
        _calculateUnreadCount();
      });
    } else {
      // Handle error
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchFriendRequests() async {
    final res = await ApiClient.get('/api/friends/requests');
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() {
        _incomingRequests =
            List<Map<String, dynamic>>.from(data['incoming'] ?? []);
      });
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    setState(() => _removingRequestIds.add(requestId));
    final res =
        await ApiClient.post('/api/friends/requests/$requestId/accept');
    if (res.statusCode == 200) {
      await Future.delayed(const Duration(milliseconds: 250));
      setState(() {
        _incomingRequests.removeWhere((r) => r['_id'] == requestId);
        _removingRequestIds.remove(requestId);
      });
    }
  }

  Future<void> _declineRequest(String requestId) async {
    setState(() => _removingRequestIds.add(requestId));
    final res =
        await ApiClient.post('/api/friends/requests/$requestId/decline');
    if (res.statusCode == 200) {
      await Future.delayed(const Duration(milliseconds: 250));
      setState(() {
        _incomingRequests.removeWhere((r) => r['_id'] == requestId);
        _removingRequestIds.remove(requestId);
      });
    }
  }

  Future<void> _markNotificationsAsRead() async {
    await ApiClient.post('/api/notifications/mark-as-read');
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context);
    final userId = session.user!['_id'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FA),
      body: Stack(
        children: [
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
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: BottomWaveClipper(),
              child: Container(
                height: 90,
                color: const Color(0xFF00B4D8),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      Expanded(
                        child: Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Placeholder for alignment if needed, or remove if not
                      const SizedBox(
                          width: 48), // Adjust width to match IconButton's visual space
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _notifications.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_off_outlined,
                                    size: 80,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No notifications yet.',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              margin: const EdgeInsets.only(top: 30),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(8.0),
                                      itemCount: _notifications.length +
                                          (_incomingRequests.isNotEmpty
                                              ? 1
                                              : 0),
                                      itemBuilder: (context, index) {
                                        if (_incomingRequests.isNotEmpty &&
                                            index == 0) {
                                          return Container(
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 8.0,
                                                horizontal: 16.0),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Colors.orange,
                                                  Colors.white,
                                                  Colors.green
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.06),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: _getNoteColor(index),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Friend Requests',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ..._incomingRequests
                                                      .map((r) {
                                                    final from =
                                                        r['from'] ?? {};
                                                    final name = from['name'] ??
                                                        from['username'] ??
                                                        '';
                                                    final email =
                                                        from['email'] ?? '';
                                                    final isRemoving =
                                                        _removingRequestIds
                                                            .contains(r['_id']);
                                                    return AnimatedSize(
                                                      duration:
                                                          const Duration(
                                                              milliseconds:
                                                                  250),
                                                      child: AnimatedOpacity(
                                                        duration:
                                                            const Duration(
                                                                milliseconds:
                                                                    250),
                                                        opacity:
                                                            isRemoving ? 0 : 1,
                                                        child: ListTile(
                                                          contentPadding:
                                                              EdgeInsets.zero,
                                                          title: Text(
                                                              name.toString()),
                                                          subtitle: Text(
                                                              email.toString()),
                                                          trailing: Wrap(
                                                            spacing: 8,
                                                            children: [
                                                              TextButton(
                                                                onPressed:
                                                                    isRemoving
                                                                        ? null
                                                                        : () =>
                                                                            _declineRequest(
                                                                                r['_id']),
                                                                child:
                                                                    const Text(
                                                                        'Decline'),
                                                              ),
                                                              ElevatedButton(
                                                                onPressed:
                                                                    isRemoving
                                                                        ? null
                                                                        : () =>
                                                                            _acceptRequest(
                                                                                r['_id']),
                                                                child:
                                                                    const Text(
                                                                        'Accept'),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ],
                                              ),
                                            ),
                                          );
                                        }
                                        final actualIndex =
                                            _incomingRequests.isNotEmpty
                                                ? index - 1
                                                : index;
                                        final notification =
                                            _notifications[actualIndex];
                                        final bool isRead =
                                            notification['readBy'].contains(userId);
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 8.0, horizontal: 16.0),
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(18),
                                            gradient: const LinearGradient(
                                              colors: [
                                                Colors.orange,
                                                Colors.white,
                                                Colors.green
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: _getNoteColor(index),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: ListTile(
                                              title: Text(notification['message']),
                                              onTap: () {
                                                final msg = (notification['message'] ?? '')
                                                    .toString()
                                                    .toLowerCase();
                                                if (msg.contains('friend request')) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            const FriendsPage()),
                                                  );
                                                }
                                              },
                                              trailing: isRead
                                                  ? null
                                                  : Container(
                                                      width: 10,
                                                      height: 10,
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  if (_notifications.length == 3 &&
                                      !_isShowingAll)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 16.0),
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            _fetchNotifications(viewAll: true),
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          elevation: 5,
                                        ),
                                        child: Ink(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF00B4D8),
                                                Color(0xFF0077B6)
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Container(
                                            width: 150,
                                            height: 40,
                                            alignment: Alignment.center,
                                            child: const Text(
                                              'View All',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(
        size.width * 0.25, size.height, size.width * 0.5, size.height * 0.7);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.4, size.width, size.height * 0.7);
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
