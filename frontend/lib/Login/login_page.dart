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
import '../services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
        final result = await EmailPasswordLogin.login(
          email: _emailController.text,
          password: _passwordController.text,
          context: context,
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

            // Register device token
            await NotificationService.registerTokenAfterLogin(session.user!['_id'], token);
          } else {
            // Fallback to OTP response data if profile fetch fails
            print('⚠️ Profile fetch failed, using OTP response data');
            print('👤 Setting user data from OTP response: $userData');
            session.setUser(userData);
            print('✅ User data set in session');

            // Register device token
            await NotificationService.registerTokenAfterLogin(session.user!['_id'], token);
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

            // Register device token
            await NotificationService.registerTokenAfterLogin(session.user!['_id'], token);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DropdownButton<String>(
                    value: _loginMethod,
                    onChanged: (String? newValue) {
                      setState(() {
                        _loginMethod = newValue!;
                      });
                    },
                    items: _loginMethods.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                  if (_loginMethod == 'Email + Password')
                    Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_loginMethod == 'Username + Password')
                    Column(
                      children: [
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(labelText: 'Username'),
                        ),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_loginMethod == 'Email + OTP')
                    Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        if (_otpSent)
                          TextFormField(
                            controller: _otpController,
                            decoration: const InputDecoration(labelText: 'OTP'),
                            onChanged: (value) {
                              _loginOtp = value;
                            },
                          ),
                        if (_otpErrorMessage != null)
                          Text(
                            _otpErrorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        if (_otpSecondsLeft > 0)
                          Text('Resend OTP in $_otpSecondsLeft seconds'),
                      ],
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _login,
                    child: Text(_otpSent ? 'Verify OTP' : 'Login'),
                  ),
                ],
              ),
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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
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