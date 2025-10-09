import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';

class QuickTransactionsPage extends StatefulWidget {
  const QuickTransactionsPage({Key? key}) : super(key: key);
  @override
  State<QuickTransactionsPage> createState() => _QuickTransactionsPageState();
}

class _QuickTransactionsPageState extends State<QuickTransactionsPage> {
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> filteredTransactions = [];
  bool loading = true;
  String? error;
  String searchQuery = '';
  String sortBy = 'created_desc';
  String filterBy = 'all'; // 'all', 'cleared', 'not_cleared'
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    fetchQuickTransactions();
  }

  void sortTransactions() {
    setState(() {
      filteredTransactions.sort((a, b) {
        switch (sortBy) {
          case 'created_asc':
            return (a['createdAt'] ?? '').compareTo(b['createdAt'] ?? '');
          case 'created_desc':
            return (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? '');
          case 'updated_asc':
            return (a['updatedAt'] ?? '').compareTo(b['updatedAt'] ?? '');
          case 'updated_desc':
            return (b['updatedAt'] ?? '').compareTo(a['updatedAt'] ?? '');
          case 'amount_asc':
            return (a['amount'] ?? 0).compareTo(b['amount'] ?? 0);
          case 'amount_desc':
            return (b['amount'] ?? 0).compareTo(a['amount'] ?? 0);
          default:
            return 0;
        }
      });
    });
  }

  void filterTransactions(String query) {
    setState(() {
      searchQuery = query;
      filteredTransactions = transactions.where((transaction) {
        // Apply cleared/not cleared filter first
        bool matchesStatusFilter = true;
        if (filterBy == 'cleared') {
          matchesStatusFilter = transaction['cleared'] == true;
        } else if (filterBy == 'not_cleared') {
          matchesStatusFilter = transaction['cleared'] != true;
        }

        if (!matchesStatusFilter) return false;

        // If no search query, return all that match status filter
        if (query.isEmpty) return true;

        // Search in description
        final description = (transaction['description'] ?? '').toLowerCase();
        final searchLower = query.toLowerCase();
        
        // Search in amount
        final amount = transaction['amount']?.toString() ?? '';
        
        // Search in counterparty names and emails
        final users = transaction['users'] as List? ?? [];
        final counterpartyInfo = users.map((u) {
          return '${u['name'] ?? ''} ${u['email'] ?? ''}'.toLowerCase();
        }).join(' ');

        return description.contains(searchLower) || 
              amount.contains(searchLower) || 
              counterpartyInfo.contains(searchLower);
      }).toList();
      sortTransactions();
    });
  }

  void applyFilter(String filter) {
    setState(() {
      filterBy = filter;
      filterTransactions(searchQuery);
    });
  }

  Future<void> fetchQuickTransactions() async {
    setState(() { loading = true; error = null; });
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final url = '${ApiConfig.baseUrl}/api/quick-transactions';
    final res = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) {
      final fetchedTransactions = List<Map<String, dynamic>>.from(json.decode(res.body)['quickTransactions']);
      setState(() {
        transactions = fetchedTransactions;
        filteredTransactions = fetchedTransactions;
        sortTransactions();
        filterTransactions(searchQuery); // Apply current filters
        loading = false;
      });
    } else {
      setState(() { error = 'Failed to load quick transactions'; loading = false; });
    }
  }

  Future<void> createOrEditQuickTransaction({Map<String, dynamic>? transaction}) async {
    final result = await showDialog(
      context: context,
      builder: (context) => _QuickTransactionDialog(transaction: transaction),
    );

    if (result is String) {
      ElegantNotification.error(
        title: Text("Error"),
        description: Text(result),
      ).show(context);
    } else if (result == true) {
      fetchQuickTransactions();
      ElegantNotification.success(
        title: Text("Success"),
        description: Text("Transaction has been successfully ${transaction != null ? 'updated' : 'created'}!"),
      ).show(context);
    }
  }

  Future<void> deleteQuickTransaction(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Quick Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      final url = '${ApiConfig.baseUrl}/api/quick-transactions/$id';
      final res = await http.delete(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        fetchQuickTransactions();
        ElegantNotification.success(
          title: Text("Success"),
          description: Text("Transaction has been successfully deleted!"),
        ).show(context);
      } else {
        final error = json.decode(res.body)['error'];
        ElegantNotification.error(
          title: Text("Error"),
          description: Text(error),
        ).show(context);
      }
    }
  }

  Future<void> clearQuickTransaction(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear Quick Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to clear this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final token = session.token;
      final url = '${ApiConfig.baseUrl}/api/quick-transactions/$id/clear';
      final res = await http.put(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        setState(() {
          final index = transactions.indexWhere((t) => t['_id'] == id);
          if (index != -1) {
            transactions[index]['cleared'] = true;
            filterTransactions(searchQuery);
          }
        });
        ElegantNotification.success(
          title: Text("Success"),
          description: Text("Transaction has been successfully cleared!"),
        ).show(context);
      } else {
        final error = json.decode(res.body)['error'];
        ElegantNotification.error(
          title: Text("Error"),
          description: Text(error),
        ).show(context);
      }
    }
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sort By',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildSortOption('Date Created (Newest)', 'created_desc'),
            _buildSortOption('Date Created (Oldest)', 'created_asc'),
            _buildSortOption('Date Updated (Newest)', 'updated_desc'),
            _buildSortOption('Date Updated (Oldest)', 'updated_asc'),
            _buildSortOption('Amount (Low to High)', 'amount_asc'),
            _buildSortOption('Amount (High to Low)', 'amount_desc'),
          ],
        ),
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter By Status',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildFilterOption('All Transactions', 'all', Icons.list),
            _buildFilterOption('Cleared Only', 'cleared', Icons.check_circle),
            _buildFilterOption('Not Cleared', 'not_cleared', Icons.pending),
          ],
        ),
      ),
    );
  }

