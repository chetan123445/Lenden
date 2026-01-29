import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../api_config.dart';
import '../profile/edit_profile_page.dart';
import 'dart:async';
import '../otp_input.dart';
import '../utils/api_client.dart';
import '../Transaction/transaction_page.dart';
import '../Transaction/user_transactions_page.dart';
import '../Transaction/analytics_page.dart';
import '../user/notes_page.dart';
import '../Transaction/group_transaction_page.dart';
import '../Transaction/view_group_transactions_page.dart';
import '../profile/profile_page.dart';
import 'ratings_page.dart';
import 'activity_page.dart';
import 'help_support_page.dart';
import 'feedback.dart';
import 'notifications_page.dart';
import '../widgets/notification_icon.dart';
import '../Digitise/subscriptions_page.dart';
import '../Transaction/quick_transactions_page.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> counterparties = [];
  bool loading = true;
  bool _counterpartiesLoading = true;
  int _imageRefreshKey = 0;
  final ScrollController _scrollController = ScrollController();

  bool _hasRatedApp = false;
  bool _ratingDialogShown = false;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, GlobalKey> _sectionKeys = {
    'quick_transactions': GlobalKey(),
    'transactions': GlobalKey(),
    'your_transactions': GlobalKey(),
    'analytics': GlobalKey(),
    'group_transaction': GlobalKey(),
    'view_group': GlobalKey(),
  };

  final List<Map<String, dynamic>> _carouselItems = [
    {
      'icon': Icons.account_balance_wallet,
      'label': 'Balance',
      'color': Colors.blue,
      'action': 'balance'
    },
    {
      'icon': Icons.history,
      'label': 'History',
      'color': Colors.orange,
      'action': 'history'
    },
    {
      'icon': Icons.favorite,
      'label': 'Favourites',
      'color': Colors.red,
      'action': 'favourites'
    },
    {
      'icon': Icons.local_offer,
      'label': 'Offers',
      'color': Colors.purple,
      'action': 'offers'
    },
    {
      'icon': Icons.share,
      'label': 'Refer',
      'color': Colors.green,
      'action': 'refer'
    },
    {
      'icon': Icons.star,
      'label': 'Ratings',
      'color': Colors.amber,
      'action': 'ratings'
    },
    {
      'icon': Icons.subscriptions,
      'label': 'Subscriptions',
      'color': Colors.red,
      'action': 'subscriptions'
    },
    {
      'icon': Icons.credit_card,
      'label': 'Credits',
      'color': Colors.blue,
      'action': 'credits'
    },
    {
      'icon': Icons.card_giftcard,
      'label': 'Gift Cards',
      'color': Colors.green,
      'action': 'gift_cards'
    },
  ];

  bool _isShowingLenDenCoin = false;

  void _showLenDenCoinsDialog(int coins) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
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
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Color(0xFFFCE4EC), // Light pink background
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LenDen Coins',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00B4D8),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.monetization_on, color: Colors.amber, size: 40),
                      SizedBox(width: 8),
                      Text(
                        '$coins',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('OK'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    fetchTransactions();
    _fetchCounterparties();
    _checkAndShowRatingDialog();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = Provider.of<SessionProvider>(context, listen: false);
      session.addListener(_onSessionChanged);
    });
  }

  @override
  void dispose() {
    final session = Provider.of<SessionProvider>(context, listen: false);
    session.removeListener(_onSessionChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    setState(() {
      _imageRefreshKey++;
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) return;

    final lowerQuery = query.toLowerCase();
    String? matchedSection;

    if (lowerQuery.contains('quick') || lowerQuery.contains('transaction')) {
      matchedSection = 'quick_transactions';
    } else if (lowerQuery.contains('create') || lowerQuery.contains('transaction')) {
      matchedSection = 'transactions';
    } else if (lowerQuery.contains('your') || lowerQuery.contains('detail')) {
      matchedSection = 'your_transactions';
    } else if (lowerQuery.contains('analytic') ||
        lowerQuery.contains('visual')) {
      matchedSection = 'analytics';
    } else if (lowerQuery.contains('group') && lowerQuery.contains('create')) {
      matchedSection = 'group_transaction';
    } else if (lowerQuery.contains('group') && lowerQuery.contains('view')) {
      matchedSection = 'view_group';
    }

    if (matchedSection != null &&
        _sectionKeys[matchedSection]?.currentContext != null) {
      Scrollable.ensureVisible(
        _sectionKeys[matchedSection]!.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> fetchTransactions() async {
    setState(() => loading = true);
    final res = await ApiClient.get('/api/transactions/me');
    setState(() {
      transactions = res.statusCode == 200
          ? List<Map<String, dynamic>>.from(jsonDecode(res.body))
          : [];
      loading = false;
    });
  }

  Future<void> _fetchCounterparties({bool forceRefresh = false}) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final now = DateTime.now();
    final lastFetched = session.counterpartiesLastFetched;

    if (!forceRefresh &&
        lastFetched != null &&
        now.difference(lastFetched).inMinutes < 5 &&
        session.counterparties != null) {
      setState(() {
        counterparties = session.counterparties!;
        _counterpartiesLoading = false;
      });
      return;
    }

    final email = session.user?['email'];
    if (email == null) {
      return;
    }
    try {
      final res = await ApiClient.get('/api/analytics/user?email=$email');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['topCounterparties'] != null) {
          List<Map<String, dynamic>> topCounterparties =
              List<Map<String, dynamic>>.from(data['topCounterparties']);

          // Fetch all profiles in parallel
          final profiles = await Future.wait(topCounterparties
              .map((cp) => _fetchCounterpartyProfile(cp['email']))); 

          List<Map<String, dynamic>> populatedCounterparties = [];
          for (int i = 0; i < topCounterparties.length; i++) {
            final profile = profiles[i];
            if (profile != null) {
              populatedCounterparties.add(profile);
            } else {
              populatedCounterparties.add(
                  {'email': topCounterparties[i]['email'], 'name': 'Unknown'});
            }
          }

          setState(() {
            counterparties = populatedCounterparties;
          });
          session.setCounterparties(populatedCounterparties);
        }
      }
    } catch (e) {
      // Handle error silently
    } finally {
      if (mounted) {
        setState(() {
          _counterpartiesLoading = false;
        });
      }
    }
  }

  void showTransactionForm() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => TransactionPage()));

  ImageProvider _getUserAvatar() {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final user = session.user;
    final gender = user?['gender'] ?? 'Other';
    final imageUrl = user?['profileImage'];

    if (imageUrl != null &&
        imageUrl is String &&
        imageUrl.trim().isNotEmpty &&
        imageUrl != 'null') {
      final cacheBustingUrl =
          '$imageUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      return NetworkImage(cacheBustingUrl);
    } else {
      return AssetImage(
        gender == 'Male'
            ? 'assets/Male.png'
            : gender == 'Female'
                ? 'assets/Female.png'
                : 'assets/Other.png',
      );
    }
  }

  Future<void> _checkAndShowRatingDialog() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    try {
      final res = await ApiClient.get('/api/rating/my');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _hasRatedApp = data['rating'] != null;
        });
        if (!_hasRatedApp &&
            !_ratingDialogShown &&
            (DateTime.now().millisecondsSinceEpoch % 3 == 0)) {
          _ratingDialogShown = true;
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) _showAppRatingDialog();
          });
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  void _showAppRatingDialog() {
    int _selectedStars = 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
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
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Color(0xFFFCE4EC), // Light pink background
                borderRadius: BorderRadius.circular(20),
              ),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Color(0xFF00B4D8), size: 48),
                      SizedBox(height: 12),
                      Text(
                        'Rate Our App!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00B4D8),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your feedback helps us improve.\nHow would you rate your experience?',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                      SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          return IconButton(
                            icon: Stack(
                              children: <Widget>[
                                Icon(
                                  Icons.star,
                                  color: i < _selectedStars
                                      ? Colors.amber
                                      : Colors.grey[300],
                                  size: 36,
                                ),
                                Icon(
                                  Icons.star_border,
                                  color: Colors.black,
                                  size: 36,
                                ),
                              ],
                            ),
                            onPressed: () {
                              setState(() => _selectedStars = i + 1);
                            },
                          );
                        }),
                      ),
                      SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('Close',
                                style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.bold)),
                          ),
                          ElevatedButton(
                            onPressed: _selectedStars > 0
                                ? () async {
                                    final res = await ApiClient.post(
                                      '/api/rating',
                                      body: {'rating': _selectedStars},
                                    );
                                    if (res.statusCode == 200) {
                                      setState(() {
                                        _hasRatedApp = true;
                                      });
                                      Navigator.of(ctx).pop();
                                      _showThankYouDialog();
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Failed to submit rating.')),
                                      );
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Text('Submit',
                                style: TextStyle(
                                    color: _selectedStars > 0
                                        ? Colors.black
                                        : Colors.grey[600],
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showThankYouDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Color(0xFFE0F7FA),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF00B4D8).withOpacity(0.15),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.celebration, color: Color(0xFF00B4D8), size: 60),
              SizedBox(height: 16),
              Text(
                'Thank You for Rating!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00B4D8),
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Your feedback means a lot to us.\nWe appreciate your support!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00B4D8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCarouselAction(String action) {
    switch (action) {
      case 'balance':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => AnalyticsPage()));
        break;
      case 'history':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => ActivityPage()));
        break;
      case 'favourites':
        _showFavouritesDialog();
        break;
      case 'offers':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offers coming soon!')),
        );
        break;
      case 'refer':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refer a friend coming soon!')),
        );
        break;
      case 'ratings':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const RatingsPage()));
        break;
      case 'subscriptions':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SubscriptionsPage()));
        break;
      case 'credits':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credits coming soon!')),
        );
        break;
      case 'gift_cards':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gift Cards coming soon!')),
        );
        break;
    }
  }

  void _showFavouritesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 16,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Color(0xFFE0F7FA),
                  Color(0xFFB2EBF2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'Favourites',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00796B),
                    ),
                  ),
                ),
                _buildFavouriteItem(
                  context,
                  icon: Icons.person,
                  text: 'Transaction',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserTransactionsPage(),
                        settings: RouteSettings(
                          arguments: {'showFavouritesOnly': true},
                        ),
                      ),
                    );
                  },
                ),
                _buildFavouriteItem(
                  context,
                  icon: Icons.group,
                  text: 'Groups',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupTransactionPage(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavouriteItem(BuildContext context,
      {required IconData icon,
      required String text,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Color(0xFF00796B)),
            SizedBox(width: 20),
            Text(
              text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF004D40),
              ),
            ),
            Spacer(),
            Icon(Icons.arrow_forward_ios, color: Color(0xFF00796B), size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final userId = session.user?['_id'];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, '/');
        }
      },
      child: Scaffold(
        drawer: Drawer(
          width: 200,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Color(0xFF00B4D8)),
                child: Text('Menu',
                    style: TextStyle(color: Colors.white, fontSize: 24)),
              ),
              ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text('Dashboard'),
                onTap: () {
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.pushNamed(context, '/settings');
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: const Text('Transaction Details'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => UserTransactionsPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.timeline),
                title: const Text('Activity'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ActivityPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.note),
                title: Text('Notes'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                      context, MaterialPageRoute(builder: (_) => NotesPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Ratings'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RatingsPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_center),
                title: const Text('Help & Support'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => HelpSupportPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.feedback),
                title: const Text('Feedback'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.pushNamed(context, '/feedback');
                },
              ),
              ListTile(
                leading: const Icon(Icons.subscriptions),
                title: const Text('Subscriptions'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SubscriptionsPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFF8F6FA),
        body: Stack(
          children: [
            // Main content
            SafeArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  top: 80,
                  bottom: 100,
                  left: 0,
                  right: 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search Bar with tricolor border
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
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
                                controller: _searchController,
                                onSubmitted: _performSearch,
                                decoration: InputDecoration(
                                  hintText: 'Search sections...',
                                  hintStyle: TextStyle(color: Colors.grey[400]),
                                  border: InputBorder.none,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                ),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.clear,
                                    color: Colors.grey[600], size: 20),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Quick Actions Grid
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildQuickActionItem(
                                icon: _carouselItems[0]['icon'] as IconData,
                                label: _carouselItems[0]['label'] as String,
                                color: _carouselItems[0]['color'] as Color,
                                onTap: () => _handleCarouselAction(
                                    _carouselItems[0]['action'] as String),
                                index: 0,
                              ),
                              _buildQuickActionItem(
                                icon: _carouselItems[1]['icon'] as IconData,
                                label: _carouselItems[1]['label'] as String,
                                color: _carouselItems[1]['color'] as Color,
                                onTap: () => _handleCarouselAction(
                                    _carouselItems[1]['action'] as String),
                                index: 1,
                              ),
                              _buildQuickActionItem(
                                icon: _carouselItems[2]['icon'] as IconData,
                                label: _carouselItems[2]['label'] as String,
                                color: _carouselItems[2]['color'] as Color,
                                onTap: () => _handleCarouselAction(
                                    _carouselItems[2]['action'] as String),
                                index: 2,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildQuickActionItem(
                                icon: _carouselItems[3]['icon'] as IconData,
                                label: _carouselItems[3]['label'] as String,
                                color: _carouselItems[3]['color'] as Color,
                                onTap: () => _handleCarouselAction(
                                    _carouselItems[3]['action'] as String),
                                index: 3,
                              ),
                              _buildQuickActionItem(
                                icon: _carouselItems[4]['icon'] as IconData,
                                label: _carouselItems[4]['label'] as String,
                                color: _carouselItems[4]['color'] as Color,
                                onTap: () => _handleCarouselAction(
                                    _carouselItems[4]['action'] as String),
                                index: 4,
                              ),
                              _buildQuickActionItem(
                                icon: _carouselItems[5]['icon'] as IconData,
                                label: _carouselItems[5]['label'] as String,
                                color: _carouselItems[5]['color'] as Color,
                                onTap: () => _handleCarouselAction(
                                    _carouselItems[5]['action'] as String),
                                index: 5,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildQuickActionItem(
                                icon: _carouselItems[6]['icon'] as IconData,
                                label: _carouselItems[6]['label'] as String,
                                color: _carouselItems[6]['color'] as Color,
                                onTap: () => _handleCarouselAction(
                                    _carouselItems[6]['action'] as String),
                                index: 6,
                              ),
                              _buildQuickActionItem(
                                icon: _carouselItems[7]['icon'] as IconData,
                                label: _carouselItems[7]['label'] as String,
                                color: _carouselItems[7]['color'] as Color,
                                onTap: () => _handleCarouselAction(
                                    _carouselItems[7]['action'] as String),
                                index: 7,
                              ),
                              _buildQuickActionItem(
                                icon: _carouselItems[8]['icon'] as IconData,
                                label: _carouselItems[8]['label'] as String,
                                color: _carouselItems[8]['color'] as Color,
                                onTap: () => _handleCarouselAction(
                                    _carouselItems[8]['action'] as String),
                                index: 8,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Counterparties section with tricolor border
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Colors.orange, Colors.white, Colors.green],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _getBoxColor(0),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.people,
                                        color: Color(0xFF00B4D8)),
                                    SizedBox(width: 8),
                                    const Text(
                                      'Top Counterparties',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF00B4D8),
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: Icon(Icons.refresh,
                                      color: Color(0xFF00B4D8)),
                                  onPressed: () =>
                                      _fetchCounterparties(forceRefresh: true),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildCounterpartiesGrid(userId),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Main action cards
                    GestureDetector(
                      key: _sectionKeys['quick_transactions'],
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuickTransactionsPage())),
                      child: Container(
                        margin:
                            EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.white, Colors.green],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: _getBoxColor(0),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.flash_on,
                                  color: Colors.amber, size: 40),
                              SizedBox(width: 20),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    'Quick Transactions',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      key: _sectionKeys['transactions'],
                      onTap: showTransactionForm,
                      child: Container(
                        margin:
                            EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.white, Colors.green],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: _getBoxColor(1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.swap_horiz,
                                  color: Colors.teal, size: 40),
                              SizedBox(width: 20),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    'Create Transactions',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      key: _sectionKeys['your_transactions'],
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => UserTransactionsPage())),
                      child: Container(
                        margin:
                            EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.white, Colors.green],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: _getBoxColor(2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.account_balance_wallet,
                                  color: Colors.blue, size: 40),
                              SizedBox(width: 20),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    'Your Transactions',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      key: _sectionKeys['analytics'],
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => AnalyticsPage())),
                      child: Container(
                        margin:
                            EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.white, Colors.green],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: _getBoxColor(3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.analytics,
                                  color: Color(0xFF00B4D8), size: 40),
                              SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Text(
                                        'Visual Analytics',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22),
                                      ),
                                    ),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Text(
                                        '(for individual transactions)',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
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

                    SizedBox(height: 20),
                    GestureDetector(
                      key: _sectionKeys['group_transaction'],
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => GroupTransactionPage())),
                      child: Container(
                        margin:
                            EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.white, Colors.green],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: _getBoxColor(4),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.group,
                                  color: Colors.deepPurple, size: 40),
                              SizedBox(width: 20),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    'Create Group Transaction',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      key: _sectionKeys['view_group'],
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ViewGroupTransactionsPage())),
                      child: Container(
                        margin:
                            EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.white, Colors.green],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: _getBoxColor(5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.visibility,
                                  color: Colors.orange, size: 40),
                              SizedBox(width: 20),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    'View Group Transactions',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22),
                                  ),
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
            ),

            // Top blue wave
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipPath(
                clipper: TopWaveClipper(),
                child: Container(
                  height: 80,
                  color: const Color(0xFF00B4D8),
                ),
              ),
            ),

            // Bottom blue wave
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipPath(
                clipper: BottomWaveClipper(),
                child: Container(
                  height: 90,
                  color: const Color(0xFF00B4D8),
                ),
              ),
            ),

            // Header section
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Container(
                      height: 60,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back,
                                    color: Colors.black),
                                onPressed: () async {
                                  final popped =
                                      await Navigator.of(context).maybePop();
                                  if (!popped && context.mounted) {
                                    Navigator.pushReplacementNamed(
                                        context, '/');
                                  }
                                },
                              ),
                              Builder(
                                builder: (context) => IconButton(
                                  icon: const Icon(Icons.menu,
                                      color: Colors.black),
                                  onPressed: () =>
                                      Scaffold.of(context).openDrawer(),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              NotificationIcon(),
                              GestureDetector(
                                onTap: () {
                                  final session = Provider.of<SessionProvider>(context, listen: false);
                                  _showLenDenCoinsDialog(session.lenDenCoins ?? 0);
                                },
                                child: Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                              ),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.orange,
                                      Colors.white,
                                      Colors.green
                                    ],
                                  ),
                                ),
                                child: GestureDetector(
                                  onTap: () async {
                                    try {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const ProfilePage()),
                                      );
                                      final session =
                                          Provider.of<SessionProvider>(context,
                                              listen: false);
                                      await session.forceRefreshProfile();
                                      setState(() {
                                        _imageRefreshKey++;
                                      });
                                    } catch (e) {
                                      print('Error navigating to profile: $e');
                                    }
                                  },
                                  child: CircleAvatar(
                                    key: ValueKey(_imageRefreshKey),
                                    radius: 16,
                                    backgroundColor: Colors.white,
                                    backgroundImage: _getUserAvatar(),
                                    onBackgroundImageError:
                                        (exception, stackTrace) {},
                                    child: _getUserAvatar() is AssetImage
                                        ? Icon(
                                            Icons.person,
                                            color: Colors.grey[400],
                                            size: 20,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout,
                                    color: Colors.black, size: 28),
                                tooltip: 'Logout',
                                onPressed: () => _confirmLogout(context),
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
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required int index,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(2), // Border width
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.white, Colors.green],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getBoxColor(index),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterpartiesGrid(String? userId) {
    if (_counterpartiesLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text(
                'Fetching counterparties...', 
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (counterparties.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No counterparties yet',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return SizedBox(
      height: 150.0, // Height for two rows
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          alignment: WrapAlignment.center,
          children: counterparties.map((counterparty) {
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 64) / 3 - 8,
              child: _buildCounterpartyCard(counterparty),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCounterpartyCard(Map<String, dynamic> counterparty) {
    final name = counterparty['name'] ?? 'Unknown';
    final imageUrl = counterparty['profileImage'];
    final gender = counterparty['gender'] ?? 'Other';
    final isPrivate = counterparty['profileIsPrivate'] == true;
    final isDeactivated = counterparty['deactivatedAccount'] == true;

    ImageProvider avatarImage;
    if (imageUrl != null &&
        imageUrl is String &&
        imageUrl.trim().isNotEmpty &&
        imageUrl != 'null') {
      avatarImage = NetworkImage(imageUrl);
    } else {
      avatarImage = AssetImage(
        gender == 'Male'
            ? 'assets/Male.png'
            : gender == 'Female'
                ? 'assets/Female.png'
                : 'assets/Other.png',
      );
    }

    return GestureDetector(
      onTap: () {
        if (isPrivate || isDeactivated) {
          showDialog(
            context: context,
            builder: (_) => _PrivateProfileDialog(
              name: name,
              isPrivate: isPrivate,
              isDeactivated: isDeactivated,
              avatarProvider: avatarImage,
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (_) => _StylishProfileDialog(
              title: 'Counterparty',
              name: name,
              avatarProvider: avatarImage,
              email: counterparty['email'],
              phone: counterparty['phone']?.toString(),
              gender: gender,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Colors.orange, Colors.white, Colors.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[300],
                backgroundImage: avatarImage,
                onBackgroundImageError: (_, __) {},
              ),
              const SizedBox(height: 4),
              Text(
                name.length > 8 ? '${name.substring(0, 8)}...' : name,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchCounterpartyProfile(String email) async {
    if (email.isEmpty) return null;
    try {
      final res = await ApiClient.get(
        '/api/users/profile-by-email?email=$email',
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _confirmLogout(BuildContext context) async {
    bool isLoggingOut = false;

    final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
              builder: (context, setState) => Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: ClipPath(
                          clipper: LogoutWaveClipper(),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF00B4D8), Color(0xFF0096CC)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            if (isLoggingOut) ...[
                              CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF00B4D8),
                                ),
                              ),
                              SizedBox(height: 20),
                              Text(
                                'Logging out...', 
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else ...[
                              Text(
                                'Are you sure?',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Do you want to logout?',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 32),
                              Row(
                                mainAxisAlignment: 
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: Container(
                                      margin: EdgeInsets.only(right: 8),
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[100],
                                          foregroundColor: Colors.grey[700],
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            side: BorderSide(
                                                color: Colors.grey[300]!),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                              vertical: 16),
                                          elevation: 0,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: 
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.close, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'NO',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      margin: EdgeInsets.only(left: 8),
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          setState(() {
                                            isLoggingOut = true;
                                          });

                                          await Provider.of<SessionProvider>(
                                                  context,
                                                  listen: false)
                                              .logout();

                                          Navigator.of(context).pop(true);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF00B4D8),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                              vertical: 16),
                                          elevation: 2,
                                          shadowColor: Color(0xFF00B4D8)
                                              .withOpacity(0.3),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: 
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.logout, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'YES',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ));

    if (confirmed == true && context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
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

class LogoutWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.8, size.width * 0.5, size.height);
    path.quadraticBezierTo(
        size.width * 0.25, size.height * 0.8, 0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _PrivateProfileDialog extends StatelessWidget {
  final String name;
  final bool isPrivate;
  final bool isDeactivated;
  final ImageProvider avatarProvider;

  const _PrivateProfileDialog({
    required this.name,
    required this.isPrivate,
    required this.isDeactivated,
    required this.avatarProvider,
  });

  @override
  Widget build(BuildContext context) {
    String message;
    IconData icon;

    if (isDeactivated) {
      message = 'This user account is deactivated.';
      icon = Icons.visibility_off;
    } else if (isPrivate) {
      message = 'This user\'s profile is private.';
      icon = Icons.lock;
    } else {
      message = 'This profile is not available.';
      icon = Icons.error;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color(0xFF00B4D8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                CircleAvatar(radius: 36, backgroundImage: avatarProvider),
                SizedBox(height: 12),
                Text(name,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Colors.white)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: Colors.teal),
                SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00B4D8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ],
      ),
    );
  }
}

class _StylishProfileDialog extends StatelessWidget {
  final String title;
  final String name;
  final ImageProvider avatarProvider;
  final String? email;
  final String? phone;
  final String? gender;
  const _StylishProfileDialog(
      {required this.title,
      required this.name,
      required this.avatarProvider,
      this.email,
      this.phone,
      this.gender});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color(0xFF00B4D8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                CircleAvatar(radius: 36, backgroundImage: avatarProvider),
                SizedBox(height: 12),
                Text(name,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Colors.white)),
                SizedBox(height: 4),
                Text(title,
                    style: TextStyle(fontSize: 14, color: Colors.white70)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (email != null) ...[
                  Row(children: [ 
                    Icon(Icons.email, size: 18, color: Colors.teal),
                    SizedBox(width: 8),
                    Text(email!, style: TextStyle(fontSize: 16))]
                  ),
                  SizedBox(height: 10), 
                ],
                if (phone != null && phone!.isNotEmpty) ...[
                  Row(children: [ 
                    Icon(Icons.phone, size: 18, color: Colors.teal),
                    SizedBox(width: 8),
                    Text(phone!, style: TextStyle(fontSize: 16))]
                  ),
                  SizedBox(height: 10), 
                ],
                if (gender != null) ...[
                  Row(children: [ 
                    Icon(Icons.transgender, size: 18, color: Colors.teal),
                    SizedBox(width: 8),
                    Text(gender!, style: TextStyle(fontSize: 16))]
                  ),
                  SizedBox(height: 10), 
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00B4D8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ],
      ),
    );
  }
}

Color _getBoxColor(int index) {
  // Returns alternating soft colors for visual variety
  final colors = [
    Color(0xFFE8F5E9), // Soft green
    Color(0xFFFFF8E7), // Soft cream
    Color(0xFFF3E5F5), // Soft purple
    Color(0xFFE8F5F7), // Soft blue
    Color(0xFFFCE4EC), // Soft pink
    Color(0xFFFFF3E0), // Soft orange
  ];
  return colors[index % colors.length];
}