//This file is to create Transactions.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../otp_input.dart';
import '../api_config.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../user/session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Add for wavy background
import 'dart:math' as math;
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http_parser/http_parser.dart';
import 'user_transactions_page.dart';

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height * 0.8,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.6,
      size.width,
      size.height * 0.8,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class TransactionPage extends StatefulWidget {
  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  String _currency = 'INR';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _placeController = TextEditingController();
  List<PlatformFile> _pickedFiles = [];
  final TextEditingController _counterpartyEmailController =
      TextEditingController();
  final TextEditingController _userEmailController = TextEditingController();
  String? _transactionId;
  String _role = 'lender'; // default
  bool _isLoading = false;
  String? _counterpartyOtp;
  String? _userOtp;
  String? _counterpartyOtpError;
  String? _userOtpError;
  String? _counterpartyEmailError;
  String? _userEmailError;
  String? _sameEmailError;
  int _counterpartyOtpSeconds = 0;
  int _userOtpSeconds = 0;
  late final ImagePicker _picker;
  bool _counterpartyVerified = false;
  bool _userVerified = false;
  String _interestType = 'none';
  final TextEditingController _interestRateController = TextEditingController();
  DateTime? _expectedReturnDate;
  int _compoundingFrequency = 1; // default annually
  final TextEditingController _descriptionController = TextEditingController();

  // Computed property to check if both users are verified
  bool get _bothUsersVerified => _counterpartyVerified && _userVerified;

  final List<Map<String, String>> _currencies = [
    {'code': 'INR', 'symbol': '₹'},
    {'code': 'USD', 'symbol': ' 24'},
    {'code': 'EUR', 'symbol': '€'},
    {'code': 'GBP', 'symbol': '£'},
    {'code': 'JPY', 'symbol': '¥'},
    {'code': 'CNY', 'symbol': '¥'},
    {'code': 'CAD', 'symbol': ' 24'},
    {'code': 'AUD', 'symbol': ' 24'},
    {'code': 'CHF', 'symbol': 'Fr'},
    {'code': 'RUB', 'symbol': '₽'},
  ];

  @override
  void initState() {
    super.initState();
    _picker = ImagePicker();
    _compoundingFrequency = 1;
    _descriptionController.text = '';
    // Prefill user email from session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<SessionProvider>(context, listen: false).user;
      if (user != null && user['email'] != null) {
        _userEmailController.text = user['email'];
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _placeController.dispose();
    _counterpartyEmailController.dispose();
    _userEmailController.dispose();
    _interestRateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedFiles.addAll(result.files);
      });
    }
  }

  void _removeFile(int idx) {
    if (_bothUsersVerified) return; // Prevent file removal when verified
    setState(() {
      _pickedFiles.removeAt(idx);
    });
  }

  Widget _buildFileThumbnail(int i) {
    final file = _pickedFiles[i];
    if (file.extension == 'pdf') {
      return GestureDetector(
        onTap: () async {
          if (file.bytes != null) {
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/${file.name}');
            await tempFile.writeAsBytes(file.bytes!, flush: true);
            await OpenFile.open(tempFile.path);
          }
        },
        child: Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
      );
    } else {
      return GestureDetector(
        onTap: () {
          if (file.bytes != null) {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.black,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: InteractiveViewer(
                    child: Image.memory(file.bytes!, fit: BoxFit.contain),
                  ),
                ),
              ),
            );
          }
        },
        child: file.bytes != null
            ? Image.memory(file.bytes!,
                width: 80, height: 80, fit: BoxFit.cover)
            : Icon(Icons.image, size: 80),
      );
    }
  }

  Widget _buildFilePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: _bothUsersVerified ? null : _pickFiles,
          icon: Icon(Icons.attach_file),
          label: Text('Add Images'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: List.generate(
              _pickedFiles.length,
              (i) => GestureDetector(
                    onTap: () {},
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildFileThumbnail(i),
                        ),
                        if (!_bothUsersVerified)
                          GestureDetector(
                            onTap: () => _removeFile(i),
                            child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.red,
                                child: Icon(Icons.close,
                                    size: 16, color: Colors.white)),
                          ),
                        if (_pickedFiles[i].extension == 'pdf')
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.white70,
                              child: Text(_pickedFiles[i].name,
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.black),
                                  textAlign: TextAlign.center),
                            ),
                          ),
                      ],
                    ),
                  )),
        ),
      ],
    );
  }

  Future<bool> _checkEmailExists(String email) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/transactions/check-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['exists'] == true;
    }
    return false;
  }

  Future<void> _sendOtp(String email, bool isCounterparty) async {
    setState(() {
      if (isCounterparty) {
        _counterpartyOtpError = null;
        _counterpartyOtpSeconds = 120;
      } else {
        _userOtpError = null;
        _userOtpSeconds = 120;
      }
    });
    final url = isCounterparty
        ? '/api/transactions/send-counterparty-otp'
        : '/api/transactions/send-user-otp';
    await http.post(
      Uri.parse(ApiConfig.baseUrl + url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    _startOtpTimer(isCounterparty);
  }

  void _startOtpTimer(bool isCounterparty) {
    Future.doWhile(() async {
      await Future.delayed(Duration(seconds: 1));
      setState(() {
        if (isCounterparty && _counterpartyOtpSeconds > 0) {
          _counterpartyOtpSeconds--;
        } else if (!isCounterparty && _userOtpSeconds > 0) {
          _userOtpSeconds--;
        }
      });
      return (isCounterparty ? _counterpartyOtpSeconds : _userOtpSeconds) > 0;
    });
  }

  Future<void> _verifyOtp(String email, String otp, bool isCounterparty) async {
    final url = isCounterparty
        ? '/api/transactions/verify-counterparty-otp'
        : '/api/transactions/verify-user-otp';
    final res = await http.post(
      Uri.parse(ApiConfig.baseUrl + url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    if (res.statusCode == 200) {
      setState(() {
        if (isCounterparty) {
          _counterpartyVerified = true;
        } else {
          _userVerified = true;
        }
      });
    } else {
      setState(() {
        if (isCounterparty) {
          _counterpartyOtpError = 'Invalid or expired OTP';
        } else {
          _userOtpError = 'Invalid or expired OTP';
        }
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _sameEmailError = null);

    // Custom validation for expected return date when interest is selected
    if (_interestType != 'none' && _expectedReturnDate == null) {
      _showStylishErrorDialog('Expected Return Date Required',
          'Please select an expected return date when interest is applied.');
      return;
    }

    // Validate form
    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      return;
    }

    print('Form validation passed, proceeding with submission');
    setState(() => _isLoading = true);
    var uri = Uri.parse('${ApiConfig.baseUrl}/api/transactions/create');
    var request = http.MultipartRequest('POST', uri);
    request.fields['amount'] = _amountController.text;
    request.fields['currency'] = _currency;
    request.fields['date'] = _selectedDate?.toIso8601String() ?? '';
    request.fields['time'] = _selectedTime?.format(context) ?? '';
    request.fields['place'] = _placeController.text;
    request.fields['counterpartyEmail'] = _counterpartyEmailController.text;
    request.fields['userEmail'] = _userEmailController.text;
    request.fields['role'] = _role;
    // Always send interest type, even if it's 'none'
    request.fields['interestType'] = _interestType;

    // Only send other interest-related fields if interest type is selected
    if (_interestType != 'none') {
      request.fields['interestRate'] = _interestRateController.text;
      request.fields['expectedReturnDate'] =
          _expectedReturnDate?.toIso8601String() ?? '';
      if (_interestType == 'compound') {
        request.fields['compoundingFrequency'] =
            _compoundingFrequency.toString();
      }
    }

    // Debug: Print the fields being sent
    print('Sending transaction with fields: ${request.fields}');
    request.fields['description'] = _descriptionController.text;
    for (var file in _pickedFiles) {
      if (file.bytes != null) {
        MediaType? mediaType;
        final ext = file.extension?.toLowerCase();
        if (ext == 'png') {
          mediaType = MediaType('image', 'png');
        } else if (ext == 'jpg' || ext == 'jpeg') {
          mediaType = MediaType('image', 'jpeg');
        } else if (ext == 'pdf') {
          mediaType = MediaType('application', 'pdf');
        }
        request.files.add(http.MultipartFile.fromBytes(
          'files',
          file.bytes!,
          filename: file.name,
          contentType: mediaType,
        ));
      }
    }
    var streamed = await request.send();
    setState(() => _isLoading = false);
    if (streamed.statusCode == 200) {
      final resp = await streamed.stream.bytesToString();
      final data = jsonDecode(resp);
      setState(() {
        _transactionId = data['transactionId'];
      });
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipPath(
                      clipper: TopWaveClipper(),
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF00B4D8), Color(0xFF48CAE4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.check_circle,
                            color: Color(0xFF00B4D8), size: 48),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Text('Transaction Created!',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00B4D8))),
                SizedBox(height: 12),
                Text('Transaction ID:',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
                SizedBox(height: 4),
                SelectableText('${_transactionId ?? ''}',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00B4D8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the success dialog
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserTransactionsPage(),
                        ),
                      );
                    },
                    child: Text('View Transactions',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      final resp = await streamed.stream.bytesToString();
      String errorMsg = 'Failed to create transaction';
      try {
        final data = jsonDecode(resp);
        errorMsg = data['error'] ?? errorMsg;
        // Also log the full response for debugging
        print('Backend error response: $data');
      } catch (_) {
        errorMsg = resp;
        print('Raw error response: $resp');
      }
      _showStylishErrorDialog('Transaction Failed', errorMsg);
    }
  }

  void _showStylishErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipPath(
                    clipper: TopWaveClipper(),
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.error_outline,
                          color: Color(0xFFFF6B6B), size: 48),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              Text(title,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6B6B))),
              SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF6B6B),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK',
                      style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyDropdown() {
    return DropdownButtonFormField<String>(
      value: _currency,
      items: _currencies
          .map((c) => DropdownMenuItem(
                value: c['code'],
                child: Text('${c['symbol']} ${c['code']}'),
              ))
          .toList(),
      onChanged: _bothUsersVerified
          ? null
          : (val) => setState(() => _currency = val ?? 'INR'),
      decoration: InputDecoration(
        labelText: 'Currency',
        border: OutlineInputBorder(),
        helperText: _bothUsersVerified
            ? 'Transaction details locked after verification'
            : null,
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _bothUsersVerified
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.light().copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Colors.teal,
                        onPrimary: Colors.white,
                        surface: Colors.teal.shade50,
                        onSurface: Colors.black,
                      ),
                      dialogBackgroundColor: Colors.white,
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date',
          border: OutlineInputBorder(),
          helperText: _bothUsersVerified
              ? 'Transaction details locked after verification'
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_selectedDate == null
                ? 'Select date'
                : DateFormat('yyyy-MM-dd').format(_selectedDate!)),
            Icon(Icons.calendar_today, color: Colors.teal),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    return InkWell(
      onTap: _bothUsersVerified
          ? null
          : () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _selectedTime ?? TimeOfDay.now(),
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.light().copyWith(
                      colorScheme: ColorScheme.light(
                        primary: Colors.teal,
                        onPrimary: Colors.white,
                        surface: Colors.teal.shade50,
                        onSurface: Colors.black,
                      ),
                      dialogBackgroundColor: Colors.white,
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) setState(() => _selectedTime = picked);
            },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Time',
          border: OutlineInputBorder(),
          helperText: _bothUsersVerified
              ? 'Transaction details locked after verification'
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_selectedTime == null
                ? 'Select time'
                : _selectedTime!.format(context)),
            Icon(Icons.access_time, color: Colors.teal),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpSection({
    required String label,
    required TextEditingController emailController,
    required bool verified,
    required String? otpError,
    required int otpSeconds,
    required void Function() onSendOtp,
    required void Function(String) onOtpChanged,
    required void Function() onVerifyOtp,
    required bool enabled,
    required String? emailError,
    bool readOnlyEmail = false,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            TextFormField(
              controller: emailController,
              enabled: !verified && !readOnlyEmail,
              readOnly: readOnlyEmail,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                errorText: emailError,
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Email required';
                if (!val.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            if (!verified) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  if (otpSeconds == 0)
                    ElevatedButton(
                      onPressed: enabled ? onSendOtp : null,
                      child: Text('Send OTP'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal),
                    )
                  else ...[
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Resend OTP (${otpSeconds}s)',
                          style: TextStyle(
                              color: Colors.teal, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  SizedBox(width: 12),
                  if (otpError != null)
                    Text(otpError, style: TextStyle(color: Colors.red)),
                ],
              ),
              SizedBox(height: 8),
              OtpInput(
                onChanged: onOtpChanged,
                enabled: enabled,
                autoFocus: false,
              ),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: enabled ? onVerifyOtp : null,
                child: Text('Verify OTP'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              ),
            ] else ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.verified, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Verified', style: TextStyle(color: Colors.green)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Wavy blue background at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopWaveClipper(),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00B4D8), Color(0xFF48CAE4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    'New Transaction',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                  if (_bothUsersVerified) ...[
                    SizedBox(height: 8),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Transaction Details Locked',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 120),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _role,
                      items: [
                        DropdownMenuItem(
                          value: 'lender',
                          child: Text('Lender (giving money)'),
                        ),
                        DropdownMenuItem(
                          value: 'borrower',
                          child: Text('Borrower (taking money)'),
                        ),
                      ],
                      onChanged: _bothUsersVerified
                          ? null
                          : (val) => setState(() => _role = val ?? 'lender'),
                      decoration: InputDecoration(
                          labelText: 'Are you a Lender or Borrower?',
                          border: OutlineInputBorder(),
                          helperText: _bothUsersVerified
                              ? 'Transaction details locked after verification'
                              : 'Lender: You are giving money. Borrower: You are taking money.'),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      enabled: !_bothUsersVerified,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                        helperText: _bothUsersVerified
                            ? 'Transaction details locked after verification'
                            : null,
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Amount required' : null,
                    ),
                    SizedBox(height: 12),
                    _buildCurrencyDropdown(),
                    SizedBox(height: 12),
                    _buildDatePicker(),
                    SizedBox(height: 12),
                    _buildTimePicker(),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _placeController,
                      enabled: !_bothUsersVerified,
                      decoration: InputDecoration(
                        labelText: 'Place',
                        border: OutlineInputBorder(),
                        helperText: _bothUsersVerified
                            ? 'Transaction details locked after verification'
                            : null,
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Place required' : null,
                    ),
                    SizedBox(height: 12),
                    _buildFilePicker(),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _interestType,
                      items: [
                        DropdownMenuItem(
                            value: 'none',
                            child: Text('No Interest (Default)')),
                        DropdownMenuItem(
                            value: 'simple', child: Text('Simple Interest')),
                        DropdownMenuItem(
                            value: 'compound',
                            child: Text('Compound Interest')),
                      ],
                      onChanged: _bothUsersVerified
                          ? null
                          : (val) {
                              setState(() {
                                _interestType = val ?? 'none';
                                // Reset expected return date and interest rate if switching back to no interest
                                if (_interestType == 'none') {
                                  _expectedReturnDate = null;
                                  _interestRateController.clear();
                                }
                              });
                            },
                      decoration: InputDecoration(
                          labelText: 'Interest Type (Optional)',
                          border: OutlineInputBorder(),
                          helperText: _bothUsersVerified
                              ? 'Transaction details locked after verification'
                              : 'Leave as "No Interest" if no interest applies to this transaction.'),
                    ),
                    if (_interestType != 'none') ...[
                      SizedBox(height: 12),
                      TextFormField(
                        controller: _interestRateController,
                        enabled: !_bothUsersVerified,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Interest Rate (%)',
                          border: OutlineInputBorder(),
                          helperText: _bothUsersVerified
                              ? 'Transaction details locked after verification'
                              : null,
                        ),
                        validator: (val) {
                          // Only validate if interest type is selected
                          if (_interestType == 'none') return null;

                          if (val == null || val.isEmpty)
                            return 'Interest rate required when interest type is selected';
                          if (double.tryParse(val) == null)
                            return 'Enter a valid number';
                          if (double.tryParse(val)! <= 0)
                            return 'Interest rate must be greater than 0';
                          if (double.tryParse(val)! > 100)
                            return 'Interest rate cannot exceed 100%';
                          return null;
                        },
                      ),
                    ],
                    if (_interestType == 'compound') ...[
                      SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _compoundingFrequency,
                        items: [
                          DropdownMenuItem(
                              value: 1, child: Text('Annually (1x/year)')),
                          DropdownMenuItem(
                              value: 2, child: Text('Semi-annually (2x/year)')),
                          DropdownMenuItem(
                              value: 4, child: Text('Quarterly (4x/year)')),
                          DropdownMenuItem(
                              value: 12, child: Text('Monthly (12x/year)')),
                        ],
                        onChanged: _bothUsersVerified
                            ? null
                            : (val) => setState(
                                () => _compoundingFrequency = val ?? 1),
                        decoration: InputDecoration(
                            labelText: 'Compounding Frequency',
                            border: OutlineInputBorder(),
                            helperText: _bothUsersVerified
                                ? 'Transaction details locked after verification'
                                : 'How often is interest compounded?'),
                        validator: (val) {
                          // Only validate if compound interest is selected
                          if (_interestType != 'compound') return null;

                          if (val == null || val <= 0)
                            return 'Select frequency';
                          return null;
                        },
                      ),
                    ],
                    if (_interestType != 'none') ...[
                      SizedBox(height: 12),
                      InkWell(
                        onTap: _bothUsersVerified
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _expectedReturnDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null)
                                  setState(() => _expectedReturnDate = picked);
                              },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Expected Return Date *',
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: _bothUsersVerified
                                      ? Colors.grey.shade300
                                      : Colors.red.shade300),
                            ),
                            helperText: _bothUsersVerified
                                ? 'Transaction details locked after verification'
                                : 'Required when interest is applied',
                            prefixIcon: Icon(Icons.calendar_today,
                                color: _bothUsersVerified
                                    ? Colors.grey.shade300
                                    : Colors.red.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_expectedReturnDate == null
                                  ? 'Select date'
                                  : DateFormat('yyyy-MM-dd')
                                      .format(_expectedReturnDate!)),
                              Icon(Icons.calendar_today, color: Colors.teal),
                            ],
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !_bothUsersVerified,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                        hintText: _bothUsersVerified
                            ? 'Transaction details locked after verification'
                            : 'Add a note or description for this transaction',
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildOtpSection(
                      label: 'Counterparty Email',
                      emailController: _counterpartyEmailController,
                      verified: _counterpartyVerified,
                      otpError: _counterpartyOtpError,
                      otpSeconds: _counterpartyOtpSeconds,
                      onSendOtp: () async {
                        final email = _counterpartyEmailController.text;
                        if (email.trim() == _userEmailController.text.trim()) {
                          setState(() => _counterpartyEmailError =
                              'Your email and counterparty email cannot be the same.');
                          return;
                        }
                        if (!await _checkEmailExists(email)) {
                          setState(() =>
                              _counterpartyEmailError = 'Email not registered');
                          return;
                        }
                        setState(() => _counterpartyEmailError = null);
                        await _sendOtp(email, true);
                      },
                      onOtpChanged: (val) => _counterpartyOtp = val,
                      onVerifyOtp: () async {
                        if ((_counterpartyOtp ?? '').length != 6) {
                          setState(() =>
                              _counterpartyOtpError = 'Enter 6-digit OTP');
                          return;
                        }
                        await _verifyOtp(_counterpartyEmailController.text,
                            _counterpartyOtp!, true);
                      },
                      enabled: !_counterpartyVerified,
                      emailError: _counterpartyEmailError,
                    ),
                    SizedBox(height: 12),
                    _buildOtpSection(
                      label: 'Your Email',
                      emailController: _userEmailController,
                      verified: _userVerified,
                      otpError: _userOtpError,
                      otpSeconds: _userOtpSeconds,
                      onSendOtp: () async {
                        final email = _userEmailController.text;
                        if (!await _checkEmailExists(email)) {
                          setState(
                              () => _userEmailError = 'Email not registered');
                          return;
                        }
                        setState(() => _userEmailError = null);
                        await _sendOtp(email, false);
                      },
                      onOtpChanged: (val) => _userOtp = val,
                      onVerifyOtp: () async {
                        if ((_userOtp ?? '').length != 6) {
                          setState(() => _userOtpError = 'Enter 6-digit OTP');
                          return;
                        }
                        await _verifyOtp(
                            _userEmailController.text, _userOtp!, false);
                      },
                      enabled: !_userVerified,
                      emailError: _userEmailError,
                      readOnlyEmail: true,
                    ),
                    if (_sameEmailError != null) ...[
                      SizedBox(height: 8),
                      Text(_sameEmailError!,
                          style: TextStyle(color: Colors.red)),
                    ],
                    SizedBox(height: 20),
                    if (_isLoading)
                      Center(child: CircularProgressIndicator())
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _counterpartyVerified &&
                                  _userVerified &&
                                  !_isLoading
                              ? _submit
                              : null,
                          child: Text('Submit Transaction'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: EdgeInsets.symmetric(vertical: 16)),
                        ),
                      ),
                    if (_transactionId != null) ...[
                      SizedBox(height: 20),
                      Center(
                          child: Text('Transaction ID: $_transactionId',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal))),
                    ],
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
