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

  void _addMemberEmail() async {
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
    setState(() { loading = true; error = null; });
    try {
      final headers = await _authHeaders(context);
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/group-transactions/${group!['_id']}/add-member'),
        headers: headers,
        body: json.encode({'email': _memberEmailController.text.trim()}),
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          group = data['group'];
          _memberEmailController.clear();
        });
      } else {
        setState(() { error = data['error'] ?? 'Failed to add member'; });
      }
    } catch (e) {
      setState(() { error = e.toString(); });
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
    final members = group?['members'] ?? [];
    final creator = group?['creator'];
    final expenses = group?['expenses'] ?? [];
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
              ],
            ),
            SizedBox(height: 16),
            Text('Members:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: [
                if (creator != null) Chip(
                  label: Text('${creator['email'] ?? ''} (Group Creator)'),
                  backgroundColor: Colors.blue.shade100,
                ),
                ...members.where((m) => (creator == null || m['email'] != creator['email']) && m['email'] != null).map<Widget>((m) => Chip(
                  label: Text(m['email'] as String),
                )),
              ],
            ),
            if (isCreator)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _memberEmailController,
                      decoration: InputDecoration(hintText: 'Add member by email', border: OutlineInputBorder()),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: loading ? null : _addMember,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
            SizedBox(height: 24),
            Text('Expenses:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...expenses.map<Widget>((e) => ListTile(
              title: Text(e['description'] ?? ''),
              subtitle: Text('Amount: ${e['amount']} | Added by: ${e['addedBy']}'),
            )),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: addingExpense ? null : () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    title: Text('Add Expense'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _expenseDescController,
                          decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: _expenseAmountController,
                          decoration: InputDecoration(labelText: 'Amount', border: OutlineInputBorder()),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                        ),
                        SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: splitType,
                          items: [
                            DropdownMenuItem(value: 'equal', child: Text('Split Equally')),
                            DropdownMenuItem(value: 'custom', child: Text('Split By Yourself')),
                          ],
                          onChanged: (v) => setState(() => splitType = v ?? 'equal'),
                          decoration: InputDecoration(
                            labelText: 'Split Type',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (splitType == 'custom')
                          Text('Custom split UI here (not implemented)'),
                        if (expenseError != null)
                          Text(expenseError!, style: TextStyle(color: Colors.red)),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                      ElevatedButton(
                        onPressed: addingExpense ? null : () async {
                          await _addExpense();
                          Navigator.pop(context);
                        },
                        child: addingExpense ? CircularProgressIndicator() : Text('Add'),
                      ),
                    ],
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00B4D8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('Add Expense', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: loading ? null : _requestLeave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[100],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('Settle/Leave Group', style: TextStyle(fontSize: 18, color: Colors.red[800])),
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