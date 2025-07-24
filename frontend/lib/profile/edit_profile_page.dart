import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lenden_frontend/user/session.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:lenden_frontend/api_config.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _birthdayController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late TextEditingController _addressController;
  String? _gender;
  Uint8List? _newImageBytes;
  bool _removeImage = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<SessionProvider>(context, listen: false).user;
    _nameController = TextEditingController(text: user?['name'] ?? '');
    String birthday = user?['birthday'] ?? '';
    if (birthday.contains('T')) {
      birthday = birthday.split('T').first;
    }
    _birthdayController = TextEditingController(text: birthday);
    _phoneController = TextEditingController(text: user?['phone'] ?? '');
    _emailController = TextEditingController(text: user?['email'] ?? '');
    _passwordController = TextEditingController();
    _addressController = TextEditingController(text: user?['address'] ?? '');
    _gender = user?['gender'] ?? 'Other';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _newImageBytes = result.files.single.bytes;
        _removeImage = false;
      });
    }
  }

  void _removeProfileImage() {
    setState(() {
      _newImageBytes = null;
      _removeImage = true;
    });
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final session = Provider.of<SessionProvider>(context, listen: false);
    final isAdmin = session.isAdmin;
    final url = isAdmin
        ? '/api/admins/me'
        : '/api/users/me';
    final uri = Uri.parse(ApiConfig.baseUrl + url);
    final request = http.MultipartRequest('PUT', uri);
    request.headers['Authorization'] = 'Bearer ${session.token}';
    request.fields['name'] = _nameController.text;
    request.fields['birthday'] = _birthdayController.text;
    request.fields['phone'] = _phoneController.text;
    request.fields['address'] = _addressController.text;
    request.fields['gender'] = _gender ?? '';
    // Email and username are not editable, so not sent
    if (_removeImage) {
      request.fields['removeImage'] = 'true';
    } else if (_newImageBytes != null) {
      request.files.add(http.MultipartFile.fromBytes('profileImage', _newImageBytes!, filename: 'profile.png'));
    }
    final response = await request.send();
    if (response.statusCode == 200) {
      final respStr = await response.stream.bytesToString();
      final updatedUser = jsonDecode(respStr);
      // Normalize profileImage to always be a String
      if (updatedUser != null && updatedUser['profileImage'] is Map && updatedUser['profileImage']['url'] != null) {
        updatedUser['profileImage'] = updatedUser['profileImage']['url'];
      }
      session.setUser(updatedUser);
      // Fetch latest user profile from backend to get updated image URL
      final isAdmin = session.isAdmin;
      final profileUrl = isAdmin
          ? ApiConfig.baseUrl + '/api/admins/me'
          : ApiConfig.baseUrl + '/api/users/me';
      try {
        final profileRes = await http.get(
          Uri.parse(profileUrl),
          headers: {'Authorization': 'Bearer ${session.token}'},
        );
        if (profileRes.statusCode == 200) {
          final latestUser = jsonDecode(profileRes.body);
          // Normalize profileImage to always be a String
          if (latestUser != null && latestUser['profileImage'] is Map && latestUser['profileImage']['url'] != null) {
            latestUser['profileImage'] = latestUser['profileImage']['url'];
          }
          session.setUser(latestUser);
        }
      } catch (_) {}
      // Re-initialize form fields with latest user data for continuous editing
      final newUser = session.user;
      setState(() {
        _nameController.text = newUser?['name'] ?? '';
        String birthday = newUser?['birthday'] ?? '';
        if (birthday.contains('T')) {
          birthday = birthday.split('T').first;
        }
        _birthdayController.text = birthday;
        _phoneController.text = newUser?['phone'] ?? '';
        _emailController.text = newUser?['email'] ?? '';
        _addressController.text = newUser?['address'] ?? '';
        _gender = newUser?['gender'] ?? 'Other';
        _newImageBytes = null;
        _removeImage = false;
      });
      // Show stylish success SnackBar and allow immediate re-editing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.check_circle, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Profile updated successfully!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00B4D8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      );
      // Do NOT pop the page, so user can continue editing
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<SessionProvider>(context).user;
    final gender = _gender ?? 'Other';
    final imageUrl = user?['profileImage'];
    dynamic fixedImageUrl = imageUrl;
    if (fixedImageUrl is Map && fixedImageUrl['url'] != null) {
      fixedImageUrl = fixedImageUrl['url'];
    }
    if (fixedImageUrl != null && fixedImageUrl is! String) {
      fixedImageUrl = null;
    }
    Widget avatar;
    if (_newImageBytes != null) {
      avatar = CircleAvatar(radius: 54, backgroundImage: MemoryImage(_newImageBytes!));
    } else if (_removeImage || fixedImageUrl == null || fixedImageUrl.toString().isEmpty || fixedImageUrl == 'null') {
      avatar = CircleAvatar(
        radius: 54,
        backgroundImage: AssetImage(
          gender == 'Male'
              ? 'assets/Male.png'
              : gender == 'Female'
                  ? 'assets/Female.png'
                  : 'assets/Other.png',
        ),
      );
    } else {
      avatar = CircleAvatar(radius: 54, backgroundImage: NetworkImage(fixedImageUrl));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: avatar),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload, color: Color(0xFF00B4D8)),
                      label: const Text('Upload', style: TextStyle(color: Color(0xFF00B4D8))),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _removeProfileImage,
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Remove', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _editField(Icons.person, 'Name', _nameController),
                _editField(Icons.account_circle, 'Username', TextEditingController(text: user?['username'] ?? ''), readOnly: true),
                _editField(Icons.cake, 'Birthday', _birthdayController),
                _editField(Icons.phone, 'Phone', _phoneController),
                _editField(Icons.home, 'Address', _addressController),
                _editField(Icons.email, 'Email', _emailController, keyboardType: TextInputType.emailAddress, readOnly: true),
                _editGenderField(),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B4D8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 18, color: Color(0xFF00B4D8))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editField(IconData icon, String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, bool readOnly = false}) {
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
              readOnly: readOnly || label == 'Birthday',
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
                suffixIcon: label == 'Birthday'
                    ? IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: controller.text.isNotEmpty ? DateTime.tryParse(controller.text) ?? DateTime(2000) : DateTime(2000),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            controller.text = picked.toIso8601String().split('T').first;
                          }
                        },
                      )
                    : null,
              ),
              validator: (val) {
                if (label == 'Birthday' || label == 'Phone' || label == 'Address') {
                  return null; // Not required
                }
                return val == null || val.isEmpty ? 'Required' : null;
              },
              onTap: label == 'Birthday'
                  ? () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: controller.text.isNotEmpty ? DateTime.tryParse(controller.text) ?? DateTime(2000) : DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        controller.text = picked.toIso8601String().split('T').first;
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _editPasswordField() {
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
          const Icon(Icons.lock, color: Color(0xFF00B4D8)),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                border: InputBorder.none,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editGenderField() {
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
          const Icon(Icons.transgender, color: Color(0xFF00B4D8)),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: InputBorder.none,
              ),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (val) => setState(() => _gender = val),
              validator: (val) => val == null ? 'Required' : null,
            ),
          ),
        ],
      ),
    );
  }
} 