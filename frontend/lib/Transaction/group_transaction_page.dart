import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';

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
  bool groupsLoading = true;
  bool showCreateGroupForm = false;

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
    if (email.toLowerCase() == currentUserEmail?.toLowerCase()) {
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
      } else {
        setState(() { error = data['error'] ?? 'Failed to remove member'; });
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
        });
      }
    } catch (_) {}
    setState(() { groupsLoading = false; });
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Your Groups', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                            ],
                          ),
                          SizedBox(height: 16),
                          if (showCreateGroupForm) ...[
                            _buildCreateGroupCard(),
                            SizedBox(height: 12),
                            TextButton(
                              onPressed: _hideCreateGroup,
                              child: Text('Cancel', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                          ...userGroups.map((g) => Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 2,
                                child: ListTile(
                                  leading: Icon(Icons.group, color: Colors.deepPurple),
                                  title: Text(g['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Creator: ${g['creator']?['email'] ?? ''}'),
                                  onTap: () => _showGroupDetails(g),
                                ),
                              )),
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
                Icon(Icons.group, color: Colors.deepPurple, size: 40),
                SizedBox(width: 16),
                Text('Group Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            Text('Members:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: [
                if (creator != null) Chip(
                  label: Text('${creator['email']} (Group Creator)'),
                  backgroundColor: Colors.blue.shade100,
                ),
                ...members.where((m) => creator == null || m['email'] != creator['email']).map<Widget>((m) => Chip(
                  label: Text(m['email'] ?? ''),
                  onDeleted: isCreator ? () => _removeMember(m['email'] ?? '') : null,
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