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
  List<Map<String, dynamic>> filteredGroups = [];
  List<Map<String, dynamic>> joinedGroups = [];
  List<Map<String, dynamic>> leftGroups = [];
  bool loading = true;
  String? error;
  final TextEditingController _searchController = TextEditingController();
  String selectedGroupFilter = 'All Groups'; // 'All Groups', 'Joined Groups', 'Left Groups'

  @override
  void initState() {
    super.initState();
    _fetchUserGroups();
    _searchController.addListener(_filterGroups);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        final allGroups = List<Map<String, dynamic>>.from(data['groups'] ?? []);
        
        // Categorize groups into joined and left groups
        List<Map<String, dynamic>> joined = [];
        List<Map<String, dynamic>> left = [];
        
        for (var group in allGroups) {
          final members = group['members'] ?? [];
          final currentUserEmail = Provider.of<SessionProvider>(context, listen: false).user?['email'];
          
          // Find current user in members
          bool isLeft = false;
          for (var member in members) {
            if ((member['email'] ?? '').toString().toLowerCase() == (currentUserEmail ?? '').toLowerCase()) {
              isLeft = member['leftAt'] != null;
              break;
            }
          }
          
          if (isLeft) {
            left.add(group);
          } else {
            joined.add(group);
          }
        }
        
        setState(() {
          userGroups = allGroups;
          joinedGroups = joined;
          leftGroups = left;
          filteredGroups = allGroups;
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

  void _filterGroups() {
    final query = _searchController.text.toLowerCase().trim();
    
    // First, get the base list based on selected filter
    List<Map<String, dynamic>> baseList;
    switch (selectedGroupFilter) {
      case 'Joined Groups':
        baseList = List.from(joinedGroups);
        break;
      case 'Left Groups':
        baseList = List.from(leftGroups);
        break;
      default:
        baseList = List.from(userGroups);
    }
    
    if (query.isEmpty) {
      setState(() {
        filteredGroups = baseList;
      });
    } else {
      setState(() {
        filteredGroups = baseList.where((group) {
          // Search in group title
          final title = (group['title'] ?? '').toString().toLowerCase();
          if (title.contains(query)) return true;
          
          // Search in group description
          final description = (group['description'] ?? '').toString().toLowerCase();
          if (description.contains(query)) return true;
          
          // Search in member emails
          final members = group['members'] ?? [];
          for (var member in members) {
            final memberEmail = (member['email'] ?? '').toString().toLowerCase();
            if (memberEmail.contains(query)) return true;
          }
          
          // Search in expense descriptions
          final expenses = group['expenses'] ?? [];
          for (var expense in expenses) {
            final expenseDesc = (expense['description'] ?? '').toString().toLowerCase();
            if (expenseDesc.contains(query)) return true;
          }
          
          return false;
        }).toList();
      });
    }
  }

  void _onGroupFilterChanged(String? newValue) {
    if (newValue != null) {
      setState(() {
        selectedGroupFilter = newValue;
      });
      _filterGroups(); // Re-filter with new selection
    }
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
    
    // Use filtered groups based on current filter and search
    final groupsToCalculate = filteredGroups;
    
    for (var group in groupsToCalculate) {
      total += _getUserPendingBalance(group, currentUserEmail ?? '');
    }
    return total;
  }

  // Calculate total expenses across all groups
  int _calculateTotalExpenses() {
    num total = 0;
    // Use filtered groups based on current filter and search
    final groupsToCalculate = filteredGroups;
    
    for (var group in groupsToCalculate) {
      total += (group['expenses'] ?? []).length;
    }
    return total.toInt();
  }

  Future<void> _editExpense(String groupId, String expenseId, Map<String, dynamic> expenseData) async {
    setState(() { loading = true; error = null; });
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
      
      final res = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/group-transactions/$groupId/expenses/$expenseId'),
        headers: headers,
        body: json.encode(expenseData),
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        // Refresh the groups data
        await _fetchUserGroups();
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Expense updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        setState(() { error = data['error'] ?? 'Failed to update expense'; });
      }
    } catch (e) {
      setState(() { error = e.toString(); });
    } finally {
      setState(() { loading = false; });
    }
  }

  void _showEditExpenseDialog(Map<String, dynamic> expense, String groupId) {
    final TextEditingController editDescController = TextEditingController(text: expense['description'] ?? '');
    final TextEditingController editAmountController = TextEditingController(text: (expense['amount'] ?? 0).toString());
    String editSplitType = 'equal';
    
    // Filter out members who have left the group from selected members
    List<String> editSelectedMembers = List<String>.from(expense['selectedMembers'] ?? []);
    // Note: In this view, we don't have access to group data, so we'll keep the original members
    // The backend will handle filtering out inactive members
    
    Map<String, double> editCustomSplitAmounts = {};
    
    // Initialize custom split amounts from existing split data
    if (expense['split'] != null) {
      for (var splitItem in expense['split']) {
        // Find the member by user ID in the group data
        // Since we don't have direct access to group data here, we'll initialize with equal split
        final splitAmount = (splitItem['amount'] ?? 0).toDouble();
        // We'll need to find the member email from the group data
        // For now, we'll use a placeholder approach
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                Icon(Icons.edit, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'Edit Expense',
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
            height: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00B4D8),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: editDescController,
                    decoration: InputDecoration(
                      hintText: 'Enter expense description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFF00B4D8), width: 2),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Amount
                  Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00B4D8),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: editAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Enter amount',
                      prefixText: '\$',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFF00B4D8), width: 2),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Member Selection
                  Text(
                    'Select Members',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00B4D8),
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    constraints: BoxConstraints(maxHeight: 120),
                    child: SingleChildScrollView(
                      child: Column(
                        children: editSelectedMembers.map<Widget>((memberEmail) {
                          return CheckboxListTile(
                            title: Text(memberEmail),
                            value: true,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == false) {
                                  editSelectedMembers.remove(memberEmail);
                                }
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  
                  // Split Type
                  Text(
                    'Split Type',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00B4D8),
                    ),
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: editSplitType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Color(0xFF00B4D8), width: 2),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(value: 'equal', child: Text('Equal Split')),
                      DropdownMenuItem(value: 'custom', child: Text('Custom Split')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        editSplitType = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(left: 16, right: 8),
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(left: 8, right: 16),
                    child: ElevatedButton(
                                              onPressed: () async {
                          if (editDescController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please enter a description')),
                            );
                            return;
                          }
                          
                          final amount = double.tryParse(editAmountController.text);
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please enter a valid amount')),
                            );
                            return;
                          }
                          
                          if (editSelectedMembers.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please select at least one member')),
                            );
                            return;
                          }
                          
                          Navigator.of(context).pop();
                          
                          final expenseData = {
                            'description': editDescController.text.trim(),
                            'amount': amount,
                            'selectedMembers': editSelectedMembers,
                            'splitType': editSplitType,
                          };
                          
                          await _editExpense(groupId, expense['_id'], expenseData);
                        },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00B4D8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Update',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAllExpensesDialog(List<Map<String, dynamic>> expenses, String groupTitle, String groupId) {
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
                      trailing: Builder(
                        builder: (context) {
                          final currentUserEmail = Provider.of<SessionProvider>(context, listen: false).user?['email'];
                          final expenseAddedBy = expense['addedBy'];
                          final shouldShowEdit = expenseAddedBy == currentUserEmail;
                          
                          // Debug: Print the comparison
                          print('View page - Edit button check:');
                          print('Current user email: $currentUserEmail');
                          print('Expense addedBy: $expenseAddedBy');
                          print('Should show edit: $shouldShowEdit');
                          
                          return shouldShowEdit
                              ? IconButton(
                                  icon: Icon(Icons.edit, color: Color(0xFF00B4D8)),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _showEditExpenseDialog(expense, groupId);
                                  },
                                )
                              : SizedBox.shrink();
                        },
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
                          // Search and Filter Row
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                // Search Bar
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFFEFF6FF), // Very light blue
                                          Color(0xFFDBEAFE), // Light blue
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(
                                        color: Color(0xFF00B4D8).withOpacity(0.3),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF00B4D8).withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: InputDecoration(
                                        labelText: 'Search Groups',
                                        labelStyle: TextStyle(
                                          color: Color(0xFF00B4D8),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: BorderSide.none,
                                        ),
                                        filled: true,
                                        fillColor: Colors.transparent,
                                        prefixIcon: Container(
                                          margin: EdgeInsets.all(8),
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Color(0xFF00B4D8).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.search,
                                            color: Color(0xFF00B4D8),
                                            size: 20,
                                          ),
                                        ),
                                        suffixIcon: _searchController.text.isNotEmpty
                                            ? IconButton(
                                                icon: Icon(Icons.clear, color: Color(0xFF00B4D8)),
                                                onPressed: () {
                                                  _searchController.clear();
                                                },
                                              )
                                            : null,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        hintText: 'Search by group name, members, or expenses...',
                                        hintStyle: TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 14,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        // The _filterGroups function is called automatically via listener
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                
                                // Groups Filter Dropdown
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF00B4D8),
                                        Color(0xFF48CAE4),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: Color(0xFF00B4D8).withOpacity(0.3),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFF00B4D8).withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedGroupFilter,
                                      onChanged: _onGroupFilterChanged,
                                      icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                                      dropdownColor: Color(0xFF00B4D8),
                                      borderRadius: BorderRadius.circular(16),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: 'All Groups',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.group, color: Colors.white, size: 18),
                                              SizedBox(width: 8),
                                              Text('All Groups'),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Joined Groups',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.group_add, color: Colors.white, size: 18),
                                              SizedBox(width: 8),
                                              Text('Joined Groups'),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Left Groups',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.group_remove, color: Colors.white, size: 18),
                                              SizedBox(width: 8),
                                              Text('Left Groups'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
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
                                          '${filteredGroups.length}',
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
                            child: filteredGroups.isEmpty && _searchController.text.isNotEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                                        SizedBox(height: 16),
                                        Text(
                                          'No Groups Found',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Try adjusting your search terms.',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    itemCount: filteredGroups.length,
                                    itemBuilder: (context, index) {
                                      final group = filteredGroups[index];
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
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Color(0xFF00B4D8),
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
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
                                                      onPressed: () => _showAllExpensesDialog(expenses, group['title'] ?? 'Group', group['_id']),
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