import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../session.dart';
import '../Support/notes_page.dart';
import '../../profile/profile_page.dart';
import '../Transactions/manage_secure_transactions_page.dart';
import '../Manage_users/user_management_page.dart';
import '../Transactions/manage_group_transactions_page.dart';
import '../Track user/track_user_activity_page.dart';
import '../Support/manage_contact_page.dart';
import '../Support/manage_support_queries_page.dart';
import '../../widgets/notification_icon.dart';
import '../Digitise/manage_subscriptions_page.dart';
import '../Digitise/manage_gift_cards_page.dart';
import '../Digitise/manage_referral_settings_page.dart';
import '../Digitise/manage_offers_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _imageRefreshKey = 0; // Key to force avatar rebuild
  bool _useCompactAdminOptions = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, GlobalKey> _sectionKeys = {
    'manage_users': GlobalKey(),
    'manage_transactions': GlobalKey(),
    'notes': GlobalKey(),
    'manage_groups': GlobalKey(),
    'track_user_activity': GlobalKey(),
    'manage_features': GlobalKey(),
    'manage_gift_cards': GlobalKey(),
    'referral_settings': GlobalKey(),
    'manage_offers': GlobalKey(),
    'contact_settings': GlobalKey(),
    'app_ratings': GlobalKey(),
    'user_feedbacks': GlobalKey(),
  };

  @override
  void initState() {
    super.initState();

    // Listen to session changes to refresh profile image
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

  List<_AdminDashboardItem> _dashboardItems(BuildContext context) => [
        _AdminDashboardItem(
          id: 'manage_users',
          icon: Icons.people_alt_rounded,
          label: 'Manage Users',
          caption: 'Review and control user accounts',
          actionLabel: 'Users',
          backgroundColor: const Color(0xFFEDEBFA),
          iconColor: const Color(0xFF304E96),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserManagementPage()),
            );
          },
        ),
        _AdminDashboardItem(
          id: 'manage_transactions',
          icon: Icons.receipt_long_rounded,
          label: 'Manage Secure Transactions',
          caption: 'Inspect and control secure records',
          actionLabel: 'Secure',
          backgroundColor: const Color(0xFFE8F4EC),
          iconColor: const Color(0xFF1E6B3B),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ManageTransactionsPage()),
            );
          },
        ),
        _AdminDashboardItem(
          id: 'notes',
          icon: Icons.route_rounded,
          label: 'Notes',
          caption: 'Open internal notes and references',
          actionLabel: 'Notes',
          backgroundColor: const Color(0xFFF5EAF4),
          iconColor: const Color(0xFF8A2F7B),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminNotesPage()),
            );
          },
        ),
        _AdminDashboardItem(
          id: 'manage_groups',
          icon: Icons.group_work_rounded,
          label: 'Manage Groups',
          caption: 'Handle group activity and expenses',
          actionLabel: 'Groups',
          backgroundColor: const Color(0xFFF3F2E8),
          iconColor: const Color(0xFF8B7A30),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ManageGroupTransactionsPage()),
            );
          },
        ),
        _AdminDashboardItem(
          id: 'track_user_activity',
          icon: Icons.insights_rounded,
          label: 'Track User Activity',
          caption: 'Monitor user-side platform behaviour',
          actionLabel: 'Track',
          backgroundColor: const Color(0xFFE8F2FB),
          iconColor: const Color(0xFF1D5D91),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TrackUserActivityPage()),
            );
          },
        ),
        _AdminDashboardItem(
          id: 'manage_features',
          icon: Icons.tune_rounded,
          label: 'Manage Features',
          caption: 'Adjust admin-side product controls',
          actionLabel: 'Features',
          backgroundColor: const Color(0xFFEAF6F0),
          iconColor: const Color(0xFF296D4E),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AdminFeaturesPage()),
            );
          },
        ),
        _AdminDashboardItem(
          id: 'manage_gift_cards',
          icon: Icons.card_giftcard_rounded,
          label: 'Manage Gift Cards',
          caption: 'Create and control gift card inventory',
          actionLabel: 'Cards',
          backgroundColor: const Color(0xFFFCEFE4),
          iconColor: const Color(0xFF9B5B21),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ManageGiftCardsPage()),
            );
          },
        ),
        _AdminDashboardItem(
          id: 'referral_settings',
          icon: Icons.share_rounded,
          label: 'Referral Settings',
          caption: 'Tune referral rewards and flows',
          actionLabel: 'Referral',
          backgroundColor: const Color(0xFFEAF0FF),
          iconColor: const Color(0xFF405FB5),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ReferralSettingsPage(),
              ),
            );
          },
        ),
        _AdminDashboardItem(
          id: 'manage_offers',
          icon: Icons.local_offer_rounded,
          label: 'Manage Offers',
          caption: 'Publish and update admin offers',
          actionLabel: 'Offers',
          backgroundColor: const Color(0xFFF4EAF0),
          iconColor: const Color(0xFF8C2C62),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageOffersPage()),
            );
          },
        ),
        _AdminDashboardItem(
          id: 'contact_settings',
          icon: Icons.contact_phone_rounded,
          label: 'Contact Settings',
          caption: 'Update support and contact details',
          actionLabel: 'Contact',
          backgroundColor: const Color(0xFFE8F7FA),
          iconColor: const Color(0xFF0B8FAC),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManageContactPage()),
            );
          },
        ),
        _AdminDashboardItem(
          id: 'app_ratings',
          icon: Icons.star_rounded,
          label: 'App Ratings',
          caption: 'Review ratings coming from the app',
          actionLabel: 'Ratings',
          backgroundColor: const Color(0xFFF7F2E8),
          iconColor: const Color(0xFF8B6E24),
          onTap: () {
            Navigator.pushNamed(context, '/admin/ratings');
          },
        ),
        _AdminDashboardItem(
          id: 'user_feedbacks',
          icon: Icons.feedback_rounded,
          label: 'User Feedbacks',
          caption: 'Read submitted feedback and issues',
          actionLabel: 'Feedback',
          backgroundColor: const Color(0xFFEAF5F8),
          iconColor: const Color(0xFF236D86),
          onTap: () {
            Navigator.pushNamed(context, '/admin/feedbacks');
          },
        ),
      ];

  String _normalizeSearch(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  bool _isSubsequence(String query, String target) {
    int qi = 0;
    for (int i = 0; i < target.length && qi < query.length; i++) {
      if (target[i] == query[qi]) {
        qi++;
      }
    }
    return qi == query.length;
  }

  int _matchScore(String query, String label) {
    final normalizedQuery = _normalizeSearch(query);
    final normalizedLabel = _normalizeSearch(label);
    if (normalizedQuery.isEmpty) return -1;
    if (normalizedLabel == normalizedQuery) return 100;
    if (normalizedLabel.startsWith(normalizedQuery)) return 80;
    if (normalizedLabel.contains(normalizedQuery)) return 70;

    final queryWords = normalizedQuery.split(' ').where((w) => w.isNotEmpty);
    int score = 0;
    for (final word in queryWords) {
      if (normalizedLabel.contains(word)) {
        score += 20;
      } else if (_isSubsequence(word, normalizedLabel.replaceAll(' ', ''))) {
        score += 8;
      }
    }

    if (_isSubsequence(
      normalizedQuery.replaceAll(' ', ''),
      normalizedLabel.replaceAll(' ', ''),
    )) {
      score += 12;
    }

    return score;
  }

  void _performSearch(String query) {
    final items = _dashboardItems(context);
    if (query.trim().isEmpty) return;

    _AdminDashboardItem? bestMatch;
    int bestScore = -1;

    for (final item in items) {
      final score = _matchScore(query, item.label);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = item;
      }
    }

    if (bestMatch != null && bestScore >= 8) {
      final targetContext = _sectionKeys[bestMatch.id]?.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.15,
        );
      }
    }
  }

  // Helper function to get admin's profile image
  ImageProvider _getAdminAvatar() {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final user = session.user;
    final gender = user?['gender'] ?? 'Other';
    final imageUrl = user?['profileImage'];

    if (imageUrl != null &&
        imageUrl is String &&
        imageUrl.trim().isNotEmpty &&
        imageUrl != 'null') {
      // Add cache busting parameter for real-time updates
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

  @override
  Widget build(BuildContext context) {
    final dashboardItems = _dashboardItems(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
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
                  Navigator.of(context).pop(); // Close drawer
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.pushNamed(context, '/admin/settings');
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_center),
                title: const Text('Help & Support'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ManageSupportQueriesPage()));
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
            // Main content area
            SafeArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [Colors.orange, Colors.white, Colors.green],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: (value) {
                            if (value.trim().length >= 2) {
                              _performSearch(value);
                            }
                          },
                          onSubmitted: _performSearch,
                          decoration: InputDecoration(
                            hintText: 'Search admin sections',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF00B4D8),
                            ),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admin Options',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Switch between detailed cards or compact admin grid.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.center,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.orange,
                                    Colors.white,
                                    Colors.green
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildAdminLayoutChip(
                                      label: 'Single View',
                                      selected: !_useCompactAdminOptions,
                                      onTap: () {
                                        setState(() {
                                          _useCompactAdminOptions = false;
                                        });
                                      },
                                    ),
                                    _buildAdminLayoutChip(
                                      label: 'Grid View',
                                      selected: _useCompactAdminOptions,
                                      onTap: () {
                                        setState(() {
                                          _useCompactAdminOptions = true;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildAdminOptionsLayout(dashboardItems),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Top blue shape (background)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipPath(
                clipper: TopWaveClipper(),
                child: Container(
                  height: 60,
                  color: const Color(0xFF00B4D8),
                ),
              ),
            ),
            // Bottom blue shape (background)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipPath(
                clipper: DashboardBottomWaveClipper(),
                child: Container(
                  height: 45,
                  color: const Color(0xFF00B4D8),
                ),
              ),
            ),
            // Header buttons overlay (on top)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
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
                                Navigator.pushReplacementNamed(context, '/');
                              }
                            },
                          ),
                          Builder(
                            builder: (context) => IconButton(
                              icon: const Icon(Icons.menu, color: Colors.black),
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
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const ProfilePage()),
                              );
                              final session = Provider.of<SessionProvider>(
                                  context,
                                  listen: false);
                              await session.forceRefreshProfile();
                              setState(() {
                                _imageRefreshKey++;
                              });
                            },
                            child: CircleAvatar(
                              key: ValueKey(_imageRefreshKey),
                              radius: 16,
                              backgroundColor: Colors.white,
                              backgroundImage: _getAdminAvatar(),
                              onBackgroundImageError:
                                  (exception, stackTrace) {},
                              child: _getAdminAvatar() is AssetImage
                                  ? Icon(
                                      Icons.person,
                                      color: Colors.grey[400],
                                      size: 20,
                                    )
                                  : null,
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required _AdminDashboardItem item,
    required bool showCaption,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.white, Colors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: item.onTap,
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: item.backgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SizedBox(
              height: 150,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      child: Icon(
                        item.icon,
                        color: item.iconColor,
                        size: 22,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.actionLabel,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: item.iconColor,
                      ),
                    ),
                    if (showCaption) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          height: 1.25,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminOptionsLayout(List<_AdminDashboardItem> items) {
    if (_useCompactAdminOptions) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final itemWidth = (width - 16) / 2;

          return Wrap(
            spacing: 16,
            runSpacing: 24,
            children: items.map((item) {
              return SizedBox(
                key: _sectionKeys[item.id],
                width: itemWidth,
                child: _buildDashboardCard(
                  context,
                  item: item,
                  showCaption: false,
                ),
              );
            }).toList(),
          );
        },
      );
    }

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: SizedBox(
            key: _sectionKeys[item.id],
            width: double.infinity,
            child: _buildDashboardCard(
              context,
              item: item,
              showCaption: true,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAdminLayoutChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? const Color(0xFF00B4D8) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF00B4D8),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
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
                  clipper: LogoutDialogWaveClipper(),
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
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Container(
                            margin: EdgeInsets.only(right: 8),
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[100],
                                foregroundColor: Colors.grey[700],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey[300]!),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                              onPressed: () => Navigator.of(context).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF00B4D8),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 16),
                                elevation: 2,
                                shadowColor:
                                    Color(0xFF00B4D8).withValues(alpha: 0.3),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) {
      await Provider.of<SessionProvider>(context, listen: false).logout();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}

class _AdminDashboardItem {
  final String id;
  final IconData icon;
  final String label;
  final String caption;
  final String actionLabel;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _AdminDashboardItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.caption,
    required this.actionLabel,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });
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

class DashboardBottomWaveClipper extends CustomClipper<Path> {
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

class LogoutDialogWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);

    // Create wavy effect
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
