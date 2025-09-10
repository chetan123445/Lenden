import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api_config.dart';
import '../../user/session.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserNotificationsPage extends StatefulWidget {
  const UserNotificationsPage({Key? key}) : super(key: key);

  @override
  _UserNotificationsPageState createState() => _UserNotificationsPageState();
}

class _UserNotificationsPageState extends State<UserNotificationsPage> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  // This flag tracks if we have successfully fetched ALL notifications
  bool _isShowingAll = false;

  @override
  void initState() {
    super.initState();
    // Fetch the initial, limited list of notifications
    _fetchNotifications(viewAll: false);
  }

  Future<void> _fetchNotifications({required bool viewAll}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    
    // Construct the URL based on whether we want all notifications or the limited list
    final url = viewAll
        ? '${ApiConfig.baseUrl}/api/notifications?viewAll=true'
        : '${ApiConfig.baseUrl}/api/notifications';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _notifications = json.decode(response.body);
          _isLoading = false;
          // If we requested all notifications, update the flag
          if (viewAll) {
            _isShowingAll = true;
          }
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load notifications: ${response.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Notifications'),
        backgroundColor: const Color(0xFF00B4D8),
        foregroundColor: Colors.white,
      ),
      // The onRefresh should fetch the initial limited list again
      body: RefreshIndicator(
        onRefresh: () => _fetchNotifications(viewAll: false),
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
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8.0),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 16.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.0),
                                side: BorderSide(
                                  color:
                                      const Color(0xFF00B4D8).withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notification['message'],
                                      style: const TextStyle(fontSize: 16.0),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Text(
                                      'Received: ${DateTime.parse(notification['createdAt']).toLocal().toString().split('.')[0]}',
                                      style: const TextStyle(
                                          fontSize: 12.0, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // The "View All" button should appear if we aren't already showing all,
                      // and the initial fetch returned exactly 3 items (the max for the limited view).
                      if (!_isShowingAll && _notifications.length == 3)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton(
                            onPressed: () => _fetchNotifications(viewAll: true),
                            child: const Text('View All'),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}
