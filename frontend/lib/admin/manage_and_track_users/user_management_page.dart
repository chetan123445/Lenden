import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../user/session.dart';
import '../../api_config.dart';
import 'user_details_page.dart';
import 'user_edit_page.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _sortBy = 'name';
  bool _sortAscending = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('ApiConfig.baseUrl/api/admin/users'),
        headers: {
          'Authorization': 'Bearer ${session.token}',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _users = List<Map<String, dynamic>>.from(data['users']);
          _filteredUsers = List.from(_users);
        });
        _applyFilters();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load users: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: ${e.toString()}'),
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

  void _applyFilters() {
    setState(() {
      _filteredUsers = _users.where((user) {
        // Search filter
        final matchesSearch = _searchQuery.isEmpty ||
            user['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            user['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
            user['username'].toString().toLowerCase().contains(_searchQuery.toLowerCase());

        // Status filter
        final matchesStatus = _statusFilter == 'All' ||
            (_statusFilter == 'Active' && user['isActive'] == true) ||
            (_statusFilter == 'Inactive' && user['isActive'] == false) ||
            (_statusFilter == 'Pending' && user['isVerified'] == false);

        return matchesSearch && matchesStatus;
      }).toList();

      // Sort
      _filteredUsers.sort((a, b) {
        var aValue = a[_sortBy] ?? '';
        var bValue = b[_sortBy] ?? '';
        
        if (aValue is String) aValue = aValue.toLowerCase();
        if (bValue is String) bValue = bValue.toLowerCase();
        
        int comparison = aValue.compareTo(bValue);
        return _sortAscending ? comparison : -comparison;
      });
    });
  }

  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final response = await http.patch(
        Uri.parse('ApiConfig.baseUrl/api/admin/users/$userId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.token}',
        },
        body: json.encode({
          'isActive': !currentStatus,
        }),
      );

      if (response.statusCode == 200) {
        // Update local data
        setState(() {
          final userIndex = _users.indexWhere((user) => user['_id'] == userId);
          if (userIndex != -1) {
            _users[userIndex]['isActive'] = !currentStatus;
          }
        });
        _applyFilters();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${!currentStatus ? 'activated' : 'deactivated'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update user status'),
            backgroundColor: Colors.red,
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

  Future<void> _deleteUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete user "$userName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final session = Provider.of<SessionProvider>(context, listen: false);
        final response = await http.delete(
          Uri.parse('ApiConfig.baseUrl/api/admin/users/$userId'),
          headers: {
            'Authorization': 'Bearer ${session.token}',
          },
        );

        if (response.statusCode == 200) {
          setState(() {
            _users.removeWhere((user) => user['_id'] == userId);
          });
          _applyFilters();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete user'),
              backgroundColor: Colors.red,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FA),
      appBar: AppBar(
        title: const Text(
          'User Management',
          style: TextStyle(
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
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users by name, email, or username...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                              _applyFilters();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _applyFilters();
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Filters Row
                Row(
                  children: [
                    // Status Filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _statusFilter,
                            isExpanded: true,
                            items: ['All', 'Active', 'Inactive', 'Pending']
                                .map((status) => DropdownMenuItem(
                                      value: status,
                                      child: Text(status),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _statusFilter = value!;
                              });
                              _applyFilters();
                            },
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Sort Button
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        setState(() {
                          if (_sortBy == value) {
                            _sortAscending = !_sortAscending;
                          } else {
                            _sortBy = value;
                            _sortAscending = true;
                          }
                        });
                        _applyFilters();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'name',
                          child: Text('Sort by Name'),
                        ),
                        const PopupMenuItem(
                          value: 'email',
                          child: Text('Sort by Email'),
                        ),
                        const PopupMenuItem(
                          value: 'createdAt',
                          child: Text('Sort by Date'),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sort, size: 20),
                            const SizedBox(width: 4),
                            Text(_sortBy == 'name' ? 'Name' : _sortBy == 'email' ? 'Email' : 'Date'),
                            Icon(
                              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Statistics
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildStatCard('Total Users', _users.length.toString(), Icons.people),
                const SizedBox(width: 12),
                _buildStatCard('Active Users', _users.where((u) => u['isActive'] == true).length.toString(), Icons.check_circle),
                const SizedBox(width: 12),
                _buildStatCard('Pending', _users.where((u) => u['isVerified'] == false).length.toString(), Icons.pending),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Users List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No users found',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return _buildUserCard(user);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
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
                fontSize: 20,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isActive = user['isActive'] ?? false;
    final isVerified = user['isVerified'] ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: const Color(0xFF00B4D8),
          child: _buildProfileImage(user),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user['name'] ?? 'Unknown User',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              user['email'] ?? 'No email',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  '@${user['username'] ?? 'unknown'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                if (!isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Pending',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'view':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserDetailsPage(user: user),
                  ),
                );
                break;
              case 'edit':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserEditPage(user: user),
                  ),
                ).then((_) => _loadUsers());
                break;
              case 'toggle':
                _toggleUserStatus(user['_id'], isActive);
                break;
              case 'delete':
                _deleteUser(user['_id'], user['name']);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 16),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16),
                  SizedBox(width: 8),
                  Text('Edit User'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(isActive ? Icons.block : Icons.check_circle, size: 16),
                  const SizedBox(width: 8),
                  Text(isActive ? 'Deactivate' : 'Activate'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete User', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          child: const Icon(Icons.more_vert),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailsPage(user: user),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileImage(Map<String, dynamic> user) {
    final profileImage = user['profileImage'];
    
    if (profileImage == null) {
      return Text(
        (user['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'U',
        style: const TextStyle(
          fontSize: 20,
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
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              (user['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(
                fontSize: 20,
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
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              (user['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(
                fontSize: 20,
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
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }
  }
} 