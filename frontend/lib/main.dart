import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'Login/login_page.dart';
import 'Register/register_page.dart';
import 'password/forgot_password_page.dart';
import 'user/dashboard.dart';
import 'admin/dashboard.dart';
import 'profile/profile_page.dart';
import 'user/session.dart';
import 'settings/settings_page.dart';
import 'settings/admin_settings_page.dart';
import 'contact_page.dart';
import 'admin/manage_and_track_users/user_management_page.dart';
import 'admin/manage_transactions_page.dart';
import 'admin/manage_group_transactions_page.dart';
import 'splash_screen.dart';
import 'user/feedback.dart'; // Import the feedback page
import 'admin/admin_ratings_page.dart';
import 'admin/admin_feedbacks_page.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SessionProvider()),
      ],
      child: const AppInitializer(),
    ),
  );
}

class AppInitializer extends StatelessWidget {
  const AppInitializer({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lenden App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFFF8F6FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/main': (context) => const MyApp(),
        '/login': (context) => const UserLoginPage(),
        '/register': (context) => const UserRegisterPage(),
        '/forgot-password': (context) => const UserForgotPasswordPage(),
        '/user/dashboard': (context) => const UserDashboardPage(),
        '/admin/dashboard': (context) => const AdminDashboardPage(),
        '/profile': (context) => const ProfilePage(),
        '/settings': (context) => const SettingsPage(),
        '/admin/settings': (context) => const AdminSettingsPage(),
        '/admin/manage-users': (context) => const UserManagementPage(),
        '/admin/manage-transactions': (context) => ManageTransactionsPage(),
        '/admin/manage-group-transactions': (context) =>
            ManageGroupTransactionsPage(),
        '/feedback': (context) => const FeedbackPage(),
        '/admin/ratings': (context) => const AdminRatingsPage(),
        '/admin/feedbacks': (context) => const AdminFeedbacksPage(),
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future:
          Provider.of<SessionProvider>(context, listen: false).initSession(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF00B4D8),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        final session = Provider.of<SessionProvider>(context);
        // Always show HomePage (main.dart) as the root after splash
        return HomePage();
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF8F6FA),
      drawer: Drawer(
        width: 200,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF00B4D8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/icon.png', width: 48, height: 48),
                  const SizedBox(height: 8),
                  const Text('Lenden App',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Login'),
              onTap: () {
                final session =
                    Provider.of<SessionProvider>(context, listen: false);
                if (session.token != null && session.user != null) {
                  if (session.isAdmin) {
                    Navigator.pushReplacementNamed(context, '/admin/dashboard');
                  } else {
                    Navigator.pushReplacementNamed(context, '/user/dashboard');
                  }
                } else {
                  Navigator.pushNamed(context, '/login');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Register'),
              onTap: () => Navigator.pushNamed(context, '/register'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.contact_mail),
              title: const Text('Contact'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactPage()),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Top blue wave
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopWaveClipper(),
              child: Container(
                height: 120,
                color: const Color(0xFF00B4D8),
              ),
            ),
          ),
          // Bottom blue wave
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
          // Main content area (white card style)
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 24.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Menu icon (left)
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                        // Right side: notification and profile
                        Row(
                          children: [
                            // Notification bell
                            Consumer<SessionProvider>(
                              builder: (context, session, _) => IconButton(
                                icon: Icon(Icons.notifications_none,
                                    color: Colors.white),
                                onPressed: () {
                                  if (session.token != null &&
                                      session.user != null) {
                                    // TODO: Navigate to notifications page if exists
                                  } else {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                        ),
                                        backgroundColor:
                                            const Color(0xFFF6F7FB),
                                        elevation: 12,
                                        title: Row(
                                          children: [
                                            Icon(Icons.lock_outline,
                                                color: Color(0xFF00B4D8),
                                                size: 28),
                                            SizedBox(width: 10),
                                            Text('Login Required',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 22)),
                                          ],
                                        ),
                                        content: Text(
                                          'Please login to view notifications.',
                                          style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87),
                                        ),
                                        actions: [
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              backgroundColor:
                                                  Color(0xFF00B4D8),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 18, vertical: 6),
                                              child: Text('OK',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            // Profile picture or icon
                            Consumer<SessionProvider>(
                              builder: (context, session, _) {
                                final user = session.user;
                                final profileImage = user != null &&
                                        user['profileImage'] != null &&
                                        user['profileImage']
                                            .toString()
                                            .isNotEmpty &&
                                        user['profileImage'] != 'null'
                                    ? NetworkImage(user['profileImage'])
                                    : null;
                                return GestureDetector(
                                  onTap: () {
                                    if (session.token != null &&
                                        session.user != null) {
                                      Navigator.pushNamed(context, '/profile');
                                    } else {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(24),
                                          ),
                                          backgroundColor:
                                              const Color(0xFFF6F7FB),
                                          elevation: 12,
                                          title: Row(
                                            children: [
                                              Icon(Icons.lock_outline,
                                                  color: Color(0xFF00B4D8),
                                                  size: 28),
                                              SizedBox(width: 10),
                                              Text('Login Required',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 22)),
                                            ],
                                          ),
                                          content: Text(
                                            'Please login to view your profile.',
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.black87),
                                          ),
                                          actions: [
                                            TextButton(
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                backgroundColor:
                                                    Color(0xFF00B4D8),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 18,
                                                    vertical: 6),
                                                child: Text('OK',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    child: profileImage != null
                                        ? CircleAvatar(
                                            backgroundImage: profileImage,
                                            radius: 18,
                                          )
                                        : const CircleAvatar(
                                            backgroundColor: Color(0xFF00B4D8),
                                            radius: 18,
                                            child: Icon(Icons.person,
                                                color: Colors.white),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Feature cards (auto-scroll, round, with border)
                    SizedBox(
                      height: 160,
                      child: _FeatureCardCarousel(),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/icon.png',
                            width: 120,
                            height: 120,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.account_balance_wallet,
                                    size: 100, color: Color(0xFF00B4D8)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Center(
                      child: Text('Welcome to Lenden',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 28),
                    // ...removed testimonial carousel...
                    ElevatedButton.icon(
                      onPressed: () {
                        final session = Provider.of<SessionProvider>(context,
                            listen: false);
                        if (session.token != null && session.user != null) {
                          if (session.isAdmin) {
                            Navigator.pushNamed(context, '/admin/dashboard');
                          } else {
                            Navigator.pushNamed(context, '/user/dashboard');
                          }
                        } else {
                          Navigator.pushNamed(context, '/login');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B4D8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: const BorderSide(
                              color: Color(0xFF0077B6), width: 2.5),
                        ),
                        elevation: 6,
                        shadowColor: const Color(0xFF00B4D8).withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 32),
                      ),
                      icon:
                          const Icon(Icons.arrow_forward, color: Colors.white),
                      label: const Text('Get Started',
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 18),
                    Consumer<SessionProvider>(
                      builder: (context, session, _) {
                        if (session.token == null || session.user == null) {
                          return OutlinedButton.icon(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/register'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Color(0xFF00B4D8), width: 2.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 32),
                              backgroundColor: Colors.white,
                              elevation: 4,
                              shadowColor:
                                  const Color(0xFF00B4D8).withOpacity(0.2),
                            ),
                            icon: const Icon(Icons.arrow_forward,
                                color: Color(0xFF00B4D8)),
                            label: const Text('Register',
                                style: TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFF00B4D8),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2)),
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    ),
                    const SizedBox(height: 28),
                    // ...existing code...
                    const SizedBox(height: 18),
                    // ...existing code...
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _FeatureCard(
      {required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Color(0xFF00B4D8),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Color(0xFF00B4D8), size: 32),
          const SizedBox(height: 10),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              description,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Feature card carousel with auto-scroll and round effect
class _FeatureCardCarousel extends StatefulWidget {
  @override
  State<_FeatureCardCarousel> createState() => _FeatureCardCarouselState();
}

class _FeatureCardCarouselState extends State<_FeatureCardCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.6);
  int _currentPage = 0;
  final List<Map<String, dynamic>> _features = [
    {
      'icon': Icons.swap_horiz,
      'title': 'One-to-One',
      'description': 'Direct lending and borrowing between users.'
    },
    {
      'icon': Icons.groups,
      'title': 'Group Transactions',
      'description': 'Manage and settle group transactions easily.'
    },
    {
      'icon': Icons.event_note,
      'title': 'Activities',
      'description': 'Track all your lending and borrowing activities.'
    },
    {
      'icon': Icons.note,
      'title': 'Notes',
      'description': 'Add notes to your transactions for better tracking.'
    },
    {
      'icon': Icons.security,
      'title': 'Secure',
      'description': 'Your data is protected with top security.'
    },
    {
      'icon': Icons.flash_on,
      'title': 'Fast',
      'description': 'Quick transactions and instant notifications.'
    },
    {
      'icon': Icons.people,
      'title': 'Community',
      'description': 'Connect with trusted users.'
    },
    {
      'icon': Icons.support_agent,
      'title': 'Support',
      'description': '24/7 customer support.'
    },
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), _autoScroll);
  }

  void _autoScroll() {
    if (!mounted) return;
    int nextPage = _currentPage + 1;
    if (nextPage >= _features.length) nextPage = 0;
    _controller.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
    setState(() => _currentPage = nextPage);
    Future.delayed(const Duration(milliseconds: 1800), _autoScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: _features.length,
      onPageChanged: (i) => setState(() => _currentPage = i),
      itemBuilder: (context, i) {
        final feature = _features[i];
        final isActive = i == _currentPage;
        return Transform.scale(
          scale: isActive ? 1.08 : 0.92,
          child: Opacity(
            opacity: isActive ? 1 : 0.7,
            child: _FeatureCard(
              icon: feature['icon'],
              title: feature['title'],
              description: feature['description'],
            ),
          ),
        );
      },
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
