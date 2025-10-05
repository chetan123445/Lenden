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
  List<Map<String, dynamic>> allActivities =
      []; // Store all activities for search
  Map<String, dynamic> stats = {};
  bool loading = true;
  bool loadingStats = true;
  String? selectedType;
  DateTime? startDate;
  DateTime? endDate;
  String searchQuery = ''; // For smart search
  int currentPage = 1;
  bool hasNextPage = false;
  bool hasPrevPage = false;
  int totalItems = 0;
  int totalPages = 0;

  // Activity insights data
  Map<String, int> activityTypeCounts = {};
  Map<String, double> activityTypeAmounts = {};
  String mostActiveDay = '';
  String mostActiveTime = '';
  int totalAmount = 0;
  int averageAmount = 0;

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
    'logout',
    'app_rated',
    'feedback_submitted',
    'user_rated',
    'user_rating_received',
    'receipt_generated'
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
        'limit': '50', // Increased limit for better search experience
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

      if (searchQuery.isNotEmpty) {
        queryParams['search'] = searchQuery;
      }

      final uri = Uri.parse('$baseUrl/api/activities')
          .replace(queryParameters: queryParams);
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Filter out 'user_rating_received' activities
        final filteredActivities =
            List<Map<String, dynamic>>.from(data['activities'])
                .where((a) => a['type'] != 'user_rating_received')
                .toList();
        setState(() {
          if (refresh) {
            activities = filteredActivities;
            allActivities = filteredActivities;
          } else {
            activities.addAll(filteredActivities);
            allActivities.addAll(filteredActivities);
          }
          final pagination = data['pagination'];
          currentPage = pagination['currentPage'];
          totalPages = pagination['totalPages'];
          totalItems = pagination['totalItems'];
          hasNextPage = pagination['hasNext'];
          hasPrevPage = pagination['hasPrev'];
          loading = false;
        });

        // Calculate insights after loading activities
        _calculateActivityInsights();
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

      final uri = Uri.parse('$baseUrl/api/activities/stats')
          .replace(queryParameters: queryParams);
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});

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

  // Calculate activity insights
  void _calculateActivityInsights() {
    if (allActivities.isEmpty) return;

    // Reset insights
    activityTypeCounts.clear();
    activityTypeAmounts.clear();
    totalAmount = 0;

    // Count activities by type and calculate amounts
    for (final activity in allActivities) {
      final type = activity['type'] as String;
      final amount = activity['amount'] as num?;

      // Count by type
      activityTypeCounts[type] = (activityTypeCounts[type] ?? 0) + 1;

      // Sum amounts
      if (amount != null) {
        activityTypeAmounts[type] =
            (activityTypeAmounts[type] ?? 0) + amount.toDouble();
        totalAmount += amount.toInt();
      }
    }

    // Calculate average amount
    final activitiesWithAmount =
        allActivities.where((a) => a['amount'] != null).length;
    averageAmount =
        activitiesWithAmount > 0 ? totalAmount ~/ activitiesWithAmount : 0;

    // Find most active day and time
    _calculateMostActiveTime();

    setState(() {});
  }

  void _calculateMostActiveTime() {
    final dayCounts = <String, int>{};
    final timeCounts = <String, int>{};

    for (final activity in allActivities) {
      final createdAt = DateTime.parse(activity['createdAt'] as String);

      // Count by day of week
      final dayName = DateFormat('EEEE').format(createdAt);
      dayCounts[dayName] = (dayCounts[dayName] ?? 0) + 1;

      // Count by hour
      final hour = createdAt.hour;
      String timeSlot;
      if (hour < 6)
        timeSlot = 'Night (12 AM - 6 AM)';
      else if (hour < 12)
        timeSlot = 'Morning (6 AM - 12 PM)';
      else if (hour < 18)
        timeSlot = 'Afternoon (12 PM - 6 PM)';
      else
        timeSlot = 'Evening (6 PM - 12 AM)';

      timeCounts[timeSlot] = (timeCounts[timeSlot] ?? 0) + 1;
    }

    // Find most active day
    if (dayCounts.isNotEmpty) {
      mostActiveDay =
          dayCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    // Find most active time
    if (timeCounts.isNotEmpty) {
      mostActiveTime =
          timeCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }
  }

  // Search functionality
  void _performSearch(String query) {
    setState(() {
      searchQuery = query;
      currentPage = 1;
    });
    fetchActivities(refresh: true);
  }

  // Clear search
  void _clearSearch() {
    setState(() {
      searchQuery = '';
      currentPage = 1;
    });
    fetchActivities(refresh: true);
  }

  String _getActivityTypeDisplayName(String type) {
    switch (type) {
      case 'transaction_created':
        return 'Transaction Created';
      case 'transaction_cleared':
        return 'Transaction Cleared';
      case 'partial_payment_made':
        return 'Partial Payment Made';
      case 'partial_payment_received':
        return 'Partial Payment Received';
      case 'group_created':
        return 'Group Created';
      case 'group_joined':
        return 'Joined Group';
      case 'group_left':
        return 'Left Group';
      case 'member_added':
        return 'Member Added';
      case 'member_removed':
        return 'Member Removed';
      case 'expense_added':
        return 'Expense Added';
      case 'expense_edited':
        return 'Expense Edited';
      case 'expense_deleted':
        return 'Expense Deleted';
      case 'expense_settled':
        return 'Expense Settled';
      case 'note_created':
        return 'Note Created';
      case 'note_edited':
        return 'Note Edited';
      case 'note_deleted':
        return 'Note Deleted';
      case 'profile_updated':
        return 'Profile Updated';
      case 'password_changed':
        return 'Password Changed';
      case 'login':
        return 'Login';
      case 'logout':
        return 'Logout';
      case 'app_rated':
        return 'App Rated';
      case 'feedback_submitted':
        return 'Feedback Submitted';
      case 'user_rated':
        return 'User Rated';
      case 'user_rating_received':
        return 'User Rating Received';
      case 'receipt_generated':
        return 'Receipt Generated';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
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
      case 'app_rated':
        return Icons.star;
      case 'feedback_submitted':
        return Icons.feedback;
      case 'user_rated':
        return Icons.person;
      case 'user_rating_received':
        return Icons.person_outline;
      case 'receipt_generated':
        return Icons.receipt;
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
      case 'app_rated':
        return Colors.amber;
      case 'feedback_submitted':
        return Colors.blueAccent;
      case 'user_rated':
        return Colors.green;
      case 'user_rating_received':
        return Colors.teal;
      case 'receipt_generated':
        return Colors.brown;
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
        foregroundColor: Colors.black,
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
      body: RefreshIndicator(
        onRefresh: () async {
          await fetchActivities(refresh: true);
          await fetchStats();
        },
        child: CustomScrollView(
          slivers: [
            // Search Bar
            SliverToBoxAdapter(child: _buildSearchBar()),

            // Stats Section
            if (!loadingStats) SliverToBoxAdapter(child: _buildStatsSection()),

            // Activity Insights Section
            if (!loading && allActivities.isNotEmpty)
              SliverToBoxAdapter(child: _buildActivityInsights()),

            // Filter chips
            if (selectedType != null ||
                startDate != null ||
                endDate != null ||
                searchQuery.isNotEmpty)
              SliverToBoxAdapter(child: _buildFilterChips()),

            // Activities List
            if (loading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: const Center(child: CircularProgressIndicator()),
              )
            else if (activities.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverList.builder(
                itemCount: activities.length + (hasNextPage ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == activities.length) {
                    return _buildLoadMoreButton();
                  }
                  return _buildSwipeableActivityCard(activities[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: 'Search activities...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          if (searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.grey[600], size: 20),
              onPressed: _clearSearch,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
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

  Widget _buildActivityInsights() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00B4D8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.insights,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Activity Insights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Insights Grid
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  'Total Amount',
                  '₹$totalAmount',
                  Icons.account_balance_wallet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  'Average',
                  '₹$averageAmount',
                  Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  'Most Active Day',
                  mostActiveDay.isNotEmpty ? mostActiveDay : 'N/A',
                  Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  'Peak Time',
                  mostActiveTime.isNotEmpty ? mostActiveTime : 'N/A',
                  Icons.access_time,
                ),
              ),
            ],
          ),

          // Top Activity Types
          if (activityTypeCounts.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Top Activity Types',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...activityTypeCounts.entries
                .take(3)
                .map((entry) => _buildActivityTypeRow(entry.key, entry.value)),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.black, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTypeRow(String type, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            _getActivityIcon(type),
            color: Colors.black,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getActivityTypeDisplayName(type),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
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
          if (searchQuery.isNotEmpty)
            Chip(
              label: Text('Search: "$searchQuery"'),
              onDeleted: _clearSearch,
              backgroundColor: Colors.purple.withOpacity(0.2),
              deleteIcon: const Icon(Icons.clear, size: 18),
            ),
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
          return _buildSwipeableActivityCard(activities[index]);
        },
      ),
    );
  }

  Widget _buildSwipeableActivityCard(Map<String, dynamic> activity) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Dismissible(
        key: Key(activity['_id'] ?? DateTime.now().toString()),
        direction: DismissDirection.endToStart, // Only swipe from right to left
        background: _buildSwipeBackground(),
        confirmDismiss: (direction) => _showSwipeActionDialog(activity),
        child: _buildActivityCard(activity),
      ),
    );
  }

  Widget _buildSwipeBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.red, Colors.orange],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  'Actions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showSwipeActionDialog(Map<String, dynamic> activity) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activity Actions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info, color: Colors.blue),
              title: const Text('View Details'),
              onTap: () {
                Navigator.of(context).pop(false);
                _showActivityDetails(activity);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.green),
              title: const Text('Share Activity'),
              onTap: () {
                Navigator.of(context).pop(false);
                _shareActivity(activity);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark, color: Colors.orange),
              title: const Text('Bookmark'),
              onTap: () {
                Navigator.of(context).pop(false);
                _bookmarkActivity(activity);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              onTap: () {
                Navigator.of(context).pop(true);
                _deleteActivity(activity);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
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
    final metadata = activity['metadata'];

    // Custom highlight for rating activities
    final isRating = type == 'user_rated' || type == 'user_rating_received';
    final ratingValue = metadata != null && metadata['rating'] != null
        ? metadata['rating']
        : null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRating
              ? Colors.amber.withOpacity(0.7)
              : _getActivityColor(type).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isRating
                    ? Colors.amber.withOpacity(0.15)
                    : _getActivityColor(type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isRating
                      ? Colors.amber.withOpacity(0.3)
                      : _getActivityColor(type).withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                isRating ? Icons.star : _getActivityIcon(type),
                color: isRating ? Colors.amber : _getActivityColor(type),
                size: 28,
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isRating ? Colors.amber[900] : Colors.black,
                          ),
                        ),
                      ),
                      if (amount != null && currency != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '$currency$amount',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      if (isRating && ratingValue != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$ratingValue ★',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: isRating ? Colors.amber[800] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatDate(createdAt, activityType: type),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      // Delete Button
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: () => _deleteActivity(activity),
                        tooltip: 'Delete Activity',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

  // Swipe Action Methods
  void _showActivityDetails(Map<String, dynamic> activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activity['title'] ?? 'Activity Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${_getActivityTypeDisplayName(activity['type'])}'),
            const SizedBox(height: 8),
            Text('Description: ${activity['description']}'),
            const SizedBox(height: 8),
            Text(
                'Date: ${_formatDate(activity['createdAt'], activityType: activity['type'])}'),
            if (activity['amount'] != null) ...[
              const SizedBox(height: 8),
              Text('Amount: ${activity['currency']}${activity['amount']}'),
            ],
            if (activity['metadata'] != null) ...[
              const SizedBox(height: 8),
              Text('Additional Info: ${activity['metadata']}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _shareActivity(Map<String, dynamic> activity) {
    // This would integrate with device sharing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing: ${activity['title']}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _bookmarkActivity(Map<String, dynamic> activity) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bookmarked: ${activity['title']}'),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            // Undo bookmark action
          },
        ),
      ),
    );
  }

  void _deleteActivity(Map<String, dynamic> activity) {
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
                    colors: [Colors.red, Colors.redAccent],
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
                        Icons.delete_forever,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Delete Activity',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This action cannot be undone',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Warning Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Activity Title
                    Text(
                      activity['title'] ?? 'Unknown Activity',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Activity Type
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getActivityColor(activity['type'])
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getActivityTypeDisplayName(activity['type']),
                        style: TextStyle(
                          color: _getActivityColor(activity['type']),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirmation Text
                    Text(
                      'Are you sure you want to delete this activity? This action cannot be undone.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.cancel, color: Colors.grey),
                        label: const Text(
                          'Cancel',
                          style: TextStyle(
                              color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop();

                          try {
                            final session = Provider.of<SessionProvider>(
                                context,
                                listen: false);
                            final token = session.token;
                            final baseUrl = ApiConfig.baseUrl;

                            final uri = Uri.parse(
                                '$baseUrl/api/activities/${activity['_id']}');
                            final response = await http.delete(
                              uri,
                              headers: {'Authorization': 'Bearer $token'},
                            );

                            if (response.statusCode == 200) {
                              // Remove from local list
                              setState(() {
                                activities.removeWhere(
                                    (a) => a['_id'] == activity['_id']);
                                allActivities.removeWhere(
                                    (a) => a['_id'] == activity['_id']);
                              });
                              _calculateActivityInsights();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle,
                                          color: Colors.white),
                                      const SizedBox(width: 8),
                                      const Text(
                                          'Activity deleted successfully'),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            } else {
                              final errorData = json.decode(response.body);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.error,
                                          color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(errorData['error'] ??
                                          'Failed to delete activity'),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.error,
                                        color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text('Error: $e'),
                                  ],
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_forever,
                            color: Colors.white),
                        label: const Text(
                          'Delete',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
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

  void _showFilterDialog() {
    print('Filter dialog opened'); // Debug print
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
                    // Close button at the top right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(
                            width: 40), // Spacer to center the content
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
                        // Close button
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Activity Type Filter with enhanced styling
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.grey.withOpacity(0.3)),
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
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.all_inclusive,
                                        size: 16, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('All Types',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            ...activityTypes
                                .map((type) => DropdownMenuItem<String>(
                                      value: type,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: _getActivityColor(type)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Icon(_getActivityIcon(type),
                                                size: 16,
                                                color: _getActivityColor(type)),
                                          ),
                                          const SizedBox(width: 12),
                                          Flexible(
                                            child: Text(
                                              _getActivityTypeDisplayName(type),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w500),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedType = value;
                            });
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
                          border:
                              Border.all(color: Colors.grey.withOpacity(0.2)),
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
                                        initialDate:
                                            startDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme:
                                                  const ColorScheme.light(
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
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: const Icon(Icons.arrow_forward,
                                      color: Colors.grey),
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
                                              colorScheme:
                                                  const ColorScheme.light(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w600),
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
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
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
        color: date != null
            ? const Color(0xFF00B4D8).withOpacity(0.1)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: date != null
              ? const Color(0xFF00B4D8)
              : Colors.grey.withOpacity(0.3),
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
                    date != null
                        ? DateFormat('MMM dd, yyyy').format(date!)
                        : label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          date != null ? FontWeight.w600 : FontWeight.normal,
                      color: date != null
                          ? const Color(0xFF00B4D8)
                          : Colors.grey[600],
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
