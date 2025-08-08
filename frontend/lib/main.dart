import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'Login/login_page.dart';
import 'Register/register_page.dart';
import 'password/forgot_password_page.dart';
import 'user/dashboard.dart';
import 'admin/dashboard.dart';
import 'profile/profile_page.dart';
import 'user/session.dart';
import 'settings/settings_page.dart';
import 'settings/admin_settings_page.dart';
import 'admin/manage_and_track_users/user_management_page.dart';

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

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});
  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    final session = Provider.of<SessionProvider>(context, listen: false);
    _initFuture = session.initSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const MyApp();
        }
        return const MaterialApp(
          home: Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      home: const HomePage(),
      routes: {
        '/login': (context) => const UserLoginPage(),
        '/register': (context) => const UserRegisterPage(),
        '/forgot-password': (context) => const UserForgotPasswordPage(),
        '/user/dashboard': (context) => const UserDashboardPage(),
        '/admin/dashboard': (context) => const AdminDashboardPage(),
        '/profile': (context) => const ProfilePage(),
        '/settings': (context) => const SettingsPage(),
        '/admin/settings': (context) => const AdminSettingsPage(),
        '/admin/manage-users': (context) => const UserManagementPage(),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                children: const [
                  Icon(Icons.account_balance_wallet, color: Colors.white, size: 48),
                  SizedBox(height: 8),
                  Text('Lenden App', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
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
                final session = Provider.of<SessionProvider>(context, listen: false);
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
              onTap: () {},
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
                height: 180,
                color: const Color(0xFF00B4D8),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Center(
                    child: Icon(Icons.account_balance_wallet, color: Color(0xFF00B4D8), size: 64),
                  ),
                  const SizedBox(height: 16),
                  const Center(
                    child: Text('Welcome to Lenden',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('Your trusted platform for lending and borrowing.',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () {
                      final session = Provider.of<SessionProvider>(context, listen: false);
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B4D8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Login', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF00B4D8), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Register', style: TextStyle(fontSize: 18, color: Color(0xFF00B4D8))),
                  ),
                  const SizedBox(height: 40),
                  const Center(
                    child: Text('© 2024 Lenden App', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