Widget _buildFilterOption(String label, String value, IconData icon) {
    final isSelected = filterBy == value;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Color(0xFF00B4D8) : Colors.grey),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Color(0xFF00B4D8) : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: Color(0xFF00B4D8)) : null,
      onTap: () {
        applyFilter(value);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSortOption(String label, String value) {
    final isSelected = sortBy == value;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Color(0xFF00B4D8) : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: Color(0xFF00B4D8)) : null,
      onTap: () {
        setState(() {
          sortBy = value;
          sortTransactions();
        });
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayedTransactions = _showAll ? filteredTransactions : filteredTransactions.take(3).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FA),
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              SizedBox(height: 120), // Reduced space for smaller wave
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(27),
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.white, Colors.green],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.grey[400], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            onChanged: filterTransactions,
                            decoration: InputDecoration(
                              hintText: 'Search by description, amount, or user...',
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        if (searchQuery.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
                            onPressed: () {
                              setState(() {
                                searchQuery = '';
                              });
                              filterTransactions('');
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Filter and Sort buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Filter button
                    GestureDetector(
                      onTap: _showFilterOptions,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.white, Colors.green],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                filterBy == 'all' ? Icons.filter_alt_outlined : Icons.filter_alt,
                                color: filterBy == 'all' ? Colors.black87 : Color(0xFF00B4D8),
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                filterBy == 'all' 
                                    ? 'Filter' 
                                    : filterBy == 'cleared' 
                                        ? 'Cleared' 
                                        : 'Not Cleared',
                                style: TextStyle(
                                  color: filterBy == 'all' ? Colors.black87 : Color(0xFF00B4D8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Sort button
                    GestureDetector(
                      onTap: _showSortOptions,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.white, Colors.green],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sort, color: Colors.black87, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Sort',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Transactions List
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator(color: Colors.black87))
                    : error != null
                        ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
                        : filteredTransactions.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
                                    const SizedBox(height: 20),
                                    Text(
                                      searchQuery.isNotEmpty || filterBy != 'all'
                                          ? 'No transactions found'
                                          : 'No quick transactions yet.',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      searchQuery.isNotEmpty || filterBy != 'all'
                                          ? 'Try adjusting your search or filters'
                                          : 'Tap the "+" button to create your first one!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  Expanded(
                                    child: ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(20.0, 8, 20.0, 110), // Added bottom padding to prevent bottom wave overlap
                                      itemCount: displayedTransactions.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                                      itemBuilder: (context, i) {
                                        final transaction = displayedTransactions[i];
                                        return _buildQuickTransactionCard(transaction);
                                      },
                                    ),
                                  ),
                                  if (filteredTransactions.length > 3)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 100.0),
                                      child: TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _showAll = !_showAll;
                                          });
                                        },
                                        child: Text(
                                          _showAll ? 'Show Less' : 'See All Transactions',
                                          style: const TextStyle(
                                            color: Color.fromARGB(255, 6, 18, 20),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
              ),
            ],
          ),

          // Bottom wave - same size as top wave
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: BottomWaveClipper(),
              child: Container(
                height: 90, // Same size as top wave
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

          // Blue wave at top - reduced to half size
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopWaveClipper(),
              child: Container(
                height: 90, // Reduced from 180 to 90
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

          // Header on wave
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/user/dashboard');
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Quick Transactions',
                          style: TextStyle(
                            fontSize: 22, // Reduced font size for smaller wave
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            letterSpacing: 1.2,
                            shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.orange, Colors.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => createOrEditQuickTransaction(),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildQuickTransactionCard(Map<String, dynamic> transaction) {
    final bool isCleared = transaction['cleared'] == true;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.white, Colors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          // Added vertical scroll
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        // Added horizontal scroll for amount
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          '${transaction['amount']} ${transaction['currency']}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    if (isCleared)
                      Text(
                        'Cleared',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          createOrEditQuickTransaction(transaction: transaction);
                        } else if (value == 'delete') {
                          deleteQuickTransaction(transaction['_id']);
                        } else if (value == 'clear') {
                          clearQuickTransaction(transaction['_id']);
                        }
                      },
                      itemBuilder: (context) => [
                        if (!isCleared)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                        if (!isCleared)
                          const PopupMenuItem(
                            value: 'clear',
                            child: Text('Clear'),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  // Added horizontal scroll for description
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    transaction['description'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  // Added horizontal scroll for user info
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        (transaction['users'] as List).map((u) => u['name'] as String).join(', '),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(width: 16),
                      Text(
                        '${transaction['date']?.substring(0, 10)} at ${transaction['time']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
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

class _QuickTransactionDialog extends StatefulWidget {
  final Map<String, dynamic>? transaction;

  const _QuickTransactionDialog({Key? key, this.transaction}) : super(key: key);

  @override
  __QuickTransactionDialogState createState() => __QuickTransactionDialogState();
}

class __QuickTransactionDialogState extends State<_QuickTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  String _currency = 'INR';
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _counterpartyEmailController = TextEditingController();
  String _role = 'lender';
  bool _isLoading = false;

  final List<Map<String, String>> _currencies = [
    {'code': 'INR', 'symbol': '₹'},
    {'code': 'USD', 'symbol': '\$'},
    {'code': 'EUR', 'symbol': '€'},
    {'code': 'GBP', 'symbol': '£'},
    {'code': 'JPY', 'symbol': '¥'},
    {'code': 'CNY', 'symbol': '¥'},
    {'code': 'CAD', 'symbol': '\$'},
    {'code': 'AUD', 'symbol': '\$'},
    {'code': 'CHF', 'symbol': 'Fr'},
    {'code': 'RUB', 'symbol': '₽'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _amountController.text = widget.transaction!['amount']?.toString() ?? '';
      _currency = widget.transaction!['currency'] ?? 'INR';
      _descriptionController.text = widget.transaction!['description'] ?? '';
      final currentUserEmail = Provider.of<SessionProvider>(context, listen: false).user!['email'];
      final counterparty = (widget.transaction!['users'] as List).firstWhere(
        (user) => user['email'] != currentUserEmail,
        orElse: () => null,
      );
      _counterpartyEmailController.text = counterparty != null ? counterparty['email'] : '';
      _role = widget.transaction!['role'] ?? 'lender';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = Provider.of<SessionProvider>(context, listen: false).user!['email'];
    final isEditing = widget.transaction != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with gradient
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00B4D8), Color(0xFF48CAE4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.add_circle_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Quick Transaction' : 'New Quick Transaction',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Form content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Amount field
                      _buildStylishField(
                        child: TextFormField(
                          controller: _amountController,
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            prefixIcon: Icon(Icons.attach_money, color: Color(0xFF00B4D8)),
                            border: InputBorder.none,
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an amount';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // Currency dropdown
                      _buildStylishField(
                        child: DropdownButtonFormField<String>(
                          value: _currency,
                          items: _currencies
                              .map((c) => DropdownMenuItem(
                                    value: c['code'],
                                    child: Text('${c['symbol']} ${c['code']}'),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => _currency = val ?? 'INR'),
                          decoration: InputDecoration(
                            labelText: 'Currency',
                            prefixIcon: Icon(Icons.currency_exchange, color: Color(0xFF00B4D8)),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // Description field
                      _buildStylishField(
                        child: TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            prefixIcon: Icon(Icons.description, color: Color(0xFF00B4D8)),
                            border: InputBorder.none,
                          ),
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a description';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // User email (disabled)
                      _buildStylishField(
                        child: TextFormField(
                          initialValue: userEmail,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Your Email',
                            prefixIcon: Icon(Icons.person, color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // Counterparty email
                      _buildStylishField(
                        child: TextFormField(
                          controller: _counterpartyEmailController,
                          enabled: !isEditing,
                          decoration: InputDecoration(
                            labelText: 'Counterparty Email',
                            prefixIcon: Icon(Icons.person_outline, color: isEditing ? Colors.grey : Color(0xFF00B4D8)),
                            border: InputBorder.none,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a counterparty email';
                            }
                            if (value == userEmail) {
                              return 'Counterparty email cannot be the same as your email';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      // Role dropdown
                      _buildStylishField(
                        child: DropdownButtonFormField<String>(
                          value: _role,
                          items: [
                            DropdownMenuItem(value: 'lender', child: Text('Lender')),
                            DropdownMenuItem(value: 'borrower', child: Text('Borrower')),
                          ],
                          onChanged: (val) => setState(() => _role = val ?? 'lender'),
                          decoration: InputDecoration(
                            labelText: 'Your Role',
                            prefixIcon: Icon(Icons.people, color: Color(0xFF00B4D8)),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Action buttons
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey[700], fontSize: 16),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: StatefulBuilder(
                      builder: (BuildContext context, StateSetter setState) {
                        return ElevatedButton(
                          onPressed: _isLoading ? null : () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                _isLoading = true;
                              });
                              final session = Provider.of<SessionProvider>(context, listen: false);
                              final token = session.token;
                              final url = isEditing
                                  ? '${ApiConfig.baseUrl}/api/quick-transactions/${widget.transaction!['_id']}'
                                  : '${ApiConfig.baseUrl}/api/quick-transactions';

                              final body = {
                                'amount': _amountController.text,
                                'currency': _currency,
                                'description': _descriptionController.text,
                                'counterpartyEmail': _counterpartyEmailController.text,
                                'role': _role,
                                'date': DateTime.now().toIso8601String(),
                                'time': TimeOfDay.now().format(context),
                              };

                              final res = isEditing
                                  ? await http.put(Uri.parse(url), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: json.encode(body))
                                  : await http.post(Uri.parse(url), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: json.encode(body));

                              if (res.statusCode == 200 || res.statusCode == 201) {
                                Navigator.pop(context, true);
                              } else {
                                final error = json.decode(res.body)['error'];
                                Navigator.pop(context, error);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF00B4D8),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                              : Text(
                                  isEditing ? 'Update' : 'Create',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        );
                      },
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

  Widget _buildStylishField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(
        size.width * 0.25, size.height, size.width * 0.5, size.height * 0.7);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.4, size.width, size.height * 0.7);
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
    path.moveTo(0, size.height * 0.3);
    path.quadraticBezierTo(
        size.width * 0.25, 0, size.width * 0.5, size.height * 0.3);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.6, size.width, size.height * 0.3);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}