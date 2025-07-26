import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class GroupTransactionPage extends StatefulWidget {
  const GroupTransactionPage({Key? key}) : super(key: key);
  @override
  State<GroupTransactionPage> createState() => _GroupTransactionPageState();
}

class _GroupTransactionPageState extends State<GroupTransactionPage> {
  // State for group creation
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _memberEmailController = TextEditingController();
  List<String> memberEmails = [];
  bool creatingGroup = false;
  String? error;
  bool loading = false;
  String? memberAddError;

  // State for group details
  Map<String, dynamic>? group; // Real group data
  bool isCreator = false; // Real logic
  String? userEmail; // For permissions

  // Expense state
  final TextEditingController _expenseDescController = TextEditingController();
  final TextEditingController _expenseAmountController = TextEditingController();
  String splitType = 'equal';
  List<Map<String, dynamic>> customSplits = [];
  bool addingExpense = false;
  String? expenseError;

  List<Map<String, dynamic>> userGroups = [];
  List<Map<String, dynamic>> filteredGroups = [];
  bool groupsLoading = true;
  bool showCreateGroupForm = false;
  String groupSearchQuery = '';
  String groupFilter = 'all'; // all, created, member
  String groupSort = 'newest'; // newest, oldest, name_az, name_za, members_high, members_low
  String memberCountFilter = 'all'; // all, 2-5, 6-10, 10+
  String dateFilter = 'all'; // all, 7days, 30days, custom
  DateTime? customStartDate;
  DateTime? customEndDate;
  Color? selectedGroupColor; // for group color customization

