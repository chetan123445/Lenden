import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';

class AdminNotificationsPage extends StatefulWidget {
  const AdminNotificationsPage({Key? key}) : super(key: key);

  @override
  _AdminNotificationsPageState createState() => _AdminNotificationsPageState();
}

class _AdminNotificationsPageState extends State<AdminNotificationsPage> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  final _messageController = TextEditingController();
  String _recipientType = 'all-users';
  final _recipientsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/notifications'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        _notifications = json.decode(response.body);
        _isLoading = false;
      });
    } else {
      // Handle error
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isSending = false;

  Future<void> _sendNotification() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final recipients =
        _recipientsController.text.split(',').map((e) => e.trim()).toList();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': _messageController.text,
          'recipientType': _recipientType,
          'recipients': recipients,
        }),
      );

      if (response.statusCode == 201) {
        _messageController.clear();
        _recipientsController.clear();
        _fetchNotifications();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8.0),
                Text(
                  'Notification sent successfully!',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            margin: const EdgeInsets.all(10.0),
          ),
        );
      } else {
        String errorMessage = 'Failed to send notification.';
        try {
          final errorBody = json.decode(response.body);
          if (errorBody != null && errorBody['message'] != null) {
            errorMessage = errorBody['message'];
          }
        } catch (e) {
          // If response.body is not valid JSON, use generic message
        }

        // Check for specific recipient not found message
        if (errorMessage.contains('The following recipients were not found:')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8.0),
                  Text(
                    'Some/one of the recipient(s) were not found. Please check the emails/usernames.',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              margin: const EdgeInsets.all(10.0),
            ),
          );
        } else {
          // Generic error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'Error: $errorMessage',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              margin: const EdgeInsets.all(10.0),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  'An unexpected error occurred: $e',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          margin: const EdgeInsets.all(10.0),
        ),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications/$notificationId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _fetchNotifications(); // Refresh the list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8.0),
                Text(
                  'Notification deleted successfully!',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            margin: const EdgeInsets.all(10.0),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to delete notification: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  Future<void> _editNotification(dynamic notification) async {
    if (notification == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Notification data is missing.')),
      );
      return;
    }

    final TextEditingController editMessageController =
        TextEditingController(text: notification['message'] ?? '');
    String editRecipientType = notification['recipientType'] ?? 'all-users';

    // Prepare recipients for display (email or username)
    String initialRecipientsText = '';
    if ((editRecipientType == 'specific-users' ||
            editRecipientType == 'specific-admins') &&
        notification['recipients'] != null &&
        notification['recipients'] is List &&
        notification['recipients'].isNotEmpty) {
      initialRecipientsText = (notification['recipients'] as List<dynamic>)
          .map<String>((r) {
            if (r['email'] != null &&
                r['email'] is String &&
                r['email'].isNotEmpty) {
              return r['email'] as String;
            } else if (r['username'] != null &&
                r['username'] is String &&
                r['username'].isNotEmpty) {
              return r['username'] as String;
            }
            return ''; // Fallback if neither email nor username is available
          })
          .where((text) => text.isNotEmpty)
          .join(', ');
    }
    final TextEditingController editRecipientsController =
        TextEditingController(text: initialRecipientsText);

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          backgroundColor: Colors.white,
          title: const Text(
            'Edit Notification',
            style: TextStyle(
              color: Color(0xFF00B4D8),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editMessageController,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: const BorderSide(color: Color(0xFF00B4D8)),
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),
                DropdownButtonFormField<String>(
                  value: editRecipientType,
                  decoration: InputDecoration(
                    labelText: 'Recipient Type',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: const BorderSide(color: Color(0xFF00B4D8)),
                    ),
                  ),
                  items: <String>[
                    'all-users',
                    'all-admins',
                    'specific-users',
                    'specific-admins'
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      // Store the old recipient type before updating
                      String oldRecipientType = editRecipientType;

                      setState(() {
                        editRecipientType = newValue;
                        // If recipient type changes, clear the recipients text field
                        if (oldRecipientType != newValue) {
                          editRecipientsController.clear();
                        }
                      });
                    }
                  },
                ),
                if (editRecipientType == 'specific-users' ||
                    editRecipientType == 'specific-admins')
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: TextField(
                      controller: editRecipientsController,
                      decoration: InputDecoration(
                        labelText: 'Recipients (comma-separated)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide:
                              const BorderSide(color: Color(0xFF00B4D8)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00B4D8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              child: const Text('Save'),
              onPressed: () async {
                final session =
                    Provider.of<SessionProvider>(context, listen: false);
                final token = session.token;
                final recipients = editRecipientsController.text
                    .split(',')
                    .map((e) => e.trim())
                    .toList();

                try {
                  final response = await http.put(
                    Uri.parse(
                        '${ApiConfig.baseUrl}/api/notifications/${notification['_id']}'),
                    headers: {
                      'Authorization': 'Bearer $token',
                      'Content-Type': 'application/json',
                    },
                    body: json.encode({
                      'message': editMessageController.text,
                      'recipientType': editRecipientType,
                      'recipients': recipients,
                    }),
                  );

                  if (response.statusCode == 200) {
                    _fetchNotifications(); // Refresh the list
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8.0),
                            Text(
                              'Notification updated successfully!',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        margin: const EdgeInsets.all(10.0),
                      ),
                    );
                    Navigator.of(context).pop(); // Close the dialog
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Failed to update notification: ${response.body}')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('An error occurred: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Admin Notifications',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Placeholder for alignment if needed, or remove if not
                      const SizedBox(
                          width:
                              48), // Adjust width to match IconButton's visual space
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
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
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(notification['message']),
                                    ),
                                    Consumer<SessionProvider>(
                                      builder: (context, session, child) {
                                        final currentAdminId = session.user!['_id'];
                                        final notificationSenderId = notification['sender'];

                                        if (currentAdminId == notificationSenderId) {
                                          return PopupMenuButton<String>(
                                            onSelected: (String result) {
                                              if (result == 'edit') {
                                                _editNotification(notification);
                                              } else if (result == 'delete') {
                                                _deleteNotification(
                                                    notification['_id']);
                                              }
                                            },
                                            itemBuilder: (BuildContext context) =>
                                                <PopupMenuEntry<String>>[
                                              const PopupMenuItem<String>(
                                                value: 'edit',
                                                child: Text('Edit'),
                                              ),
                                              const PopupMenuItem<String>(
                                                value: 'delete',
                                                child: Text('Delete'),
                                              ),
                                            ],
                                          );
                                        } else {
                                          return const SizedBox.shrink(); // Hide the three dots
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      DropdownButton<String>(
                        value: _recipientType,
                        onChanged: (String? newValue) {
                          setState(() {
                            _recipientType = newValue!;
                          });
                        },
                        items: <String>[
                          'all-users',
                          'all-admins',
                          'specific-users',
                          'specific-admins'
                        ].map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                      if (_recipientType == 'specific-users' ||
                          _recipientType == 'specific-admins')
                        TextField(
                          controller: _recipientsController,
                          decoration: const InputDecoration(
                            labelText: 'Recipients (comma-separated)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      const SizedBox(height: 8.0),
                      ElevatedButton(
                        onPressed: _isSending ? null : _sendNotification,
                        child: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text('Send Notification'),
                      ),
                    ],
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
