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
  _ManageSupportQueriesPageState createState() =>
      _ManageSupportQueriesPageState();
}

class _ManageSupportQueriesPageState extends State<ManageSupportQueriesPage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _queries = [];
  bool _isLoading = true;
  String? _error;
  IO.Socket? socket;
  String _searchTerm = ''; // Add search term

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

      socket?.on('support_query_created', (data) {
        print('Received support_query_created: $data');
        setState(() {
          _queries.insert(0, data);
          _queries.sort((a, b) => DateTime.parse(b['createdAt'])
              .compareTo(DateTime.parse(a['createdAt'])));
        });
        _showStylishSnackBar('New query created!', Colors.green);
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
      final uri =
          Uri.parse('${ApiConfig.baseUrl}/api/admin/support/queries').replace(
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
      _showStylishSnackBar('Reply cannot be empty.', Colors.red);
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
        Uri.parse(
            '${ApiConfig.baseUrl}/api/admin/support/queries/$queryId/reply'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'replyText': replyText}),
      );

      if (response.statusCode == 200) {
        _showStylishSnackBar('Reply added successfully!', Colors.green);
        final updatedQuery = jsonDecode(response.body);
        setState(() {
          int index =
              _queries.indexWhere((q) => q['_id'] == updatedQuery['_id']);
          if (index != -1) {
            _queries[index] = updatedQuery;
          }
        });
      } else {
        final data = jsonDecode(response.body);
        _showStylishSnackBar(
            data['error'] ?? 'Failed to add reply.', Colors.red);
      }
    } catch (e) {
      _showStylishSnackBar('Network error while adding reply.', Colors.red);
    }
  }

  Future<void> _editReply(
      String queryId, String replyId, String newReplyText) async {
    if (newReplyText.isEmpty) {
      _showStylishSnackBar('Reply cannot be empty.', Colors.red);
      return;
    }

    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showStylishSnackBar('Authentication token not found.', Colors.red);
      return;
    }

    try {
      final response = await http.put(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/admin/support/queries/$queryId/replies/$replyId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'replyText': newReplyText}),
      );

      if (response.statusCode == 200) {
        _showStylishSnackBar('Reply updated successfully!', Colors.green);
        final updatedQuery = jsonDecode(response.body);
        setState(() {
          int index =
              _queries.indexWhere((q) => q['_id'] == updatedQuery['_id']);
          if (index != -1) {
            _queries[index] = updatedQuery;
          }
        });
      } else {
        final data = jsonDecode(response.body);
        _showStylishSnackBar(
            data['error'] ?? 'Failed to update reply.', Colors.red);
      }
    } catch (e) {
      _showStylishSnackBar('Network error while editing reply.', Colors.red);
    }
  }

  Future<void> _deleteReply(String queryId, String replyId) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showStylishSnackBar('Authentication token not found.', Colors.red);
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/admin/support/queries/$queryId/replies/$replyId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _showStylishSnackBar('Reply deleted successfully!', Colors.green);
        final updatedQuery = jsonDecode(response.body);
        setState(() {
          int index =
              _queries.indexWhere((q) => q['_id'] == updatedQuery['_id']);
          if (index != -1) {
            _queries[index] = updatedQuery;
          }
        });
      } else {
        final data = jsonDecode(response.body);
        _showStylishSnackBar(
            data['error'] ?? 'Failed to delete reply.', Colors.red);
      }
    } catch (e) {
      _showStylishSnackBar('Network error while deleting reply.', Colors.red);
    }
  }

  Future<void> _updateQueryStatus(String queryId, String status) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showStylishSnackBar('Authentication token not found.', Colors.red);
      return;
    }

    try {
      final response = await http.patch(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/admin/support/queries/$queryId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        _showStylishSnackBar(
            'Query status updated successfully!', Colors.green);
        final updatedQuery = jsonDecode(response.body);
        setState(() {
          int index =
              _queries.indexWhere((q) => q['_id'] == updatedQuery['_id']);
          if (index != -1) {
            _queries[index] = updatedQuery;
          }
        });
      } else {
        final data = jsonDecode(response.body);
        _showStylishSnackBar(
            data['error'] ?? 'Failed to update status.', Colors.red);
      }
    } catch (e) {
      _showStylishSnackBar('Network error while updating status.', Colors.red);
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Support Queries'),
        backgroundColor: Color(0xFF00B4D8),
        foregroundColor: Colors.black,
        elevation: 2,
      ),
      body: Container(
        color: Color(0xFFF6FBFF),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search by Topic',
                  prefixIcon: Icon(Icons.search, color: Color(0xFF00B4D8)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
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
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.support_agent, color: Color(0xFF00B4D8)),
                  SizedBox(width: 8),
                  Text(
                    'All Support Queries',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF0077B5),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: TextStyle(color: Colors.red)))
                      : filteredQueries.isEmpty
                          ? Center(child: Text('No support queries found.'))
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              itemCount: filteredQueries.length,
                              itemBuilder: (context, index) {
                                final query = filteredQueries[index];
                                return _buildQueryCard(query);
                              },
                            ),
            ),
          ],
        ),
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
      margin: EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0077B5)),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: _getStatusColor(query['status']).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    query['status'].toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(query['status']),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person, size: 18, color: Colors.grey[700]),
                SizedBox(width: 6),
                Text(
                  'User: ${query['user']?['email'] ?? query['user']?['username'] ?? 'Unknown'}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(query['description'], style: TextStyle(fontSize: 16)),
            SizedBox(height: 10),
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
            SizedBox(height: 18),
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
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF0077B5)),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _showReplyDialog(query['_id']),
                  icon: Icon(Icons.reply, size: 18),
                  label: Text('Reply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00B4D8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
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
      padding: const EdgeInsets.only(top: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Replies:',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF00B4D8)),
          ),
          SizedBox(height: 10),
          ...replies.map<Widget>((reply) {
            return Container(
              margin: EdgeInsets.only(bottom: 10),
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
                        'Admin: ${reply['admin']?['email'] ?? 'Unknown'}',
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
                  SizedBox(height: 4),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit,
                            size: 18, color: Color(0xFF0077B5)),
                        onPressed: () => _showEditReplyDialog(
                            reply['queryId'], reply['_id'], reply['replyText']),
                        tooltip: 'Edit Reply',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete,
                            size: 18, color: Colors.red[700]),
                        onPressed: () =>
                            _deleteReply(reply['queryId'], reply['_id']),
                        tooltip: 'Delete Reply',
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Reply',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFF00B4D8))),
              SizedBox(height: 16),
              TextField(
                controller: replyController,
                decoration: InputDecoration(
                  labelText: 'Your Reply',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.reply, color: Color(0xFF00B4D8)),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: Icon(Icons.send, color: Colors.white),
                    label: Text('Send Reply'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00B4D8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      _replyToQuery(queryId, replyController.text);
                      Navigator.of(context).pop();
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

  void _showEditReplyDialog(
      String queryId, String replyId, String currentReplyText) {
    final TextEditingController editReplyController =
        TextEditingController(text: currentReplyText);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Reply',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFF00B4D8))),
              SizedBox(height: 16),
              TextField(
                controller: editReplyController,
                decoration: InputDecoration(
                  labelText: 'Edit Your Reply',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(Icons.edit, color: Color(0xFF00B4D8)),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: Icon(Icons.save, color: Colors.white),
                    label: Text('Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00B4D8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      _editReply(queryId, replyId, editReplyController.text);
                      Navigator.of(context).pop();
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
}
