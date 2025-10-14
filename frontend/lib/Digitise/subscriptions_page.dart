import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../api_config.dart';
import '../user/session.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({Key? key}) : super(key: key);

  @override
  _SubscriptionsPageState createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  String? _selectedPlan;
  String _searchQuery = '';
  String _filterOption = 'All'; // All, Active, Expired
  bool _showComparison = false;
  
  final List<Map<String, dynamic>> _plans = [
    {'name': '1 month', 'duration': 1, 'price': 99, 'pricePerMonth': 99, 'savings': 0},
    {'name': '2 months', 'duration': 2, 'price': 189, 'pricePerMonth': 94.5, 'savings': 5},
    {'name': '3 months', 'duration': 3, 'price': 267, 'pricePerMonth': 89, 'savings': 10},
    {'name': '6 months', 'duration': 6, 'price': 474, 'pricePerMonth': 79, 'savings': 20, 'popular': true},
    {'name': '1 year', 'duration': 12, 'price': 828, 'pricePerMonth': 69, 'savings': 30, 'bestValue': true},
  ];

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _subscribe() async {
    if (_selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subscription plan.')),
      );
      return;
    }

    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final user = session.user;

    if (token == null || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to subscribe.')),
      );
      return;
    }

    final plan = _plans.firstWhere((p) => p['name'] == _selectedPlan);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/subscription/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': user['_id'],
          'subscriptionPlan': plan['name'],
          'duration': plan['duration'],
          'price': plan['price'],
          'discount': plan['savings'],
        }),
      );

      if (response.statusCode == 200) {
        final session = Provider.of<SessionProvider>(context, listen: false);
        await session.checkSubscriptionStatus();

        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Colors.orange, Colors.white, Colors.green],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFFFCE4EC),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 30),
                          SizedBox(width: 10),
                          Text('Success!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: const Text('You are now a premium member. Enjoy unlimited access!'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextButton(
                        child: const Text('OK'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to subscribe: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  Color _getBenefitColor(int index) {
    final colors = [
      Color(0xFFFFF4E6), // Cream
      Color(0xFFE8F5E9), // Light green
      Color(0xFFFCE4EC), // Light pink
      Color(0xFFE3F2FD), // Light blue
      Color(0xFFFFF9C4), // Light yellow
      Color(0xFFF3E5F5), // Light purple
    ];
    return colors[index % colors.length];
  }

  List<Map<String, dynamic>> _getFilteredHistory(List<Map<String, dynamic>> history) {
    return history.where((sub) {
      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          sub['subscriptionPlan'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      // Status filter
      bool matchesFilter = true;
      if (_filterOption == 'Active') {
        final endDate = DateTime.parse(sub['endDate']);
        matchesFilter = endDate.isAfter(DateTime.now());
      } else if (_filterOption == 'Expired') {
        final endDate = DateTime.parse(sub['endDate']);
        matchesFilter = endDate.isBefore(DateTime.now());
      }
      
      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Go Premium', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Consumer<SessionProvider>(
        builder: (context, session, child) {
          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipPath(
                  clipper: TopWaveClipper(),
                  child: Container(
                    height: 150,
                    color: const Color(0xFF00B4D8),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipPath(
                  clipper: BottomWaveClipper(),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.13,
                    color: const Color(0xFF00B4D8),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      if (session.subscriptionHistory != null && session.subscriptionHistory!.isNotEmpty)
                        _buildSubscriptionHistory(session.subscriptionHistory!),
                      session.isSubscribed
                          ? _buildSubscribedView(session)
                          : _buildSubscribeView(),
                      const SizedBox(height: 20),
                      _buildFAQSection(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionHistory(List<Map<String, dynamic>> history) {
    final filteredHistory = _getFilteredHistory(history);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Subscription History',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        
        // Search Bar
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Colors.orange, Colors.white, Colors.green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by plan name...',
                border: InputBorder.none,
                icon: Icon(Icons.search, color: Color(0xFF00B4D8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
        
        const SizedBox(height: 15),
        
        // Filter Chips
        Wrap(
          spacing: 8,
          children: ['All', 'Active', 'Expired'].map((filter) {
            return FilterChip(
              label: Text(filter),
              selected: _filterOption == filter,
              onSelected: (selected) {
                setState(() {
                  _filterOption = filter;
                });
              },
              selectedColor: Color(0xFF00B4D8),
              labelStyle: TextStyle(
                color: _filterOption == filter ? Colors.white : Colors.black,
              ),
            );
          }).toList(),
        ),
        
        const SizedBox(height: 15),
        
        // History List
        if (filteredHistory.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'No subscriptions found',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          ...filteredHistory.map((sub) {
            final endDate = DateTime.parse(sub['endDate']);
            final isActive = endDate.isAfter(DateTime.now());
            
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: isActive 
                      ? [Colors.green, Colors.white, Colors.green]
                      : [Colors.grey, Colors.white, Colors.grey],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isActive ? Color(0xFFE8F5E9) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ListTile(
                  leading: Icon(
                    isActive ? Icons.check_circle : Icons.history,
                    color: isActive ? Colors.green : Colors.grey,
                    size: 30,
                  ),
                  title: Text(
                    sub['subscriptionPlan'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isActive 
                        ? 'Active until: ${endDate.toLocal().toString().substring(0, 10)}'
                        : 'Expired on: ${endDate.toLocal().toString().substring(0, 10)}',
                  ),
                  trailing: Chip(
                    label: Text(
                      isActive ? 'ACTIVE' : 'EXPIRED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ),
            );
          }),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSubscribedView(SessionProvider session) {
    final daysRemaining = session.subscriptionEndDate != null
        ? session.subscriptionEndDate!.difference(DateTime.now()).inDays
        : 0;
    
    return Column(
      children: [
        // Stats Dashboard
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00B4D8), Color(0xFF0096C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF00B4D8).withOpacity(0.3),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                '🎉 Premium Member',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(Icons.calendar_today, '$daysRemaining', 'Days Left'),
                  _buildStatCard(Icons.workspace_premium, session.subscriptionPlan?.split(' ')[0] ?? 'N/A', 'Plan'),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Active Subscription Details
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Colors.orange, Colors.white, Colors.green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFCE4EC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subscription Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Icon(Icons.edit, color: Color(0xFF00B4D8)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoRow('Plan:', session.subscriptionPlan ?? 'N/A'),
                const SizedBox(height: 10),
                _buildInfoRow('Expires On:', session.subscriptionEndDate?.toLocal().toString().split(' ')[0] ?? 'N/A'),
                const SizedBox(height: 20),
                const Text(
                  'Premium Features:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildBenefitItem(0, Icons.all_inclusive, 'Unlimited Transactions', ''),
                _buildBenefitItem(1, Icons.group_add, 'Unlimited Groups', ''),
                _buildBenefitItem(2, Icons.message, 'Unlimited Messaging', ''),
                _buildBenefitItem(3, Icons.star, 'View User Ratings', ''),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 30),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
    );
  }

  Widget _buildSubscribeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 60),
        
        // Benefits Section
        const Text(
          'Premium Benefits',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        _buildBenefitItem(0, Icons.all_inclusive, 'Unlimited Transactions', 'Create as many transactions as you need without any limits.'),
        _buildBenefitItem(1, Icons.group_add, 'Unlimited Groups', 'Create and manage an unlimited number of groups for your transactions.'),
        _buildBenefitItem(2, Icons.message, 'Unlimited Messaging', 'Enjoy unlimited messaging in both one-to-one and group chats.'),
        _buildBenefitItem(3, Icons.star, 'View User Ratings', 'See the ratings of other users to build a trusted network.'),
        
        const SizedBox(height: 30),
        
        // Plan Comparison Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select a Plan',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showComparison = !_showComparison;
                });
              },
              icon: Icon(_showComparison ? Icons.grid_view : Icons.view_list),
              label: Text(_showComparison ? 'List View' : 'Compare'),
            ),
          ],
        ),
        
        const SizedBox(height: 15),
        
        // Plans Display
        _showComparison
            ? _buildComparisonView()
            : Column(
                children: _plans.map((plan) => _buildPlanCard(plan)).toList(),
              ),
        
        const SizedBox(height: 30),
        
        // Subscribe Button
        Center(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.white, Colors.green],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _subscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rocket_launch, color: Colors.black),
                  SizedBox(width: 10),
                  Text(
                    'Subscribe Now',
                    style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Trust Badges
        _buildTrustBadges(),
      ],
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isSelected = _selectedPlan == plan['name'];
    final bool isPopular = plan['popular'] ?? false;
    final bool isBestValue = plan['bestValue'] ?? false;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = plan['name'];
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
                  colors: [Colors.orange, Colors.white, Colors.green],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.grey[50],
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            children: [
              // Badge
              if (isPopular || isBestValue)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isBestValue 
                            ? [Colors.purple, Colors.deepPurple]
                            : [Colors.orange, Colors.deepOrange],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isBestValue ? '⭐ BEST VALUE' : '🔥 POPULAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Radio<String>(
                        value: plan['name'],
                        groupValue: _selectedPlan,
                        onChanged: (value) {
                          setState(() {
                            _selectedPlan = value;
                          });
                        },
                        activeColor: Color(0xFF00B4D8),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan['name'],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '₹${plan['price']}',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00B4D8),
                                  ),
                                ),
                                SizedBox(width: 8),
                                if (plan['savings'] > 0)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Save ${plan['savings']}%',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              '₹${plan['pricePerMonth'].toStringAsFixed(0)}/month',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _plans.map((plan) {
          final isSelected = _selectedPlan == plan['name'];
          final bool isPopular = plan['popular'] ?? false;
          final bool isBestValue = plan['bestValue'] ?? false;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedPlan = plan['name'];
              });
            },
            child: Container(
              width: 160,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                        colors: [Colors.orange, Colors.white, Colors.green],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.grey[50],
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isPopular || isBestValue)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isBestValue 
                                ? [Colors.purple, Colors.deepPurple]
                                : [Colors.orange, Colors.deepOrange],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isBestValue ? '⭐ BEST' : '🔥 HOT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    SizedBox(height: 12),
                    Text(
                      plan['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '₹${plan['price']}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00B4D8),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '₹${plan['pricePerMonth'].toStringAsFixed(0)}/mo',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    if (plan['savings'] > 0) ...[
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Save ${plan['savings']}%',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrustBadges() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBadge(Icons.security, 'Secure\nPayment'),
          _buildBadge(Icons.support_agent, '24/7\nSupport'),
          _buildBadge(Icons.verified, 'Money Back\nGuarantee'),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Color(0xFF00B4D8), size: 30),
        SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(int index, IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.white, Colors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _getBenefitColor(index),
          borderRadius: BorderRadius.circular(15),
        ),
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF00B4D8), size: 40),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
        ),
      ),
    );
  }

  Widget _buildFAQSection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, color: Color(0xFF00B4D8), size: 28),
              SizedBox(width: 10),
              Text(
                'FAQs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildFAQItem(
            'Can I subscribe anytime?',
            'Yes, you can subscribe at any time(Only one active subscription is allowed at a time) and enjoy premium features immediately.',
            0,
          ),
          _buildFAQItem(
            'Do you offer refunds?',
            'We offer a 7-day money-back guarantee if you\'re not satisfied with our premium features.',
            1,
          ),
          _buildFAQItem(
            'What payment methods do you accept?',
            'We accept all major credit cards, debit cards, UPI, and net banking.',
            2,
          ),
          _buildFAQItem(
            'Will my subscription auto-renew?',
            'Your subscription will expire at the end of the period. You can manually renew when needed.',
            3,
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.white, Colors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _getBenefitColor(index),
          borderRadius: BorderRadius.circular(15),
        ),
        child: ExpansionTile(
          title: Text(
            question,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            ),
          ],
          tilePadding: EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height * 0.35);
    path.quadraticBezierTo(
        size.width * 0.25, size.height * 0.5, size.width * 0.5, size.height * 0.35);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.2, size.width, size.height * 0.35);
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