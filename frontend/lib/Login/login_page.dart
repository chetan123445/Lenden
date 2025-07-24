import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import '../otp_input.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';

class UserLoginPage extends StatefulWidget {
  const UserLoginPage({super.key});

  @override
  State<UserLoginPage> createState() => _UserLoginPageState();
}

class _UserLoginPageState extends State<UserLoginPage> {
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Login method selection
  String _loginMethod = 'Email + Password';
  final List<String> _loginMethods = [
    'Email + Password',
    'Email + OTP',
    'Username + Password',
  ];

  // Controllers for input fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isVerifyingOtp = false;
  String _loginOtp = '';
  String? _otpErrorMessage;
  int _otpSecondsLeft = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _login() async {
    setState(() => _isLoading = true);
    String? error;
    dynamic userOrAdmin;
    String? userType;
    String? token;
    try {
      if (_loginMethod == 'Email + Password') {
        // Try admin login first
        final adminRes = await _loginAdmin(email: _emailController.text, password: _passwordController.text);
        if (adminRes['success']) {
          userOrAdmin = adminRes['data'];
          userType = 'admin';
          token = adminRes['token'];
        } else if (adminRes['error'] != null && adminRes['error'] != 'User not found') {
          error = adminRes['error'];
        } else if (adminRes['error'] == 'User not found') {
          // Try user login only if not found in admin
          final userRes = await _loginUser(username: _emailController.text, password: _passwordController.text, isEmail: true);
          if (userRes['success']) {
            userOrAdmin = userRes['data'];
            userType = 'user';
            token = userRes['token'];
          } else if (userRes['error'] != null && userRes['error'] != 'User not found') {
            error = userRes['error'];
          } else {
            error = 'User not found';
          }
        }
      } else if (_loginMethod == 'Username + Password') {
        // Try admin login first
        final adminRes = await _loginAdmin(username: _usernameController.text, password: _passwordController.text);
        if (adminRes['success']) {
          userOrAdmin = adminRes['data'];
          userType = 'admin';
          token = adminRes['token'];
        } else if (adminRes['error'] != null && adminRes['error'] != 'User not found') {
          error = adminRes['error'];
        } else if (adminRes['error'] == 'User not found') {
          // Try user login only if not found in admin
          final userRes = await _loginUser(username: _usernameController.text, password: _passwordController.text);
          if (userRes['success']) {
            userOrAdmin = userRes['data'];
            userType = 'user';
            token = userRes['token'];
          } else if (userRes['error'] != null && userRes['error'] != 'User not found') {
            error = userRes['error'];
          } else {
            error = 'User not found';
          }
        }
      } else if (_loginMethod == 'Email + OTP') {
        if (!_otpSent) {
          setState(() => _isLoading = true);
          final otpSendRes = await _post('/api/users/send-login-otp', {
            'email': _emailController.text,
          });
          setState(() => _isLoading = false);
          if (otpSendRes['status'] == 200) {
            setState(() {
              _otpSent = true;
              _otpErrorMessage = null;
              _otpSecondsLeft = 120;
            });
            _startOtpTimer();
          } else {
            setState(() {
              _otpErrorMessage = otpSendRes['data']['error'] ?? 'User not found';
            });
          }
        } else if (_otpSecondsLeft > 0) {
          setState(() => _isVerifyingOtp = true);
          final otpVerifyRes = await _post('/api/users/verify-login-otp', {
            'email': _emailController.text,
            'otp': _loginOtp,
          });
          setState(() => _isVerifyingOtp = false);
          if (otpVerifyRes['status'] == 200) {
            setState(() {
              _otpSent = false;
              _loginOtp = '';
              _otpErrorMessage = null;
              _otpSecondsLeft = 0;
            });
            if (otpVerifyRes['data']['userType'] == 'admin') {
              Navigator.pushReplacementNamed(context, '/admin/dashboard');
            } else {
              Navigator.pushReplacementNamed(context, '/user/dashboard');
            }
            return;
          } else {
            setState(() {
              _otpErrorMessage = otpVerifyRes['data']['error'] ?? 'OTP verification failed.';
            });
          }
        }
      }
      // Save token and fetch user info
      if (token != null && userType != null) {
        final session = Provider.of<SessionProvider>(context, listen: false);
        await session.saveToken(token);
        final profileRes = await _fetchProfile(token, userType);
        if (profileRes != null) {
          if (userType == 'admin') {
            profileRes['role'] = 'admin';
          } else {
            profileRes['role'] = 'user';
          }
          session.setUser(profileRes);
        }
      }
      if (userOrAdmin != null && userType != null) {
        // Navigate to dashboard
        if (userType == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin/dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/user/dashboard');
        }
      } else if (error != null) {
        if (error == 'Incorrect password') {
          _showIncorrectPasswordDialog();
        } else {
          _showUserNotFoundDialog();
        }
      }
    } catch (e) {
      _showErrorDialog('Login failed. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchProfile(String token, String userType) async {
    final url = userType == 'admin'
        ? ApiConfig.baseUrl + '/api/admins/me'
        : ApiConfig.baseUrl + '/api/users/me';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> _loginAdmin({String? email, String? username, required String password}) async {
    try {
      final res = await _post('/api/admins/login', {
        if (email != null) 'username': email, // backend expects username, so use email as username if email login
        if (username != null) 'username': username,
        'password': password,
      });
      if (res['status'] == 200 && res['data']['admin'] != null) {
        return {'success': true, 'data': res['data']['admin'], 'token': res['data']['token']};
      }
      return {'success': false, 'error': res['data']['error']};
    } catch (_) {
      return {'success': false};
    }
  }

  Future<Map<String, dynamic>> _loginUser({String? username, required String password, bool isEmail = false}) async {
    try {
      final res = await _post('/api/users/login', {
        'username': username,
        'password': password,
      });
      if (res['status'] == 200 && res['data']['user'] != null) {
        return {'success': true, 'data': res['data']['user'], 'token': res['data']['token']};
      }
      return {'success': false, 'error': res['data']['error']};
    } catch (_) {
      return {'success': false};
    }
  }

  Future<String?> _showOtpInputDialog() async {
    String? otpValue;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: const Color(0xFFF8F6FA),
          title: Row(
            children: const [
              Icon(Icons.lock_clock, color: Color(0xFF00B4D8), size: 28),
              SizedBox(width: 8),
              Text('Enter OTP', style: TextStyle(color: Colors.black)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the 6-digit OTP sent to your email:', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              OtpInput(
                onChanged: (val) => _loginOtp = val,
                enabled: true,
                autoFocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.deepPurple)),
            ),
            TextButton(
              onPressed: () {
                otpValue = _loginOtp;
                Navigator.of(context).pop();
              },
              child: const Text('Verify', style: TextStyle(color: Color(0xFF00B4D8), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    return otpValue;
  }

  void _startOtpTimer() {
    _otpSecondsLeft = 120;
    Future.doWhile(() async {
      if (_otpSecondsLeft > 0 && mounted && _otpSent) {
        await Future.delayed(const Duration(seconds: 1));
        setState(() { _otpSecondsLeft--; });
        return true;
      }
      return false;
    });
  }

  void _showIncorrectPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: const Color(0xFFF8F6FA),
        title: Row(
          children: const [
            Icon(Icons.lock_outline, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Incorrect Password', style: TextStyle(color: Colors.black)),
          ],
        ),
        content: const Text(
          'The password you entered is incorrect.',
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.deepPurple)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/forgot-password');
            },
            child: const Text('Forgot Password', style: TextStyle(color: Color(0xFF00B4D8), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _verifyOtp(String email, String otp) async {
    try {
      final res = await _post('/api/users/verify-otp', {
        'email': email,
        'otp': otp,
      });
      if (res['status'] == 201 && res['data']['message'] != null) {
        // After OTP verification, fetch user
        final userRes = await _post('/api/users/login', {
          'username': email,
          'password': '', // No password for OTP
        });
        if (userRes['status'] == 200 && userRes['data']['user'] != null) {
          return {'success': true, 'data': userRes['data']['user'], 'type': 'user'};
        }
      }
      return {'success': false, 'error': res['data']['error']};
    } catch (_) {
      return {'success': false};
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + path),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      return {'status': response.statusCode, 'data': data};
    } catch (e) {
      return {'status': 500, 'data': {'error': e.toString()}};
    }
  }

  void _sendOtp() async {
    // TODO: Implement send OTP logic
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isLoading = false);
    // TODO: Show message that OTP is sent
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FA),
      body: Stack(
        children: [
          // Top blue shape
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopWaveClipper(),
              child: Container(
                height: 120,
                color: const Color(0xFF00B4D8),
                child: SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.home, color: Colors.white),
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/');
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Bottom blue shape
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
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),
                    const Text('Login',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text('Hello Welcome Back',
                        style: TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    // Dropdown for login method
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                      child: DropdownButton<String>(
                        value: _loginMethod,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: _loginMethods.map((method) {
                          return DropdownMenuItem<String>(
                            value: method,
                            child: Text(method),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _loginMethod = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Dynamic input fields based on login method
                    if (_loginMethod == 'Email + Password') ...[
                      Container(
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
                        child: TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: const TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
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
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: const TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                      ),
                    ] else if (_loginMethod == 'Username + Password') ...[
                      Container(
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
                        child: TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            labelStyle: const TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
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
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: const TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                      ),
                    ] else if (_loginMethod == 'Email + OTP') ...[
                      Container(
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
                        child: TextField(
                          controller: _emailController,
                          enabled: !_otpSent,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: const TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (!_otpSent) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00B4D8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Send OTP', style: TextStyle(fontSize: 18, color: Colors.white)),
                          ),
                        ),
                        if (_otpErrorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(_otpErrorMessage!, style: const TextStyle(color: Colors.red)),
                          ),
                      ] else ...[
                        OtpInput(
                          onChanged: (val) => setState(() => _loginOtp = val),
                          enabled: _otpSecondsLeft > 0,
                          autoFocus: true,
                        ),
                        const SizedBox(height: 10),
                        if (_otpSecondsLeft > 0)
                          Text('OTP expires in  ${_otpSecondsLeft ~/ 60}:${(_otpSecondsLeft % 60).toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.grey)),
                        if (_otpSecondsLeft == 0)
                          TextButton(
                            onPressed: _isVerifyingOtp ? null : () {
                              setState(() {
                                _otpSent = false;
                                _loginOtp = '';
                                _otpErrorMessage = null;
                              });
                            },
                            child: const Text('Resend OTP'),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isVerifyingOtp || _loginOtp.length != 6 || _otpSecondsLeft == 0 ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00B4D8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isVerifyingOtp
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Verify OTP', style: TextStyle(fontSize: 18, color: Colors.white)),
                          ),
                        ),
                        if (_otpErrorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(_otpErrorMessage!, style: const TextStyle(color: Colors.red)),
                          ),
                      ],
                    ],
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B4D8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Login', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("I Don't Have an Account ? ", style: TextStyle(fontSize: 14)),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/register'),
                          child: const Text(
                            'Register',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
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
    );
  }

  void _showUserNotFoundDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: const Color(0xFFF8F6FA),
        title: Row(
          children: const [
            Icon(Icons.person_off, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text('User Not Found', style: TextStyle(color: Colors.black)),
          ],
        ),
        content: const Text(
          'No user found with these credentials. Would you like to register?',
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.deepPurple)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacementNamed(context, '/register');
            },
            child: const Text('Register', style: TextStyle(color: Color(0xFF00B4D8), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
}

class SocialIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const SocialIconButton({required this.icon, required this.color, required this.onTap, super.key});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: FaIcon(icon, color: color, size: 20),
        ),
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