import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../user/session.dart';
import 'custom_warning_widget.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _isLoading = false;
  bool _isSaving = false;
  
  // Privacy settings
  bool _profileVisibility = true;
  bool _transactionHistory = true;
  bool _contactSharing = false;
  bool _analyticsSharing = true;
  bool _marketingEmails = false;
  bool _dataCollection = true;
  
  // Security settings
  bool _twoFactorAuth = false;
  bool _loginNotifications = true;
  bool _deviceManagement = true;
  String _sessionTimeout = '30'; // minutes

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/users/privacy-settings'),
        headers: {
          'Authorization': 'Bearer ${session.token}',
        },
      );

      if (response.statusCode == 200) {
        final settings = json.decode(response.body);
        setState(() {
          _profileVisibility = settings['profileVisibility'] ?? true;
          _transactionHistory = settings['transactionHistory'] ?? true;
          _contactSharing = settings['contactSharing'] ?? false;
          _analyticsSharing = settings['analyticsSharing'] ?? true;
          _marketingEmails = settings['marketingEmails'] ?? false;
          _dataCollection = settings['dataCollection'] ?? true;
          _twoFactorAuth = settings['twoFactorAuth'] ?? false;
          _loginNotifications = settings['loginNotifications'] ?? true;
          _deviceManagement = settings['deviceManagement'] ?? true;
          _sessionTimeout = settings['sessionTimeout']?.toString() ?? '30';
        });
      }
    } catch (e) {
      if (mounted) {
        CustomWarningWidget.showAnimatedError(context, 'Error loading settings: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePrivacySettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final response = await http.put(
        Uri.parse('http://localhost:5000/api/users/privacy-settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.token}',
        },
        body: json.encode({
          'profileVisibility': _profileVisibility,
          'transactionHistory': _transactionHistory,
          'contactSharing': _contactSharing,
          'analyticsSharing': _analyticsSharing,
          'marketingEmails': _marketingEmails,
          'dataCollection': _dataCollection,
          'twoFactorAuth': _twoFactorAuth,
          'loginNotifications': _loginNotifications,
          'deviceManagement': _deviceManagement,
          'sessionTimeout': int.parse(_sessionTimeout),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          CustomWarningWidget.showAnimatedSuccess(context, 'Privacy settings saved successfully!');
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          CustomWarningWidget.showAnimatedError(context, errorData['message'] ?? 'Failed to save settings');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomWarningWidget.showAnimatedError(context, 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _downloadUserData() async {
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/users/download-data'),
        headers: {
          'Authorization': 'Bearer ${session.token}',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          CustomWarningWidget.showAnimatedSuccess(context, 'Data download initiated. Check your email.');
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          CustomWarningWidget.showAnimatedError(context, errorData['message'] ?? 'Failed to download data');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomWarningWidget.showAnimatedError(context, 'Error: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteAccount() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Account',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: const Text(
            'Are you sure you want to delete your account? This action is permanent and cannot be undone. All your data will be permanently deleted.',
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
              onPressed: () async {
                Navigator.of(context).pop();
                await _performAccountDeletion();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Delete Account',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performAccountDeletion() async {
    try {
      final session = Provider.of<SessionProvider>(context, listen: false);
      final response = await http.delete(
        Uri.parse('http://localhost:5000/api/users/delete-account'),
        headers: {
          'Authorization': 'Bearer ${session.token}',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          session.logout();
          Navigator.of(context).pushReplacementNamed('/');
          CustomWarningWidget.showAnimatedSuccess(context, 'Account deleted successfully');
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          CustomWarningWidget.showAnimatedError(context, errorData['message'] ?? 'Failed to delete account');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomWarningWidget.showAnimatedError(context, 'Error: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FA),
      appBar: AppBar(
        title: const Text(
          'Privacy Settings',
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
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _savePrivacySettings,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Color(0xFF00B4D8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
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
                    child: Column(
                      children: [
                        const Icon(
                          Icons.privacy_tip_outlined,
                          size: 48,
                          color: Color(0xFF00B4D8),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Privacy & Security',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Control your privacy and security preferences',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Privacy Settings Section
                  _buildSettingsSection(
                    'Privacy Settings',
                    [
                      _buildSwitchTile(
                        'Profile Visibility',
                        'Allow others to see your profile information',
                        Icons.visibility_outlined,
                        _profileVisibility,
                        (value) => setState(() => _profileVisibility = value),
                      ),
                      _buildSwitchTile(
                        'Transaction History',
                        'Share transaction history with trusted contacts',
                        Icons.history,
                        _transactionHistory,
                        (value) => setState(() => _transactionHistory = value),
                      ),
                      _buildSwitchTile(
                        'Contact Sharing',
                        'Allow the app to access your contacts',
                        Icons.contacts_outlined,
                        _contactSharing,
                        (value) => setState(() => _contactSharing = value),
                      ),
                      _buildSwitchTile(
                        'Analytics Sharing',
                        'Help improve the app by sharing usage data',
                        Icons.analytics_outlined,
                        _analyticsSharing,
                        (value) => setState(() => _analyticsSharing = value),
                      ),
                      _buildSwitchTile(
                        'Marketing Emails',
                        'Receive promotional emails and offers',
                        Icons.campaign_outlined,
                        _marketingEmails,
                        (value) => setState(() => _marketingEmails = value),
                      ),
                      _buildSwitchTile(
                        'Data Collection',
                        'Allow data collection for app functionality',
                        Icons.data_usage,
                        _dataCollection,
                        (value) => setState(() => _dataCollection = value),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Security Settings Section
                  _buildSettingsSection(
                    'Security Settings',
                    [
                      _buildSwitchTile(
                        'Two-Factor Authentication',
                        'Add an extra layer of security to your account',
                        Icons.security,
                        _twoFactorAuth,
                        (value) => setState(() => _twoFactorAuth = value),
                      ),
                      _buildSwitchTile(
                        'Login Notifications',
                        'Get notified when someone logs into your account',
                        Icons.notifications_active_outlined,
                        _loginNotifications,
                        (value) => setState(() => _loginNotifications = value),
                      ),
                      _buildSwitchTile(
                        'Device Management',
                        'Allow multiple devices to access your account',
                        Icons.devices,
                        _deviceManagement,
                        (value) => setState(() => _deviceManagement = value),
                      ),
                      _buildDropdownTile(
                        'Session Timeout',
                        'Auto-logout after inactivity',
                        Icons.timer_outlined,
                        _sessionTimeout,
                        {
                          '15': '15 minutes',
                          '30': '30 minutes',
                          '60': '1 hour',
                          '120': '2 hours',
                          '0': 'Never',
                        },
                        (value) => setState(() => _sessionTimeout = value!),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Data Management Section
                  _buildSettingsSection(
                    'Data Management',
                    [
                      _buildActionTile(
                        'Download My Data',
                        'Get a copy of all your data',
                        Icons.download_outlined,
                        () => _downloadUserData(),
                      ),
                      _buildActionTile(
                        'Delete Account',
                        'Permanently delete your account and all data',
                        Icons.delete_forever_outlined,
                        () => _deleteAccount(),
                        isDestructive: true,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Information Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Privacy & Security Tips:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Enable two-factor authentication for enhanced security\n• Regularly review your privacy settings\n• Be cautious about sharing personal information\n• Keep your app updated for the latest security features',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
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

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF00B4D8)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF00B4D8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    IconData icon,
    String value,
    Map<String, String> options,
    ValueChanged<String?> onChanged,
  ) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF00B4D8)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
      trailing: DropdownButton<String>(
        value: value,
        onChanged: onChanged,
        underline: Container(),
        items: options.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value),
          );
        }).toList(),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : const Color(0xFF00B4D8),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: isDestructive ? Colors.red : Colors.grey,
        size: 16,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
} 