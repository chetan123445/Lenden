import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../user/session.dart';
import '../api_config.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ManageSupportQueriesPage extends StatefulWidget {
  @override
  _ManageSupportQueriesPageState createState() => _ManageSupportQueriesPageState();
}

class _ManageSupportQueriesPageState extends State<ManageSupportQueriesPage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _queries = [];
  bool _isLoading = true;
  String? _error;
  IO.Socket? socket;

  @override
  void initState() {
    super.initState();
    _fetchAllQueries();
    _connectSocket();
  }

  @override
  void dispose() {
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

      socket?.on('support_query_updated', (data) {
        print('Received support_query_updated: $data');
        // Find the updated query and replace it, or add if new
        final updatedQuery = data;
        setState(() {
          int index = _queries.indexWhere((q) => q['_id'] == updatedQuery['_id']);
          if (index != -1) {
            _queries[index] = updatedQuery;
          } else {
            // This case might happen if a new query is created by a user
            _queries.add(updatedQuery);
          }
          // Sort to maintain order
          _queries.sort((a, b) => DateTime.parse(b['createdAt']).compareTo(DateTime.parse(a['createdAt'])));
        });
      });

      // Optionally, join a room for admin-specific updates if needed
      // socket?.emit('join_admin_room', {'adminId': session.user?['_id']});

    } catch (e) {
      print('Error connecting to socket: $e');
    }
  }

  Future<void> _fetchAllQueries({String? searchTerm}) async {
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
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/admin/support/queries').replace(
        queryParameters: searchTerm != null && searchTerm.isNotEmpty
            ? {'searchTerm': searchTerm}
            : null,
      );
      final response = await http.get(
        uri,
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

  Future<void> _replyToQuery(String queryId, String replyText) async {
    if (replyText.isEmpty) {
      _showSnackBar('Reply cannot be empty.');
      return;
    }

    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showSnackBar('Authentication token not found.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/support/queries/$queryId/reply'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'replyText': replyText}),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Reply added successfully!');
        final updatedQuery = jsonDecode(response.body);
        setState(() {
          int index = _queries.indexWhere((q) => q['_id'] == updatedQuery['_id']);
          if (index != -1) {
            _queries[index] = updatedQuery;
          }
        });
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(data['error'] ?? 'Failed to add reply.');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    }
  }

  Future<void> _editReply(String queryId, String replyId, String newReplyText) async {
    if (newReplyText.isEmpty) {
      _showSnackBar('Reply cannot be empty.');
      return;
    }

    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showSnackBar('Authentication token not found.');
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/support/queries/$queryId/replies/$replyId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'replyText': newReplyText}),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Reply updated successfully!');
        final updatedQuery = jsonDecode(response.body);
        setState(() {
          int index = _queries.indexWhere((q) => q['_id'] == updatedQuery['_id']);
          if (index != -1) {
            _queries[index] = updatedQuery;
          }
        });
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(data['error'] ?? 'Failed to update reply.');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    }
  }

  Future<void> _deleteReply(String queryId, String replyId) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showSnackBar('Authentication token not found.');
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/support/queries/$queryId/replies/$replyId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _showSnackBar('Reply deleted successfully!');
        final updatedQuery = jsonDecode(response.body);
        setState(() {
          int index = _queries.indexWhere((q) => q['_id'] == updatedQuery['_id']);
          if (index != -1) {
            _queries[index] = updatedQuery;
          }
        });
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(data['error'] ?? 'Failed to delete reply.');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    }
  }

  Future<void> _updateQueryStatus(String queryId, String status) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showSnackBar('Authentication token not found.');
      return;
    }

    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/support/queries/$queryId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Query status updated successfully!');
        final updatedQuery = jsonDecode(response.body);
        setState(() {
          int index = _queries.indexWhere((q) => q['_id'] == updatedQuery['_id']);
          if (index != -1) {
            _queries[index] = updatedQuery;
          }
        });
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(data['error'] ?? 'Failed to update status.');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Support Queries'),
        backgroundColor: Color(0xFF00B4D8),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Topic',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    _fetchAllQueries(searchTerm: _searchController.text);
                  },
                ),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                _fetchAllQueries(searchTerm: value);
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
                    : _queries.isEmpty
                        ? Center(child: Text('No support queries found.'))
                        : ListView.builder(
                            itemCount: _queries.length,
                            itemBuilder: (context, index) {
                              final query = _queries[index];
                              return _buildQueryCard(query);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  Widget _buildQueryCard(Map<String, dynamic> query) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  query['topic'],
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0077B5)),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(query['status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    query['status'].toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(query['status']),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'User: ${query['user']?['email'] ?? query['user']?['username'] ?? 'Unknown'}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            Text(query['description'], style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text(
              'Submitted: ${_formatDateTime(query['createdAt'])}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (query['replies'] != null && query['replies'].isNotEmpty)
              _buildReplies(query['replies']),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DropdownButton<String>(
                  value: query['status'],
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _updateQueryStatus(query['_id'], newValue);
                    }
                  },
                  items: <String>['open', 'in_progress', 'resolved', 'closed']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value.toUpperCase()),
                    );
                  }).toList(),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _showReplyDialog(query['_id']),
                  child: Text('Reply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00B4D8),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
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
            'Replies:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
          ),
          SizedBox(height: 8),
          ...replies.map<Widget>((reply) {
            return Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin: ${reply['admin']?['email'] ?? 'Unknown'}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0077B5)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    reply['replyText'],
                    style: TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Replied: ${_formatDateTime(reply['timestamp'])}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, size: 18, color: Color(0xFF0077B5)),
                        onPressed: () => _showEditReplyDialog(reply['queryId'], reply['_id'], reply['replyText']),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, size: 18, color: Colors.red[700]),
                        onPressed: () => _deleteReply(reply['queryId'], reply['_id']),
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

  void _showReplyDialog(String queryId) {
    final TextEditingController replyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Reply'),
        content: TextField(
          controller: replyController,
          decoration: InputDecoration(labelText: 'Your Reply'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _replyToQuery(queryId, replyController.text);
              Navigator.of(context).pop();
            },
            child: Text('Send Reply'),
          ),
        ],
      ),
    );
  }

  void _showEditReplyDialog(String queryId, String replyId, String currentReplyText) {
    final TextEditingController editReplyController = TextEditingController(text: currentReplyText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Reply'),
        content: TextField(
          controller: editReplyController,
          decoration: InputDecoration(labelText: 'Edit Your Reply'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _editReply(queryId, replyId, editReplyController.text);
              Navigator.of(context).pop();
            },
            child: Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}