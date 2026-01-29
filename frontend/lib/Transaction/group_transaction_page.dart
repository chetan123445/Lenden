import 'package:flutter/material.dart';
import 'dart:convert';
import '../api_config.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import '../utils/api_client.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../widgets/subscription_prompt.dart';
import '../widgets/stylish_dialog.dart';
import '../Digitise/subscriptions_page.dart';

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
  final TextEditingController _expenseAmountController =
      TextEditingController();
  String splitType = 'equal';
  List<Map<String, dynamic>> customSplits = [];
  List<String> selectedMembers = []; // New: selected members for expense
  Map<String, double> customSplitAmounts =
      {}; // New: track custom split amounts for each member
  bool addingExpense = false;
  String? expenseError;

  List<Map<String, dynamic>> userGroups = [];
  List<Map<String, dynamic>> filteredGroups = [];
  bool groupsLoading = true;
  bool showCreateGroupForm = false;
  String groupSearchQuery = '';
  String groupFilter = 'all'; // all, created, member
  String groupSort =
      'newest'; // newest, oldest, name_az, name_za, members_high, members_low
  String memberCountFilter = 'all'; // all, 2-5, 6-10, 10+
  String dateFilter = 'all'; // all, 7days, 30days, custom
  DateTime? customStartDate;
  DateTime? customEndDate;
  Color? selectedGroupColor; // for group color customization
  bool _showFavouritesOnly = false;

  @override
  void initState() {
    super.initState();
    _fetchUserGroups();
  }

  Future<void> _toggleFavourite(String groupId) async {
    try {
      final response = await ApiClient.put(
        '/api/group-transactions/$groupId/favourite',
      );

      if (response.statusCode == 200) {
        _fetchUserGroups();
      } else {
        // Handle error
      }
    } catch (e) {
      // Handle error
    }
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
      final res = await ApiClient.post(
        '/api/users/check-email',
        body: {'email': email},
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

    setState(() {
      memberAddError = null;
    });

    // Get current user's email
    final currentUserEmail =
        Provider.of<SessionProvider>(context, listen: false).user?['email'];

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
      setState(() {
        memberAddError = 'This user does not exist, can\'t add.';
      });
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

  // Initialize selected members for expense (start with no members selected)
  void _initializeSelectedMembers() {
    if (group != null) {
      // Start with no members selected - user must explicitly choose
      selectedMembers = [];
    }
  }

  // Initialize custom split amounts for selected members
  void _initializeCustomSplitAmounts() {
    customSplitAmounts.clear();
    for (String memberEmail in selectedMembers) {
      customSplitAmounts[memberEmail] = 0.0;
    }
  }

  // Get total amount entered for custom split
  double get _totalCustomSplitAmount {
    return customSplitAmounts.values.fold(0.0, (sum, amount) => sum + amount);
  }

  // Get remaining amount for custom split
  double get _remainingCustomSplitAmount {
    final totalExpenseAmount =
        double.tryParse(_expenseAmountController.text.trim()) ?? 0.0;
    return totalExpenseAmount - _totalCustomSplitAmount;
  }

  // Calculate member's total split amount from all expenses in the group (excluding settled amounts)
  double _getMemberBalance(String memberEmail) {
    if (group == null) return 0.0;

    double total = 0.0;
    final expenses = (group!['expenses'] ?? []) as List<dynamic>;
    final members = (group!['members'] ?? []) as List<dynamic>;

    // Find the member with this email to get their ID
    String? userMemberId;
    for (var member in members) {
      if (member['email'] == memberEmail) {
        userMemberId = member['_id'].toString();
        break;
      }
    }

    if (userMemberId == null) {
      print('User member ID not found for email: $memberEmail');
      return 0.0;
    }

    print(
        'Calculating total split for member: $memberEmail (ID: $userMemberId)');
    print('Total expenses in group: ${expenses.length}');

    for (var expense in expenses) {
      final split = (expense['split'] ?? []) as List<dynamic>;
      print('Expense: ${expense['description']}, Split items: ${split.length}');

      for (var splitItem in split) {
        // Check if this split item belongs to the current user and is not settled
        String splitUserId = splitItem['user'].toString();
        double splitAmount =
            double.parse((splitItem['amount'] ?? 0).toString());
        bool isSettled = splitItem['settled'] == true;
        print(
            'Split item - User ID: $splitUserId, Amount: $splitAmount, Settled: $isSettled');
        print('  - Raw settled value: ${splitItem['settled']}');
        print('  - Type of settled: ${splitItem['settled'].runtimeType}');

        if (splitUserId == userMemberId) {
          print('  - This split belongs to current user');
          if (!isSettled) {
            total += splitAmount;
            print(
                '  - NOT SETTLED: Adding $splitAmount to total. New total: $total');
          } else {
            print('  - SETTLED: Skipping $splitAmount (already settled)');
          }
        }
      }
    }

    print('Final total split amount for $memberEmail: $total');
    return total;
  }

  // Calculate current user's total split amount from all expenses in the group
  double _getCurrentUserBalance() {
    if (group == null) return 0.0;

    final currentUserEmail =
        Provider.of<SessionProvider>(context, listen: false).user?['email'];
    if (currentUserEmail == null) return 0.0;

    return _getMemberBalance(currentUserEmail);
  }

  Future<Map<String, String>> _authHeaders(BuildContext context) async {
    final token = Provider.of<SessionProvider>(context, listen: false).token;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _createGroupWithCoins() async {
    setState(() {
      creatingGroup = true;
      error = null;
    });
    try {
      final res = await ApiClient.post(
        '/api/group-transactions/with-coins',
        body: {
          'title': _titleController.text.trim(),
          'memberEmails':
              memberEmails, // Backend expects emails for group creation
          'color': selectedGroupColor != null
              ? '#${selectedGroupColor!.value.toRadixString(16).substring(2).toUpperCase()}'
              : null,
        },
      );
      final data = json.decode(res.body);
      if (res.statusCode == 201) {
        setState(() {
          group = data['group'];
          isCreator = true;
        });
        final session = Provider.of<SessionProvider>(context, listen: false);
        session.loadFreebieCounts();
      } else if (res.statusCode == 403) {
        showInsufficientCoinsDialog(context);
      } else {
        setState(() {
          error = data['error'] ?? 'Failed to create group';
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        creatingGroup = false;
      });
    }
  }

  Future<void> _createGroup() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    if (!session.isSubscribed && (session.freeGroupsRemaining ?? 0) <= 0) {
      if ((session.lenDenCoins ?? 0) < 20) {
        if ((session.lenDenCoins ?? 0) == 0) {
          showZeroCoinsDialog(context);
        } else {
          showInsufficientCoinsDialog(context);
        }
        return;
      }
      final useCoins = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.white, Colors.green],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monetization_on, color: Colors.orange, size: 48),
                  SizedBox(height: 16),
                  Text(
                    'Use LenDen Coins',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'You have no free groups remaining. Would you like to use 20 LenDen coins to create this group?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'OR',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Subscribe now for unlimited access',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, false);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubscriptionsPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          'Subscribe',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          'Use Coins',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (useCoins == true) {
        _createGroupWithCoins();
      }
      return;
    }

    setState(() {
      creatingGroup = true;
      error = null;
    });
    try {
      final res = await ApiClient.post(
        '/api/group-transactions',
        body: {
          'title': _titleController.text.trim(),
          'memberEmails':
              memberEmails, // Backend expects emails for group creation
          'color': selectedGroupColor != null
              ? '#${selectedGroupColor!.value.toRadixString(16).substring(2).toUpperCase()}'
              : null,
        },
      );
      final data = json.decode(res.body);
      if (res.statusCode == 201) {
        setState(() {
          group = data['group'];
          isCreator = true;
        });
        session.loadFreebieCounts();
      } else {
        setState(() {
          error = data['error'] ?? 'Failed to create group';
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        creatingGroup = false;
      });
    }
  }

  Widget _buildFloatingErrorCard(String errorMessage, Function setDialogState) {
    // Auto-dismiss error after 5 seconds
    Future.delayed(Duration(seconds: 5), () {
      if (memberAddError != null) {
        setDialogState(() {
          memberAddError = null;
        });
      }
    });

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFDC2626), // Red
            Color(0xFFEF4444),
            Color(0xFFF87171),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFDC2626).withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setDialogState(() {
              memberAddError = null;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Error icon
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),

                // Error message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Error',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        errorMessage,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Close button
                Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addMemberWithDialog(Function setDialogState) async {
    if (_memberEmailController.text.trim().isEmpty) return;

    final email = _memberEmailController.text.trim();

    // Check if user exists before adding
    final exists = await _checkUserExists(email);
    if (!exists) {
      setDialogState(() {
        memberAddError =
            'User with email "$email" does not exist in our database. Please check the email address.';
      });
      return;
    }

    // Check if trying to add the group creator (current user)
    final currentUserEmail =
        Provider.of<SessionProvider>(context, listen: false).user?['email'];
    if (email.toLowerCase() == (currentUserEmail ?? '').toLowerCase()) {
      setDialogState(() {
        memberAddError =
            'You (group creator) are already a member of this group.';
      });
      return;
    }

    // Check if user is already a member
    final members = (group?['members'] ?? []) as List<dynamic>;
    final isAlreadyMember = members.any((member) =>
        (member['email'] ?? '').toString().toLowerCase() ==
            email.toLowerCase() &&
        member['leftAt'] == null);

    if (isAlreadyMember) {
      setDialogState(() {
        memberAddError = 'User "$email" is already a member of this group.';
      });
      return;
    }

    setDialogState(() {
      loading = true;
      memberAddError = null;
    });
    try {
      final res = await ApiClient.post(
        '/api/group-transactions/${group!['_id']}/add-member',
        body: {'email': email},
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          group = data['group'];
          _memberEmailController.clear();
        });

        // Close dialog and show success message
        Navigator.of(context).pop();

        // Show stylish success popup
        _showMemberAddedSuccessDialog(email);
      } else {
        final errorMessage =
            data['error'] ?? 'Failed to add member. Please try again.';
        // Check if it's a permission error and show stylish dialog
        if (errorMessage
                .toLowerCase()
                .contains('only creator can add members') ||
            errorMessage.toLowerCase().contains('only creator can add')) {
          Navigator.of(context).pop(); // Close the add member dialog
          _showAddMemberPermissionDeniedDialog();
        } else {
          setDialogState(() {
            memberAddError = errorMessage;
          });
        }
      }
    } catch (e) {
      setDialogState(() {
        memberAddError =
            'Network error. Please check your connection and try again.';
      });
    } finally {
      setDialogState(() {
        loading = false;
      });
    }
  }

  Future<void> _addMember() async {
    if (_memberEmailController.text.trim().isEmpty) return;

    final email = _memberEmailController.text.trim();

    // Check if user exists before adding
    final exists = await _checkUserExists(email);
    if (!exists) {
      setState(() {
        memberAddError =
            'User with email "$email" does not exist in our database. Please check the email address.';
        _memberEmailController.clear();
      });
      return;
    }

    // Check if trying to add the group creator (current user)
    final currentUserEmail =
        Provider.of<SessionProvider>(context, listen: false).user?['email'];
    if (email.toLowerCase() == (currentUserEmail ?? '').toLowerCase()) {
      setState(() {
        memberAddError =
            'You (group creator) are already a member of this group.';
        _memberEmailController.clear();
      });
      return;
    }

    // Check if user is already a member
    final members = (group?['members'] ?? []) as List<dynamic>;
    final isAlreadyMember = members.any((member) =>
        (member['email'] ?? '').toString().toLowerCase() ==
        email.toLowerCase());

    if (isAlreadyMember) {
      setState(() {
        memberAddError = 'User "$email" is already a member of this group.';
        _memberEmailController.clear();
      });
      return;
    }

    setState(() {
      loading = true;
      memberAddError = null;
    });
    try {
      final res = await ApiClient.post(
        '/api/group-transactions/${group!['_id']}/add-member',
        body: {'email': email},
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
        final errorMessage =
            data['error'] ?? 'Failed to add member. Please try again.';
        // Check if it's a permission error and show stylish dialog
        if (errorMessage
                .toLowerCase()
                .contains('only creator can add members') ||
            errorMessage.toLowerCase().contains('only creator can add')) {
          Navigator.of(context).pop(); // Close the add member dialog
          _showAddMemberPermissionDeniedDialog();
        } else {
          setState(() {
            memberAddError = errorMessage;
          });
        }
      }
    } catch (e) {
      setState(() {
        memberAddError =
            'Network error. Please check your connection and try again.';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _addExpense() async {
    // Validation is now handled in the dialog, so we don't need to check here

    setState(() {
      addingExpense = true;
    });
    try {
      // Prepare split data based on split type
      List<Map<String, dynamic>> splitData = [];
      if (splitType == 'equal') {
        // For equal split, send selected members with null amounts (backend will calculate)
        splitData = selectedMembers
            .map((memberEmail) => {
                  'user': memberEmail,
                  'amount': null, // Backend will calculate equal amounts
                })
            .toList();
      } else if (splitType == 'custom') {
        // For custom split, send the amounts for each member
        splitData = selectedMembers
            .map((memberEmail) => {
                  'user': memberEmail,
                  'amount': customSplitAmounts[memberEmail] ?? 0.0,
                })
            .toList();
      }

      // Debug: Print request data
      final requestData = {
        'description': _expenseDescController.text.trim(),
        'amount': double.tryParse(_expenseAmountController.text.trim()),
        'splitType': splitType,
        'split': splitData,
        'selectedMembers': selectedMembers,
      };
      print('Adding expense with data: ${json.encode(requestData)}');

      final res = await ApiClient.post(
        '/api/group-transactions/${group!['_id']}/add-expense',
        body: requestData,
      );

      print('Response status: ${res.statusCode}');
      print('Response body: ${res.body}');

      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          group = data['group'];
          _expenseDescController.clear();
          _expenseAmountController.clear();
          customSplits.clear();
          selectedMembers.clear();
          customSplitAmounts.clear(); // Clear custom split amounts
        });
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Expense added successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // Throw exception instead of setting error state
        throw Exception(data['error'] ?? 'Failed to add expense');
      }
    } catch (e) {
      print('Error adding expense: $e');
      // Re-throw the exception so the dialog can handle it
      rethrow;
    } finally {
      setState(() {
        addingExpense = false;
      });
    }
  }

  Future<void> _requestLeave() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await ApiClient.post(
        '/api/group-transactions/${group!['_id']}/request-leave',
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          group = data['group'];
        });
      } else {
        setState(() {
          error = data['error'] ?? 'Failed to request leave';
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _fetchUserGroups() async {
    setState(() {
      groupsLoading = true;
      error = null;
    });
    try {
      final res = await ApiClient.get('/api/group-transactions/user-groups');

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          userGroups = List<Map<String, dynamic>>.from(data['groups'] ?? []);
          _filterAndSearchGroups();
        });
      } else {
        setState(() {
          error =
              'Failed to load groups. Status code: ${res.statusCode}\nBody: ${res.body}';
        });
      }
    } catch (e) {
      setState(() {
        error = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        groupsLoading = false;
      });
    }
  }

  void _filterAndSearchGroups() {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final myEmail = session.user?['email'] ?? '';
    List<Map<String, dynamic>> temp = userGroups.where((g) {
      if (_showFavouritesOnly) {
        final isFavourite = (g['favourite'] as List? ?? []).contains(myEmail);
        if (!isFavourite) return false;
      }

      final title = (g['title'] ?? '').toString().toLowerCase();
      final creatorEmail =
          (g['creator']?['email'] ?? '').toString().toLowerCase();
      final matchesSearch = groupSearchQuery.isEmpty ||
          title.contains(groupSearchQuery.toLowerCase()) ||
          creatorEmail.contains(groupSearchQuery.toLowerCase());
      final isCreator = creatorEmail == myEmail.toLowerCase();
      final isMember = (g['members'] as List).any(
          (m) => (m['email'] ?? '').toLowerCase() == myEmail.toLowerCase());
      if (groupFilter == 'created') return matchesSearch && isCreator;
      if (groupFilter == 'member')
        return matchesSearch && !isCreator && isMember;
      // Advanced filters
      final memberCount = (g['members'] as List).length;
      if (memberCountFilter == '2-5' && (memberCount < 2 || memberCount > 5))
        return false;
      if (memberCountFilter == '6-10' && (memberCount < 6 || memberCount > 10))
        return false;
      if (memberCountFilter == '10+' && memberCount < 11) return false;
      if (dateFilter == '7days') {
        final created =
            DateTime.tryParse(g['createdAt'] ?? '') ?? DateTime(2000);
        if (created.isBefore(DateTime.now().subtract(Duration(days: 7))))
          return false;
      }
      if (dateFilter == '30days') {
        final created =
            DateTime.tryParse(g['createdAt'] ?? '') ?? DateTime(2000);
        if (created.isBefore(DateTime.now().subtract(Duration(days: 30))))
          return false;
      }
      if (dateFilter == 'custom' &&
          customStartDate != null &&
          customEndDate != null) {
        final created =
            DateTime.tryParse(g['createdAt'] ?? '') ?? DateTime(2000);
        if (created.isBefore(customStartDate!) ||
            created.isAfter(customEndDate!)) return false;
      }
      return matchesSearch;
    }).toList();
    // Sorting (same as before)
    temp.sort((a, b) {
      switch (groupSort) {
        case 'oldest':
          return (a['createdAt'] ?? '').compareTo(b['createdAt'] ?? '');
        case 'name_az':
          return (a['title'] ?? '')
              .toLowerCase()
              .compareTo((b['title'] ?? '').toLowerCase());
        case 'name_za':
          return (b['title'] ?? '')
              .toLowerCase()
              .compareTo((a['title'] ?? '').toLowerCase());
        case 'members_high':
          return (b['members'] as List)
              .length
              .compareTo((a['members'] as List).length);
        case 'members_low':
          return (a['members'] as List)
              .length
              .compareTo((b['members'] as List).length);
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
              backgroundColor: Colors
                  .primaries[(member['email'] ?? '').toString().hashCode %
                      Colors.primaries.length]
                  .shade300,
              radius: 32,
              child: Text(
                () {
                  final email = (member['email'] ?? '').toString();
                  return email.isNotEmpty ? email[0].toUpperCase() : '?';
                }(),
                style: TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 16),
            Text((member['email'] ?? '').toString(),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (member['joinedAt'] != null)
              Text('Joined: ${member['joinedAt'].toString().substring(0, 10)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
            if (member['leftAt'] != null)
              Text('Left: ${member['leftAt'].toString().substring(0, 10)}',
                  style: TextStyle(fontSize: 14, color: Colors.red)),
          ],
        ),
      ),
    );
  }

  void _showGroupDetails(Map<String, dynamic> g) {
    setState(() {
      group = g;
      isCreator = g['creator']?['email'] ==
          Provider.of<SessionProvider>(context, listen: false).user?['email'];
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
    setState(() {
      loading = true;
    });
    try {
      final res = await ApiClient.put(
        '/api/group-transactions/${group!['_id']}/color',
        body: {
          'color':
              '#${newColor.value.toRadixString(16).substring(2).toUpperCase()}'
        },
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          group = data['group'];
        });
        _fetchUserGroups();
      }
    } catch (_) {}
    setState(() {
      loading = false;
    });
  }

  void _showMembersDialog(
      List<dynamic> members, Map<String, dynamic>? creator) {
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
                    border:
                        Border.all(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Color(0xFF1E3A8A), size: 20),
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
                      border:
                          Border.all(color: Color(0xFF059669).withOpacity(0.3)),
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
                  final isMemberCreator = creator != null &&
                      (member['email'] ?? '').toString() ==
                          (creator['email'] ?? '').toString();
                  final isCurrentUserCreator = creator != null &&
                      (creator['email'] ?? '').toString() ==
                          (Provider.of<SessionProvider>(context, listen: false)
                                      .user?['email'] ??
                                  '')
                              .toString();
                  final hasLeft = member['leftAt'] != null;
                  final memberEmail = (member['email'] ?? '').toString();

                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isMemberCreator
                          ? Color(0xFF059669).withOpacity(0.1)
                          : hasLeft
                              ? Colors.grey[100]
                              : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isMemberCreator
                            ? Color(0xFF059669).withOpacity(0.3)
                            : hasLeft
                                ? Colors.grey[300]!
                                : Color(0xFF1E3A8A).withOpacity(0.2),
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
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: isMemberCreator
                            ? Color(0xFF059669)
                            : hasLeft
                                ? Colors.grey[400]!
                                : Color(0xFF1E3A8A),
                        child: Text(
                          () {
                            final email = memberEmail;
                            return email.isNotEmpty
                                ? email[0].toUpperCase()
                                : '?';
                          }(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        memberEmail,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: hasLeft ? Colors.grey[600] : Color(0xFF1E3A8A),
                        ),
                      ),
                      subtitle: Text(
                        isMemberCreator
                            ? 'Group Creator'
                            : hasLeft
                                ? (isCurrentUserCreator
                                    ? 'Removed by Creator: ${member['leftAt'] != null ? member['leftAt'].toString().substring(0, 10) : ''}'
                                    : 'Left Group: ${member['leftAt'] != null ? member['leftAt'].toString().substring(0, 10) : ''}')
                                : 'Joined: ${member['joinedAt'] != null ? member['joinedAt'].toString().substring(0, 10) : ''}',
                        style: TextStyle(
                          color: isMemberCreator
                              ? Color(0xFF059669)
                              : hasLeft
                                  ? (isCurrentUserCreator
                                      ? Colors.red[500]
                                      : Colors.orange[500])
                                  : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      trailing: isMemberCreator
                          ? Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
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
                          : hasLeft
                              ? isCurrentUserCreator
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.red[400],
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'REMOVED',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(Icons.person_add,
                                              color: Color(0xFF059669)),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            _showReAddMemberDialog(memberEmail);
                                          },
                                        ),
                                      ],
                                    )
                                  : Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[400],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'LEFT',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                              : isCurrentUserCreator
                                  ? IconButton(
                                      icon: Icon(Icons.person_remove,
                                          color: Color(0xFFDC2626)),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _showRemoveMemberDialog(memberEmail);
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
    setState(() {
      memberAddError = null;
    });

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Stack(
            children: [
              AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                backgroundColor: Colors.white,
                title: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF1E40AF), // Deep blue
                        Color(0xFF3B82F6), // Medium blue
                        Color(0xFF60A5FA), // Light blue
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [0.0, 0.5, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF1E40AF).withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.person_add,
                            color: Colors.white, size: 28),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Add New Member',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.2),
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
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
                      // Email input field with wavy blue design
                      Container(
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
                            color: Color(0xFF3B82F6).withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF3B82F6).withOpacity(0.1),
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
                              color: Color(0xFF1E40AF),
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
                                color: Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.email,
                                color: Color(0xFF1E40AF),
                                size: 20,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            hintText: 'Enter member\'s email address',
                            hintStyle: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                          ),
                          onChanged: (value) {
                            // Clear error when user starts typing
                            if (memberAddError != null) {
                              setDialogState(() {
                                memberAddError = null;
                              });
                            }
                          },
                          onSubmitted: (value) async {
                            // Allow submission on Enter key
                            if (value.trim().isNotEmpty && !loading) {
                              await _addMemberWithDialog(setDialogState);
                            }
                          },
                        ),
                      ),
                      SizedBox(height: 24),

                      // Add Member button with wavy blue design
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF1E40AF),
                              Color(0xFF3B82F6),
                              Color(0xFF60A5FA),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: [0.0, 0.5, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF1E40AF).withOpacity(0.3),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: loading
                              ? null
                              : () async {
                                  await _addMemberWithDialog(setDialogState);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: loading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.person_add,
                                          color: Colors.white, size: 20),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Add Member',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            offset: Offset(0, 1),
                                            blurRadius: 2,
                                          ),
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
                actions: [
                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            setState(() {
                              memberAddError = null;
                            });
                          },
                    style: TextButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Color(0xFF6B7280)),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              // Floating error message overlay
              if (memberAddError != null)
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child:
                      _buildFloatingErrorCard(memberAddError!, setDialogState),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteGroup() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await ApiClient.delete(
        '/api/group-transactions/${group!['_id']}',
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          group = null;
        });
        _fetchUserGroups();
        // Show stylish success dialog
        _showGroupDeletedSuccessDialog();
      } else {
        setState(() {
          error = data['error'] ?? 'Failed to delete group';
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _leaveGroup() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await ApiClient.post(
        '/api/group-transactions/${group!['_id']}/leave',
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          group = null;
        });
        _fetchUserGroups();
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully left the group!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          error = data['error'] ?? 'Failed to leave group';
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _sendLeaveRequest() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await ApiClient.post(
        '/api/group-transactions/${group!['_id']}/send-leave-request',
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ Leave request sent to group creator successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        setState(() {
          error = data['error'] ?? 'Failed to send leave request';
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _removeMember(String email) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await ApiClient.post(
        '/api/group-transactions/${group!['_id']}/remove-member',
        body: {'email': email},
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          group = data['group'];
        });
        // Show stylish success dialog
        _showMemberRemovedSuccessDialog(email);
      } else {
        setState(() {
          error = data['error'] ?? 'Failed to remove member';
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _reAddMember(String email) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await ApiClient.post(
        '/api/group-transactions/${group!['_id']}/add-member',
        body: {'email': email},
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          group = data['group'];
        });
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $email has been re-added to the group!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          error = data['error'] ?? 'Failed to re-add member';
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _settleAndRemoveMember(String email) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      // First, settle all expenses for this member (set their split amounts to 0)
      final res = await ApiClient.post(
        '/api/group-transactions/${group!['_id']}/settle-member-expenses',
        body: {'email': email},
      );

      if (res.statusCode != 200) {
        final data = json.decode(res.body);
        setState(() {
          error = data['error'] ?? 'Failed to settle member expenses';
        });
        return;
      }

      // Then remove the member
      final removeRes = await ApiClient.post(
        '/api/group-transactions/${group!['_id']}/remove-member',
        body: {'email': email},
      );

      final removeData = json.decode(removeRes.body);
      if (removeRes.statusCode == 200) {
        setState(() {
          group = removeData['group'];
        });
        // Show stylish success dialog
        _showMemberSettledAndRemovedSuccessDialog(email);
      } else {
        setState(() {
          error = removeData['error'] ?? 'Failed to remove member';
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await ApiClient.delete(
        '/api/group-transactions/${group!['_id']}/expenses/$expenseId',
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200) {
        setState(() {
          group = data['group'];
        });
        // Show stylish success dialog
        _showExpenseDeletedSuccessDialog();
      } else {
        setState(() {
          error = data['error'] ?? 'Failed to delete expense';
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _editExpense(
      String expenseId, Map<String, dynamic> expenseData) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      // Debug: Print the expense data being sent
      print('Sending edit expense request:');
      print('Expense ID: $expenseId');
      print('Expense Data: $expenseData');
      print(
          'Current user email: ${Provider.of<SessionProvider>(context, listen: false).user?['email']}');

      final res = await ApiClient.put(
        '/api/group-transactions/${group!['_id']}/expenses/$expenseId',
        body: expenseData,
      );
      final data = json.decode(res.body);

      // Debug: Print the response
      print('Response status: ${res.statusCode}');
      print('Response data: $data');

      if (res.statusCode == 200) {
        setState(() {
          group = data['group'];
        });
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Expense updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          error = data['error'] ?? 'Failed to update expense';
        });
        // Show debug info if available
        if (data['debug'] != null) {
          print('Debug info: ${data['debug']}');
        }
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _settleExpenseSplits(
      String expenseId, List<String> memberEmails) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await ApiClient.post(
        '/api/group-transactions/${group!['_id']}/expenses/$expenseId/settle',
        body: {'memberEmails': memberEmails},
      );
      final data = json.decode(res.body);

      if (res.statusCode == 200) {
        setState(() {
          group = data['group'];
        });
        // Show success message with details about already settled members
        String message = '✅ ${data['message']}';
        Color backgroundColor = Colors.green;
        int duration = 4;

        if (data['alreadySettledCount'] > 0) {
          backgroundColor = Colors.orange;
          duration = 5;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: Duration(seconds: duration),
          ),
        );
      } else {
        setState(() {
          error = data['error'] ?? 'Failed to settle expense splits';
        });
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Failed to settle expense splits'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        error = e.toString();
      });
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  void _showExpenseDeletedSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF34D399)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF10B981).withOpacity(0.3),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon with Animation
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 50,
                  color: Color(0xFF10B981),
                ),
              ),
              SizedBox(height: 24),
              // Success Title
              Text(
                'Success!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 12),
              // Success Message
              Text(
                'Expense deleted successfully',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'The expense has been removed from the group',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              // Continue Button
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemberRemovedSuccessDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF34D399)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF10B981).withOpacity(0.3),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon with Animation
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person_remove,
                  size: 50,
                  color: Color(0xFF10B981),
                ),
              ),
              SizedBox(height: 24),
              // Success Title
              Text(
                'Member Removed!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 12),
              // Success Message
              Text(
                '$email has been removed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'The member has been successfully removed from the group',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              // Continue Button
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGroupDeletedSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFDC2626).withOpacity(0.3),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon with Animation
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.delete_forever,
                  size: 50,
                  color: Color(0xFFDC2626),
                ),
              ),
              SizedBox(height: 24),
              // Success Title
              Text(
                'Group Deleted!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 12),
              // Success Message
              Text(
                'Group has been permanently deleted',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'All group data and expenses have been removed',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              // Continue Button
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFFDC2626),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPermissionDeniedDialog() {
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
              Icon(Icons.block, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Permission Denied',
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
              // Error icon
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: Color(0xFFDC2626).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.security,
                  size: 40,
                  color: Color(0xFFDC2626),
                ),
              ),
              SizedBox(height: 20),

              // Error message
              Text(
                'Only Group Creator Can Remove Members',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'You don\'t have permission to remove members from this group. Only the group creator can perform this action.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

              // Info box
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFFFFEAA7)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFF856404), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Contact the group creator if you need a member to be removed.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF856404),
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
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDC2626),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'OK',
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

  void _showAddMemberPermissionDeniedDialog() {
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
              Icon(Icons.block, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Permission Denied',
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
              // Error icon
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: Color(0xFFDC2626).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.security,
                  size: 40,
                  color: Color(0xFFDC2626),
                ),
              ),
              SizedBox(height: 20),

              // Error message
              Text(
                'Only Group Creator Can Add Members',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFDC2626),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'You don\'t have permission to add members to this group. Only the group creator can perform this action.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),

              // Info box
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFFFFEAA7)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFF856404), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Contact the group creator if you need a member to be added.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF856404),
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
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDC2626),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'OK',
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

  void _showMemberAddedSuccessDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF059669), // Green
                Color(0xFF10B981),
                Color(0xFF34D399),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF059669).withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.check_circle, color: Colors.white, size: 28),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Success!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.2),
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
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
              // Success icon with animation
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: Color(0xFF059669).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.person_add,
                  color: Color(0xFF059669),
                  size: 40,
                ),
              ),
              SizedBox(height: 16),

              // Success message
              Text(
                'Member Added Successfully!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF059669),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),

              // Member email
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFF059669).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  email,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Additional info
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF059669).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(0xFF059669).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF059669),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The member has been added to the group and can now participate in expenses.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w500,
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
          Container(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF059669),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding: EdgeInsets.symmetric(vertical: 12),
                elevation: 4,
                shadowColor: Color(0xFF059669).withOpacity(0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Great!',
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
    );
  }

  void _showReAddMemberDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF10B981)],
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
                'Re-add Member',
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
              // Member info
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFF059669).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFF059669),
                      child: Text(
                        email[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                          Text(
                            'Previously removed from this group',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Confirmation message
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFF059669).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF059669),
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This will re-add the member to the group with a fresh start (no previous expenses).',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
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
                    _reAddMember(email);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF059669),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    elevation: 4,
                    shadowColor: Color(0xFF059669).withOpacity(0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Re-add',
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

  void _showMemberSettledAndRemovedSuccessDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF34D399)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF10B981).withOpacity(0.3),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon with Animation
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 50,
                  color: Color(0xFF10B981),
                ),
              ),
              SizedBox(height: 24),
              // Success Title
              Text(
                'Member Marked Settled & Removed!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 12),
              // Success Message
              Text(
                '$email has been marked settled and removed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'All their expenses have been marked as settled and they have been removed from the group',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              // Continue Button
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                    Icon(Icons.info_outline,
                        color: Color(0xFFDC2626), size: 24),
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
                    Icon(Icons.error_outline,
                        color: Color(0xFFDC2626), size: 20),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
    // Check if user has pending balances
    final userBalance = _getCurrentUserBalance();
    final hasBalance = userBalance != 0;

    // Debug: Print detailed balance information
    print('=== LEAVE GROUP DEBUG ===');
    print('User Balance: $userBalance');
    print('Has Balance: $hasBalance');
    print(
        'Current User Email: ${Provider.of<SessionProvider>(context, listen: false).user?['email']}');
    print('=======================');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: hasBalance
                  ? [Color(0xFFDC2626), Color(0xFFEF4444)]
                  : [Color(0xFFF59E0B), Color(0xFFF97316)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(hasBalance ? Icons.warning_amber_rounded : Icons.exit_to_app,
                  color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                hasBalance ? 'Cannot Leave Group' : 'Leave Group',
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
              // User balance info
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: hasBalance
                      ? Color(0xFFDC2626).withOpacity(0.1)
                      : Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: hasBalance
                          ? Color(0xFFDC2626).withOpacity(0.3)
                          : Color(0xFFF59E0B).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                        hasBalance
                            ? Icons.account_balance_wallet
                            : Icons.info_outline,
                        color:
                            hasBalance ? Color(0xFFDC2626) : Color(0xFFF59E0B),
                        size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasBalance
                                ? 'You have pending expenses!'
                                : 'Leave Group Confirmation',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: hasBalance
                                  ? Color(0xFFDC2626)
                                  : Color(0xFFF59E0B),
                            ),
                          ),
                          if (hasBalance) ...[
                            SizedBox(height: 4),
                            Text(
                              'Total Split Amount: \$${userBalance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Balance warning if user has balance
              if (hasBalance) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Color(0xFFFFEAA7)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Color(0xFF856404), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cannot leave with pending expenses!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF856404),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'You need to settle your expenses before leaving. Send a request to the group creator.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF856404),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ] else ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_outlined,
                          color: Color(0xFFF59E0B), size: 20),
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
                SizedBox(height: 16),
              ],

              // Confirmation message
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: hasBalance
                      ? Color(0xFFFEF2F2)
                      : Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: hasBalance
                          ? Color(0xFFFECACA)
                          : Color(0xFFF59E0B).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasBalance ? Icons.email_outlined : Icons.info_outline,
                      color: hasBalance ? Color(0xFFDC2626) : Color(0xFFF59E0B),
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasBalance
                            ? 'Click "Send Request" to notify the group creator about your leave request.'
                            : 'Are you sure you want to leave this group? This action cannot be undone.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: hasBalance
                              ? Color(0xFFDC2626)
                              : Color(0xFFF59E0B),
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
              if (!hasBalance) ...[
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _leaveGroup();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF59E0B),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
              ] else ...[
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _sendLeaveRequest();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFDC2626),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      elevation: 4,
                      shadowColor: Color(0xFFDC2626).withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.email_outlined,
                            color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Send Request',
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
            ],
          ),
        ],
      ),
    );
  }

  void _showRemoveMemberDialog(String email) async {
    // First check if member has any balance
    final memberBalance = _getMemberBalance(email);
    final hasBalance = memberBalance != 0;

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
              // Member info
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF1E3A8A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFF1E3A8A),
                      child: Text(
                        email[0].toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          Text(
                            'Total Split Amount: \$${memberBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: memberBalance > 0
                                  ? Colors.orange[700]
                                  : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Balance warning if member has balance
              if (hasBalance) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Color(0xFFFFEAA7)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Color(0xFF856404), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Member has expenses!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF856404),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'You can mark all their expenses as settled and then remove them.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF856404),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Confirmation message
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: hasBalance
                      ? Color(0xFFFEF2F2)
                      : Color(0xFFDC2626).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: hasBalance
                          ? Color(0xFFFECACA)
                          : Color(0xFFDC2626).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasBalance ? Icons.error_outline : Icons.info_outline,
                      color: hasBalance ? Color(0xFFDC2626) : Color(0xFFDC2626),
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasBalance
                            ? 'Click "Settle & Remove" to mark all their split amounts as settled and remove them.'
                            : 'Are you sure you want to remove this member? This action cannot be undone.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: hasBalance
                              ? Color(0xFFDC2626)
                              : Color(0xFFDC2626),
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
              if (!hasBalance) ...[
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _removeMember(email);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFDC2626),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      elevation: 4,
                      shadowColor: Color(0xFFDC2626).withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_remove,
                            color: Colors.white, size: 20),
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
              ] else ...[
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _settleAndRemoveMember(email);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFDC2626),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      elevation: 4,
                      shadowColor: Color(0xFFDC2626).withOpacity(0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet,
                            color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Mark Settled & Remove',
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
            ],
          ),
        ],
      ),
    );
  }

  void _showExpensesDialog(List<dynamic> expenses) {
    // Get members from the current group
    final members = (group?['members'] ?? []) as List<dynamic>;

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
                    border:
                        Border.all(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Color(0xFF1E3A8A), size: 20),
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
                          Icon(Icons.receipt_long,
                              color: Colors.grey, size: 48),
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
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            if (expense['createdAt'] != null ||
                                expense['date'] != null)
                              Row(
                                children: [
                                  Icon(Icons.access_time,
                                      color: Colors.grey[500], size: 12),
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
                            if (expense['split'] != null &&
                                expense['split'].isNotEmpty)
                              Container(
                                margin: EdgeInsets.only(top: 8),
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF1E3A8A).withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          Color(0xFF1E3A8A).withOpacity(0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.people_outline,
                                            color: Color(0xFF1E3A8A), size: 16),
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
                                      constraints:
                                          BoxConstraints(maxHeight: 120),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: (expense['split'] as List)
                                              .map<Widget>((splitItem) {
                                            final member = members.firstWhere(
                                              (m) =>
                                                  m['_id'] == splitItem['user'],
                                              orElse: () =>
                                                  {'email': 'Unknown User'},
                                            );
                                            final isSettled =
                                                splitItem['settled'] == true;
                                            return Padding(
                                              padding:
                                                  EdgeInsets.only(bottom: 2),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    '• ${(member['email'] ?? '').toString()}: ',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  Text(
                                                    '\$${splitItem['amount'].toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isSettled
                                                          ? Colors.grey[500]
                                                          : Colors.green[700],
                                                      decoration: isSettled
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : null,
                                                    ),
                                                  ),
                                                  if (isSettled)
                                                    Text(
                                                      ' (Settled)',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey[500],
                                                        fontStyle:
                                                            FontStyle.italic,
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Edit button - only for expense creator
                            Builder(
                              builder: (context) {
                                final currentUserEmail =
                                    Provider.of<SessionProvider>(context,
                                            listen: false)
                                        .user?['email'];
                                final expenseAddedBy = expense['addedBy'];
                                final shouldShowEdit =
                                    expenseAddedBy == currentUserEmail;

                                // Debug: Print the comparison
                                print('Edit button check:');
                                print('Current user email: $currentUserEmail');
                                print('Expense addedBy: $expenseAddedBy');
                                print('Should show edit: $shouldShowEdit');

                                return shouldShowEdit
                                    ? IconButton(
                                        icon: Icon(Icons.edit,
                                            color: Color(0xFF1E3A8A)),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          _showEditExpenseDialog(expense);
                                        },
                                      )
                                    : SizedBox.shrink();
                              },
                            ),
                            // Settle button - only for group creator
                            if (isCreator)
                              IconButton(
                                icon: Icon(Icons.check_circle_outline,
                                    color: Colors.green),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showSettleExpenseDialog(expense);
                                },
                              ),
                            // Delete button - only for group creator
                            if (isCreator)
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _showDeleteExpenseDialog(
                                    expense['_id'],
                                    expense['description'] ?? 'Unknown',
                                  );
                                },
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
                backgroundColor: Color(0xFF1E3A8A),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (group == null)
                  Text(
                    'Group Transactions',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  )
                else
                  Text(
                    'Group: ${group?['title'] ?? ''}',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                if (group == null)
                  IconButton(
                    icon: Icon(
                      _showFavouritesOnly ? Icons.star : Icons.star_border,
                      color: _showFavouritesOnly ? Colors.amber : Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _showFavouritesOnly = !_showFavouritesOnly;
                      });
                      _filterAndSearchGroups();
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
                top:
                    180), // Add top padding to move content below the wavy header
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
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(18)),
                                    elevation: 4,
                                    child: Padding(
                                      padding: const EdgeInsets.all(32.0),
                                      child: Column(
                                        children: [
                                          Icon(Icons.group_off,
                                              color: Colors.grey, size: 60),
                                          SizedBox(height: 16),
                                          Text('No groups found.',
                                              style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold)),
                                          SizedBox(height: 8),
                                          Text(
                                              'Create your first group to get started!',
                                              style: TextStyle(fontSize: 16)),
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
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                    ),
                                  if (showCreateGroupForm) ...[
                                    _buildCreateGroupCard(),
                                    SizedBox(height: 12),
                                    TextButton(
                                      onPressed: _hideCreateGroup,
                                      child: Text('Cancel',
                                          style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Search bar at the top
                                Container(
                                  padding:
                                      const EdgeInsets.all(2), // border width
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.orange,
                                        Colors.white,
                                        Colors.green
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText:
                                          'Search by group name or creator email...',
                                      prefixIcon: Icon(Icons.search,
                                          color: Color(0xFF00B4D8)),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: EdgeInsets.symmetric(
                                          vertical: 0, horizontal: 16),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    onChanged: (val) {
                                      groupSearchQuery = val;
                                      _filterAndSearchGroups();
                                    },
                                  ),
                                ),
                                SizedBox(height: 16),

                                // Filters in a scrollable row below search bar
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Colors.orange,
                                              Colors.white,
                                              Colors.green
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: DropdownButton<String>(
                                            value: groupFilter,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            style: const TextStyle(
                                                color: Color(0xFF00B4D8),
                                                fontWeight: FontWeight.bold),
                                            underline: Container(),
                                            items: const [
                                              DropdownMenuItem(
                                                  value: 'all',
                                                  child: Text('All')),
                                              DropdownMenuItem(
                                                  value: 'created',
                                                  child: Text('Created by Me')),
                                              DropdownMenuItem(
                                                  value: 'member',
                                                  child: Text('Member')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  groupFilter = val;
                                                });
                                                _filterAndSearchGroups();
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Colors.orange,
                                              Colors.white,
                                              Colors.green
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: DropdownButton<String>(
                                            value: groupSort,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            style: const TextStyle(
                                                color: Color(0xFF00B4D8),
                                                fontWeight: FontWeight.bold),
                                            underline: Container(),
                                            items: const [
                                              DropdownMenuItem(
                                                  value: 'newest',
                                                  child: Text('Newest')),
                                              DropdownMenuItem(
                                                  value: 'oldest',
                                                  child: Text('Oldest')),
                                              DropdownMenuItem(
                                                  value: 'name_az',
                                                  child: Text('Name A-Z')),
                                              DropdownMenuItem(
                                                  value: 'name_za',
                                                  child: Text('Name Z-A')),
                                              DropdownMenuItem(
                                                  value: 'members_high',
                                                  child:
                                                      Text('Members High-Low')),
                                              DropdownMenuItem(
                                                  value: 'members_low',
                                                  child:
                                                      Text('Members Low-High')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  groupSort = val;
                                                });
                                                _filterAndSearchGroups();
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Colors.orange,
                                              Colors.white,
                                              Colors.green
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: DropdownButton<String>(
                                            value: memberCountFilter,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            style: const TextStyle(
                                                color: Color(0xFF00B4D8),
                                                fontWeight: FontWeight.bold),
                                            underline: Container(),
                                            items: const [
                                              DropdownMenuItem(
                                                  value: 'all',
                                                  child: Text('All Members')),
                                              DropdownMenuItem(
                                                  value: '2-5',
                                                  child: Text('2-5')),
                                              DropdownMenuItem(
                                                  value: '6-10',
                                                  child: Text('6-10')),
                                              DropdownMenuItem(
                                                  value: '10+',
                                                  child: Text('10+'))
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  memberCountFilter = val;
                                                });
                                                _filterAndSearchGroups();
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Colors.orange,
                                              Colors.white,
                                              Colors.green
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: DropdownButton<String>(
                                            value: dateFilter,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            style: const TextStyle(
                                                color: Color(0xFF00B4D8),
                                                fontWeight: FontWeight.bold),
                                            underline: Container(),
                                            items: const [
                                              DropdownMenuItem(
                                                  value: 'all',
                                                  child: Text('All Dates')),
                                              DropdownMenuItem(
                                                  value: '7days',
                                                  child: Text('Last 7 Days')),
                                              DropdownMenuItem(
                                                  value: '30days',
                                                  child: Text('Last 30 Days')),
                                              DropdownMenuItem(
                                                  value: 'custom',
                                                  child: Text('Custom'))
                                            ],
                                            onChanged: (val) async {
                                              if (val != null) {
                                                setState(() {
                                                  dateFilter = val;
                                                });
                                                if (val == 'custom') {
                                                  final picked =
                                                      await showDateRangePicker(
                                                    context: context,
                                                    firstDate: DateTime(2020),
                                                    lastDate: DateTime.now(),
                                                  );
                                                  if (picked != null) {
                                                    setState(() {
                                                      customStartDate =
                                                          picked.start;
                                                      customEndDate =
                                                          picked.end;
                                                    });
                                                  }
                                                }
                                                _filterAndSearchGroups();
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 16),
                                if (!showCreateGroupForm)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Consumer<SessionProvider>(
                                        builder: (context, session, child) {
                                          final bool canCreate = session
                                                  .isSubscribed ||
                                              (session.freeGroupsRemaining ??
                                                      0) >
                                                  0 ||
                                              (session.lenDenCoins ?? 0) >= 20;
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              if (!session.isSubscribed &&
                                                  (session.freeGroupsRemaining ??
                                                          0) >
                                                      0)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 8.0),
                                                  child: Text(
                                                    '${session.freeGroupsRemaining} free group creations remaining.',
                                                    style: TextStyle(
                                                        color: Colors.green),
                                                  ),
                                                ),
                                              ElevatedButton.icon(
                                                onPressed: canCreate
                                                    ? _showCreateGroup
                                                    : null,
                                                icon: Icon(Icons.add),
                                                label: Text('Create Group'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: canCreate
                                                      ? Color(0xFF00B4D8)
                                                      : Colors.grey,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12)),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                if (showCreateGroupForm) ...[
                                  _buildCreateGroupCard(),
                                  SizedBox(height: 12),
                                  TextButton(
                                    onPressed: _hideCreateGroup,
                                    child: Text('Cancel',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                                ...filteredGroups.map((g) {
                                  final groupColor = g['color'] != null
                                      ? Color(int.parse(g['color']
                                          .toString()
                                          .replaceFirst('#', '0xff')))
                                      : Colors.blue.shade300;
                                  final avatarText = () {
                                    final title = g['title'] ?? '';
                                    return title.isNotEmpty
                                        ? title[0].toUpperCase()
                                        : '?';
                                  }();
                                  return Card(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(18)),
                                    elevation: 6,
                                    margin: EdgeInsets.only(bottom: 18),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: groupColor,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 18, horizontal: 18),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // New row for Favourites and View Details buttons
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      IconButton(
                                                        icon: Icon(
                                                          (g['favourite'] as List? ??
                                                                      [])
                                                                  .contains(Provider.of<
                                                                              SessionProvider>(
                                                                          context,
                                                                          listen:
                                                                              false)
                                                                      .user?['email'])
                                                              ? Icons.star
                                                              : Icons.star_border,
                                                          color: (g['favourite']
                                                                          as List? ??
                                                                      [])
                                                                  .contains(Provider.of<
                                                                              SessionProvider>(
                                                                          context,
                                                                          listen:
                                                                              false)
                                                                      .user?['email'])
                                                              ? Colors.amber
                                                              : Colors.grey,
                                                        ),
                                                        onPressed: () =>
                                                            _toggleFavourite(
                                                                g['_id']),
                                                      ),
                                                      ElevatedButton(
                                                        onPressed: () =>
                                                            _showGroupDetails(
                                                                g),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Color(0xFF48CAE4),
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12)),
                                                          elevation: 0,
                                                        ),
                                                        child: Text(
                                                            'View Details',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white)),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 10),
                                                  // Existing row with avatar, title, and color indicator
                                                  Row(
                                                    children: [
                                                      CircleAvatar(
                                                        backgroundColor:
                                                            groupColor,
                                                        radius: 22,
                                                        child: Text(avatarText,
                                                            style: TextStyle(
                                                                fontSize: 22,
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                      ),
                                                      SizedBox(width: 14),
                                                      Expanded(
                                                        child: Text(
                                                          g['title'] ?? '',
                                                          style: TextStyle(
                                                              fontSize: 20,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Color(
                                                                  0xFF00B4D8)),
                                                        ),
                                                      ),
                                                      // Group color indicator
                                                      Container(
                                                        width: 18,
                                                        height: 18,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: groupColor,
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                              color:
                                                                  Colors.white,
                                                              width: 2),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 10),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.person,
                                                          size: 18,
                                                          color: Colors.grey),
                                                      SizedBox(width: 4),
                                                      Text(
                                                          'Creator: ${g['creator']?['email'] ?? ''}',
                                                          style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors
                                                                  .grey[700])),
                                                    ],
                                                  ),
                                                  SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.people,
                                                          size: 18,
                                                          color: Colors.grey),
                                                      SizedBox(width: 4),
                                                      Text(
                                                          'Members: ${(g['members'] as List).length}',
                                                          style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors
                                                                  .grey[700])),
                                                      SizedBox(width: 12),
                                                      // Member avatars
                                                      ...((g['members'] as List)
                                                          .take(5)
                                                          .map((m) =>
                                                              GestureDetector(
                                                                onTap: () =>
                                                                    _showMemberDetails(
                                                                        m),
                                                                child: Padding(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          2),
                                                                  child:
                                                                      CircleAvatar(
                                                                    radius: 12,
                                                                    backgroundColor: Colors
                                                                        .primaries[(m['email'] ?? '').toString().hashCode %
                                                                            Colors.primaries.length]
                                                                        .shade200,
                                                                    child: Text(
                                                                      () {
                                                                        final email =
                                                                            (m['email'] ?? '').toString();
                                                                        return email.isNotEmpty
                                                                            ? email[0].toUpperCase()
                                                                            : '?';
                                                                      }(),
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                          color: Colors
                                                                              .white,
                                                                          fontWeight:
                                                                              FontWeight.bold),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ))),
                                                      if ((g['members'] as List)
                                                              .length >
                                                          5)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      2),
                                                          child: CircleAvatar(
                                                            radius: 12,
                                                            backgroundColor:
                                                                Colors
                                                                    .grey[400],
                                                            child: Text(
                                                                '+${(g['members'] as List).length - 5}',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color: Colors
                                                                        .white)),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.calendar_today,
                                                          size: 16,
                                                          color: Colors.grey),
                                                      SizedBox(width: 4),
                                                      Text(
                                                          'Created: ${g['createdAt'] != null ? g['createdAt'].toString().substring(0, 10) : ''}',
                                                          style: TextStyle(
                                                              fontSize: 13,
                                                              color: Colors
                                                                  .grey[600])),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ]),
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
                icon: Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/user/dashboard'),
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
                Text('Create Group',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                Text('Group Color:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
                Text(selectedGroupColor != null
                    ? '#${selectedGroupColor!.value.toRadixString(16).substring(2).toUpperCase()}'
                    : 'Default'),
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
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 20),
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
                    decoration: InputDecoration(
                        hintText: 'Enter email', border: OutlineInputBorder()),
                    onSubmitted: (_) => _addMemberEmail(),
                  ),
                ),
                SizedBox(width: 8),
                TextButton(
                  onPressed: _addMemberEmail,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  child: Text('Add',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (memberAddError != null) ...[
              SizedBox(height: 6),
              Text(memberAddError!, style: TextStyle(color: Colors.red)),
            ],
            Wrap(
              spacing: 8,
              children: memberEmails
                  .map((e) => Chip(
                      label: Text(e), onDeleted: () => _removeMemberEmail(e)))
                  .toList(),
            ),
            SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: Consumer<SessionProvider>(
                builder: (context, session, child) {
                  final bool canCreate = session.isSubscribed ||
                      (session.freeGroupsRemaining ?? 0) > 0 ||
                      (session.lenDenCoins ?? 0) >= 20;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!session.isSubscribed &&
                          (session.freeGroupsRemaining ?? 0) > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            '${session.freeGroupsRemaining} free group creations remaining.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.green),
                          ),
                        ),
                      ElevatedButton(
                        onPressed:
                            creatingGroup || !canCreate ? null : _createGroup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF00B4D8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: creatingGroup
                            ? CircularProgressIndicator()
                            : Text('Create Group',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.white)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupDetailsCard() {
    final members = (group?['members'] ?? []) as List<dynamic>;
    final creator = group?['creator'];
    final expenses = (group?['expenses'] ?? []) as List<dynamic>;
    final groupColor = group?['color'] != null
        ? Color(int.parse(group!['color'].toString().replaceFirst('#', '0xff')))
        : Colors.blue.shade300;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: groupColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
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
                        style: TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text('Group Details',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
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
                  if (isCreator) SizedBox(width: 8),
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
                        child:
                            Icon(Icons.delete, color: Colors.white, size: 18),
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
                      label: Text('View Members (${members.length})',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  if (isCreator)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddMemberDialog(),
                        icon: Icon(Icons.person_add, color: Colors.white),
                        label: Text('Add Member',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Text('Expenses:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _showExpensesDialog(expenses),
                    icon:
                        Icon(Icons.receipt_long, color: Colors.white, size: 18),
                    label: Text('View All (${expenses.length})',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1E3A8A),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
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
                ...expenses.take(3).map<Widget>((expense) {
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
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          if (expense['createdAt'] != null ||
                              expense['date'] != null)
                            Row(
                              children: [
                                Icon(Icons.access_time,
                                    color: Colors.grey[500], size: 12),
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
                          if (expense['split'] != null &&
                              expense['split'].isNotEmpty)
                            Container(
                              margin: EdgeInsets.only(top: 8),
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFF1E3A8A).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Color(0xFF1E3A8A).withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.people_outline,
                                          color: Color(0xFF1E3A8A), size: 16),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: (expense['split'] as List)
                                            .map<Widget>((splitItem) {
                                          final member = members.firstWhere(
                                            (m) =>
                                                m['_id'] == splitItem['user'],
                                            orElse: () =>
                                                {'email': 'Unknown User'},
                                          );
                                          final isSettled =
                                              splitItem['settled'] == true;
                                          return Padding(
                                            padding: EdgeInsets.only(bottom: 2),
                                            child: Row(
                                              children: [
                                                Text(
                                                  '• ${(member['email'] ?? '').toString()}: ',
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
                                                    color: isSettled
                                                        ? Colors.grey[500]
                                                        : Colors.green[700],
                                                    decoration: isSettled
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : null,
                                                  ),
                                                ),
                                                if (isSettled)
                                                  Text(
                                                    ' (Settled)',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey[500],
                                                      fontStyle:
                                                          FontStyle.italic,
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
                      trailing: null,
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
                onPressed: addingExpense
                    ? null
                    : () {
                        _showAddExpenseDialog();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00B4D8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Add Expense',
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
              SizedBox(height: 24),
              if (!isCreator) ...[
                // Check if current user is still an active member
                Builder(
                  builder: (context) {
                    final currentUserEmail =
                        Provider.of<SessionProvider>(context, listen: false)
                            .user?['email'];
                    final isActiveMember = (group?['members'] ?? []).any(
                        (member) =>
                            member['email'] == currentUserEmail &&
                            member['leftAt'] == null);

                    if (isActiveMember) {
                      // User is still an active member - show Leave Group button
                      return ElevatedButton(
                        onPressed: loading ? null : _showLeaveGroupDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFF59E0B),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          elevation: 4,
                          shadowColor: Color(0xFFF59E0B).withOpacity(0.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.exit_to_app,
                                color: Colors.white, size: 20),
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
                      );
                    } else {
                      // User is no longer an active member - show disabled button
                      return ElevatedButton(
                        onPressed: null, // Disabled
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[400],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'No longer a member of this group',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!, style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditExpenseDialog(Map<String, dynamic> expense) {
    final TextEditingController editDescController =
        TextEditingController(text: expense['description'] ?? '');
    final TextEditingController editAmountController =
        TextEditingController(text: (expense['amount'] ?? 0).toString());
    String editSplitType = 'equal';

    // Filter out members who have left the group from selected members
    List<String> editSelectedMembers =
        List<String>.from(expense['selectedMembers'] ?? []);
    final activeMembers = (group?['members'] ?? [])
        .where((member) => member['leftAt'] == null)
        .map((m) => m['email'])
        .toList();
    editSelectedMembers = editSelectedMembers
        .where((email) => activeMembers.contains(email))
        .toList();

    Map<String, double> editCustomSplitAmounts = {};
    String? validationError;

    // Initialize custom split amounts from existing split data
    if (expense['split'] != null) {
      for (var splitItem in expense['split']) {
        final member = (group?['members'] ?? []).firstWhere(
          (m) => m['_id'] == splitItem['user'],
          orElse: () => null,
        );
        if (member != null) {
          editCustomSplitAmounts[member['email']] =
              (splitItem['amount'] ?? 0).toDouble();
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
            height: 600,
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
                      color: Color(0xFF1E3A8A),
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
                        borderSide:
                            BorderSide(color: Color(0xFF1E3A8A), width: 2),
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
                      color: Color(0xFF1E3A8A),
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
                        borderSide:
                            BorderSide(color: Color(0xFF1E3A8A), width: 2),
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
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    constraints: BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Column(
                        children: (group?['members'] ?? [])
                            .where((member) => member['leftAt'] == null)
                            .map<Widget>((member) {
                          final memberEmail = member['email'] ?? '';
                          final isSelected =
                              editSelectedMembers.contains(memberEmail);

                          return CheckboxListTile(
                            title: Text(memberEmail),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  editSelectedMembers.add(memberEmail);
                                  // Initialize custom split amount for new member
                                  if (editSplitType == 'custom') {
                                    final amount = double.tryParse(
                                            editAmountController.text) ??
                                        0;
                                    editCustomSplitAmounts[memberEmail] =
                                        amount /
                                            (editSelectedMembers.length + 1);
                                  }
                                } else {
                                  editSelectedMembers.remove(memberEmail);
                                  editCustomSplitAmounts.remove(memberEmail);
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
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: editSplitType,
                    items: [
                      DropdownMenuItem(
                          value: 'equal', child: Text('Equal Split')),
                      DropdownMenuItem(
                          value: 'custom', child: Text('Custom Split'))
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        editSplitType = value!;
                        // Recalculate custom split amounts when switching to custom
                        if (value == 'custom' &&
                            editSelectedMembers.isNotEmpty) {
                          final amount =
                              double.tryParse(editAmountController.text) ?? 0;
                          final splitAmount =
                              amount / editSelectedMembers.length;
                          for (var memberEmail in editSelectedMembers) {
                            editCustomSplitAmounts[memberEmail] = splitAmount;
                          }
                        }
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Split Type',
                      labelStyle: TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Icon(Icons.share, color: Color(0xFF1E3A8A)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: Color(0xFF1E3A8A).withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: Color(0xFF1E3A8A).withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: Color(0xFF1E3A8A), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),

                  // Custom Split Amounts (only show for custom split)
                  if (editSplitType == 'custom' &&
                      editSelectedMembers.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      'Custom Split Amounts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    SizedBox(height: 8),

                    // Total Split and Remaining Amount Display
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Color(0xFF1E3A8A).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Split:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          Text(
                            '\$${editSelectedMembers.fold<double>(0, (sum, email) => sum + (editCustomSplitAmounts[email] ?? 0)).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: editSelectedMembers.fold<double>(
                                          0,
                                          (sum, email) =>
                                              sum +
                                              (editCustomSplitAmounts[email] ??
                                                  0)) >
                                      0
                                  ? Colors.green[700]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Color(0xFF1E3A8A).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Remaining:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          Text(
                            '\$${((double.tryParse(editAmountController.text) ?? 0) - editSelectedMembers.fold<double>(0, (sum, email) => sum + (editCustomSplitAmounts[email] ?? 0))).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: ((double.tryParse(
                                                  editAmountController.text) ??
                                              0) -
                                          editSelectedMembers.fold<double>(
                                              0,
                                              (sum, email) =>
                                                  sum +
                                                  (editCustomSplitAmounts[email] ??
                                                      0))) >
                                      0
                                  ? Colors.orange[700]
                                  : ((double.tryParse(editAmountController.text) ??
                                                  0) -
                                              editSelectedMembers.fold<double>(
                                                  0,
                                                  (sum, email) =>
                                                      sum +
                                                      (editCustomSplitAmounts[
                                                              email] ??
                                                          0))) <
                                          0
                                      ? Colors.red[700]
                                      : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),

                    // Validation error display
                    if (validationError != null) ...[
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                validationError!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                    ],
                    ...editSelectedMembers
                        .map<Widget>((memberEmail) => Container(
                              margin: EdgeInsets.only(bottom: 12),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Color(0xFF1E3A8A).withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Color(0xFF1E3A8A),
                                    child: Text(
                                      memberEmail[0].toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          memberEmail,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF1E3A8A),
                                          ),
                                        ),
                                        Text(
                                          'Amount: \$${(editCustomSplitAmounts[memberEmail] ?? 0.0).toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: 'Amount',
                                        prefixText: '\$',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                      ),
                                      controller: TextEditingController(
                                        text:
                                            editCustomSplitAmounts[memberEmail]
                                                    ?.toStringAsFixed(2) ??
                                                '0.00',
                                      ),
                                      onChanged: (value) {
                                        final amount =
                                            double.tryParse(value) ?? 0;
                                        editCustomSplitAmounts[memberEmail] =
                                            amount;
                                        // Update dialog state to refresh the display
                                        setDialogState(() {
                                          // Clear validation error when user starts typing
                                          if (validationError != null &&
                                              validationError!.contains(
                                                  'Custom split amounts')) {
                                            validationError = null;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ],
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                        setDialogState(() {
                          validationError = null; // Clear previous errors
                        });

                        if (editDescController.text.trim().isEmpty) {
                          setDialogState(() {
                            validationError = 'Please enter a description';
                          });
                          return;
                        }

                        final amount =
                            double.tryParse(editAmountController.text);
                        if (amount == null || amount <= 0) {
                          setDialogState(() {
                            validationError = 'Please enter a valid amount';
                          });
                          return;
                        }

                        if (editSelectedMembers.isEmpty) {
                          setDialogState(() {
                            validationError =
                                'Please select at least one member';
                          });
                          return;
                        }

                        // Validate custom split amounts
                        if (editSplitType == 'custom') {
                          double totalCustomAmount = 0;
                          for (var memberEmail in editSelectedMembers) {
                            totalCustomAmount +=
                                editCustomSplitAmounts[memberEmail] ?? 0;
                          }

                          if ((totalCustomAmount - amount).abs() > 0.01) {
                            setDialogState(() {
                              validationError =
                                  'Custom split amounts must equal the total amount (\$${amount.toStringAsFixed(2)}). Current total: \$${totalCustomAmount.toStringAsFixed(2)}';
                            });
                            return;
                          }
                        }

                        Navigator.of(context).pop();

                        final expenseData = {
                          'description': editDescController.text.trim(),
                          'amount': amount,
                          'selectedMembers': editSelectedMembers,
                          'splitType': editSplitType,
                          'customSplitAmounts': editSplitType == 'custom'
                              ? editCustomSplitAmounts
                              : null,
                        };

                        await _editExpense(expense['_id'], expenseData);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1E3A8A),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                    Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626), size: 24),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  void _showSettleExpenseDialog(Map<String, dynamic> expense) {
    final members = group?['members'] ?? [];
    final expenseSplit = expense['split'] ?? [];

    // Get member emails that are in this expense and not already settled
    List<String> availableMembers = [];
    List<String> settledMembers = [];
    for (var splitItem in expenseSplit) {
      final member = members.firstWhere(
        (m) => m['_id'] == splitItem['user'],
        orElse: () => {'email': 'Unknown User'},
      );
      if (member['email'] != 'Unknown User') {
        if (splitItem['settled'] == true) {
          settledMembers.add(member['email']);
        } else {
          availableMembers.add(member['email']);
        }
      }
    }

    if (availableMembers.isEmpty) {
      String message = 'All splits in this expense are already settled!';
      if (settledMembers.isNotEmpty) {
        message += ' Settled members: ${settledMembers.join(', ')}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    Set<String> selectedMembers = {};
    bool selectAll = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          title: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00B4D8), Color(0xFF0096CC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'Settle Expense',
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
                      color: Color(0xFF00B4D8).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Color(0xFF00B4D8).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Color(0xFF00B4D8), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Select members to settle their split amounts:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF00B4D8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  if (settledMembers.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Already settled: ${settledMembers.join(', ')}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Color(0xFF00B4D8).withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expense: ${expense['description'] ?? 'Unknown'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00B4D8),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Amount: \$${(expense['amount'] ?? 0).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  // Select All / Clear All buttons
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            if (selectAll) {
                              selectedMembers.clear();
                              selectAll = false;
                            } else {
                              selectedMembers.addAll(availableMembers);
                              selectAll = true;
                            }
                          });
                        },
                        child: Text(
                          selectAll ? 'Clear All' : 'Select All',
                          style: TextStyle(
                            color: Color(0xFF00B4D8),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Member checkboxes
                  Container(
                    constraints: BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: availableMembers.length,
                      itemBuilder: (context, index) {
                        final memberEmail = availableMembers[index];
                        final splitItem = expenseSplit.firstWhere(
                          (split) {
                            final member = members.firstWhere(
                              (m) => m['_id'] == split['user'],
                              orElse: () => {'email': 'Unknown User'},
                            );
                            return member['email'] == memberEmail;
                          },
                          orElse: () => null,
                        );

                        return CheckboxListTile(
                          title: Text(
                            memberEmail,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            'Amount: \$${(splitItem?['amount'] ?? 0).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          value: selectedMembers.contains(memberEmail),
                          onChanged: (bool? value) {
                            setDialogState(() {
                              if (value == true) {
                                selectedMembers.add(memberEmail);
                              } else {
                                selectedMembers.remove(memberEmail);
                              }
                              selectAll = selectedMembers.length ==
                                  availableMembers.length;
                            });
                          },
                          activeColor: Color(0xFF00B4D8),
                          contentPadding: EdgeInsets.symmetric(horizontal: 0),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: selectedMembers.isEmpty
                  ? null
                  : () async {
                      Navigator.of(context).pop();
                      await _settleExpenseSplits(
                          expense['_id'], selectedMembers.toList());
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00B4D8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Settle Selected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseDialog() {
    // Initialize selected members with all active members
    _initializeSelectedMembers();

    // Local error state for the dialog
    String? dialogError;
    bool dialogAddingExpense = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                      border:
                          Border.all(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Color(0xFF1E3A8A), size: 20),
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
                      border:
                          Border.all(color: Color(0xFF1E3A8A).withOpacity(0.2)),
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
                        prefixIcon:
                            Icon(Icons.description, color: Color(0xFF1E3A8A)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: Color(0xFF1E3A8A).withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: Color(0xFF1E3A8A).withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: Color(0xFF1E3A8A), width: 2),
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
                      border:
                          Border.all(color: Color(0xFF1E3A8A).withOpacity(0.2)),
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
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount (\$)',
                        labelStyle: TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon:
                            Icon(Icons.attach_money, color: Color(0xFF1E3A8A)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: Color(0xFF1E3A8A).withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: Color(0xFF1E3A8A).withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: Color(0xFF1E3A8A), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Member Selection Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Color(0xFF1E3A8A).withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () => _showMemberSelectionDialog(),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        child: Row(
                          children: [
                            Icon(Icons.people, color: Color(0xFF1E3A8A)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Choose Members',
                                    style: TextStyle(
                                      color: Color(0xFF1E3A8A),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    selectedMembers.isEmpty
                                        ? 'Select members to include in this expense'
                                        : "${selectedMembers.length} member${selectedMembers.length == 1 ? '' : 's'} selected",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_drop_down,
                                color: Color(0xFF1E3A8A)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Color(0xFF1E3A8A).withOpacity(0.2)),
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
                              Icon(Icons.person_outline,
                                  color: Color(0xFF1E3A8A)),
                              SizedBox(width: 8),
                              Text('Custom Split'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setDialogState(() {
                          splitType = v ?? 'equal';
                          if (splitType == 'custom') {
                            _initializeCustomSplitAmounts();
                          }
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Split Type',
                        labelStyle: TextStyle(
                          color: Color(0xFF1E3A8A),
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: Icon(Icons.share, color: Color(0xFF1E3A8A)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: Color(0xFF1E3A8A).withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: Color(0xFF1E3A8A).withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: Color(0xFF1E3A8A), width: 2),
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
                        border: Border.all(
                            color: Color(0xFF1E3A8A).withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Color(0xFF1E3A8A), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Custom Split',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Enter amount for each selected member',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          SizedBox(height: 12),
                          // Amount summary
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Color(0xFF1E3A8A).withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Split:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                                Text(
                                  '\$${_totalCustomSplitAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _totalCustomSplitAmount > 0
                                        ? Colors.green[700]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Color(0xFF1E3A8A).withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Remaining:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                ),
                                Text(
                                  '\$${_remainingCustomSplitAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _remainingCustomSplitAmount > 0
                                        ? Colors.orange[700]
                                        : _remainingCustomSplitAmount < 0
                                            ? Colors.red[700]
                                            : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          // Member amount inputs
                          ...selectedMembers
                              .map((memberEmail) => Container(
                                    margin: EdgeInsets.only(bottom: 12),
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Color(0xFF1E3A8A)
                                              .withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Color(0xFF1E3A8A),
                                          child: Text(
                                            memberEmail[0].toUpperCase(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                memberEmail,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF1E3A8A),
                                                ),
                                              ),
                                              Text(
                                                'Amount: \$${(customSplitAmounts[memberEmail] ?? 0.0).toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Container(
                                          width: 100,
                                          child: TextField(
                                            keyboardType:
                                                TextInputType.numberWithOptions(
                                                    decimal: true),
                                            decoration: InputDecoration(
                                              hintText: '0.00',
                                              prefixText: '\$',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                    color: Color(0xFF1E3A8A)
                                                        .withOpacity(0.3)),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                    color: Color(0xFF1E3A8A)
                                                        .withOpacity(0.3)),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                    color: Color(0xFF1E3A8A),
                                                    width: 2),
                                              ),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 8),
                                            ),
                                            style: TextStyle(fontSize: 14),
                                            onChanged: (value) {
                                              setDialogState(() {
                                                final amount =
                                                    double.tryParse(value) ??
                                                        0.0;
                                                customSplitAmounts[
                                                    memberEmail] = amount;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ],
                      ),
                    ),
                  if (dialogError != null)
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
                          Icon(Icons.error_outline,
                              color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dialogError!,
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                      onPressed: dialogAddingExpense
                          ? null
                          : () async {
                              // Clear previous error
                              setDialogState(() {
                                dialogError = null;
                              });

                              // Validate that at least one member is selected
                              if (selectedMembers.isEmpty) {
                                setDialogState(() {
                                  dialogError =
                                      'Please select at least one member for this expense';
                                });
                                return;
                              }

                              // Validate custom split amounts if split type is custom
                              if (splitType == 'custom') {
                                final totalExpenseAmount = double.tryParse(
                                        _expenseAmountController.text.trim()) ??
                                    0.0;
                                final totalSplitAmount =
                                    _totalCustomSplitAmount;

                                if (totalSplitAmount != totalExpenseAmount) {
                                  setDialogState(() {
                                    dialogError =
                                        'Total split amount (\$${totalSplitAmount.toStringAsFixed(2)}) must equal expense amount (\$${totalExpenseAmount.toStringAsFixed(2)})';
                                  });
                                  return;
                                }
                              }

                              setDialogState(() {
                                dialogAddingExpense = true;
                              });
                              try {
                                await _addExpense();
                                setDialogState(() {
                                  dialogAddingExpense = false;
                                });
                                Navigator.of(context).pop();
                              } catch (e) {
                                setDialogState(() {
                                  dialogAddingExpense = false;
                                  dialogError = e.toString();
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1E3A8A),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: dialogAddingExpense
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
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
      ),
    );
  }

  // Member Selection Dialog
  void _showMemberSelectionDialog() {
    if (group == null) return;

    final members = (group!['members'] ?? []) as List<dynamic>;
    final activeMembers =
        members.where((member) => member['leftAt'] == null).toList();

    // Sort members alphabetically by email
    activeMembers.sort((a, b) =>
        (a['email'] ?? '').toString().compareTo((b['email'] ?? '').toString()));

    // Create a temporary list for the dialog
    List<String> tempSelectedMembers = List.from(selectedMembers);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                  'Select Members',
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF1E3A8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Color(0xFF1E3A8A).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Color(0xFF1E3A8A), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Select members who should be included in this expense split',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                // Select All / Clear All buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            tempSelectedMembers.clear();
                            tempSelectedMembers.addAll(activeMembers
                                .map((member) => member['email'].toString()));
                          });
                        },
                        icon: Icon(Icons.select_all, size: 18),
                        label: Text('Select All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            tempSelectedMembers.clear();
                          });
                        },
                        icon: Icon(Icons.clear_all, size: 18),
                        label: Text('Clear All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Container(
                  height: 300,
                  child: ListView.builder(
                    itemCount: activeMembers.length,
                    itemBuilder: (context, index) {
                      final member = activeMembers[index];
                      final email = member['email']
                          .toString(); // Convert to string safely
                      final isSelected = tempSelectedMembers.contains(email);

                      return Container(
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(0xFF1E3A8A).withOpacity(0.1)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Color(0xFF1E3A8A)
                                : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (bool? value) {
                            setDialogState(() {
                              if (value == true) {
                                if (!tempSelectedMembers.contains(email)) {
                                  tempSelectedMembers.add(email);
                                }
                              } else {
                                tempSelectedMembers.remove(email);
                              }
                            });
                          },
                          title: Text(
                            email,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Color(0xFF1E3A8A)
                                  : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            isSelected ? 'Included in expense' : 'Not included',
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? Color(0xFF1E3A8A)
                                  : Colors.grey[600],
                            ),
                          ),
                          activeColor: Color(0xFF1E3A8A),
                          checkColor: Colors.white,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      );
                    },
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
                      onPressed: () {
                        // Reset selected members when canceling
                        selectedMembers.clear();
                        setState(() {});
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(left: 8, right: 16),
                    child: ElevatedButton(
                      onPressed: () {
                        // Update the main widget state to reflect the changes
                        setState(() {
                          selectedMembers.clear();
                          selectedMembers.addAll(tempSelectedMembers);
                          // Initialize custom split amounts if split type is custom
                          if (splitType == 'custom') {
                            _initializeCustomSplitAmounts();
                          }
                        });
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1E3A8A),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Done',
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

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
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
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height * 0.8,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.6,
      size.width,
      size.height * 0.8,
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
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.6,
        size.width * 0.5, size.height * 0.4);
    path.quadraticBezierTo(size.width * 0.75, 0, size.width, size.height * 0.4);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class SettleWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height * 0.7,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.4,
      size.width,
      size.height * 0.7,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
