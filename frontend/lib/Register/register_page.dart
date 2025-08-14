import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import '../otp_input.dart';

class UserRegisterPage extends StatefulWidget {
  const UserRegisterPage({super.key});

  @override
  State<UserRegisterPage> createState() => _UserRegisterPageState();
}

class _UserRegisterPageState extends State<UserRegisterPage> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  bool _newsOptOut = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _otpSent = false;
  bool _isVerifyingOtp = false;
  int _otpSecondsLeft = 0;
  String _registerOtp = '';
  String? _selectedGender;
  // double _rating = 0.0; // Rating removed

  // Uniqueness check state
  bool _isUsernameUnique = true;
  bool _isEmailUnique = true;
  bool _checkingUsername = false;
  bool _checkingEmail = false;

  // Password validation
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  bool get _hasLower => RegExp(r'[a-z]').hasMatch(_passwordController.text);
  bool get _hasSpecial =>
      RegExp(r'[^A-Za-z0-9]').hasMatch(_passwordController.text);
  bool get _hasLength =>
      _passwordController.text.length >= 8 &&
      _passwordController.text.length <= 30;
  bool get _isPasswordValid =>
      _hasUpper && _hasLower && _hasSpecial && _hasLength;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _checkUsernameUnique(String username) async {
    setState(() {
      _checkingUsername = true;
    });
    final res =
        await _post('/api/users/check-username', {'username': username});
    setState(() {
      _isUsernameUnique = res['status'] == 200 && res['data']['unique'] == true;
      _checkingUsername = false;
    });
  }

  Future<void> _checkEmailUnique(String email) async {
    setState(() {
      _checkingEmail = true;
    });
    final res = await _post('/api/users/check-email', {'email': email});
    setState(() {
      _isEmailUnique = res['status'] == 200 && res['data']['unique'] == true;
      _checkingEmail = false;
    });
  }

  void _register() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    if (!_isPasswordValid) {
      setState(() {
        _errorMessage = 'Password does not meet all requirements.';
        _isLoading = false;
      });
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
        _isLoading = false;
      });
      return;
    }
    if (!_isUsernameUnique) {
      setState(() {
        _errorMessage = 'Username already exists.';
        _isLoading = false;
      });
      return;
    }
    if (!_isEmailUnique) {
      setState(() {
        _errorMessage = 'Email already exists.';
        _isLoading = false;
      });
      return;
    }
    // Send OTP
    final res = await _post('/api/users/register', {
      'name': _nameController.text,
      'username': _usernameController.text,
      'email': _emailController.text,
      'password': _passwordController.text,
      'gender': _selectedGender,
      // 'rating': _rating, // Rating removed
    });
    if (res['status'] == 200) {
      setState(() {
        _otpSent = true;
        _isLoading = false;
        _otpSecondsLeft = 120;
      });
      _showSnackBar('OTP sent to your email.');
      _startOtpTimer();
    } else {
      setState(() {
        _errorMessage = res['data']['error'] ?? 'Failed to send OTP.';
        _isLoading = false;
      });
    }
  }

  void _startOtpTimer() {
    _otpSecondsLeft = 120;
    Future.doWhile(() async {
      if (_otpSecondsLeft > 0 && mounted && _otpSent) {
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _otpSecondsLeft--;
        });
        return true;
      }
      return false;
    });
  }

  void _verifyOtp() async {
    setState(() {
      _isVerifyingOtp = true;
      _errorMessage = null;
    });
    final res = await _post('/api/users/verify-otp', {
      'email': _emailController.text,
      'otp': _otpController.text,
    });
    if (res['status'] == 201) {
      setState(() {
        _isVerifyingOtp = false;
      });
      _showSnackBar('Registration successful!');
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      setState(() {
        _errorMessage = res['data']['error'] ?? 'OTP verification failed.';
        _isVerifyingOtp = false;
      });
    }
  }

  void _verifyOtpWithOtp(String otp) async {
    setState(() {
      _isVerifyingOtp = true;
      _errorMessage = null;
    });
    final res = await _post('/api/users/verify-otp', {
      'email': _emailController.text,
      'otp': otp,
    });
    if (res['status'] == 201) {
      setState(() {
        _isVerifyingOtp = false;
      });
      _showSnackBar('Registration successful!');
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      setState(() {
        _errorMessage = res['data']['error'] ?? 'OTP verification failed.';
        _isVerifyingOtp = false;
      });
    }
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    try {
      print('🌐 Making API call to: ${ApiConfig.baseUrl + path}');
      print('📤 Request body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + path),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Lenden-Flutter-App/1.0',
        },
        body: jsonEncode(body),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response headers: ${response.headers}');
      print('📥 Response body: ${response.body}');

      // Handle different response status codes
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return {'status': response.statusCode, 'data': data};
      } else if (response.statusCode == 404) {
        return {
          'status': 404,
          'data': {'error': 'API endpoint not found'}
        };
      } else if (response.statusCode == 500) {
        return {
          'status': 500,
          'data': {'error': 'Server error'}
        };
      } else {
        final data = jsonDecode(response.body);
        return {'status': response.statusCode, 'data': data};
      }
    } catch (e) {
      print('❌ API call error: $e');
      if (e.toString().contains('SocketException')) {
        return {
          'status': 0,
          'data': {'error': 'No internet connection'}
        };
      } else if (e.toString().contains('HandshakeException')) {
        return {
          'status': 0,
          'data': {'error': 'SSL/TLS connection failed'}
        };
      } else {
        return {
          'status': 500,
          'data': {'error': e.toString()}
        };
      }
    }
  }

  void _showSnackBar(String message) {
    // Show a stylish dialog for OTP sent
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
            Text('OTP Sent!',
                style: TextStyle(
                    color: Color(0xFF0077B5),
                    fontWeight: FontWeight.bold,
                    fontSize: 22),
                textAlign: TextAlign.center),
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
            child: const Text('OK',
                style: TextStyle(
                    color: Color(0xFF00B4D8),
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: const Color(0xFFE0F7FA),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF00B4D8), size: 60),
            SizedBox(height: 12),
            Text('Registration Successful',
                style: TextStyle(
                    color: Color(0xFF0077B5),
                    fontWeight: FontWeight.bold,
                    fontSize: 22),
                textAlign: TextAlign.center),
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
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Login',
                style: TextStyle(
                    color: Color(0xFF00B4D8),
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPasswordRules() {
    final rules = <Map<String, bool>>[
      {'At least one uppercase letter': _hasUpper},
      {'At least one lowercase letter': _hasLower},
      {'At least one special character': _hasSpecial},
      {'8-30 characters': _hasLength},
    ];
    if (_passwordController.text.isEmpty || _isPasswordValid) return [];
    return rules
        .where((rule) => !rule.values.first)
        .map((rule) => Row(
              children: [
                const Icon(Icons.cancel, color: Colors.red, size: 18),
                const SizedBox(width: 6),
                Text(rule.keys.first,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ))
        .toList();
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
                    // Remove the IconButton with Icons.arrow_back from the top blue shape
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 28.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),
                    const Text('Register',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text('Hello Welcome :)',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 32),
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
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          labelStyle: const TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
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
                        controller: _usernameController,
                        onChanged: (val) {
                          if (val.isNotEmpty) _checkUsernameUnique(val);
                        },
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: const TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          suffixIcon: _checkingUsername
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : _isUsernameUnique
                                  ? null
                                  : const Icon(Icons.error, color: Colors.red),
                        ),
                      ),
                    ),
                    if (!_isUsernameUnique)
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 4),
                        child: Text('Username already exists.',
                            style: TextStyle(color: Colors.red, fontSize: 13)),
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
                      child: DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'Gender',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                              value: 'Female', child: Text('Female')),
                          DropdownMenuItem(
                              value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedGender = val),
                        validator: (val) =>
                            val == null ? 'Please select gender' : null,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Rating field removed
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
                        controller: _emailController,
                        onChanged: (val) {
                          if (val.isNotEmpty) _checkEmailUnique(val);
                        },
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: const TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          suffixIcon: _checkingEmail
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : _isEmailUnique
                                  ? null
                                  : const Icon(Icons.error, color: Colors.red),
                        ),
                      ),
                    ),
                    if (!_isEmailUnique)
                      const Padding(
                        padding: EdgeInsets.only(left: 8, top: 4),
                        child: Text('Email already exists.',
                            style: TextStyle(color: Colors.red, fontSize: 13)),
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
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._buildPasswordRules(),
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
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          labelStyle: const TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(() =>
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!_otpSent) ...[
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(_errorMessage!,
                              style: const TextStyle(color: Colors.red)),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00B4D8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white)),
                                    SizedBox(width: 12),
                                    Text('Sending OTP...',
                                        style: TextStyle(
                                            fontSize: 18, color: Colors.white)),
                                  ],
                                )
                              : const Text('Register',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.white)),
                        ),
                      ),
                    ] else ...[
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(_errorMessage!,
                              style: const TextStyle(color: Colors.red)),
                        ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F7FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.email, color: Color(0xFF00B4D8)),
                            const SizedBox(width: 8),
                            Text('OTP sent to your email',
                                style: TextStyle(
                                    color: Color(0xFF0077B5),
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      OtpInput(
                        onChanged: (val) => setState(() => _registerOtp = val),
                        enabled: _otpSecondsLeft > 0,
                        autoFocus: true,
                      ),
                      const SizedBox(height: 10),
                      if (_otpSecondsLeft > 0)
                        Text(
                            'OTP expires in  ${_otpSecondsLeft ~/ 60}:${(_otpSecondsLeft % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Colors.grey)),
                      if (_otpSecondsLeft == 0)
                        TextButton(
                          onPressed: _isVerifyingOtp
                              ? null
                              : () {
                                  setState(() {
                                    _otpSent = false;
                                    _registerOtp = '';
                                    _errorMessage = null;
                                  });
                                },
                          child: const Text('Resend OTP'),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isVerifyingOtp ||
                                  _registerOtp.length != 6 ||
                                  _otpSecondsLeft == 0
                              ? null
                              : () => _verifyOtpWithOtp(_registerOtp),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00B4D8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isVerifyingOtp
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white)),
                                    SizedBox(width: 12),
                                    Text('Verifying OTP...',
                                        style: TextStyle(
                                            fontSize: 18, color: Colors.white)),
                                  ],
                                )
                              : const Text('Verify OTP & Register',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.white)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('I Have an Account ? ',
                            style: TextStyle(fontSize: 14)),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/login'),
                          child: const Text('Login',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
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
}

class SocialIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const SocialIconButton(
      {required this.icon,
      required this.color,
      required this.onTap,
      super.key});
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
