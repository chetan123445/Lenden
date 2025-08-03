import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import '../user/session.dart';
import 'package:intl/intl.dart';

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  List<Map<String, dynamic>> activities = [];
  Map<String, dynamic> stats = {};
  bool loading = true;
  bool loadingStats = true;
  String? selectedType;
  DateTime? startDate;
  DateTime? endDate;
  int currentPage = 1;
  bool hasNextPage = false;
  bool hasPrevPage = false;
  int totalItems = 0;
  int totalPages = 0;
  
  final List<String> activityTypes = [
    'transaction_created',
    'transaction_cleared',
    'partial_payment_made',
    'partial_payment_received',
    'group_created',
    'group_joined',
    'group_left',
    'member_added',
    'member_removed',
    'expense_added',
    'expense_edited',
    'expense_deleted',
    'expense_settled',
    'note_created',
    'note_edited',
    'note_deleted',
    'profile_updated',
    'password_changed',
    'login',
    'logout'
  ];

  @override
  void initState() {
    super.initState();
    fetchActivities();
    fetchStats();
  }

  Future<void> fetchActivities({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        currentPage = 1;
        loading = true;
      });
    } else {
      setState(() => loading = true);
    }

    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      final baseUrl = ApiConfig.baseUrl;
      
      // Build query parameters
      final queryParams = <String, String>{
        'page': currentPage.toString(),
        'limit': '20',
      };
      
      if (selectedType != null) {
        queryParams['type'] = selectedType!;
      }
      
      if (startDate != null) {
        queryParams['startDate'] = startDate!.toIso8601String();
      }
      
      if (endDate != null) {
        queryParams['endDate'] = endDate!.toIso8601String();
      }
      
      final uri = Uri.parse('$baseUrl/api/activities').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          if (refresh) {
            activities = List<Map<String, dynamic>>.from(data['activities']);
          } else {
            activities.addAll(List<Map<String, dynamic>>.from(data['activities']));
          }
          final pagination = data['pagination'];
          currentPage = pagination['currentPage'];
          totalPages = pagination['totalPages'];
          totalItems = pagination['totalItems'];
          hasNextPage = pagination['hasNext'];
          hasPrevPage = pagination['hasPrev'];
          loading = false;
        });
      } else {
        setState(() => loading = false);
        _showErrorDialog('Failed to load activities');
      }
    } catch (e) {
      setState(() => loading = false);
      _showErrorDialog('Error: $e');
    }
  }

  Future<void> fetchStats() async {
    setState(() => loadingStats = true);
    
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      final baseUrl = ApiConfig.baseUrl;
      
      final queryParams = <String, String>{};
      if (startDate != null) {
        queryParams['startDate'] = startDate!.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate!.toIso8601String();
      }
      
      final uri = Uri.parse('$baseUrl/api/activities/stats').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      
      if (response.statusCode == 200) {
        setState(() {
          stats = json.decode(response.body);
          loadingStats = false;
        });
      } else {
        setState(() => loadingStats = false);
      }
    } catch (e) {
      setState(() => loadingStats = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getActivityTypeDisplayName(String type) {
    switch (type) {
      case 'transaction_created': return 'Transaction Created';
      case 'transaction_cleared': return 'Transaction Cleared';
      case 'partial_payment_made': return 'Partial Payment Made';
      case 'partial_payment_received': return 'Partial Payment Received';
      case 'group_created': return 'Group Created';
      case 'group_joined': return 'Joined Group';
      case 'group_left': return 'Left Group';
      case 'member_added': return 'Member Added';
      case 'member_removed': return 'Member Removed';
      case 'expense_added': return 'Expense Added';
      case 'expense_edited': return 'Expense Edited';
      case 'expense_deleted': return 'Expense Deleted';
      case 'expense_settled': return 'Expense Settled';
      case 'note_created': return 'Note Created';
      case 'note_edited': return 'Note Edited';
      case 'note_deleted': return 'Note Deleted';
      case 'profile_updated': return 'Profile Updated';
      case 'password_changed': return 'Password Changed';
      case 'login': return 'Login';
      case 'logout': return 'Logout';
      default: return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'transaction_created':
      case 'transaction_cleared':
        return Icons.swap_horiz;
      case 'partial_payment_made':
      case 'partial_payment_received':
        return Icons.payment;
      case 'group_created':
      case 'group_joined':
      case 'group_left':
        return Icons.group;
      case 'member_added':
      case 'member_removed':
        return Icons.person_add;
      case 'expense_added':
      case 'expense_edited':
      case 'expense_deleted':
      case 'expense_settled':
        return Icons.receipt;
      case 'note_created':
      case 'note_edited':
      case 'note_deleted':
        return Icons.note;
      case 'profile_updated':
        return Icons.person;
      case 'password_changed':
        return Icons.lock;
      case 'login':
      case 'logout':
        return Icons.login;
      default:
        return Icons.info;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'transaction_created':
      case 'group_created':
      case 'note_created':
      case 'expense_added':
        return Colors.green;
      case 'transaction_cleared':
      case 'expense_settled':
        return Colors.blue;
      case 'partial_payment_made':
      case 'partial_payment_received':
        return Colors.orange;
      case 'expense_deleted':
      case 'note_deleted':
      case 'group_left':
        return Colors.red;
      case 'expense_edited':
      case 'note_edited':
      case 'profile_updated':
        return Colors.purple;
      case 'member_added':
        return Colors.teal;
      case 'member_removed':
        return Colors.red;
      case 'login':
        return Colors.green;
      case 'logout':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String dateString, {String? activityType}) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      // For login activities, always show full date and time
      if (activityType == 'login') {
        return DateFormat('MMM dd, yyyy • h:mm a').format(date);
      }
      
      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes} minutes ago';
        }
        return '${difference.inHours} hours ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return DateFormat('MMM dd, yyyy').format(date);
      }
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF00B4D8),
        foregroundColor: Colors.white,
        title: const Text('Activity Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              fetchActivities(refresh: true);
              fetchStats();
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8F6FA),
      body: Column(
        children: [
          // Stats Section
          if (!loadingStats) _buildStatsSection(),
          
          // Filter chips
          if (selectedType != null || startDate != null || endDate != null)
            _buildFilterChips(),
          
          // Activities List
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : activities.isEmpty
                    ? _buildEmptyState()
                    : _buildActivitiesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00B4D8),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Activities',
                  '${stats['totalActivities'] ?? 0}',
                  Icons.timeline,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Recent (7 days)',
                  '${stats['recentActivities'] ?? 0}',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: [
          if (selectedType != null)
            Chip(
              label: Text(_getActivityTypeDisplayName(selectedType!)),
              onDeleted: () {
                setState(() => selectedType = null);
                fetchActivities(refresh: true);
              },
              backgroundColor: const Color(0xFF00B4D8).withOpacity(0.2),
            ),
          if (startDate != null)
            Chip(
              label: Text('From: ${DateFormat('MMM dd').format(startDate!)}'),
              onDeleted: () {
                setState(() => startDate = null);
                fetchActivities(refresh: true);
              },
              backgroundColor: Colors.orange.withOpacity(0.2),
            ),
          if (endDate != null)
            Chip(
              label: Text('To: ${DateFormat('MMM dd').format(endDate!)}'),
              onDeleted: () {
                setState(() => endDate = null);
                fetchActivities(refresh: true);
              },
              backgroundColor: Colors.orange.withOpacity(0.2),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timeline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No activities found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your activities will appear here',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesList() {
    return RefreshIndicator(
      onRefresh: () async {
        await fetchActivities(refresh: true);
        await fetchStats();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: activities.length + (hasNextPage ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == activities.length) {
            return _buildLoadMoreButton();
          }
          return _buildActivityCard(activities[index]);
        },
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final type = activity['type'] as String;
    final title = activity['title'] as String;
    final description = activity['description'] as String;
    final createdAt = activity['createdAt'] as String;
    final amount = activity['amount'];
    final currency = activity['currency'];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getActivityColor(type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getActivityIcon(type),
                color: _getActivityColor(type),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            
            // Activity Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (amount != null && currency != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$currency$amount',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(createdAt, activityType: type),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ElevatedButton(
          onPressed: () {
            setState(() => currentPage++);
            fetchActivities();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00B4D8),
            foregroundColor: Colors.white,
          ),
          child: const Text('Load More'),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                offset: const Offset(0, 10),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient background
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.filter_list_alt,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Filter Activities',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customize your activity view',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Filter Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: StatefulBuilder(
                  builder: (context, setState) => Column(
                    children: [
                      // Activity Type Filter with enhanced styling
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: selectedType,
                          decoration: InputDecoration(
                            labelText: 'Activity Type',
                            labelStyle: const TextStyle(
                              color: Color(0xFF00B4D8),
                              fontWeight: FontWeight.w600,
                            ),
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00B4D8).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.category,
                                color: Color(0xFF00B4D8),
                                size: 20,
                              ),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.all_inclusive, size: 16, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('All Types', style: TextStyle(fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            ...activityTypes.map((type) => DropdownMenuItem<String>(
                              value: type,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _getActivityColor(type).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(_getActivityIcon(type), size: 16, color: _getActivityColor(type)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _getActivityTypeDisplayName(type),
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                          onChanged: (value) {
                            setState(() => selectedType = value);
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Date Range Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.date_range,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Date Range',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Date Range Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDateButton(
                                    context: context,
                                    label: 'Start Date',
                                    date: startDate,
                                    onPressed: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: startDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: const ColorScheme.light(
                                                primary: Color(0xFF00B4D8),
                                                onPrimary: Colors.white,
                                                surface: Colors.white,
                                                onSurface: Colors.black,
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (date != null) {
                                        setState(() => startDate = date);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: const Icon(Icons.arrow_forward, color: Colors.grey),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDateButton(
                                    context: context,
                                    label: 'End Date',
                                    date: endDate,
                                    onPressed: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: endDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: const ColorScheme.light(
                                                primary: Color(0xFF00B4D8),
                                                onPrimary: Colors.white,
                                                surface: Colors.white,
                                                onSurface: Colors.black,
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (date != null) {
                                        setState(() => endDate = date);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Action Buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            selectedType = null;
                            startDate = null;
                            endDate = null;
                          });
                        },
                        icon: const Icon(Icons.clear_all, color: Colors.red),
                        label: const Text(
                          'Clear All',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          fetchActivities(refresh: true);
                          fetchStats();
                        },
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          'Apply Filters',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B4D8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
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
    );
  }

  Widget _buildDateButton({
    required BuildContext context,
    required String label,
    required DateTime? date,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: date != null ? const Color(0xFF00B4D8).withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: date != null ? const Color(0xFF00B4D8) : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: date != null ? const Color(0xFF00B4D8) : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    date != null ? DateFormat('MMM dd, yyyy').format(date!) : label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                      color: date != null ? const Color(0xFF00B4D8) : Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 