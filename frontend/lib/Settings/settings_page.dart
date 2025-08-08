import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import 'change_password_page.dart';
import 'alternative_email_page.dart';
import 'notification_settings_page.dart';
import 'privacy_settings_page.dart';
import 'account_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    // No need to refresh on init as the session should already have user data
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FA),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF00B4D8),
                                         child: session.user?['profileImage'] != null
                         ? ClipOval(
                             child: session.user!['profileImage'] is String
                                 ? Image.network(
                                     session.user!['profileImage'],
                                     width: 60,
                                     height: 60,
                                     fit: BoxFit.cover,
                                     errorBuilder: (context, error, stackTrace) {
                                       return Text(
                                         (session.user?['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'U',
                                         style: const TextStyle(
                                           fontSize: 24,
                                           fontWeight: FontWeight.bold,
                                           color: Colors.white,
                                         ),
                                       );
                                     },
                                   )
                                 : Image.memory(
                                     session.user!['profileImage'],
                                     width: 60,
                                     height: 60,
                                     fit: BoxFit.cover,
                                   ),
                           )
                         : Text(
                             (session.user?['name'] as String?)?.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                                 Text(
                           session.user?['name'] ?? 'User',
                           style: const TextStyle(
                             fontSize: 18,
                             fontWeight: FontWeight.bold,
                             color: Colors.black,
                           ),
                         ),
                                                 const SizedBox(height: 4),
                         Text(
                           session.user?['email'] ?? 'user@example.com',
                           style: const TextStyle(
                             fontSize: 14,
                             color: Colors.grey,
                           ),
                         ),
                         if (session.user?['altEmail'] != null && (session.user!['altEmail'] as String).isNotEmpty) ...[
                           const SizedBox(height: 2),
                           Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               const Icon(
                                 Icons.check_circle,
                                 size: 12,
                                 color: Colors.green,
                               ),
                               const SizedBox(width: 4),
                               Text(
                                 'Alternative email set',
                                 style: const TextStyle(
                                   fontSize: 10,
                                   color: Colors.green,
                                   fontWeight: FontWeight.w500,
                                 ),
                               ),
                             ],
                           ),
                         ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Color(0xFF00B4D8)),
                    onPressed: () {
                      Navigator.pushNamed(context, '/profile');
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Settings Categories
            _buildSettingsSection(
              context,
              'Account Settings',
              [
                _buildSettingsTile(
                  context,
                  'Change Password',
                  Icons.lock_outline,
                  Icons.arrow_forward_ios,
                                     () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => const ChangePasswordPage(),
                       ),
                     ).then((_) => setState(() {}));
                   },
                ),
                _buildSettingsTile(
                  context,
                                     session.user?['altEmail'] != null && (session.user!['altEmail'] as String).isNotEmpty
                       ? 'Change Alternative Email'
                       : 'Add Alternative Email',
                  Icons.email_outlined,
                  Icons.arrow_forward_ios,
                                     () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => const AlternativeEmailPage(),
                       ),
                     ).then((_) => setState(() {}));
                   },
                                     subtitle: session.user?['altEmail'] != null && (session.user!['altEmail'] as String).isNotEmpty
                       ? session.user!['altEmail'] as String
                       : 'Add a backup email for account recovery',
                   showStatus: true,
                   isActive: session.user?['altEmail'] != null && (session.user!['altEmail'] as String).isNotEmpty,
                ),
                _buildSettingsTile(
                  context,
                  'Account Information',
                  Icons.person_outline,
                  Icons.arrow_forward_ios,
                                     () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => const AccountSettingsPage(),
                       ),
                     ).then((_) => setState(() {}));
                   },
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildSettingsSection(
              context,
              'Preferences',
              [
                _buildSettingsTile(
                  context,
                  'Notification Settings',
                  Icons.notifications_outlined,
                  Icons.arrow_forward_ios,
                                     () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => const NotificationSettingsPage(),
                       ),
                     ).then((_) => setState(() {}));
                   },
                ),
                _buildSettingsTile(
                  context,
                  'Privacy Settings',
                  Icons.privacy_tip_outlined,
                  Icons.arrow_forward_ios,
                                     () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => const PrivacySettingsPage(),
                       ),
                     ).then((_) => setState(() {}));
                   },
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildSettingsSection(
              context,
              'Support & About',
              [
                _buildSettingsTile(
                  context,
                  'Help & Support',
                  Icons.help_outline,
                  Icons.arrow_forward_ios,
                  () {
                    // TODO: Implement help and support
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Help & Support coming soon!')),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  'About Lenden',
                  Icons.info_outline,
                  Icons.arrow_forward_ios,
                  () {
                    // TODO: Implement about page
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('About page coming soon!')),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  'Terms of Service',
                  Icons.description_outlined,
                  Icons.arrow_forward_ios,
                  () {
                    // TODO: Implement terms of service
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Terms of Service coming soon!')),
                    );
                  },
                ),
                _buildSettingsTile(
                  context,
                  'Privacy Policy',
                  Icons.security_outlined,
                  Icons.arrow_forward_ios,
                  () {
                    // TODO: Implement privacy policy
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Privacy Policy coming soon!')),
                    );
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showLogoutDialog(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00B4D8),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context,
    String title,
    IconData leadingIcon,
    IconData trailingIcon,
    VoidCallback onTap, {
    String? subtitle,
    bool showStatus = false,
    bool isActive = false,
  }) {
    return ListTile(
      leading: Stack(
        children: [
          Icon(
            leadingIcon,
            color: const Color(0xFF00B4D8),
            size: 24,
          ),
          if (showStatus)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            )
          : null,
      trailing: Icon(
        trailingIcon,
        color: Colors.grey,
        size: 16,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final session = Provider.of<SessionProvider>(context, listen: false);
                session.logout();
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
} 