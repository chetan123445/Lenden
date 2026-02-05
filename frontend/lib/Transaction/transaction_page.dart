//This file is to create Transactions.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../otp_input.dart';
import '../api_config.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import '../utils/api_client.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Add for wavy background
import 'dart:math' as math;
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'user_transactions_page.dart';
import '../widgets/subscription_prompt.dart';
import '../user/gift_card_page.dart';
import '../widgets/stylish_dialog.dart';
import '../Digitise/subscriptions_page.dart';

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
  final String? prefillCounterpartyEmail;

  const TransactionPage({Key? key, this.prefillCounterpartyEmail})
      : super(key: key);

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
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _friendSuggestions = [];
  Set<String> _blockedEmails = {};

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
    if ((widget.prefillCounterpartyEmail ?? '').isNotEmpty) {
      _counterpartyEmailController.text =
          widget.prefillCounterpartyEmail!.trim();
    }
    _loadFriends();
    _counterpartyEmailController.addListener(_updateFriendSuggestions);
    // Prefill user email from session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<SessionProvider>(context, listen: false).user;
      if (user != null && user['email'] != null) {
        _userEmailController.text = user['email'];
      }
    });
  }

  Future<void> _pickFriendForCounterparty() async {
    try {
      final res = await ApiClient.get('/api/friends');
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      final friends = List<Map<String, dynamic>>.from(data['friends'] ?? []);
      final blocked = List<Map<String, dynamic>>.from(data['blockedUsers'] ?? []);
      _blockedEmails = blocked
          .map((u) => (u['email'] ?? '').toString().toLowerCase().trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.white, Colors.green],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: _getFriendNoteColor(0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Select Friend',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (friends.isEmpty)
                    const Text('No friends found')
                  else
                    ...friends.map((f) {
                      final email = f['email'] ?? '';
                      final name = f['name'] ?? f['username'] ?? '';
                      final isBlocked =
                          _blockedEmails.contains(email.toString().toLowerCase().trim());
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.white, Colors.green],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                _getFriendNoteColor(email.hashCode.abs() % 6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(name.toString()),
                            subtitle: Text(email.toString()),
                            trailing: isBlocked
                                ? const Text('Blocked',
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600))
                                : null,
                            onTap: () {
                              if (isBlocked) {
                                showBlockedUserDialog(context);
                                return;
                              }
                              setState(() {
                                _counterpartyEmailController.text =
                                    email.toString();
                              });
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (_) {}
  }

  Color _getFriendNoteColor(int index) {
    final colors = [
      Color(0xFFFFF4E6),
      Color(0xFFE8F5E9),
      Color(0xFFFCE4EC),
      Color(0xFFE3F2FD),
      Color(0xFFFFF9C4),
      Color(0xFFF3E5F5),
    ];
    return colors[index % colors.length];
  }

  @override
  void dispose() {
    _counterpartyEmailController.removeListener(_updateFriendSuggestions);
    _amountController.dispose();
    _placeController.dispose();
    _counterpartyEmailController.dispose();
    _userEmailController.dispose();
    _interestRateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    try {
      final res = await ApiClient.get('/api/friends');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _friends = List<Map<String, dynamic>>.from(data['friends'] ?? []);
          final blocked =
              List<Map<String, dynamic>>.from(data['blockedUsers'] ?? []);
          _blockedEmails = blocked
              .map((u) => (u['email'] ?? '').toString().toLowerCase().trim())
              .where((e) => e.isNotEmpty)
              .toSet();
        });
        _updateFriendSuggestions();
      }
    } catch (_) {}
  }

  bool _isBlockedEmail(String? email) {
    final target = email?.toLowerCase().trim();
    if (target == null || target.isEmpty) return false;
    return _blockedEmails.contains(target);
  }

  void _updateFriendSuggestions() {
    final query = _counterpartyEmailController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _friendSuggestions = []);
      return;
    }
    final matches = _friends.where((f) {
      final email = (f['email'] ?? '').toString().toLowerCase();
      final name = (f['name'] ?? f['username'] ?? '').toString().toLowerCase();
      if (_isBlockedEmail(email)) return false;
      return email.contains(query) || name.contains(query);
    }).toList();
    setState(() => _friendSuggestions = matches.take(5).toList());
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
    final res = await ApiClient.post(
      '/api/transactions/check-email',
      body: {'email': email},
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
    await ApiClient.post(
      url,
      body: {'email': email},
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
    final res = await ApiClient.post(
      url,
      body: {'email': email, 'otp': otp},
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
    final session = Provider.of<SessionProvider>(context, listen: false);
    if (_isBlockedEmail(_counterpartyEmailController.text)) {
      showBlockedUserDialog(context);
      return;
    }
    if (session.isSubscribed ||
        (session.freeUserTransactionsRemaining ?? 0) > 0) {
      _submitWithApi();
    } else {
      if ((session.lenDenCoins ?? 0) < 10) {
        if ((session.lenDenCoins ?? 0) == 0) {
          showZeroCoinsDialog(context);
        } else {
          showInsufficientCoinsDialog(context);
        }
      } else {
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Colors.orange, Colors.white, Colors.green],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.monetization_on,
                          color: Colors.orange, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Use LenDen Coins',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'You have no free transactions remaining. Would you like to use 10 LenDen coins to create this transaction?',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'OR',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Subscribe now for unlimited access',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SubscriptionsPage(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Text(
                              'Subscribe',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _submitWithCoins();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: Text(
                              'Use Coins',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }
    }
  }

  Future<void> _submitWithCoins() async {
    // Logic to submit with coins
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> body = {
        'amount': _amountController.text,
        'currency': _currency,
        'date': _selectedDate?.toIso8601String() ?? '',
        'time': _selectedTime?.format(context) ?? '',
        'place': _placeController.text,
        'counterpartyEmail': _counterpartyEmailController.text,
        'userEmail': _userEmailController.text,
        'role': _role,
        'interestType': _interestType,
        'description': _descriptionController.text,
      };

      if (_interestType != 'none') {
        body['interestRate'] = _interestRateController.text;
        body['expectedReturnDate'] =
            _expectedReturnDate?.toIso8601String() ?? '';
        if (_interestType == 'compound') {
          body['compoundingFrequency'] = _compoundingFrequency;
        }
      }

      // Attach files as base64 payloads to avoid multipart complexity.
      if (_pickedFiles.isNotEmpty) {
        body['files'] = _pickedFiles.where((f) => f.bytes != null).map((f) {
          final ext = (f.extension ?? '').toLowerCase();
          String mime = 'application/octet-stream';
          if (ext == 'png')
            mime = 'image/png';
          else if (ext == 'jpg' || ext == 'jpeg')
            mime = 'image/jpeg';
          else if (ext == 'pdf') mime = 'application/pdf';
          return {
            'name': f.name,
            'mime': mime,
            'data': base64Encode(f.bytes!),
          };
        }).toList();
      }

      final res =
          await ApiClient.post('/api/transactions/with-coins', body: body);
      setState(() => _isLoading = false);
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final giftCardAwarded = data['giftCardAwarded'] == true;
        setState(() {
          _transactionId = data['transactionId'];
        });
        final session = Provider.of<SessionProvider>(context, listen: false);
        session.loadFreebieCounts();
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
                  if (giftCardAwarded) ...[
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close the success dialog
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GiftCardPage(),
                            ),
                          );
                        },
                        child: Text('View Gift Card (You Earned)',
                            style:
                                TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      } else if (res.statusCode == 403) {
        String errorMsg = 'Forbidden';
        try {
          final data = jsonDecode(res.body);
          errorMsg = data['error'] ?? data['message'] ?? errorMsg;
        } catch (_) {}
        if (errorMsg.toLowerCase().contains('blocked')) {
          showBlockedUserDialog(context, message: errorMsg);
          return;
        }
        showInsufficientCoinsDialog(context);
      } else {
        final errBody = (res.body.isNotEmpty) ? res.body : 'Unknown error';
        String errorMsg = 'Failed to create transaction';
        try {
          final data = jsonDecode(errBody);
          errorMsg = data['error'] ?? data['message'] ?? errBody;
        } catch (_) {
          errorMsg = errBody;
        }
        _showStylishErrorDialog('Transaction Failed', errorMsg);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showStylishErrorDialog('Transaction Failed', e.toString());
    }
  }

  Future<void> _submitWithApi() async {
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
    try {
      final Map<String, dynamic> body = {
        'amount': _amountController.text,
        'currency': _currency,
        'date': _selectedDate?.toIso8601String() ?? '',
        'time': _selectedTime?.format(context) ?? '',
        'place': _placeController.text,
        'counterpartyEmail': _counterpartyEmailController.text,
        'userEmail': _userEmailController.text,
        'role': _role,
        'interestType': _interestType,
        'description': _descriptionController.text,
      };

      if (_interestType != 'none') {
        body['interestRate'] = _interestRateController.text;
        body['expectedReturnDate'] =
            _expectedReturnDate?.toIso8601String() ?? '';
        if (_interestType == 'compound') {
          body['compoundingFrequency'] = _compoundingFrequency;
        }
      }

      // Attach files as base64 payloads to avoid multipart complexity.
      if (_pickedFiles.isNotEmpty) {
        body['files'] = _pickedFiles.where((f) => f.bytes != null).map((f) {
          final ext = (f.extension ?? '').toLowerCase();
          String mime = 'application/octet-stream';
          if (ext == 'png')
            mime = 'image/png';
          else if (ext == 'jpg' || ext == 'jpeg')
            mime = 'image/jpeg';
          else if (ext == 'pdf') mime = 'application/pdf';
          return {
            'name': f.name,
            'mime': mime,
            'data': base64Encode(f.bytes!),
          };
        }).toList();
      }

      final res = await ApiClient.post('/api/transactions/create', body: body);
      setState(() => _isLoading = false);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final giftCardAwarded = data['giftCardAwarded'] == true;
        setState(() {
          _transactionId = data['transactionId'];
        });
        final session = Provider.of<SessionProvider>(context, listen: false);
        session.loadFreebieCounts();

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
                  if (giftCardAwarded) ...[
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(); // Close the success dialog
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GiftCardPage(),
                            ),
                          );
                        },
                        child: Text('View Gift Card (You Earned)',
                            style:
                                TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      } else {
        final errBody = (res.body.isNotEmpty) ? res.body : 'Unknown error';
        String errorMsg = 'Failed to create transaction';
        try {
          final data = jsonDecode(errBody);
          errorMsg = data['error'] ?? data['message'] ?? errBody;
        } catch (_) {
          errorMsg = errBody;
        }
        if (errorMsg.toLowerCase().contains('blocked')) {
          showBlockedUserDialog(context, message: errorMsg);
          return;
        }
        _showStylishErrorDialog('Transaction Failed', errorMsg);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showStylishErrorDialog('Transaction Failed', e.toString());
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
    VoidCallback? onPickFriend,
    List<Map<String, dynamic>>? friendSuggestions,
    void Function(String email)? onSelectFriend,
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
                suffixIcon: onPickFriend != null
                    ? IconButton(
                        icon: const Icon(Icons.people),
                        onPressed: onPickFriend,
                      )
                    : null,
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
            if (!verified &&
                (friendSuggestions ?? []).isNotEmpty &&
                onSelectFriend != null) ...[
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (friendSuggestions ?? []).map((f) {
                  final email = (f['email'] ?? '').toString();
                  final name =
                      (f['name'] ?? f['username'] ?? '').toString();
                  return Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [Colors.orange, Colors.white, Colors.green],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getFriendNoteColor(
                            email.hashCode.abs() % 6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ActionChip(
                        label:
                            Text(name.isNotEmpty ? '$name ($email)' : email),
                        onPressed: () => onSelectFriend(email),
                      ),
                    ),
                  );
                }).toList(),
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
                  Consumer<SessionProvider>(
                    builder: (context, session, child) {
                      if (session.isSubscribed) {
                        return Text('You have unlimited transactions.',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white));
                      }
                      final remaining = session.freeUserTransactionsRemaining;
                      if (remaining == null) {
                        return SizedBox.shrink();
                      }
                      return Text(
                          'You have $remaining free transactions remaining.',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white));
                    },
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
                        if (_isBlockedEmail(email)) {
                          showBlockedUserDialog(context);
                          return;
                        }
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
                      onPickFriend: _counterpartyVerified
                          ? null
                          : _pickFriendForCounterparty,
                      friendSuggestions: _friendSuggestions,
                      onSelectFriend: (email) {
                        setState(() {
                          _counterpartyEmailController.text = email;
                        });
                      },
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
                          onPressed: (_counterpartyVerified &&
                                  _userVerified &&
                                  !_isLoading)
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
