import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lenden_frontend/user/session.dart';
import 'notes_page.dart';
import '../profile/profile_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _imageRefreshKey = 0; // Key to force avatar rebuild

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
    super.dispose();
  }

  void _onSessionChanged() {
    setState(() {
      _imageRefreshKey++;
    });
  }

  // Helper function to get admin's profile image
  ImageProvider _getAdminAvatar() {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final user = session.user;
    final gender = user?['gender'] ?? 'Other';
    final imageUrl = user?['profileImage'];
    
    print('🖼️ Admin Dashboard - _getAdminAvatar called:');
    print('   User: ${user != null ? 'Present' : 'Missing'}');
    print('   User data: $user');
    print('   Gender: $gender');
    print('   Profile image URL: $imageUrl');
    print('   Image URL type: ${imageUrl.runtimeType}');
    print('   Image URL is null: ${imageUrl == null}');
    print('   Image URL is empty: ${imageUrl == ""}');
    print('   Image URL is "null": ${imageUrl == "null"}');
    
    if (imageUrl != null && imageUrl is String && imageUrl.trim().isNotEmpty && imageUrl != 'null') {
      // Add cache busting parameter for real-time updates
      final cacheBustingUrl = '$imageUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      print('   ✅ Using network image: $cacheBustingUrl');
      return NetworkImage(cacheBustingUrl);
    } else {
      print('   ⚠️ Using default asset image for gender: $gender');
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
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacementNamed(context, '/');
        return false;
      },
      child: Scaffold(
        drawer: Drawer(
          width: 200,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Color(0xFF00B4D8)),
                child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
              ),
              const ListTile(
                leading: Icon(Icons.dashboard),
                title: Text('Dashboard'),
              ),
              const ListTile(
                leading: Icon(Icons.settings),
                title: Text('Settings'),
              ),
              ListTile(
                leading: Icon(Icons.note),
                title: Text('Notes'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AdminNotesPage()));
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    SizedBox(height: 100),
                    Text('Admin Dashboard', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black), textAlign: TextAlign.center),
                    SizedBox(height: 16),
                    Text('Welcome to your dashboard!', style: TextStyle(fontSize: 18, color: Colors.grey), textAlign: TextAlign.center),
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
                  height: 120,
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
                clipper: BottomWaveClipper(),
                child: Container(
                  height: 90,
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
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () async {
                              final popped = await Navigator.of(context).maybePop();
                              if (!popped && context.mounted) {
                                Navigator.pushReplacementNamed(context, '/');
                              }
                            },
                          ),
                          Builder(
                            builder: (context) => IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onPressed: () => Scaffold.of(context).openDrawer(),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications, color: Colors.white, size: 28),
                            tooltip: 'Notifications',
                            onPressed: () {
                              // TODO: Implement notifications page navigation
                            },
                          ),
                          GestureDetector(
                            onTap: () async {
                              print('Admin profile icon tapped - navigating to profile page');
                              try {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                                );
                                print('Admin returned from profile page');
                                // Force refresh after returning from profile page
                                final session = Provider.of<SessionProvider>(context, listen: false);
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
                              backgroundImage: _getAdminAvatar(),
                              onBackgroundImageError: (exception, stackTrace) {
                                // Handle image loading error
                              },
                              child: _getAdminAvatar() is AssetImage ? Icon(
                                Icons.person,
                                color: Colors.grey[400],
                                size: 20,
                              ) : null,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout, color: Colors.white, size: 28),
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
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Blue wavy header bar
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
              // White content area
              Container(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Title
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
                    
                    // Message
                    Text(
                      'Do you want to logout?',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 32),
                    
                    // Stylish buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // NO button
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
                        // YES button
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
                                shadowColor: Color(0xFF00B4D8).withOpacity(0.3),
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

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.5, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.4, size.width, size.height * 0.7);
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
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.6, size.width * 0.5, size.height * 0.4);
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
    
    // Create wavy effect
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.8, size.width * 0.5, size.height);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.8, 0, size.height);
    path.close();
    return path;
  }
  
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
} 