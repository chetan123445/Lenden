import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lenden_frontend/user/session.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import '../profile/edit_profile_page.dart';
import 'dart:async'; // Added for Timer
import '../otp_input.dart';
import '../Transaction/transaction_page.dart';
import '../Transaction/user_transactions_page.dart';
import '../Transaction/analytics_page.dart';
import '../user/notes_page.dart';
import '../Transaction/group_transaction_page.dart';
import '../Transaction/view_group_transactions_page.dart';
import '../profile/profile_page.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
  List<Map<String, dynamic>> transactions = [];
  bool loading = true;
  int _imageRefreshKey = 0; // Key to force avatar rebuild
  final ScrollController _scrollController = ScrollController();
  bool _showAllOptions = false; // Control visibility of additional options

  @override
  void initState() {
    super.initState();
    fetchTransactions();
    
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

  Future<void> fetchTransactions() async {
    setState(() => loading = true);
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final baseUrl = ApiConfig.baseUrl;
    final res = await http.get(Uri.parse('$baseUrl/api/transactions/me'), headers: {'Authorization': 'Bearer $token'});
    setState(() {
      transactions = res.statusCode == 200 ? List<Map<String, dynamic>>.from(json.decode(res.body)) : [];
      loading = false;
    });
  }

  void showTransactionForm() => Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionPage()));

  // Helper function to get user's profile image
  ImageProvider _getUserAvatar() {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final user = session.user;
    final gender = user?['gender'] ?? 'Other';
    final imageUrl = user?['profileImage'];
    
    if (imageUrl != null && imageUrl is String && imageUrl.trim().isNotEmpty && imageUrl != 'null') {
      // Add cache busting parameter for real-time updates
      final cacheBustingUrl = '$imageUrl?t=${DateTime.now().millisecondsSinceEpoch}';
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
    final session = Provider.of<SessionProvider>(context, listen: false);
    final userId = session.user?['_id'];
    final lendingList = transactions.where((t) => t['lender']?['_id'] == userId).toList();
    final borrowingList = transactions.where((t) => t['borrower']?['_id'] == userId).toList();
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
                leading: const Icon(Icons.list_alt),
                title: const Text('Transaction Details'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => UserTransactionsPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.note),
                title: Text('Notes'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => NotesPage()));
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
                padding: EdgeInsets.only(
                  top: 160, // Account for top blue wave + extra spacing
                  bottom: 130, // Account for bottom blue wave + extra spacing
                  left: 0,
                  right: 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // First 3 options (always visible)
                    GestureDetector(
                      onTap: showTransactionForm,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.swap_horiz, color: Colors.teal, size: 40),
                            SizedBox(width: 20),
                            Text('Create Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserTransactionsPage())),
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: Colors.blue, size: 40),
                            SizedBox(width: 20),
                            Text('Your Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsPage())),
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.analytics, color: Color(0xFF00B4D8), size: 40),
                            SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Visual Analytics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                                Text('(for individual transactions)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // More options button (always visible)
                    SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showAllOptions = !_showAllOptions;
                        });
                      },
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF00B4D8).withOpacity(0.1), Color(0xFF00B4D8).withOpacity(0.2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Color(0xFF00B4D8).withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF00B4D8).withOpacity(0.2),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showAllOptions ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: Color(0xFF00B4D8),
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                _showAllOptions ? 'Hide additional options' : 'Show more options',
                                style: TextStyle(
                                  color: Color(0xFF00B4D8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                _showAllOptions ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                color: Color(0xFF00B4D8),
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Additional options (only visible when _showAllOptions is true)
                    if (_showAllOptions) ...[
                      SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupTransactionPage())),
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.group, color: Colors.deepPurple, size: 40),
                              SizedBox(width: 20),
                              Text('Create Group Transaction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewGroupTransactionsPage())),
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.visibility, color: Colors.orange, size: 40),
                              SizedBox(width: 20),
                              Text('View Group Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                              print('Profile icon tapped - navigating to profile page');
                              try {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                                );
                                print('Returned from profile page');
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
                              backgroundImage: _getUserAvatar(),
                              onBackgroundImageError: (exception, stackTrace) {
                                // Handle image loading error
                              },
                              child: _getUserAvatar() is AssetImage ? null : Icon(
                                Icons.person,
                                color: Colors.grey[400],
                                size: 20,
                              ),
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

class LendingBorrowingPage extends StatefulWidget {
  final String type; // 'lending' or 'borrowing'
  final VoidCallback onSuccess;
  const LendingBorrowingPage({required this.type, required this.onSuccess, super.key});

  @override
  State<LendingBorrowingPage> createState() => _LendingBorrowingPageState();
}

class _LendingBorrowingPageState extends State<LendingBorrowingPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _counterpartyController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _placeController = TextEditingController();
  final _otpSelfController = TextEditingController();
  final _otpCounterpartyController = TextEditingController();
  List<File> _photos = [];
  bool _sendingOtps = false;
  bool _verifyingOtps = false;
  String? _otpSelfError;
  String? _otpCounterpartyError;
  int _otpSelfSeconds = 0;
  int _otpCounterpartySeconds = 0;
  Timer? _otpSelfTimer;
  Timer? _otpCounterpartyTimer;
  String? _selfEmail;
  String? _counterpartyEmail;
  String _selectedCurrency = '₹';
  final List<Map<String, String>> _currencies = [
    {'symbol': '₹', 'name': 'Rupee'},
    {'symbol': ' 24', 'name': 'Dollar'},
    {'symbol': '€', 'name': 'Euro'},
    {'symbol': '£', 'name': 'Pound'},
    {'symbol': '¥', 'name': 'Yen'},
    {'symbol': '₩', 'name': 'Won'},
    {'symbol': '₽', 'name': 'Ruble'},
    {'symbol': '₺', 'name': 'Lira'},
    {'symbol': 'R\$', 'name': 'Real'},
    {'symbol': 'A\$', 'name': 'Australian Dollar'},
  ];
  bool _lenderOtpSent = false;
  bool _borrowerOtpSent = false;
  bool _lenderVerified = false;
  bool _borrowerVerified = false;
  String _lenderOtp = '';
  String _borrowerOtp = '';
  int _lenderOtpSeconds = 0;
  int _borrowerOtpSeconds = 0;
  Timer? _lenderOtpTimer;
  Timer? _borrowerOtpTimer;
  bool _counterpartyExists = true;
  String? _counterpartyError;
  Timer? _counterpartyDebounce;
  String? _counterpartyResolvedEmail;
  bool _sendingLenderOtp = false;
  bool _sendingBorrowerOtp = false;
  bool _sameUserError = false;

  // Add helper to determine which email to verify first
  bool get _verifyBorrowerFirst => widget.type == 'lending';
  bool get _verifyLenderFirst => widget.type == 'borrowing';

  @override
  void dispose() {
    _amountController.dispose();
    _counterpartyController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _placeController.dispose();
    _otpSelfController.dispose();
    _otpCounterpartyController.dispose();
    _otpSelfTimer?.cancel();
    _otpCounterpartyTimer?.cancel();
    _lenderOtpTimer?.cancel();
    _borrowerOtpTimer?.cancel();
    _counterpartyDebounce?.cancel();
    super.dispose();
  }

  void _startOtpTimers() {
    setState(() {
      _otpSelfSeconds = 120;
      _otpCounterpartySeconds = 120;
    });
    _otpSelfTimer?.cancel();
    _otpCounterpartyTimer?.cancel();
    _otpSelfTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpSelfSeconds > 0) {
        setState(() => _otpSelfSeconds--);
      } else {
        timer.cancel();
      }
    });
    _otpCounterpartyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_otpCounterpartySeconds > 0) {
        setState(() => _otpCounterpartySeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked != null && picked.isNotEmpty) {
      setState(() => _photos = picked.map((x) => File(x.path)).toList());
    }
  }

  Future<void> _sendOtps() async {
    setState(() { _sendingOtps = true; _otpSelfError = null; _otpCounterpartyError = null; });
    final session = Provider.of<SessionProvider>(context, listen: false);
    _selfEmail = session.user?['email'] ?? '';
    _counterpartyEmail = _counterpartyController.text;
    final baseUrl = ApiConfig.baseUrl;
    final res = await http.post(
      Uri.parse('$baseUrl/api/transactions/send-otps'),
      body: json.encode({'email1': _selfEmail, 'email2': _counterpartyEmail}),
      headers: {'Content-Type': 'application/json'},
    );
    setState(() { _sendingOtps = false; });
    if (res.statusCode == 200) {
      _showOtpDialog('OTPs sent to both emails!');
      _startOtpTimers();
    } else {
      _showOtpDialog('Failed to send OTPs.');
    }
  }

  Future<void> _resendOtp(String email, bool isSelf) async {
    final baseUrl = ApiConfig.baseUrl;
    final res = await http.post(
      Uri.parse('$baseUrl/api/transactions/resend-otp'),
      body: json.encode({'email': email}),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode == 200) {
      _showOtpDialog('OTP resent to $email');
      setState(() {
        if (isSelf) {
          _otpSelfSeconds = 120;
          _otpSelfTimer?.cancel();
          _otpSelfTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (_otpSelfSeconds > 0) {
              setState(() => _otpSelfSeconds--);
            } else {
              timer.cancel();
            }
          });
        } else {
          _otpCounterpartySeconds = 120;
          _otpCounterpartyTimer?.cancel();
          _otpCounterpartyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (_otpCounterpartySeconds > 0) {
              setState(() => _otpCounterpartySeconds--);
            } else {
              timer.cancel();
            }
          });
        }
      });
    } else {
      _showOtpDialog('Failed to resend OTP.');
    }
  }

  void _showOtpDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: const Color(0xFFE0F7FA),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.email, color: Color(0xFF00B4D8), size: 60),
            SizedBox(height: 12),
            Text('OTP Notification', style: TextStyle(color: Color(0xFF0077B5), fontWeight: FontWeight.bold, fontSize: 22), textAlign: TextAlign.center),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Color(0xFF00B4D8), fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_otpSelfController.text.isEmpty || _otpCounterpartyController.text.isEmpty) {
      setState(() {
        if (_otpSelfController.text.isEmpty) _otpSelfError = 'Required';
        if (_otpCounterpartyController.text.isEmpty) _otpCounterpartyError = 'Required';
      });
      return;
    }
    setState(() { _verifyingOtps = true; });
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final baseUrl = ApiConfig.baseUrl;
    final uri = Uri.parse('$baseUrl/api/transactions');
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['counterpartyUsernameOrEmail'] = _counterpartyController.text;
    request.fields['amount'] = _amountController.text;
    request.fields['currency'] = _selectedCurrency;
    request.fields['date'] = _dateController.text;
    request.fields['time'] = _timeController.text;
    request.fields['place'] = _placeController.text;
    request.fields['role'] = widget.type == 'lending' ? 'lender' : 'borrower';
    request.fields['selfEmail'] = _selfEmail ?? '';
    request.fields['counterpartyEmail'] = _counterpartyEmail ?? '';
    request.fields['otpSelf'] = _otpSelfController.text;
    request.fields['otpCounterparty'] = _otpCounterpartyController.text;
    for (int i = 0; i < _photos.length; i++) {
      request.files.add(await http.MultipartFile.fromPath('photos', _photos[i].path));
    }
    final streamed = await request.send();
    if (streamed.statusCode == 201) {
      widget.onSuccess();
      Navigator.of(context).pop();
    } else {
      final resp = await streamed.stream.bytesToString();
      _showOtpDialog('Failed: ${resp.isNotEmpty ? resp : 'Unknown error'}');
    }
    setState(() { _verifyingOtps = false; });
  }

  Future<void> _sendOtp(String emailOrUsername, bool isLender) async {
    print('Sending OTP to: $emailOrUsername (isLender: $isLender)');
    final normalizedEmail = emailOrUsername.trim().toLowerCase();
    // Check if user exists before sending OTP
    if (!isLender && (!_counterpartyExists || _counterpartyResolvedEmail == null)) {
      _showOtpDialog('User not found. Please enter a valid email or username.');
      return;
    }
    final email = isLender ? normalizedEmail : _counterpartyResolvedEmail;
    if (isLender && (email == null || email.isEmpty)) {
      _showOtpDialog('Your email is missing.');
      return;
    }
    setState(() {
      if (isLender) {
        _lenderOtpSent = false;
        _sendingLenderOtp = true;
      } else {
        _borrowerOtpSent = false;
        _sendingBorrowerOtp = true;
      }
    });
    final baseUrl = ApiConfig.baseUrl;
    final res = await http.post(
      Uri.parse('$baseUrl/api/transactions/resend-otp'),
      body: json.encode({'email': email}),
      headers: {'Content-Type': 'application/json'},
    );
    setState(() {
      if (isLender) _sendingLenderOtp = false; else _sendingBorrowerOtp = false;
    });
    if (res.statusCode == 200) {
      _showOtpDialog('OTP sent to $email');
      setState(() {
        if (isLender) {
          _lenderOtpSent = true;
          _lenderOtpSeconds = 120;
          _lenderOtpTimer?.cancel();
          _lenderOtpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (_lenderOtpSeconds > 0) {
              setState(() => _lenderOtpSeconds--);
            } else {
              timer.cancel();
            }
          });
        } else {
          _borrowerOtpSent = true;
          _borrowerOtpSeconds = 120;
          _borrowerOtpTimer?.cancel();
          _borrowerOtpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (_borrowerOtpSeconds > 0) {
              setState(() => _borrowerOtpSeconds--);
            } else {
              timer.cancel();
            }
          });
        }
      });
    } else {
      _showOtpDialog('Failed to send OTP.');
    }
  }

  Future<void> _verifyOtp(String email, String otp, bool isLender) async {
    print('Verifying OTP for email: $email, OTP: $otp, isLender: $isLender');
    final normalizedEmail = email.trim().toLowerCase();
    final baseUrl = ApiConfig.baseUrl;
    final res = await http.post(
      Uri.parse('$baseUrl/api/transactions/verify-otp'),
      body: json.encode({'email': normalizedEmail, 'otp': otp}),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode == 200) {
      setState(() {
        if (isLender) _lenderVerified = true; else _borrowerVerified = true;
      });
      _showOtpDialog('${isLender ? 'Lender' : 'Borrower'} email verified!');
    } else {
      final resp = res.body.isNotEmpty ? res.body : 'Unknown error';
      _showOtpDialog('OTP verification failed. Details: $resp');
    }
  }

  Future<void> _checkCounterpartyExists(String value) async {
    print('Checking counterparty existence for: $value');
    final normalizedValue = value.trim().toLowerCase();
    if (normalizedValue.isEmpty) {
      setState(() {
        _counterpartyExists = false;
        _counterpartyError = 'Required';
        _counterpartyResolvedEmail = null;
        _sameUserError = false;
      });
      return;
    }
    final baseUrl = ApiConfig.baseUrl;
    String? resolvedEmail;
    if (normalizedValue.contains('@')) {
      // Treat as email
      final res = await http.post(
        Uri.parse('$baseUrl/api/users/check-email'),
        body: json.encode({'email': normalizedValue}),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200 && json.decode(res.body)['unique'] == false) {
        resolvedEmail = normalizedValue;
        setState(() {
          _counterpartyExists = true;
          _counterpartyError = null;
          _counterpartyResolvedEmail = normalizedValue;
          _sameUserError = (_selfEmail != null && _selfEmail == resolvedEmail);
        });
      } else {
        setState(() {
          _counterpartyExists = false;
          _counterpartyError = 'User not found';
          _counterpartyResolvedEmail = null;
          _sameUserError = false;
        });
      }
    } else {
      // Treat as username
      final res = await http.post(
        Uri.parse('$baseUrl/api/users/check-username'),
        body: json.encode({'username': normalizedValue}),
        headers: {'Content-Type': 'application/json'},
      );
      final data = json.decode(res.body);
      if (res.statusCode == 200 && data['unique'] == false && data['email']) {
        resolvedEmail = data['email'];
        setState(() {
          _counterpartyExists = true;
          _counterpartyError = null;
          _counterpartyResolvedEmail = data['email'];
          _sameUserError = (_selfEmail != null && _selfEmail == resolvedEmail);
        });
      } else {
        setState(() {
          _counterpartyExists = false;
          _counterpartyError = 'User not found';
          _counterpartyResolvedEmail = null;
          _sameUserError = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context, listen: false);
    _selfEmail = session.user?['email'] ?? '';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.type == 'lending' ? 'Lend Money' : 'Borrow Money', style: const TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF8F6FA),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Text(
                              _selectedCurrency,
                              style: const TextStyle(
                                color: Color(0xFF00B4D8),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                  border: InputBorder.none,
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _selectedCurrency,
                      items: _currencies.map((c) => DropdownMenuItem<String>(
                        value: c['symbol'],
                        child: Text('${c['symbol']} (${c['name']})'),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCurrency = val);
                      },
                    ),
                  ],
                ),
                _inputField(Icons.person, widget.type == 'lending' ? 'Borrower Username/Email' : 'Lender Username/Email', _counterpartyController),
                if (_sameUserError)
                  const Text('Counterparty must be a different user.', style: TextStyle(color: Colors.red)),
                _inputField(Icons.cake, 'Date', _dateController, readOnly: true, onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) _dateController.text = picked.toIso8601String().split('T').first;
                }),
                _inputField(
                  Icons.access_time,
                  'Time (e.g. 14:30)',
                  _timeController,
                  readOnly: true,
                  onTap: () async {
                    final result = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Select Time'),
                        content: const Text('Do you want to use the current time or pick a time?'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              final now = TimeOfDay.now();
                              _timeController.text = now.format(context);
                              Navigator.of(context).pop('current');
                            },
                            child: const Text('Use Current Time'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop('pick');
                            },
                            child: const Text('Pick Time'),
                          ),
                        ],
                      ),
                    );
                    if (result == 'pick') {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        _timeController.text = picked.format(context);
                      }
                    }
                  },
                ),
                _inputField(Icons.place, 'Place', _placeController),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickPhotos,
                      icon: const Icon(Icons.photo),
                      label: const Text('Add Proof Photos'),
                    ),
                    if (_photos.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      ..._photos.map((f) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: SizedBox(
                          width: 40, height: 40,
                          child: Image.file(f, fit: BoxFit.cover),
                        ),
                      )),
                    ]
                  ],
                ),
                const SizedBox(height: 16),
                // OTP Verification Order
                // Lender email and OTP
                _inputField(Icons.email, 'Your Email', TextEditingController(text: _selfEmail ?? ''), readOnly: true),
                if (!_lenderVerified) ...[
                  ElevatedButton(
                    onPressed: _lenderOtpSeconds > 0 || _sendingLenderOtp ? null : () => _sendOtp(_selfEmail ?? '', true),
                    child: _sendingLenderOtp
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Sending OTP...'),
                          ],
                        )
                      : Text(_lenderOtpSeconds > 0 ? 'Resend in ${_lenderOtpSeconds ~/ 60}:${(_lenderOtpSeconds % 60).toString().padLeft(2, '0')}' : 'Send OTP'),
                  ),
                  if (_lenderOtpSent)
                    Column(
                      children: [
                        const SizedBox(height: 8),
                        OtpInput(
                          onChanged: (val) => _lenderOtp = val,
                          enabled: true,
                          autoFocus: true,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _lenderOtp.length == 6 ? () => _verifyOtp(_selfEmail ?? '', _lenderOtp, true) : null,
                          child: const Text('Verify OTP'),
                        ),
                      ],
                    ),
                ] else ...[
                  Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Lender email verified!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                // Borrower email and OTP
                _inputField(
                  Icons.email,
                  'Counterparty Email',
                  _counterpartyController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (val) {
                    _counterpartyDebounce?.cancel();
                    _counterpartyDebounce = Timer(const Duration(milliseconds: 500), () {
                      _checkCounterpartyExists(val);
                    });
                  },
                  onFieldSubmitted: (val) => _checkCounterpartyExists(val),
                  errorText: _counterpartyError,
                ),
                if (!_counterpartyExists)
                  const Text('User not found. Please enter a valid email or username.', style: TextStyle(color: Colors.red)),
                if (!_borrowerVerified) ...[
                  ElevatedButton(
                    onPressed: _borrowerOtpSeconds > 0 || _sendingBorrowerOtp || !_counterpartyExists || _sameUserError ? null : () => _sendOtp(_counterpartyController.text, false),
                    child: _sendingBorrowerOtp
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Sending OTP...'),
                          ],
                        )
                      : Text(_borrowerOtpSeconds > 0 ? 'Resend in ${_borrowerOtpSeconds ~/ 60}:${(_borrowerOtpSeconds % 60).toString().padLeft(2, '0')}' : 'Send OTP'),
                  ),
                  if (_borrowerOtpSent)
                    Column(
                      children: [
                        const SizedBox(height: 8),
                        OtpInput(
                          onChanged: (val) => _borrowerOtp = val,
                          enabled: true,
                          autoFocus: true,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _borrowerOtp.length == 6 ? () => _verifyOtp(_counterpartyController.text, _borrowerOtp, false) : null,
                          child: const Text('Verify OTP'),
                        ),
                      ],
                    ),
                ] else ...[
                  Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Borrower email verified!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _lenderVerified && _borrowerVerified && !_verifyingOtps && _counterpartyExists && !_sameUserError ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B4D8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _verifyingOtps ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(IconData icon, String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, bool readOnly = false, void Function()? onTap, void Function(String)? onChanged, void Function(String)? onFieldSubmitted, String? errorText}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00B4D8)),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              readOnly: readOnly,
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
                errorText: errorText,
              ),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              onTap: onTap,
              onChanged: onChanged,
              onFieldSubmitted: onFieldSubmitted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _otpField(TextEditingController controller, String? error, int seconds, VoidCallback onResend) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'OTP'),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: seconds > 0 ? null : onResend,
              child: Text(seconds > 0 ? 'Resend in ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}' : 'Resend OTP'),
            ),
          ],
        ),
        if (error != null) Text(error, style: const TextStyle(color: Colors.red)),
      ],
    );
  }
}

