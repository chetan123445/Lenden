import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../user/session.dart';
import '../../api_config.dart';
import 'user_edit_page.dart';

class UserDetailsPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserDetailsPage({super.key, required this.user});

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  Map<String, dynamic>? _userStats;
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _userActivity = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse(
            'ApiConfig.baseUrl/api/admin/users/${widget.user['_id']}/details'),
        headers: {
          'Authorization': 'Bearer ${session.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userStats = data['stats'];
          _recentTransactions =
              List<Map<String, dynamic>>.from(data['recentTransactions'] ?? []);
          _userActivity =
              List<Map<String, dynamic>>.from(data['userActivity'] ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading user details: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleUserStatus() async {
    final currentStatus = widget.user['isActive'] ?? false;

    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final response = await http.patch(
        Uri.parse(
            'ApiConfig.baseUrl/api/admin/users/${widget.user['_id']}/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.token}',
        },
        body: json.encode({
          'isActive': !currentStatus,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          widget.user['isActive'] = !currentStatus;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'User ${!currentStatus ? 'activated' : 'deactivated'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isActive = user['isActive'] ?? false;
    final isVerified = user['isVerified'] ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FA),
      appBar: AppBar(
        title: Text(
          user['name'] ?? 'User Details',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserEditPage(user: user),
                ),
              ).then((_) => _loadUserDetails());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // User Profile Header
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Profile Image and Basic Info
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: const Color(0xFF00B4D8),
                            child: _buildProfileImage(user),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['name'] ?? 'Unknown User',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user['email'] ?? 'No email',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '@${user['username'] ?? 'unknown'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF00B4D8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Status Indicators
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isActive ? Colors.green : Colors.red,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isActive ? Icons.check_circle : Icons.block,
                                    color: isActive ? Colors.green : Colors.red,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isActive ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: isVerified
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      isVerified ? Colors.blue : Colors.orange,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isVerified ? Icons.verified : Icons.pending,
                                    color: isVerified
                                        ? Colors.blue
                                        : Colors.orange,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isVerified ? 'Verified' : 'Pending',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isVerified
                                          ? Colors.blue
                                          : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _toggleUserStatus,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isActive ? Colors.red : Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                isActive ? 'Deactivate' : 'Activate',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        UserEditPage(user: user),
                                  ),
                                ).then((_) => _loadUserDetails());
                              },
                              style: OutlinedButton.styleFrom(
                                side:
                                    const BorderSide(color: Color(0xFF00B4D8)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Edit User',
                                style: TextStyle(color: Color(0xFF00B4D8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF00B4D8),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFF00B4D8),
                    tabs: const [
                      Tab(text: 'Profile'),
                      Tab(text: 'Stats'),
                      Tab(text: 'Transactions'),
                      Tab(text: 'Activity'),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProfileTab(),
                      _buildStatsTab(),
                      _buildTransactionsTab(),
                      _buildActivityTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProfileTab() {
    final user = widget.user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoSection('Personal Information', [
            _buildInfoTile('Full Name', user['name'] ?? 'Not provided'),
            _buildInfoTile('Username', '@${user['username'] ?? 'unknown'}'),
            _buildInfoTile('Email', user['email'] ?? 'Not provided'),
            _buildInfoTile('Phone', user['phone'] ?? 'Not provided'),
            _buildInfoTile('Gender', user['gender'] ?? 'Not specified'),
            _buildInfoTile(
                'Date of Birth', user['dateOfBirth'] ?? 'Not provided'),
            _buildInfoTile('Address', user['address'] ?? 'Not provided'),
          ]),
          const SizedBox(height: 16),
          _buildInfoSection('Account Information', [
            _buildInfoTile('User ID', user['_id'] ?? 'Unknown'),
            _buildInfoTile('Account Type', user['role'] ?? 'User'),
            _buildInfoTile('Joined Date', _formatDate(user['createdAt'])),
            _buildInfoTile('Last Login', _formatDate(user['lastLogin'])),
            _buildInfoTile('Alternative Email', user['altEmail'] ?? 'Not set'),
          ]),
          const SizedBox(height: 16),
          _buildInfoSection('Account Status', [
            _buildInfoTile('Account Status',
                widget.user['isActive'] == true ? 'Active' : 'Inactive'),
            _buildInfoTile('Email Verified',
                widget.user['isVerified'] == true ? 'Yes' : 'No'),
            _buildInfoTile('Phone Verified',
                widget.user['phoneVerified'] == true ? 'Yes' : 'No'),
            _buildInfoTile(
                'Two-Factor Auth',
                widget.user['twoFactorEnabled'] == true
                    ? 'Enabled'
                    : 'Disabled'),
          ]),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    if (_userStats == null) {
      return const Center(
        child: Text('No statistics available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                  child: _buildStatCard(
                      'Total Transactions',
                      _userStats!['totalTransactions']?.toString() ?? '0',
                      Icons.receipt)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard(
                      'Total Amount',
                      '\$${_userStats!['totalAmount']?.toString() ?? '0'}',
                      Icons.attach_money)),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                  child: _buildStatCard(
                      'Groups',
                      _userStats!['totalGroups']?.toString() ?? '0',
                      Icons.group)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard(
                      'Friends',
                      _userStats!['totalFriends']?.toString() ?? '0',
                      Icons.people)),
            ],
          ),

          const SizedBox(height: 16),

          // Detailed Stats
          _buildInfoSection('Transaction Statistics', [
            _buildInfoTile('Successful Transactions',
                _userStats!['successfulTransactions']?.toString() ?? '0'),
            _buildInfoTile('Failed Transactions',
                _userStats!['failedTransactions']?.toString() ?? '0'),
            _buildInfoTile('Average Transaction',
                '\$${_userStats!['averageTransaction']?.toString() ?? '0'}'),
            _buildInfoTile('Largest Transaction',
                '\$${_userStats!['largestTransaction']?.toString() ?? '0'}'),
          ]),

          const SizedBox(height: 16),

          _buildInfoSection('Activity Statistics', [
            _buildInfoTile(
                'Days Active', _userStats!['daysActive']?.toString() ?? '0'),
            _buildInfoTile(
                'Last Activity', _formatDate(_userStats!['lastActivity'])),
            _buildInfoTile(
                'Login Count', _userStats!['loginCount']?.toString() ?? '0'),
            _buildInfoTile('Profile Views',
                _userStats!['profileViews']?.toString() ?? '0'),
          ]),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return _recentTransactions.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No transactions found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _recentTransactions.length,
            itemBuilder: (context, index) {
              final transaction = _recentTransactions[index];
              return _buildTransactionCard(transaction);
            },
          );
  }

  Widget _buildActivityTab() {
    return _userActivity.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No activity found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _userActivity.length,
            itemBuilder: (context, index) {
              final activity = _userActivity[index];
              return _buildActivityCard(activity);
            },
          );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00B4D8),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF00B4D8), size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final amount = transaction['amount']?.toString() ?? '0';
    final type = transaction['type'] ?? 'unknown';
    final status = transaction['status'] ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00B4D8).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              type == 'send' ? Icons.send : Icons.call_received,
              color: const Color(0xFF00B4D8),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${type.toUpperCase()} Transaction',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(transaction['createdAt']),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$$amount',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'completed'
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: status == 'completed' ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final action = activity['action'] ?? 'unknown';
    final timestamp = activity['timestamp'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00B4D8).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getActivityIcon(action),
              color: const Color(0xFF00B4D8),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getActivityTitle(action),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String action) {
    switch (action.toLowerCase()) {
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'transaction':
        return Icons.receipt;
      case 'profile_update':
        return Icons.edit;
      case 'password_change':
        return Icons.lock;
      default:
        return Icons.info;
    }
  }

  String _getActivityTitle(String action) {
    switch (action.toLowerCase()) {
      case 'login':
        return 'User logged in';
      case 'logout':
        return 'User logged out';
      case 'transaction':
        return 'Transaction completed';
      case 'profile_update':
        return 'Profile updated';
      case 'password_change':
        return 'Password changed';
      default:
        return 'Activity recorded';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Not available';

    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildProfileImage(Map<String, dynamic> user) {
    final profileImage = user['profileImage'];

    if (profileImage == null) {
      return Text(
        (user['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'U',
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }

    // Handle different profileImage formats
    if (profileImage is String) {
      // It's a URL
      return ClipOval(
        child: Image.network(
          profileImage,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              (user['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          },
        ),
      );
    } else if (profileImage is Map && profileImage['url'] != null) {
      // It's a Map with URL
      return ClipOval(
        child: Image.network(
          profileImage['url'],
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              (user['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          },
        ),
      );
    } else {
      // Fallback to initials
      return Text(
        (user['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'U',
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }
  }
}