  @override
  void initState() {
    super.initState();
    _fetchUserGroups();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _memberEmailController.dispose();
    _expenseDescController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  Future<bool> _checkUserExists(String email) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/users/check-email'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data['unique'] == false; // unique==false means user exists
      }
    } catch (_) {}
    return false;
  }

  Future<void> _addMemberEmail() async {
    final email = _memberEmailController.text.trim();
    if (email.isEmpty) return;
    
    setState(() { memberAddError = null; });
    
    // Get current user's email
    final currentUserEmail = Provider.of<SessionProvider>(context, listen: false).user?['email'];
    
    // Debug: Print both emails to see what's happening
    print('Trying to add email: $email');
    print('Current user email: $currentUserEmail');
    
    // Check if trying to add the group creator (current user)
    if (email.toLowerCase() == (currentUserEmail ?? '').toLowerCase()) {
      setState(() { 
        memberAddError = 'You (group creator) are already added by default.'; 
        _memberEmailController.clear();
      });
      return;
    }
    
    // Check if email already exists in the list
    if (memberEmails.contains(email)) {
      setState(() { 
        memberAddError = 'This user is already added to the group.'; 
        _memberEmailController.clear();
      });
      return;
    }
    
    final exists = await _checkUserExists(email);
    if (!exists) {
      setState(() { memberAddError = 'This user does not exist, can\'t add.'; });
      return;
    }
    
    setState(() {
      memberEmails.add(email);
      _memberEmailController.clear();
    });
  }

  void _removeMemberEmail(String email) {
    setState(() {
      memberEmails.remove(email);
    });
  }

  Future<Map<String, String>> _authHeaders(BuildContext context) async {
    final token = Provider.of<SessionProvider>(context, listen: false).token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _createGroup() async {
    setState(() { creatingGroup = true; error = null; });
    try {
      final headers = await _authHeaders(context);
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/group-transactions'),
        headers: headers,
        body: json.encode({
          'title': _titleController.text.trim(),
          'memberEmails': memberEmails, // Backend expects emails for group creation
          'color': selectedGroupColor != null ? '#${selectedGroupColor!.value.toRadixString(16).substring(2).toUpperCase()}' : null,
        }),
      );
      final data = json.decode(res.body);
      if (res.statusCode == 201) {
        setState(() {
          group = data['group'];
          isCreator = true;
        });
      } else {
        setState(() { error = data['error'] ?? 'Failed to create group'; });
      }
    } catch (e) {
      setState(() { error = e.toString(); });
    } finally {
      setState(() { creatingGroup = false; });
    }
  }

  Future<void> _addMember() async {
    if (_memberEmailController.text.trim().isEmpty) return;
    
    final email = _memberEmailController.text.trim();
    
    // Check if user exists before adding
    final exists = await _checkUserExists(email);
    if (!exists) {
      setState(() { 
        memberAddError = 'User with email "$email" does not exist in our database. Please check the email address.'; 
        _memberEmailController.clear();
      });
      return;
    }
    
    // Check if trying to add the group creator (current user)
    final currentUserEmail = Provider.of<SessionProvider>(context, listen: false).user?['email'];
    if (email.toLowerCase() == (currentUserEmail ?? '').toLowerCase()) {
      setState(() { 
        memberAddError = 'You (group creator) are already a member of this group.'; 
        _memberEmailController.clear();
      });
      return;
    }
    
    // Check if user is already a member
    final members = (group?['members'] ?? []).cast<Map<String, dynamic>>();
    final isAlreadyMember = members.any((member) => 
        (member['email'] ?? '').toLowerCase() == email.toLowerCase());
    
    if (isAlreadyMember) {
      setState(() { 
        memberAddError = 'User "$email" is already a member of this group.'; 
        _memberEmailController.clear();
      });
      return;
    }
    
    setState(() { loading = true; memberAddError = null; });
    try {
      final headers = await _authHeaders(context);
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/group-transactions/${group!['_id']}/add-member'),
        headers: headers,
        body: json.encode({'email': email}),
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          group = data['group'];
          _memberEmailController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Member "$email" added successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        setState(() { memberAddError = data['error'] ?? 'Failed to add member. Please try again.'; });
      }
    } catch (e) {
      setState(() { memberAddError = 'Network error. Please check your connection and try again.'; });
    } finally {
      setState(() { loading = false; });
    }
  }

  Future<void> _addExpense() async {
    setState(() { addingExpense = true; expenseError = null; });
    try {
      final headers = await _authHeaders(context);
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/group-transactions/${group!['_id']}/add-expense'),
        headers: headers,
        body: json.encode({
          'description': _expenseDescController.text.trim(),
          'amount': double.tryParse(_expenseAmountController.text.trim()),
          'splitType': splitType,
          'split': splitType == 'custom' ? customSplits : null,
        }),
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          group = data['group'];
          _expenseDescController.clear();
          _expenseAmountController.clear();
          customSplits.clear();
        });
      } else {
        setState(() { expenseError = data['error'] ?? 'Failed to add expense'; });
      }
    } catch (e) {
      setState(() { expenseError = e.toString(); });
    } finally {
      setState(() { addingExpense = false; });
    }
  }

  Future<void> _requestLeave() async {
    setState(() { loading = true; error = null; });
    try {
      final headers = await _authHeaders(context);
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/group-transactions/${group!['_id']}/request-leave'),
        headers: headers,
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() { group = data['group']; });
      } else {
        setState(() { error = data['error'] ?? 'Failed to request leave'; });
      }
    } catch (e) {
      setState(() { error = e.toString(); });
    } finally {
      setState(() { loading = false; });
    }
  }

  Future<void> _fetchUserGroups() async {
    setState(() { groupsLoading = true; });
    try {
      final headers = await _authHeaders(context);
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/group-transactions/user-groups'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          userGroups = List<Map<String, dynamic>>.from(data['groups'] ?? []);
          _filterAndSearchGroups();
        });
      }
    } catch (_) {}
    setState(() { groupsLoading = false; });
  }

  void _filterAndSearchGroups() {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final myEmail = session.user?['email'] ?? '';
    List<Map<String, dynamic>> temp = userGroups.where((g) {
      final title = (g['title'] ?? '').toString().toLowerCase();
      final creatorEmail = (g['creator']?['email'] ?? '').toString().toLowerCase();
      final matchesSearch = groupSearchQuery.isEmpty ||
        title.contains(groupSearchQuery.toLowerCase()) ||
        creatorEmail.contains(groupSearchQuery.toLowerCase());
      final isCreator = creatorEmail == myEmail.toLowerCase();
      final isMember = (g['members'] as List).any((m) => (m['email'] ?? '').toLowerCase() == myEmail.toLowerCase());
      if (groupFilter == 'created') return matchesSearch && isCreator;
      if (groupFilter == 'member') return matchesSearch && !isCreator && isMember;
      // Advanced filters
      final memberCount = (g['members'] as List).length;
      if (memberCountFilter == '2-5' && (memberCount < 2 || memberCount > 5)) return false;
      if (memberCountFilter == '6-10' && (memberCount < 6 || memberCount > 10)) return false;
      if (memberCountFilter == '10+' && memberCount < 11) return false;
      if (dateFilter == '7days') {
        final created = DateTime.tryParse(g['createdAt'] ?? '') ?? DateTime(2000);
        if (created.isBefore(DateTime.now().subtract(Duration(days: 7)))) return false;
      }
      if (dateFilter == '30days') {
        final created = DateTime.tryParse(g['createdAt'] ?? '') ?? DateTime(2000);
        if (created.isBefore(DateTime.now().subtract(Duration(days: 30)))) return false;
      }
      if (dateFilter == 'custom' && customStartDate != null && customEndDate != null) {
        final created = DateTime.tryParse(g['createdAt'] ?? '') ?? DateTime(2000);
        if (created.isBefore(customStartDate!) || created.isAfter(customEndDate!)) return false;
      }
      return matchesSearch;
    }).toList();
    // Sorting (same as before)
    temp.sort((a, b) {
      switch (groupSort) {
        case 'oldest':
          return (a['createdAt'] ?? '').compareTo(b['createdAt'] ?? '');
        case 'name_az':
          return (a['title'] ?? '').toLowerCase().compareTo((b['title'] ?? '').toLowerCase());
        case 'name_za':
          return (b['title'] ?? '').toLowerCase().compareTo((a['title'] ?? '').toLowerCase());
        case 'members_high':
          return (b['members'] as List).length.compareTo((a['members'] as List).length);
        case 'members_low':
          return (a['members'] as List).length.compareTo((b['members'] as List).length);
        case 'newest':
        default:
          return (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? '');
      }
    });
    setState(() {
      filteredGroups = temp;
    });
  }

  void _showMemberDetails(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: Colors.primaries[(member['email'] ?? '').hashCode % Colors.primaries.length].shade300,
              radius: 32,
              child: Text(() {
                final email = member['email'] ?? '';
                return email.isNotEmpty ? email[0].toUpperCase() : '?';
              }(),
                style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 16),
            Text(member['email'] ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (member['joinedAt'] != null)
              Text('Joined: ${member['joinedAt'].toString().substring(0, 10)}', style: TextStyle(fontSize: 14, color: Colors.grey)),
            if (member['leftAt'] != null)
              Text('Left: ${member['leftAt'].toString().substring(0, 10)}', style: TextStyle(fontSize: 14, color: Colors.red)),
          ],
        ),
      ),
    );
  }

  void _showGroupDetails(Map<String, dynamic> g) {
    setState(() {
      group = g;
      isCreator = g['creator']?['email'] == Provider.of<SessionProvider>(context, listen: false).user?['email'];
    });
  }

  void _showCreateGroup() {
    setState(() {
      group = null;
      _titleController.clear();
      memberEmails.clear();
      error = null;
      memberAddError = null;
      showCreateGroupForm = true;
    });
  }

  void _hideCreateGroup() {
    setState(() {
      showCreateGroupForm = false;
    });
  }

  Future<void> _updateGroupColor(Color newColor) async {
    if (group == null) return;
    setState(() { loading = true; });
    try {
      final headers = await _authHeaders(context);
      final res = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/group-transactions/${group!['_id']}/color'),
        headers: headers,
        body: json.encode({'color': '#${newColor.value.toRadixString(16).substring(2).toUpperCase()}'}),
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          group = data['group'];
        });
        _fetchUserGroups();
      }
    } catch (_) {}
    setState(() { loading = false; });
  }

  void _showMembersDialog(List<Map<String, dynamic>> members, Map<String, dynamic>? creator) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.people, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Group Members',
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
                    color: Color(0xFF1E3A8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF1E3A8A), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Total Members: ${members.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                if (creator != null)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF059669).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF059669).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star, color: Color(0xFF059669), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Creator: ${creator['email'] ?? ''}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 16),
                ...members.map<Widget>((member) {
                  final isCreator = creator != null && member['email'] == creator['email'];
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isCreator ? Color(0xFF059669).withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCreator ? Color(0xFF059669).withOpacity(0.3) : Color(0xFF1E3A8A).withOpacity(0.2),
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
                        backgroundColor: isCreator 
                          ? Color(0xFF059669)
                          : Color(0xFF1E3A8A),
                        child: Text(
                          () {
                            final email = member['email'] ?? '';
                            return email.isNotEmpty ? email[0].toUpperCase() : '?';
                          }(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        member['email'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                      subtitle: Text(
                        isCreator 
                          ? 'Group Creator' 
                          : 'Joined: ${member['joinedAt'] != null ? member['joinedAt'].toString().substring(0, 10) : ''}',
                        style: TextStyle(
                          color: isCreator ? Color(0xFF059669) : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      trailing: isCreator 
                        ? Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(0xFF059669),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'CREATOR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : IconButton(
                            icon: Icon(Icons.person_remove, color: Color(0xFFDC2626)),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showRemoveMemberDialog(member['email'] ?? '');
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
                backgroundColor: Color(0xFF1E3A8A),
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

  void _showAddMemberDialog() {
    // Clear any previous errors when opening dialog
    setState(() { memberAddError = null; });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.person_add, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Add New Member',
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
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: memberAddError != null 
                      ? Color(0xFFDC2626).withOpacity(0.5)
                      : Color(0xFF1E3A8A).withOpacity(0.3)
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _memberEmailController,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: TextStyle(
                      color: memberAddError != null 
                        ? Color(0xFFDC2626)
                        : Color(0xFF1E3A8A)
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: memberAddError != null 
                      ? Color(0xFFDC2626).withOpacity(0.05)
                      : Color(0xFF1E3A8A).withOpacity(0.05),
                    prefixIcon: Icon(
                      Icons.email, 
                      color: memberAddError != null 
                        ? Color(0xFFDC2626)
                        : Color(0xFF1E3A8A)
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    errorText: memberAddError,
                    errorStyle: TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                    ),
                  ),
                  onChanged: (value) {
                    // Clear error when user starts typing
                    if (memberAddError != null) {
                      setState(() { memberAddError = null; });
                    }
                  },
                ),
              ),
              SizedBox(height: 24),
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : () async {
                    await _addMember();
                    if (memberAddError == null) {
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1E3A8A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    elevation: 4,
                    shadowColor: Color(0xFF1E3A8A).withOpacity(0.3),
                  ),
                  child: loading 
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Add Member',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // Clear error when dialog is closed
      setState(() { memberAddError = null; });
    });
  }

  Future<void> _deleteGroup() async {
    setState(() { loading = true; error = null; });
    try {
      final headers = await _authHeaders(context);
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/group-transactions/${group!['_id']}'),
        headers: headers,
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() { group = null; });
        _fetchUserGroups();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group deleted successfully')),
        );
      } else {
        setState(() { error = data['error'] ?? 'Failed to delete group'; });
      }
    } catch (e) {
      setState(() { error = e.toString(); });
    } finally {
      setState(() { loading = false; });
    }
  }

  Future<void> _leaveGroup() async {
    setState(() { loading = true; error = null; });
    try {
      final headers = await _authHeaders(context);
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/group-transactions/${group!['_id']}/leave'),
        headers: headers,
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() { group = null; });
        _fetchUserGroups();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Left group successfully')),
        );
      } else {
        setState(() { error = data['error'] ?? 'Failed to leave group'; });
      }
    } catch (e) {
      setState(() { error = e.toString(); });
    } finally {
      setState(() { loading = false; });
    }
  }

  Future<void> _removeMember(String email) async {
    setState(() { loading = true; error = null; });
    try {
      final headers = await _authHeaders(context);
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/group-transactions/${group!['_id']}/remove-member'),
        headers: headers,
        body: json.encode({'email': email}),
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() { group = data['group']; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Member removed successfully')),
        );
      } else {
        setState(() { error = data['error'] ?? 'Failed to remove member'; });
      }
    } catch (e) {
      setState(() { error = e.toString(); });
    } finally {
      setState(() { loading = false; });
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    setState(() { loading = true; error = null; });
    try {
      final headers = await _authHeaders(context);
      final res = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/group-transactions/${group!['_id']}/expenses/$expenseId'),
        headers: headers,
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() { group = data['group']; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Expense deleted successfully')),
        );
      } else {
        setState(() { error = data['error'] ?? 'Failed to delete expense'; });
      }
    } catch (e) {
      setState(() { error = e.toString(); });
    } finally {
      setState(() { loading = false; });
    }
  }

  void _showDeleteGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Delete Group',
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
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFFDC2626).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Are you sure you want to delete this group?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone. All group data will be permanently deleted.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Color(0xFF1E3A8A)),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _deleteGroup();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFDC2626),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    elevation: 4,
                    shadowColor: Color(0xFFDC2626).withOpacity(0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLeaveGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.exit_to_app, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Leave Group',
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
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFFF59E0B).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Are you sure you want to leave this group?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFFED7AA)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined, color: Color(0xFFF59E0B), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You will no longer have access to this group and its expenses.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Color(0xFF1E3A8A)),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _leaveGroup();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFF59E0B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    elevation: 4,
                    shadowColor: Color(0xFFF59E0B).withOpacity(0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.exit_to_app, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Leave',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRemoveMemberDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.person_remove, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Remove Member',
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
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFFDC2626).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Are you sure you want to remove this member?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF1E3A8A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email, color: Color(0xFF1E3A8A), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Member: $email',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Color(0xFF1E3A8A)),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _removeMember(email);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFDC2626),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    elevation: 4,
                    shadowColor: Color(0xFFDC2626).withOpacity(0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_remove, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Remove',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExpensesDialog(List<Map<String, dynamic>> expenses) {
    // Get members from the current group
    final members = (group?['members'] ?? []).cast<Map<String, dynamic>>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
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
                'Group Expenses',
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
                    color: Color(0xFF1E3A8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF1E3A8A), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Total Expenses: ${expenses.length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                if (expenses.isEmpty)
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long, color: Colors.grey, size: 48),
                          SizedBox(height: 8),
                          Text(
                            'No expenses yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Add your first expense to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...expenses.map<Widget>((expense) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Color(0xFF1E3A8A).withOpacity(0.2),
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
                          backgroundColor: Color(0xFF1E3A8A),
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
                            color: Color(0xFF1E3A8A),
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
                                    'Created: ${_formatDateTime(expense['createdAt'] ?? expense['date'])}',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            // Show split details
                            if (expense['split'] != null && expense['split'].isNotEmpty)
                              Container(
                                margin: EdgeInsets.only(top: 8),
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF1E3A8A).withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Color(0xFF1E3A8A).withOpacity(0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.people_outline, color: Color(0xFF1E3A8A), size: 16),
                                        SizedBox(width: 4),
                                        Text(
                                          'Split Details:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E3A8A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Container(
                                      constraints: BoxConstraints(maxHeight: 120),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: (expense['split'] as List).map<Widget>((splitItem) {
                                            final member = members.firstWhere(
                                              (m) => m['_id'] == splitItem['user'],
                                              orElse: () => {'email': 'Unknown User'},
                                            );
                                            return Padding(
                                              padding: EdgeInsets.only(bottom: 2),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    '• ${member['email']}: ',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  Text(
                                                    '\$${splitItem['amount'].toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.green[700],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        trailing: isCreator
                            ? IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showDeleteExpenseDialog(
                                    expense['_id'],
                                    expense['description'] ?? 'Unknown',
                                  );
                                },
                              )
                            : null,
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
                backgroundColor: Color(0xFF1E3A8A),
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
    return Scaffold(
      body: Stack(
        children: [
          // Wavy blue background at the top (header/banner only)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopWaveClipper(),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00B4D8), Color(0xFF48CAE4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                group == null ? 'Group Transactions' : 'Group: ${group?['title'] ?? ''}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 180), // Add top padding to move content below the wavy header
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: groupsLoading
                ? Center(child: CircularProgressIndicator())
                : group != null
                  ? _buildGroupDetailsCard()
                  : userGroups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.group_off, color: Colors.grey, size: 60),
                                    SizedBox(height: 16),
                                    Text('No groups found.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    SizedBox(height: 8),
                                    Text('Create your first group to get started!', style: TextStyle(fontSize: 16)),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 24),
                            if (!showCreateGroupForm)
                              ElevatedButton.icon(
                                onPressed: _showCreateGroup,
                                icon: Icon(Icons.add),
                                label: Text('Create Group'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF00B4D8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            if (showCreateGroupForm) ...[
                              _buildCreateGroupCard(),
                              SizedBox(height: 12),
                              TextButton(
                                onPressed: _hideCreateGroup,
                                child: Text('Cancel', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Search bar, filters, and sorting
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search by group name or creator email...',
                                    prefixIcon: Icon(Icons.search, color: Color(0xFF00B4D8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Color(0xFF00B4D8), width: 2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Color(0xFF00B4D8), width: 2),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(color: Color(0xFF00B4D8), width: 2),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    groupSearchQuery = val;
                                    _filterAndSearchGroups();
                                  },
                                ),
                              ),
                              SizedBox(width: 12),
                              DropdownButton<String>(
                                value: groupFilter,
                                borderRadius: BorderRadius.circular(16),
                                style: const TextStyle(color: Color(0xFF00B4D8), fontWeight: FontWeight.bold),
                                underline: Container(),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('All')),
                                  DropdownMenuItem(value: 'created', child: Text('Created by Me')),
                                  DropdownMenuItem(value: 'member', child: Text('Member')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    groupFilter = val;
                                    _filterAndSearchGroups();
                                  }
                                },
                              ),
                              SizedBox(width: 12),
                              DropdownButton<String>(
                                value: groupSort,
                                borderRadius: BorderRadius.circular(16),
                                style: const TextStyle(color: Color(0xFF00B4D8), fontWeight: FontWeight.bold),
                                underline: Container(),
                                items: const [
                                  DropdownMenuItem(value: 'newest', child: Text('Newest')),
                                  DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                                  DropdownMenuItem(value: 'name_az', child: Text('Name A-Z')),
                                  DropdownMenuItem(value: 'name_za', child: Text('Name Z-A')),
                                  DropdownMenuItem(value: 'members_high', child: Text('Members High-Low')),
                                  DropdownMenuItem(value: 'members_low', child: Text('Members Low-High')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    groupSort = val;
                                    _filterAndSearchGroups();
                                  }
                                },
                              ),
                              SizedBox(width: 12),
                              DropdownButton<String>(
                                value: memberCountFilter,
                                borderRadius: BorderRadius.circular(16),
                                style: const TextStyle(color: Color(0xFF00B4D8), fontWeight: FontWeight.bold),
                                underline: Container(),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('All Members')),
                                  DropdownMenuItem(value: '2-5', child: Text('2-5')),
                                  DropdownMenuItem(value: '6-10', child: Text('6-10')),
                                  DropdownMenuItem(value: '10+', child: Text('10+')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    memberCountFilter = val;
                                    _filterAndSearchGroups();
                                  }
                                },
                              ),
                              SizedBox(width: 12),
                              DropdownButton<String>(
                                value: dateFilter,
                                borderRadius: BorderRadius.circular(16),
                                style: const TextStyle(color: Color(0xFF00B4D8), fontWeight: FontWeight.bold),
                                underline: Container(),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('All Dates')),
                                  DropdownMenuItem(value: '7days', child: Text('Last 7 Days')),
                                  DropdownMenuItem(value: '30days', child: Text('Last 30 Days')),
                                  DropdownMenuItem(value: 'custom', child: Text('Custom')),
                                ],
                                onChanged: (val) async {
                                  if (val != null) {
                                    dateFilter = val;
                                    if (val == 'custom') {
                                      final picked = await showDateRangePicker(
                                        context: context,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null) {
                                        customStartDate = picked.start;
                                        customEndDate = picked.end;
                                      }
                                    }
                                    _filterAndSearchGroups();
                                  }
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          if (!showCreateGroupForm)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _showCreateGroup,
                                  icon: Icon(Icons.add),
                                  label: Text('Create Group'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF00B4D8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          if (showCreateGroupForm) ...[
                            _buildCreateGroupCard(),
                            SizedBox(height: 12),
                            TextButton(
                              onPressed: _hideCreateGroup,
                              child: Text('Cancel', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                          ...filteredGroups.map((g) {
                            final groupColor = g['color'] != null
                                ? Color(int.parse(g['color'].toString().replaceFirst('#', '0xff')))
                                : Colors.blue.shade300;
                            final avatarText = () {
                              final title = g['title'] ?? '';
                              return title.isNotEmpty ? title[0].toUpperCase() : '?';
                            }();
                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 6,
                              margin: EdgeInsets.only(bottom: 18),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: groupColor,
                                          radius: 22,
                                          child: Text(avatarText, style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                        SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            g['title'] ?? '',
                                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00B4D8)),
                                          ),
                                        ),
                                        // Group color indicator
                                        Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: groupColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        ElevatedButton(
                                          onPressed: () => _showGroupDetails(g),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Color(0xFF48CAE4),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            elevation: 0,
                                          ),
                                          child: Text('View Details', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Icon(Icons.person, size: 18, color: Colors.grey),
                                        SizedBox(width: 4),
                                        Text('Creator: ${g['creator']?['email'] ?? ''}', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                                        SizedBox(width: 16),
                                        Icon(Icons.people, size: 18, color: Colors.grey),
                                        SizedBox(width: 4),
                                        Text('Members: ${(g['members'] as List).length}', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                                        SizedBox(width: 12),
                                        // Member avatars
                                        ...((g['members'] as List).take(5).map((m) => GestureDetector(
                                              onTap: () => _showMemberDetails(m),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                                child: CircleAvatar(
                                                  radius: 12,
                                                  backgroundColor: Colors.primaries[(m['email'] ?? '').hashCode % Colors.primaries.length].shade200,
                                                  child: Text(() {
                                                    final email = m['email'] ?? '';
                                                    return email.isNotEmpty ? email[0].toUpperCase() : '?';
                                                  }(),
                                                    style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                            ))),
                                        if ((g['members'] as List).length > 5)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 2),
                                            child: CircleAvatar(
                                              radius: 12,
                                              backgroundColor: Colors.grey[400],
                                              child: Text('+${(g['members'] as List).length - 5}', style: TextStyle(fontSize: 12, color: Colors.white)),
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                        SizedBox(width: 4),
                                        Text('Created: ${g['createdAt'] != null ? g['createdAt'].toString().substring(0, 10) : ''}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pushReplacementNamed(context, '/user/dashboard'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateGroupCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.group, color: Colors.deepPurple, size: 40),
                SizedBox(width: 16),
                Text('Create Group', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            if (error != null) ...[
              SizedBox(height: 8),
              Text(error!, style: TextStyle(color: Colors.red)),
            ],
            SizedBox(height: 24),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Group Title',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            // Color picker
            Row(
              children: [
                Text('Group Color:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 12),
                GestureDetector(
                  onTap: () async {
                    Color picked = selectedGroupColor ?? Colors.blue;
                    await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Pick Group Color'),
                        content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: picked,
                            onColorChanged: (color) {
                              picked = color;
                            },
                            showLabel: false,
                            pickerAreaHeightPercent: 0.7,
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: Text('Cancel'),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          TextButton(
                            child: Text('Select'),
                            onPressed: () {
                              setState(() {
                                selectedGroupColor = picked;
                              });
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selectedGroupColor ?? Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 2),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(selectedGroupColor != null ? '#${selectedGroupColor!.value.toRadixString(16).substring(2).toUpperCase()}' : 'Default'),
              ],
            ),
            SizedBox(height: 20),
            Text('Add Members (by email):'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You (group creator) will be automatically added to the group.',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberEmailController,
                    decoration: InputDecoration(hintText: 'Enter email', border: OutlineInputBorder()),
                    onSubmitted: (_) => _addMemberEmail(),
                  ),
                ),
                SizedBox(width: 8),
                TextButton(
                  onPressed: _addMemberEmail,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  child: Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (memberAddError != null) ...[
              SizedBox(height: 6),
              Text(memberAddError!, style: TextStyle(color: Colors.red)),
            ],
            Wrap(
              spacing: 8,
              children: memberEmails.map((e) => Chip(label: Text(e), onDeleted: () => _removeMemberEmail(e))).toList(),
            ),
            SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: creatingGroup ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00B4D8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: creatingGroup ? CircularProgressIndicator() : Text('Create Group', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupDetailsCard() {
    final members = (group?['members'] ?? []).cast<Map<String, dynamic>>();
    final creator = group?['creator'];
    final expenses = (group?['expenses'] ?? []).cast<Map<String, dynamic>>();
    final groupColor = group?['color'] != null
        ? Color(int.parse(group!['color'].toString().replaceFirst('#', '0xff')))
        : Colors.blue.shade300;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.red),
                tooltip: 'Close',
                onPressed: () => setState(() => group = null),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: groupColor,
                  radius: 28,
                  child: Text(() {
                    final title = group?['title'] ?? '';
                    return title.isNotEmpty ? title[0].toUpperCase() : '?';
                  }(),
                      style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text('Group Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                if (isCreator)
                  GestureDetector(
                    onTap: () async {
                      Color picked = groupColor;
                      await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Change Group Color'),
                          content: SingleChildScrollView(
                            child: ColorPicker(
                              pickerColor: picked,
                              onColorChanged: (color) {
                                picked = color;
                              },
                              showLabel: false,
                              pickerAreaHeightPercent: 0.7,
                            ),
                          ),
                          actions: [
                            TextButton(
                              child: Text('Cancel'),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            TextButton(
                              child: Text('Update'),
                              onPressed: () {
                                _updateGroupColor(picked);
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: groupColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey, width: 2),
                      ),
                      child: Icon(Icons.edit, color: Colors.white, size: 18),
                    ),
                  ),
                if (isCreator)
                  SizedBox(width: 8),
                if (isCreator)
                  GestureDetector(
                    onTap: loading ? null : _showDeleteGroupDialog,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFFDC2626).withOpacity(0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.delete, color: Colors.white, size: 18),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            Text('Members:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showMembersDialog(members, creator),
                    icon: Icon(Icons.people, color: Colors.white),
                    label: Text('View Members (${members.length})', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                if (isCreator)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddMemberDialog(),
                      icon: Icon(Icons.person_add, color: Colors.white),
                      label: Text('Add Member', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Text('Expenses:', style: TextStyle(fontWeight: FontWeight.bold)),
                Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showExpensesDialog(expenses),
                  icon: Icon(Icons.receipt_long, color: Colors.white, size: 18),
                  label: Text('View All (${expenses.length})', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1E3A8A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (expenses.isEmpty)
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.grey, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'No expenses yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Add your first expense to get started',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...expenses.map<Widget>((expense) {
                return Container(
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Color(0xFF1E3A8A).withOpacity(0.2),
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
                      backgroundColor: Color(0xFF1E3A8A),
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
                        color: Color(0xFF1E3A8A),
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
                                'Created: ${_formatDateTime(expense['createdAt'] ?? expense['date'])}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        // Show split details
                        if (expense['split'] != null && expense['split'].isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(top: 8),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFF1E3A8A).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Color(0xFF1E3A8A).withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.people_outline, color: Color(0xFF1E3A8A), size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Split Details:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Container(
                                  constraints: BoxConstraints(maxHeight: 120),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: (expense['split'] as List).map<Widget>((splitItem) {
                                        final member = members.firstWhere(
                                          (m) => m['_id'] == splitItem['user'],
                                          orElse: () => {'email': 'Unknown User'},
                                        );
                                        return Padding(
                                          padding: EdgeInsets.only(bottom: 2),
                                          child: Row(
                                            children: [
                                              Text(
                                                '• ${member['email']}: ',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                '\$${splitItem['amount'].toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    trailing: isCreator
                        ? IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showDeleteExpenseDialog(
                                expense['_id'],
                                expense['description'] ?? 'Unknown',
                              );
                            },
                          )
                        : null,
                  ),
                );
              }).toList(),
            if (expenses.length > 3)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '... and ${expenses.length - 3} more expenses',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: addingExpense ? null : () {
                _showAddExpenseDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00B4D8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('Add Expense', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            SizedBox(height: 24),
            if (!isCreator)
              ElevatedButton(
                onPressed: loading ? null : _showLeaveGroupDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFF59E0B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  elevation: 4,
                  shadowColor: Color(0xFFF59E0B).withOpacity(0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Leave Group',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!, style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteExpenseDialog(String expenseId, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Delete Expense',
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
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFDC2626).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Are you sure you want to delete this expense?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  '"$description"',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
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
                      Navigator.of(context).pop();
                      await _deleteExpense(expenseId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFDC2626),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Delete',
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
    );
  }

  void _showAddExpenseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Add New Expense',
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF1E3A8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF1E3A8A), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Add expense details and choose split type',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Color(0xFF1E3A8A).withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _expenseDescController,
                    decoration: InputDecoration(
                      labelText: 'Expense Description',
                      labelStyle: TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Icon(Icons.description, color: Color(0xFF1E3A8A)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Color(0xFF1E3A8A), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Color(0xFF1E3A8A).withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _expenseAmountController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (\$)',
                      labelStyle: TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Icon(Icons.attach_money, color: Color(0xFF1E3A8A)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Color(0xFF1E3A8A), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Color(0xFF1E3A8A).withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    value: splitType,
                    items: [
                      DropdownMenuItem(
                        value: 'equal',
                        child: Row(
                          children: [
                            Icon(Icons.equalizer, color: Color(0xFF1E3A8A)),
                            SizedBox(width: 8),
                            Text('Split Equally'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline, color: Color(0xFF1E3A8A)),
                            SizedBox(width: 8),
                            Text('Custom Split'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => splitType = v ?? 'equal'),
                    decoration: InputDecoration(
                      labelText: 'Split Type',
                      labelStyle: TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Icon(Icons.share, color: Color(0xFF1E3A8A)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Color(0xFF1E3A8A), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
                if (splitType == 'custom')
                  Container(
                    margin: EdgeInsets.only(top: 16),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF1E3A8A).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF1E3A8A).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF1E3A8A), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Custom split feature will be implemented in the next update',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1E3A8A),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (expenseError != null)
                  Container(
                    margin: EdgeInsets.only(top: 16),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            expenseError!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red[700],
                            ),
                          ),
                        ),
                      ],
                    ),
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
                    onPressed: addingExpense ? null : () async {
                      await _addExpense();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1E3A8A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: addingExpense
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Add Expense',
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
    );
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
}

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.25, size.height,
      size.width * 0.5, size.height * 0.8,
    );
    path.quadraticBezierTo(
      size.width * 0.75, size.height * 0.6,
      size.width, size.height * 0.8,
    );
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
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.6, size.width * 0.5, size.height * 0.4);
    path.quadraticBezierTo(size.width * 0.75, 0, size.width, size.height * 0.4);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
} 