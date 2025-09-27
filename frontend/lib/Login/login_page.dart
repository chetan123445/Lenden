import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_config.dart';
import '../otp_input.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import 'email_password_login.dart';
import 'username_password_login.dart';
import 'email_otp_login.dart';
import 'package:uuid/uuid.dart';

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
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _initDeviceId();
  }

  Future<void> _initDeviceId() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    String? deviceId = await session.getDeviceId();
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await session.saveDeviceId(deviceId);
    }
    setState(() {
      _deviceId = deviceId;
    });
  }

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
        final result = await EmailPasswordLogin.login(
          email: _emailController.text,
          password: _passwordController.text,
          context: context,
          deviceId: _deviceId ?? '', // Pass non-null String
        );

        if (result['success']) {
          userOrAdmin = result['userOrAdmin'];
          userType = result['userType'];
          token = result['token'];
        } else {
          error = result['error'];
        }
      } else if (_loginMethod == 'Username + Password') {
        final result = await UsernamePasswordLogin.login(
          username: _usernameController.text,
          password: _passwordController.text,
          context: context,
          deviceId: _deviceId ?? '',
        );

        if (result['success']) {
          userOrAdmin = result['data'];
          userType = result['userType'];
          token = result['token'];
        } else {
          error = result['error'];
        }
      } else if (_loginMethod == 'Email + OTP') {
        if (!_otpSent) {
          setState(() => _isLoading = true);
          final result = await EmailOtpLogin.sendOtp(
            email: _emailController.text,
            context: context,
          );
          setState(() => _isLoading = false);

          if (result['success']) {
            setState(() {
              _otpSent = true;
              _otpErrorMessage = null;
              _otpSecondsLeft = 120;
            });
            _startOtpTimer();
            return; // Return early to wait for OTP input
          } else {
            setState(() {
              _otpErrorMessage = result['error'];
            });
            return; // Return early on error
          }
        } else if (_otpSecondsLeft > 0) {
          setState(() => _isVerifyingOtp = true);
          final result = await EmailOtpLogin.verifyOtp(
            email: _emailController.text,
            otp: _loginOtp,
            context: context,
            deviceId: _deviceId ?? '',
          );
          setState(() => _isVerifyingOtp = false);

          if (result['success']) {
            setState(() {
              _otpSent = false;
              _loginOtp = '';
              _otpErrorMessage = null;
              _otpSecondsLeft = 0;
            });
            userOrAdmin = result['userOrAdmin'];
            userType = result['userType'];
            token = result['token'];
          } else {
            setState(() {
              _otpErrorMessage = result['error'];
            });
            return; // Return early on error
          }
        }
      }

      // Save token and fetch user info
      if (token != null && userType != null) {
        print('🔐 Saving authentication data for login method: $_loginMethod');
        print('🎫 Token: ${token != null ? 'Present' : 'Missing'}');
        print('👤 User type: $userType');
        print('👤 User data: $userOrAdmin');

        final session = Provider.of<SessionProvider>(context, listen: false);
        print('🔐 About to save token to session');
        print('🔐 Token to save: ${token != null ? 'Present' : 'Missing'}');
        print('🔐 Token length: ${token?.length ?? 0}');
        await session.saveToken(token);
        print('✅ Token saved to session');

        // Verify token was saved
        print('🔍 Token verification after save:');
        print(
            '   Session token: ${session.token != null ? 'Present' : 'Missing'}');
        print('   Session token length: ${session.token?.length ?? 0}');

        // For Email + OTP, also fetch the complete profile to ensure all fields are present
        if (_loginMethod == 'Email + OTP' && userOrAdmin != null) {
          print(
              '📱 Using user data from OTP response and fetching complete profile');
          final userData = Map<String, dynamic>.from(userOrAdmin);

          // Ensure required fields are present
          if (!userData.containsKey('name') || userData['name'] == null) {
            userData['name'] = userData['username'] ?? 'User';
          }
          if (!userData.containsKey('email') || userData['email'] == null) {
            userData['email'] = _emailController.text;
          }
          if (!userData.containsKey('username') ||
              userData['username'] == null) {
            userData['username'] = userData['name'] ?? 'user';
          }

          if (userType == 'admin') {
            userData['role'] = 'admin';
          } else {
            userData['role'] = 'user';
          }

          // Also fetch the complete profile to ensure we have all fields including profileImage
          print('🌐 Fetching complete profile for email+OTP login');
          final profileRes = await _fetchProfile(token, userType);
          if (profileRes != null) {
            // Merge the profile data with the OTP response data
            final completeUserData = Map<String, dynamic>.from(profileRes);
            completeUserData['role'] = userType == 'admin' ? 'admin' : 'user';
            print('👤 Setting complete user data: $completeUserData');
            session.setUser(completeUserData);
            print('✅ Complete user data set in session');
          } else {
            // Fallback to OTP response data if profile fetch fails
            print('⚠️ Profile fetch failed, using OTP response data');
            print('👤 Setting user data from OTP response: $userData');
            session.setUser(userData);
            print('✅ User data set in session');
          }

          // Verify the session was set correctly
          print('🔍 Verifying session data after setting:');
          print('   Token: ${session.token != null ? 'Present' : 'Missing'}');
          print('   User: ${session.user}');
          print('   Role: ${session.role}');
          print('   Is Admin: ${session.isAdmin}');
        } else {
          // For other login methods, fetch profile
          print('🌐 Fetching user profile from API');
          final profileRes = await _fetchProfile(token, userType);
          if (profileRes != null) {
            if (userType == 'admin') {
              profileRes['role'] = 'admin';
            } else {
              profileRes['role'] = 'user';
            }
            print('👤 Setting user data from profile: $profileRes');
            session.setUser(profileRes);
            print('✅ User data set in session');
          } else {
            print('❌ Failed to fetch user profile');
          }
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

  Future<Map<String, dynamic>?> _fetchProfile(
      String token, String userType) async {
    final url = userType == 'admin'
        ? ApiConfig.baseUrl + '/api/admins/me'
        : ApiConfig.baseUrl + '/api/users/me';
    try {
      print('🌐 Fetching profile from: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      print('🌐 Profile response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final profileData = jsonDecode(response.body);
        print('🌐 Profile data received: $profileData');
        print('🌐 Profile image URL: ${profileData['profileImage']}');
        return profileData;
      } else {
        print('❌ Profile fetch failed with status: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ Error fetching profile: $e');
    }
    return null;
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

  void _showIncorrectPasswordDialog() {
    if (_loginMethod == 'Email + Password') {
      EmailPasswordLogin.showIncorrectPasswordDialog(context);
    } else if (_loginMethod == 'Username + Password') {
      UsernamePasswordLogin.showIncorrectPasswordDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FA),
      body: SizedBox(
        height: MediaQuery.of(context).size.height, // Ensure Stack fills screen
        child: Stack(
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
                  child: Container(),
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
                      const Text('Login',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      const Text('Hello Welcome Back',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 32),
                      // Dropdown for login method
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
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
                            controller: _passwordController,
                            obscureText: _obscurePassword,
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
                            controller: _passwordController,
                            obscureText: _obscurePassword,
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
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 18),
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
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Text('Send OTP',
                                      style: TextStyle(
                                          fontSize: 18, color: Colors.white)),
                            ),
                          ),
                          if (_otpErrorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(_otpErrorMessage!,
                                  style: const TextStyle(color: Colors.red)),
                            ),
                        ] else ...[
                          OtpInput(
                            onChanged: (val) => setState(() => _loginOtp = val),
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
                                        _loginOtp = '';
                                        _otpErrorMessage = null;
                                      });
                                    },
                              child: const Text('Resend OTP'),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isVerifyingOtp ||
                                      _loginOtp.length != 6 ||
                                      _otpSecondsLeft == 0
                                  ? null
                                  : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00B4D8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isVerifyingOtp
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Text('Verify OTP',
                                      style: TextStyle(
                                          fontSize: 18, color: Colors.white)),
                            ),
                          ),
                          if (_otpErrorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(_otpErrorMessage!,
                                  style: const TextStyle(color: Colors.red)),
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
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Login',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("I Don't Have an Account ? ",
                              style: TextStyle(fontSize: 14)),
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, '/register'),
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
            // Move the bottom wave to the end of the stack so it's always at the bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipPath(
                clipper: BottomWaveClipper(),
                child: Container(
                  height:
                      80, // Adjust height as needed (try 80 for a slim wave)
                  color: const Color(0xFF00B4D8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserNotFoundDialog() {
    if (_loginMethod == 'Email + Password') {
      EmailPasswordLogin.showUserNotFoundDialog(context);
    } else if (_loginMethod == 'Username + Password') {
      UsernamePasswordLogin.showUserNotFoundDialog(context);
    }
  }

  void _showErrorDialog(String message) {
    if (_loginMethod == 'Email + OTP') {
      EmailOtpLogin.showErrorDialog(context, message);
    } else {
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
