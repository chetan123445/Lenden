import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import '../user/session.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:math';

class HelpSupportPage extends StatefulWidget {
  @override
  _HelpSupportPageState createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController =
      TextEditingController(); // Add search controller
  List<dynamic> _queries = [];
  bool _isLoading = true;
  String? _error;
  IO.Socket? socket;
  bool _showAllQueries = false;
  String _searchTerm = ''; // Track search term

  @override
  void initState() {
    super.initState();
    _fetchUserQueries();
    _connectSocket();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    socket?.disconnect();
    socket?.dispose();
    super.dispose();
  }

  void _connectSocket() {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      print('Socket: Authentication token not found. Cannot connect.');
      return;
    }

    try {
      socket = IO.io(
        ApiConfig.baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableForceNew()
            .disableAutoConnect()
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .build(),
      );

      socket?.connect();

      socket?.onConnect((_) => print('Socket Connected: ${socket?.id}'));
      socket?.onDisconnect((_) => print('Socket Disconnected'));
      socket?.onConnectError((err) => print('Socket Connect Error: $err'));
      socket?.onError((err) => print('Socket Error: $err'));

      socket?.on('support_query_created', (data) {
        print('Received support_query_created: $data');
        if (data['user'] != null &&
            data['user']['_id'] == session.user?['_id']) {
          setState(() {
            _queries.insert(0, data);
          });
          _showStylishSnackBar('Query created!', Colors.green);
        } else {
          _showStylishSnackBar('A new support query was created.', Colors.blue);
        }
      });

      socket?.on('support_query_updated', (data) {
        print('Received support_query_updated: $data');
        final updatedQuery = data;
        setState(() {
          int index =
              _queries.indexWhere((q) => q['_id'] == updatedQuery['_id']);
          if (index != -1) {
            _queries[index] = updatedQuery;
          } else {
            _queries.add(updatedQuery);
          }
          _queries.sort((a, b) => DateTime.parse(b['createdAt'])
              .compareTo(DateTime.parse(a['createdAt'])));
        });
        _showStylishSnackBar('Query updated!', Colors.orange);
      });

      socket?.on('support_query_deleted', (data) {
        print('Received support_query_deleted: $data');
        final deletedQueryId = data['queryId'];
        setState(() {
          _queries.removeWhere((q) => q['_id'] == deletedQueryId);
        });
        _showStylishSnackBar('Query deleted!', Colors.red);
      });
    } catch (e) {
      print('Error connecting to socket: $e');
    }
  }

  Future<void> _fetchUserQueries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      setState(() {
        _error = 'Authentication token not found.';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/support/queries/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _queries = data['queries'] ?? [];
          _isLoading = false;
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _error = data['error'] ?? 'Failed to load queries.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitQuery() async {
    if (_topicController.text.isEmpty || _descriptionController.text.isEmpty) {
      _showStylishSnackBar(
          'Please fill in both topic and description.', Colors.red);
      return;
    }

    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showStylishSnackBar('Authentication token not found.', Colors.red);
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/support/queries'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'topic': _topicController.text,
          'description': _descriptionController.text,
        }),
      );

      print('Submit Query Response Status: ${response.statusCode}');
      print('Submit Query Response Body: ${response.body}');

      if (response.statusCode == 201) {
        _showStylishSnackBar('Query submitted successfully!', Colors.green);
        // Do NOT add the query here, socket event will handle it
        _topicController.clear();
        _descriptionController.clear();
      } else {
        final data = jsonDecode(response.body);
        _showStylishSnackBar(
            data['error'] ?? 'Failed to submit query.', Colors.red);
      }
    } catch (e) {
      print('Submit Query Error: $e');
      _showStylishSnackBar('Network error while submitting query.', Colors.red);
    }
  }

  void _showStylishSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: color),
            SizedBox(width: 12),
            Expanded(
                child: Text(message,
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: color.withOpacity(0.15),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _editQuery(
      String queryId, String currentTopic, String currentDescription) async {
    _topicController.text = currentTopic;
    _descriptionController.text = currentDescription;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Support Query',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFF00B4D8))),
              SizedBox(height: 16),
              TextField(
                controller: _topicController,
                decoration: InputDecoration(
                  labelText: 'Topic',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.topic, color: Color(0xFF00B4D8)),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.description, color: Color(0xFF00B4D8)),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _topicController.clear();
                      _descriptionController.clear();
                    },
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: Icon(Icons.save, color: Colors.white),
                    label: Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00B4D8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (_topicController.text.isEmpty ||
                          _descriptionController.text.isEmpty) {
                        _showStylishSnackBar(
                            'Please fill in both topic and description.',
                            Colors.red);
                        return;
                      }

                      final session =
                          Provider.of<SessionProvider>(context, listen: false);
                      final token = session.token;

                      if (token == null) {
                        _showStylishSnackBar(
                            'Authentication token not found.', Colors.red);
                        return;
                      }

                      try {
                        final response = await http.put(
                          Uri.parse(
                              '${ApiConfig.baseUrl}/api/support/queries/$queryId'),
                          headers: {
                            'Authorization': 'Bearer $token',
                            'Content-Type': 'application/json',
                          },
                          body: jsonEncode({
                            'topic': _topicController.text,
                            'description': _descriptionController.text,
                          }),
                        );

                        print(
                            'Edit Query Response Status: ${response.statusCode}');
                        print('Edit Query Response Body: ${response.body}');

                        if (response.statusCode == 200) {
                          _showStylishSnackBar(
                              'Query updated successfully!', Colors.green);
                          Navigator.of(context).pop();
                          _topicController.clear();
                          _descriptionController.clear();
                        } else {
                          final data = jsonDecode(response.body);
                          _showStylishSnackBar(
                              data['error'] ?? 'Failed to update query.',
                              Colors.red);
                        }
                      } catch (e) {
                        print('Edit Query Error: $e');
                        _showStylishSnackBar(
                            'Network error while editing query.', Colors.red);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteQuery(String queryId) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showStylishSnackBar('Authentication token not found.', Colors.red);
      return;
    }

    // Show confirmation dialog
    bool confirmDelete = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Confirm Deletion',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                  'Are you sure you want to delete this query? This action cannot be undone.'),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.delete, color: Colors.white),
                  label: Text('Delete'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmDelete) {
      return; // User cancelled deletion
    }

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/support/queries/$queryId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Delete Query Response Status: ${response.statusCode}');
      print('Delete Query Response Body: ${response.body}');

      if (response.statusCode == 200) {
        _showStylishSnackBar('Query deleted successfully!', Colors.green);
        // Socket event will handle UI update, but we can also remove it directly for immediate feedback
        setState(() {
          _queries.removeWhere((query) => query['_id'] == queryId);
        });
      } else {
        final data = jsonDecode(response.body);
        _showStylishSnackBar(
            data['error'] ?? 'Failed to delete query.', Colors.red);
      }
    } catch (e) {
      print('Delete Query Error: $e');
      _showStylishSnackBar('Network error while deleting query.', Colors.red);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDateTime(String dateTimeString) {
    final dateTime = DateTime.parse(dateTimeString);
    return DateFormat('MMM d, yyyy h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    // Filter queries by search term if present
    List<dynamic> filteredQueries = _searchTerm.isEmpty
        ? _queries
        : _queries
            .where((q) => (q['topic'] ?? '')
                .toString()
                .toLowerCase()
                .contains(_searchTerm.toLowerCase()))
            .toList();

    final displayedQueries = _showAllQueries
        ? filteredQueries
        : (filteredQueries.length > 3
            ? filteredQueries.sublist(0, 3)
            : filteredQueries);

    return Scaffold(
      appBar: AppBar(
        title: Text('Help & Support'),
        backgroundColor: Color(0xFF00B4D8),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search by Topic',
                  prefixIcon: Icon(Icons.search, color: Color(0xFF00B4D8)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: _searchTerm.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchTerm = '';
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchTerm = value;
                  });
                },
              ),
              SizedBox(height: 20),
              Text(
                'Other Support Options',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0077B5)),
              ),
              SizedBox(height: 8),
              Card(
                color: Colors.blue[50],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(Icons.email, color: Color(0xFF00B4D8)),
                  title: Text('Email us at',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('chetandudi791@gmail.com',
                      style: TextStyle(color: Color(0xFF0077B5))),
                  onTap: () {
                    // Optionally, launch email app
                    // launchUrl(Uri.parse('mailto:chetandudi791@gmail.com'));
                  },
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Submit a New Query',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _topicController,
                decoration: InputDecoration(
                  labelText: 'Topic',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitQuery,
                child: Text('Submit Query'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00B4D8),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50), // Full width button
                ),
              ),
              SizedBox(height: 32),
              Text(
                'Your Queries',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: TextStyle(color: Colors.red)))
                      : filteredQueries.isEmpty
                          ? Center(child: Text('No queries found.'))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: displayedQueries.length,
                              itemBuilder: (context, index) {
                                final query = displayedQueries[index];
                                return _buildQueryCard(query);
                              },
                            ),
              if (!_showAllQueries && filteredQueries.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showAllQueries = true;
                        });
                      },
                      child: Text('View All Queries'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueryCard(Map<String, dynamic> query) {
    return Card(
      margin: EdgeInsets.only(bottom: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.question_answer, color: Color(0xFF00B4D8)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    query['topic'],
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0077B5)),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: query['status'] == 'resolved'
                        ? Colors.green[100]
                        : Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    query['status'].toUpperCase(),
                    style: TextStyle(
                      color: query['status'] == 'resolved'
                          ? Colors.green[800]
                          : Colors.orange[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(query['description'], style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  'Submitted: ${_formatDateTime(query['createdAt'])}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            if (query['replies'] != null && query['replies'].isNotEmpty)
              _buildReplies(query['replies']),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (query['replies'] == null || query['replies'].isEmpty)
                    TextButton.icon(
                      onPressed: () => _editQuery(
                          query['_id'], query['topic'], query['description']),
                      icon: Icon(Icons.edit, color: Color(0xFF0077B5)),
                      label: Text('Edit',
                          style: TextStyle(color: Color(0xFF0077B5))),
                    ),
                  TextButton.icon(
                    onPressed: () => _deleteQuery(query['_id']),
                    icon: Icon(Icons.delete, color: Colors.red[700]),
                    label: Text('Delete',
                        style: TextStyle(color: Colors.red[700])),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplies(List<dynamic> replies) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Replies:',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF00B4D8)),
          ),
          SizedBox(height: 8),
          ...replies.map<Widget>((reply) {
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Color(0xFF00B4D8), width: 1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.admin_panel_settings,
                          size: 16, color: Color(0xFF0077B5)),
                      SizedBox(width: 4),
                      Text(
                        'Admin Reply',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF0077B5)),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    reply['replyText'],
                    style: TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 13, color: Colors.grey[600]),
                      SizedBox(width: 3),
                      Text(
                        'Replied: ${_formatDateTime(reply['timestamp'])}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