class TransactionDetailsPage extends StatefulWidget {
  const TransactionDetailsPage({super.key});
  @override
  State<TransactionDetailsPage> createState() => _TransactionDetailsPageState();
}

class _TransactionDetailsPageState extends State<TransactionDetailsPage> {
  List<Map<String, dynamic>> details = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchDetails();
  }

  Future<void> fetchDetails() async {
    setState(() => loading = true);
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    final baseUrl = ApiConfig.baseUrl;
    final res = await http.get(Uri.parse('$baseUrl/api/transactions/details'), headers: {'Authorization': 'Bearer $token'});
    setState(() {
      details = res.statusCode == 200 ? List<Map<String, dynamic>>.from(json.decode(res.body)) : [];
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Transaction Details', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFF8F6FA),
      body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: details.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, i) {
              final t = details[i];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(t['type'] == 'lending' ? Icons.arrow_upward : Icons.arrow_downward, color: t['type'] == 'lending' ? Colors.green : Colors.orange),
                          const SizedBox(width: 8),
                          Text(t['type'].toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: t['type'] == 'lending' ? Colors.green : Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Amount: ₹${t['amount']}', style: const TextStyle(fontSize: 16)),
                      Text('Date: ${t['date']?.split('T')?.first ?? ''}'),
                      Text('Time: ${t['time'] ?? ''}'),
                      Text('Place: ${t['place'] ?? ''}'),
                      Text('Lender: ${t['lender']?['username'] ?? ''}'),
                      Text('Borrower: ${t['borrower']?['username'] ?? ''}'),
                      Text('Transaction ID: ${t['transactionId'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
} 