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
    final members = group['members'] ?? [];
    
    // Find the member with this email to get their ID
    String? userMemberId;
    for (var member in members) {
      if (member['email'] == userEmail) {
        userMemberId = member['_id'].toString();
        break;
      }
    }
    
    if (userMemberId == null) {
      print('User member ID not found for email: $userEmail');
      return 0.0;
    }
    
    print('User member ID: $userMemberId for email: $userEmail');
    print('Total expenses in group: ${expenses.length}');
    
    for (var expense in expenses) {
      final split = expense['split'] ?? [];
      print('Expense: ${expense['description']}, Split items: ${split.length}');
      
      for (var splitItem in split) {
        // Check if this split item belongs to the current user
        String splitUserId = splitItem['user'].toString();
        double splitAmount = double.parse((splitItem['amount'] ?? 0).toString());
        print('Split item - User ID: $splitUserId, Amount: $splitAmount');
        
        if (splitUserId == userMemberId) {
          total += splitAmount;
          print('Match found! Adding $splitAmount to total. New total: $total');
        }
      }
    }
    
    print('Final total split amount for $userEmail: $total');
    return total;
  }

  // Get user's pending balance for a group
  double _getUserPendingBalance(Map<String, dynamic> group, String userEmail) {
    // Calculate pending balance based on total split amounts for this user
    double totalSplitAmount = _calculateUserTotalSplit(group, userEmail);
    
    // Debug print to understand the calculation
    print('Group: ${group['title']}, User: $userEmail, Total Split: $totalSplitAmount');
    
    // Also check if there's a balance in the balances array (for backward compatibility)
    final balances = group['balances'] ?? [];
    final members = group['members'] ?? [];
    
    // Find the member with this email
    for (var member in members) {
      if (member['email'] == userEmail) {
        // Find the balance for this user
        for (var balance in balances) {
          if (balance['user'] == member['_id']) {
            double balanceAmount = double.parse((balance['balance'] ?? 0).toString());
            print('Balance from array: $balanceAmount');
            // If balance is 0 or null, use the calculated split amount
            if (balanceAmount == 0) {
              return totalSplitAmount;
            }
            return balanceAmount;
          }
        }
        // If no balance found, return the calculated split amount
        return totalSplitAmount;
      }
    }
    
    return totalSplitAmount;
  }

  // Calculate total pending balance across all groups
  double _calculateTotalPendingBalance() {
    double total = 0.0;
    final currentUserEmail = Provider.of<SessionProvider>(context, listen: false).user?['email'];
    
    for (var group in userGroups) {
      total += _getUserPendingBalance(group, currentUserEmail ?? '');
    }
    return total;
  }

  // Calculate total expenses across all groups
  int _calculateTotalExpenses() {
    num total = 0;
    for (var group in userGroups) {
      total += (group['expenses'] ?? []).length;
    }
    return total.toInt();
  }

  void _showAllExpensesDialog(List<Map<String, dynamic>> expenses, String groupTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00B4D8), Color(0xFF48CAE4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'All Expenses - $groupTitle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF00B4D8).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFF00B4D8).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF00B4D8), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Total Expenses: ${expenses.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00B4D8),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                ...expenses.map<Widget>((expense) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Color(0xFF00B4D8).withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFF00B4D8),
                        child: Icon(
                          Icons.receipt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        expense['description'] ?? 'No description',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00B4D8),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amount: \$${(expense['amount'] ?? 0).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        actions: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00B4D8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Close',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
                      child: Column(
                        children: [
                          // Summary Header
                          Container(
                            margin: EdgeInsets.all(16),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF00B4D8), Color(0xFF48CAE4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                                    SizedBox(width: 8),
                                    Text(
                                      'Total Summary',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Groups',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          '${userGroups.length}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Total Expenses',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          '${_calculateTotalExpenses()}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Total Pending',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          '\$${_calculateTotalPendingBalance().toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Groups List
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 16),
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
                                              Row(
                                                children: [
                                                  Text(
                                                    'Recent Expenses',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  Spacer(),
                                                  if (expenses.length > 3)
                                                    TextButton(
                                                      onPressed: () => _showAllExpensesDialog(expenses, group['title'] ?? 'Group'),
                                                      child: Text(
                                                        'View All (${expenses.length})',
                                                        style: TextStyle(
                                                          color: Color(0xFF00B4D8),
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              ...expenses.take(3).map<Widget>((expense) {
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
                        ],
                      ),
                    ),
    );
  }
} 