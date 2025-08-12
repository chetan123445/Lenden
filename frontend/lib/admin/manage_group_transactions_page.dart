import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import '../api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ManageGroupTransactionsPage extends StatefulWidget {
  @override
  State<ManageGroupTransactionsPage> createState() =>
      _ManageGroupTransactionsPageState();
}

class _ManageGroupTransactionsPageState
    extends State<ManageGroupTransactionsPage> {
  List<dynamic> groups = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    setState(() {
      loading = true;
      error = null;
    });

    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      setState(() {
        error = 'Authentication token not found.';
        loading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/group-transactions'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          groups = data['groups'] ?? [];
          loading = false;
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          error = data['error'] ?? 'Failed to load groups.';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'An error occurred: $e';
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
      String month = DateFormat('MMM').format(date);
      String day = date.day.toString();
      String year = date.year.toString();
      String hour =
          date.hour > 12 ? (date.hour - 12).toString() : date.hour.toString();
      if (hour == '0') hour = '12';
      String minute = date.minute.toString().padLeft(2, '0');
      String period = date.hour >= 12 ? 'PM' : 'AM';

      return '$month $day, $year at $hour:$minute $period';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Future<void> _deleteGroup(String groupId) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showSnackBar('Authentication token not found.');
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/group-transactions/$groupId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _showSnackBar('Group deleted successfully.');
        _fetchGroups();
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(data['error'] ?? 'Failed to delete group.');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    }
  }

  void _showDeleteConfirmationDialog(String groupId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Group'),
        content: Text(
            'Are you sure you want to delete this group and all its expenses?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteGroup(groupId);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateGroup(
      String groupId, Map<String, dynamic> updateData) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showSnackBar('Authentication token not found.');
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/group-transactions/$groupId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Group updated successfully.');
        _fetchGroups();
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(data['error'] ?? 'Failed to update group.');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    }
  }

  void _showEditGroupDialog(Map<String, dynamic> group) {
    final _titleController = TextEditingController(text: group['title']);
    final _colorController = TextEditingController(text: group['color']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Group Title'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _colorController,
              decoration: InputDecoration(
                labelText: 'Group Color (Hex)',
                hintText: '#FF5722',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_titleController.text.trim().isEmpty) {
                _showSnackBar('Group title cannot be empty.');
                return;
              }

              final updateData = {
                'title': _titleController.text.trim(),
                'color': _colorController.text.trim(),
              };
              Navigator.of(context).pop();
              _updateGroup(group['_id'], updateData);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addMember(String groupId, String email) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showSnackBar('Authentication token not found.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/admin/group-transactions/$groupId/members'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Member added successfully.');
        _fetchGroups();
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(data['error'] ?? 'Failed to add member.');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    }
  }

  void _showAddMemberDialog(String groupId) {
    final _emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Member'),
        content: TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Member Email',
            hintText: 'user@example.com',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final email = _emailController.text.trim();
              if (email.isEmpty || !_isValidEmail(email)) {
                _showSnackBar('Please enter a valid email address.');
                return;
              }
              Navigator.of(context).pop();
              _addMember(groupId, email);
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  Future<void> _removeMember(String groupId, String memberId) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showSnackBar('Authentication token not found.');
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/admin/group-transactions/$groupId/members/$memberId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _showSnackBar('Member removed successfully.');
        _fetchGroups();
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(data['error'] ?? 'Failed to remove member.');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    }
  }

  void _showRemoveMemberConfirmationDialog(
      String groupId, String memberId, String memberEmail) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Member'),
        content: Text(
            'Are you sure you want to remove $memberEmail from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeMember(groupId, memberId);
            },
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _addExpense(
      String groupId, Map<String, dynamic> expenseData) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showSnackBar('Authentication token not found.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/admin/group-transactions/$groupId/expenses'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(expenseData),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Expense added successfully.');
        _fetchGroups();
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(data['error'] ?? 'Failed to add expense.');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    }
  }

  void _showAddExpenseDialog(String groupId, List<dynamic> members) {
    if (members.isEmpty) {
      _showSnackBar('Cannot add expense: Group has no members.');
      return;
    }

    final _descController = TextEditingController();
    final _amountController = TextEditingController();
    String _splitType = 'equal';
    List<String> _selectedMembers =
        members.map((m) => m['email'].toString()).toList();
    Map<String, TextEditingController> _customSplitControllers = {};

    members.forEach((m) {
      _customSplitControllers[m['email'].toString()] = TextEditingController();
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Add Expense'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _descController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'Dinner, groceries, etc.',
                    ),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '\$',
                    ),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _splitType,
                    decoration: InputDecoration(labelText: 'Split Type'),
                    items: ['equal', 'custom'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                            value == 'equal' ? 'Equal Split' : 'Custom Split'),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setDialogState(() {
                        _splitType = newValue!;
                      });
                    },
                  ),
                  SizedBox(height: 10),
                  if (_splitType == 'custom')
                    ...members.map<Widget>((member) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TextField(
                          controller: _customSplitControllers[
                              member['email'].toString()],
                          decoration: InputDecoration(
                            labelText: '${member['email']} Amount',
                            prefixText: '\$',
                          ),
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                        ),
                      );
                    }).toList(),
                  SizedBox(height: 10),
                  Text('Selected Members:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...members.map<Widget>((member) {
                    return CheckboxListTile(
                      title: Text(member['email']),
                      value: _selectedMembers.contains(member['email']),
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            _selectedMembers.add(member['email']);
                          } else {
                            _selectedMembers.remove(member['email']);
                          }
                        });
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (_descController.text.trim().isEmpty) {
                    _showSnackBar('Please enter a description.');
                    return;
                  }

                  final amount = double.tryParse(_amountController.text);
                  if (amount == null || amount <= 0) {
                    _showSnackBar('Please enter a valid amount.');
                    return;
                  }

                  if (_selectedMembers.isEmpty) {
                    _showSnackBar('Please select at least one member.');
                    return;
                  }

                  List<Map<String, dynamic>> splitData = [];

                  if (_splitType == 'custom') {
                    double totalCustomAmount = 0;
                    for (String email in _selectedMembers) {
                      final customAmount = double.tryParse(
                              _customSplitControllers[email]!.text) ??
                          0;
                      splitData.add({'user': email, 'amount': customAmount});
                      totalCustomAmount += customAmount;
                    }

                    if ((totalCustomAmount - amount).abs() > 0.01) {
                      _showSnackBar(
                          'Custom split amounts must sum to total amount.');
                      return;
                    }
                  } else {
                    final splitAmount = amount / _selectedMembers.length;
                    _selectedMembers.forEach((email) {
                      splitData.add({'user': email, 'amount': splitAmount});
                    });
                  }

                  final expenseData = {
                    'description': _descController.text.trim(),
                    'amount': amount,
                    'splitType': _splitType,
                    'split': splitData,
                    'selectedMembers': _selectedMembers,
                    'addedByEmail':
                        Provider.of<SessionProvider>(context, listen: false)
                            .user?['email'],
                  };

                  Navigator.of(context).pop();
                  _addExpense(groupId, expenseData);
                },
                child: Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editExpense(String groupId, String expenseId,
      Map<String, dynamic> expenseData) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showSnackBar('Authentication token not found.');
      return;
    }

    try {
      final response = await http.put(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/admin/group-transactions/$groupId/expenses/$expenseId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(expenseData),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Expense updated successfully.');
        _fetchGroups();
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(data['error'] ?? 'Failed to update expense.');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    }
  }

  void _showEditExpenseDialog(
      Map<String, dynamic> expense, String groupId, List<dynamic> members) {
    final _descController = TextEditingController(text: expense['description']);
    final _amountController =
        TextEditingController(text: expense['amount'].toString());
    String _splitType = expense['splitType'] ?? 'equal';
    List<String> _selectedMembers =
        List<String>.from(expense['selectedMembers'] ?? []);
    Map<String, TextEditingController> _customSplitControllers = {};

    // Initialize custom split controllers with existing split amounts
    if (_splitType == 'custom' && expense['split'] != null) {
      for (var splitItem in expense['split']) {
        final member = members.firstWhere(
          (m) => m['_id'] == splitItem['user'],
          orElse: () => {'email': ''},
        );
        if (member['email'].isNotEmpty) {
          _customSplitControllers[member['email']] =
              TextEditingController(text: splitItem['amount'].toString());
        }
      }
    }

    // Initialize controllers for all members
    members.forEach((m) {
      if (!_customSplitControllers.containsKey(m['email'].toString())) {
        _customSplitControllers[m['email'].toString()] =
            TextEditingController();
      }
    });

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Edit Expense'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _descController,
                    decoration: InputDecoration(labelText: 'Description'),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '\$',
                    ),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                  ),
                  SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _splitType,
                    decoration: InputDecoration(labelText: 'Split Type'),
                    items: ['equal', 'custom'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                            value == 'equal' ? 'Equal Split' : 'Custom Split'),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setDialogState(() {
                        _splitType = newValue!;
                      });
                    },
                  ),
                  SizedBox(height: 10),
                  if (_splitType == 'custom')
                    ...members.map<Widget>((member) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TextField(
                          controller: _customSplitControllers[
                              member['email'].toString()],
                          decoration: InputDecoration(
                            labelText: '${member['email']} Amount',
                            prefixText: '\$',
                          ),
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                        ),
                      );
                    }).toList(),
                  SizedBox(height: 10),
                  Text('Selected Members:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...members.map<Widget>((member) {
                    return CheckboxListTile(
                      title: Text(member['email']),
                      value: _selectedMembers.contains(member['email']),
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            _selectedMembers.add(member['email']);
                          } else {
                            _selectedMembers.remove(member['email']);
                          }
                        });
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (_descController.text.trim().isEmpty) {
                    _showSnackBar('Please enter a description.');
                    return;
                  }

                  final amount = double.tryParse(_amountController.text);
                  if (amount == null || amount <= 0) {
                    _showSnackBar('Please enter a valid amount.');
                    return;
                  }

                  if (_selectedMembers.isEmpty) {
                    _showSnackBar('Please select at least one member.');
                    return;
                  }

                  List<Map<String, dynamic>> splitData = [];

                  if (_splitType == 'custom') {
                    double totalCustomAmount = 0;
                    for (String email in _selectedMembers) {
                      final customAmount = double.tryParse(
                              _customSplitControllers[email]!.text) ??
                          0;
                      splitData.add({'user': email, 'amount': customAmount});
                      totalCustomAmount += customAmount;
                    }

                    if ((totalCustomAmount - amount).abs() > 0.01) {
                      _showSnackBar(
                          'Custom split amounts must sum to total amount.');
                      return;
                    }
                  } else {
                    final splitAmount = amount / _selectedMembers.length;
                    _selectedMembers.forEach((email) {
                      splitData.add({'user': email, 'amount': splitAmount});
                    });
                  }

                  final expenseData = {
                    'description': _descController.text.trim(),
                    'amount': amount,
                    'splitType': _splitType,
                    'split': splitData,
                    'selectedMembers': _selectedMembers,
                    'addedByEmail': expense['addedBy'], // Keep original addedBy
                  };

                  Navigator.of(context).pop();
                  _editExpense(groupId, expense['_id'], expenseData);
                },
                child: Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteExpense(String groupId, String expenseId) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showSnackBar('Authentication token not found.');
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/admin/group-transactions/$groupId/expenses/$expenseId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        _showSnackBar('Expense deleted successfully.');
        _fetchGroups();
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(data['error'] ?? 'Failed to delete expense.');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    }
  }

  void _showDeleteExpenseConfirmationDialog(
      String groupId, String expenseId, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Expense'),
        content: Text('Are you sure you want to delete "$description"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteExpense(groupId, expenseId);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _settleExpenseSplits(
      String groupId, String expenseId, List<String> memberEmails) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;

    if (token == null) {
      _showSnackBar('Authentication token not found.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/api/admin/group-transactions/$groupId/expenses/$expenseId/settle'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'memberEmails': memberEmails}),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Expense splits settled successfully.');
        _fetchGroups();
      } else {
        final data = jsonDecode(response.body);
        _showSnackBar(data['error'] ?? 'Failed to settle expense splits.');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    }
  }

  void _showSettleExpenseSplitsDialog(String groupId, String expenseId,
      List<dynamic> members, List<dynamic> splitItems) {
    List<String> _selectedMembersToSettle = [];

    // Pre-select members who are not yet settled
    for (var splitItem in splitItems) {
      if (splitItem['settled'] != true) {
        final member = members.firstWhere(
          (m) => m['_id'] == splitItem['user'],
          orElse: () => {'email': ''},
        );
        if (member['email'].isNotEmpty) {
          _selectedMembersToSettle.add(member['email']);
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Settle Expense Splits'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Select members whose splits you want to settle:'),
                SizedBox(height: 10),
                ...members.map<Widget>((member) {
                  final splitItem = splitItems.firstWhere(
                    (item) => item['user'] == member['_id'],
                    orElse: () => {'settled': false, 'amount': 0},
                  );
                  final isSettled = splitItem['settled'] == true;
                  final amount = splitItem['amount']?.toString() ?? '0';

                  return CheckboxListTile(
                    title: Text(member['email']),
                    subtitle: Text(
                        'Amount: \$$amount${isSettled ? ' (Settled)' : ''}'),
                    value: _selectedMembersToSettle.contains(member['email']),
                    onChanged: isSettled
                        ? null
                        : (bool? value) {
                            setDialogState(() {
                              if (value == true) {
                                _selectedMembersToSettle.add(member['email']);
                              } else {
                                _selectedMembersToSettle
                                    .remove(member['email']);
                              }
                            });
                          },
                  );
                }).toList(),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: _selectedMembersToSettle.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        _settleExpenseSplits(
                            groupId, expenseId, _selectedMembersToSettle);
                      },
                child: Text('Settle'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Group Transactions'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchGroups,
        child: loading
            ? Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          error!,
                          style: TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchGroups,
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : groups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_off, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No groups found',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final expenses = group['expenses'] ?? [];
                          final members = group['members'] ?? [];
                          final creator = group['creator'];
                          final groupColor = group['color'] != null
                              ? _parseColor(group['color'])
                              : Colors.blue;

                          return Card(
                            margin: EdgeInsets.all(8.0),
                            elevation: 4,
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: groupColor,
                                child: Text(
                                  group['title']
                                          ?.substring(0, 1)
                                          .toUpperCase() ??
                                      'G',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                group['title'] ?? 'Untitled Group',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Creator: ${creator?['email'] ?? 'Unknown'}'),
                                  Text(
                                      'Members: ${members.length} • Expenses: ${expenses.length}'),
                                  if (expenses.isNotEmpty)
                                    Text(
                                        'Total: \${_calculateGroupTotal(expenses).toStringAsFixed(2)}'),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Group Info
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Group ID: ${group['_id']}',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600])),
                                            Text(
                                                'Color: ${group['color'] ?? 'Default'}',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600])),
                                            Text(
                                                'Created: ${_formatDateTime(group['createdAt'])}',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600])),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 16),

                                      // Group Actions
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _showEditGroupDialog(group),
                                            icon: Icon(Icons.edit, size: 16),
                                            label: Text('Edit'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _showDeleteConfirmationDialog(
                                                    group['_id']),
                                            icon: Icon(Icons.delete, size: 16),
                                            label: Text('Delete'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 20),

                                      // Members Section
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Members (${members.length})',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _showAddMemberDialog(
                                                    group['_id']),
                                            icon: Icon(Icons.person_add,
                                                size: 16),
                                            label: Text('Add'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),

                                      if (members.isEmpty)
                                        Container(
                                          padding: EdgeInsets.all(16),
                                          child: Text(
                                            'No members in this group',
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontStyle: FontStyle.italic),
                                          ),
                                        )
                                      else
                                        ...members.map<Widget>((member) {
                                          final isActive =
                                              member['leftAt'] == null;
                                          return Card(
                                            margin: EdgeInsets.symmetric(
                                                vertical: 2),
                                            child: ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: isActive
                                                    ? Colors.green
                                                    : Colors.grey,
                                                child: Icon(
                                                  isActive
                                                      ? Icons.person
                                                      : Icons.person_off,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                              title: Text(member['email']),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                      'Joined: ${_formatDateTime(member['joinedAt'])}'),
                                                  if (member['leftAt'] != null)
                                                    Text(
                                                      'Left: ${_formatDateTime(member['leftAt'])}',
                                                      style: TextStyle(
                                                          color: Colors.red),
                                                    ),
                                                ],
                                              ),
                                              trailing: isActive
                                                  ? IconButton(
                                                      icon: Icon(
                                                          Icons.person_remove,
                                                          color: Colors.red),
                                                      onPressed: () =>
                                                          _showRemoveMemberConfirmationDialog(
                                                        group['_id'],
                                                        member['_id'],
                                                        member['email'],
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                          );
                                        }).toList(),

                                      SizedBox(height: 20),

                                      // Expenses Section
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Expenses (${expenses.length})',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: members.isEmpty
                                                ? null
                                                : () => _showAddExpenseDialog(
                                                    group['_id'], members),
                                            icon: Icon(Icons.add, size: 16),
                                            label: Text('Add'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),

                                      if (expenses.isEmpty)
                                        Container(
                                          padding: EdgeInsets.all(16),
                                          child: Text(
                                            'No expenses in this group',
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontStyle: FontStyle.italic),
                                          ),
                                        )
                                      else
                                        ...expenses.map<Widget>((expense) {
                                          final splitItems =
                                              expense['split'] ?? [];
                                          final settledCount = splitItems
                                              .where((item) =>
                                                  item['settled'] == true)
                                              .length;
                                          final totalSplits = splitItems.length;

                                          return Card(
                                            margin: EdgeInsets.symmetric(
                                                vertical: 2),
                                            child: ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor:
                                                    settledCount == totalSplits
                                                        ? Colors.green
                                                        : Colors.orange,
                                                child: Text(
                                                  '\,${expense['amount']?.toStringAsFixed(2) ?? '0.00'}',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                              title: Text(
                                                  expense['description'] ??
                                                      'No description'),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                      'Amount: \,${expense['amount']?.toString() ?? '0'}'),
                                                  Text(
                                                      'Added by: ${expense['addedBy'] ?? 'Unknown'}'),
                                                  Text(
                                                      'Split: ${expense['splitType']?.toString().toUpperCase() ?? 'EQUAL'}'),
                                                  Text(
                                                      'Settled: $settledCount/$totalSplits'),
                                                  Text(
                                                      'Date: ${_formatDateTime(expense['createdAt'])}'),
                                                ],
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.edit,
                                                        color: Colors.blue),
                                                    onPressed: () =>
                                                        _showEditExpenseDialog(
                                                            expense,
                                                            group['_id'],
                                                            members),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(Icons.delete,
                                                        color: Colors.red),
                                                    onPressed: () =>
                                                        _showDeleteExpenseConfirmationDialog(
                                                      group['_id'],
                                                      expense['_id'],
                                                      expense['description'] ??
                                                          'this expense',
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.check_box,
                                                      color: settledCount ==
                                                              totalSplits
                                                          ? Colors.green
                                                          : Colors.orange,
                                                    ),
                                                    onPressed: () =>
                                                        _showSettleExpenseSplitsDialog(
                                                      group['_id'],
                                                      expense['_id'],
                                                      members,
                                                      splitItems,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
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

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return Colors.blue;

    try {
      // Remove # if present
      String cleanColor = colorString.replaceAll('#', '');

      // Add FF for full opacity if not present
      if (cleanColor.length == 6) {
        cleanColor = 'FF$cleanColor';
      }

      return Color(int.parse(cleanColor, radix: 16));
    } catch (e) {
      return Colors.blue; // Fallback color
    }
  }

  double _calculateGroupTotal(List<dynamic> expenses) {
    double total = 0;
    for (var expense in expenses) {
      total += (expense['amount'] ?? 0).toDouble();
    }
    return total;
  }
}
