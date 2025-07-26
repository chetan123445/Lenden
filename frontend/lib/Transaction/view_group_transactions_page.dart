import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import '../user/session.dart';

class ViewGroupTransactionsPage extends StatefulWidget {
  const ViewGroupTransactionsPage({super.key});

  @override
  State<ViewGroupTransactionsPage> createState() => _ViewGroupTransactionsPageState();
}

class _ViewGroupTransactionsPageState extends State<ViewGroupTransactionsPage> {
  List<Map<String, dynamic>> userGroups = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchUserGroups();
  }

  Future<void> _fetchUserGroups() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      final headers = {'Authorization': 'Bearer $token'};
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/group-transactions/user-groups'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          userGroups = List<Map<String, dynamic>>.from(data['groups'] ?? []);
          loading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load group transactions';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Network error: ${e.toString()}';
        loading = false;
      });
    }
  }

  // Helper function to format date and time
  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'Unknown';
    
    try {
      DateTime date;
      if (dateTime is String) {
        date = DateTime.parse(dateTime);
      } else if (dateTime is DateTime) {
        date = dateTime;
      } else {
        return 'Invalid date';
      }
      
      // Format: "Dec 15, 2023 at 2:30 PM"
      String month = _getMonthName(date.month);
      String day = date.day.toString();
      String year = date.year.toString();
      String hour = date.hour > 12 ? (date.hour - 12).toString() : date.hour.toString();
      if (hour == '0') hour = '12';
      String minute = date.minute.toString().padLeft(2, '0');
      String period = date.hour >= 12 ? 'PM' : 'AM';
      
      return '$month $day, $year at $hour:$minute $period';
    } catch (e) {
      return 'Invalid date';
    }
  }
  
  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  // Calculate user's total split amount for all expenses in a group
  double _calculateUserTotalSplit(Map<String, dynamic> group, String userEmail) {
    double total = 0.0;
    final expenses = group['expenses'] ?? [];
    
    for (var expense in expenses) {
      final split = expense['split'] ?? [];
      for (var splitItem in split) {
        // Find the member with this user ID
        final members = group['members'] ?? [];
        for (var member in members) {
          if (member['email'] == userEmail && member['_id'] == splitItem['user']) {
            total += (splitItem['amount'] ?? 0).toDouble();
            break;
          }
        }
      }
    }
    
    return total;
  }

  // Get user's pending balance for a group
  double _getUserPendingBalance(Map<String, dynamic> group, String userEmail) {
    final balances = group['balances'] ?? [];
    final members = group['members'] ?? [];
    
    // Find the member with this email
    for (var member in members) {
      if (member['email'] == userEmail) {
        // Find the balance for this user
        for (var balance in balances) {
          if (balance['user'] == member['_id']) {
            return (balance['balance'] ?? 0).toDouble();
          }
        }
        break;
      }
    }
    
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final currentUserEmail = session.user?['email'];

    return Scaffold(
      appBar: AppBar(
        title: Text('View Group Transactions'),
        backgroundColor: Color(0xFF00B4D8),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(error!, style: TextStyle(fontSize: 16, color: Colors.red)),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchUserGroups,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : userGroups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No Group Transactions Found',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'You are not part of any group transactions yet.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchUserGroups,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: userGroups.length,
                        itemBuilder: (context, index) {
                          final group = userGroups[index];
                          final expenses = group['expenses'] ?? [];
                          final members = group['members'] ?? [];
                          final creator = group['creator'];
                          final isCreator = creator?['email'] == currentUserEmail;
                          
                          // Calculate user's total split amount
                          final userTotalSplit = _calculateUserTotalSplit(group, currentUserEmail ?? '');
                          
                          // Get user's pending balance
                          final userPendingBalance = _getUserPendingBalance(group, currentUserEmail ?? '');
                          
                          return Card(
                            margin: EdgeInsets.only(bottom: 16),
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: Color(0xFF00B4D8),
                                child: Text(
                                  (group['title'] ?? 'G')[0].toUpperCase(),
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                group['title'] ?? 'Untitled Group',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Creator: ${creator?['email'] ?? 'Unknown'}'),
                                  Text('Members: ${members.length}'),
                                  Text('Expenses: ${expenses.length}'),
                                ],
                              ),
                              children: [
                                Container(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Group Summary
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF00B4D8).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Your Summary',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Color(0xFF00B4D8),
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Total Split Amount:'),
                                                Text(
                                                  '\$${userTotalSplit.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Pending Balance:'),
                                                Text(
                                                  '\$${userPendingBalance.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: userPendingBalance > 0 ? Colors.red[700] : Colors.green[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      
                                      // Expenses List
                                      if (expenses.isNotEmpty) ...[
                                        Text(
                                          'All Expenses',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        ...expenses.map<Widget>((expense) {
                                          return Container(
                                            margin: EdgeInsets.only(bottom: 8),
                                            padding: EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey[300]!),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.receipt, color: Color(0xFF00B4D8), size: 20),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        expense['description'] ?? 'No description',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      '\$${(expense['amount'] ?? 0).toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.green[700],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Added by: ${expense['addedBy'] ?? 'Unknown'}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                if (expense['createdAt'] != null || expense['date'] != null)
                                                  Row(
                                                    children: [
                                                      Icon(Icons.access_time, color: Colors.grey[500], size: 12),
                                                      SizedBox(width: 4),
                                                      Text(
                                                        _formatDateTime(expense['createdAt'] ?? expense['date']),
                                                        style: TextStyle(
                                                          color: Colors.grey[500],
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                
                                                // Split Details
                                                if (expense['split'] != null && expense['split'].isNotEmpty) ...[
                                                  SizedBox(height: 8),
                                                  Container(
                                                    padding: EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Color(0xFF00B4D8).withOpacity(0.05),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: Color(0xFF00B4D8).withOpacity(0.2)),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(Icons.people_outline, color: Color(0xFF00B4D8), size: 14),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'Split Details:',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w600,
                                                                color: Color(0xFF00B4D8),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 4),
                                                        ...(expense['split'] as List).map<Widget>((splitItem) {
                                                          final member = members.firstWhere(
                                                            (m) => m['_id'] == splitItem['user'],
                                                            orElse: () => {'email': 'Unknown User'},
                                                          );
                                                          final isCurrentUser = member['email'] == currentUserEmail;
                                                          
                                                          return Padding(
                                                            padding: EdgeInsets.only(bottom: 2),
                                                            child: Row(
                                                              children: [
                                                                Text(
                                                                  '• ${member['email']}: ',
                                                                  style: TextStyle(
                                                                    fontSize: 11,
                                                                    color: Colors.grey[600],
                                                                    fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  '\$${splitItem['amount'].toStringAsFixed(2)}',
                                                                  style: TextStyle(
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: isCurrentUser ? Color(0xFF00B4D8) : Colors.green[700],
                                                                  ),
                                                                ),
                                                                if (isCurrentUser)
                                                                  Text(
                                                                    ' (You)',
                                                                    style: TextStyle(
                                                                      fontSize: 10,
                                                                      color: Color(0xFF00B4D8),
                                                                      fontStyle: FontStyle.italic,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ] else ...[
                                        Container(
                                          padding: EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'No expenses in this group yet',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
} 