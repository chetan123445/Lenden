import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import '../api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:string_similarity/string_similarity.dart';
import 'chat_page.dart'; // Corrected import for ChatPage

class UserTransactionsPage extends StatefulWidget {
  @override
  _UserTransactionsPageState createState() => _UserTransactionsPageState();
}

class _UserTransactionsPageState extends State<UserTransactionsPage> {
  List<dynamic> lending = [];
  List<dynamic> borrowing = [];
  bool loading = true;
  String? error;
  String filter = 'All'; // 'All', 'Lending', 'Borrowing'
  String clearanceFilter = 'All'; // 'All', 'Totally Cleared', 'Totally Uncleared', 'Partially Cleared'
  String partialClearedType = 'my'; // 'my', 'other'
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;
  // New filter/search state
  String _searchCounterparty = '';
  String _searchPlace = '';
  String _searchTransactionId = '';
  double? _searchAmount;
  String _sortBy = 'Date'; // 'Date', 'Amount', 'Status'
  bool _sortAsc = false;
  String interestTypeFilter = 'All'; // 'All', 'simple', 'compound'
  String globalSearch = '';
  final TextEditingController _globalSearchController = TextEditingController();

  final TextEditingController _counterpartyController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _transactionIdController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool showAllTransactions = false;

  @override
  void initState() {
    super.initState();
    fetchTransactions();
    _counterpartyController.text = _searchCounterparty;
    _placeController.text = _searchPlace;
    _transactionIdController.text = _searchTransactionId;
    _amountController.text = _searchAmount?.toString() ?? '';
  }

  @override
  void dispose() {
    _counterpartyController.dispose();
    _placeController.dispose();
    _transactionIdController.dispose();
    _amountController.dispose();
    _globalSearchController.dispose();
    super.dispose();
  }

  Future<void> fetchTransactions() async {
    setState(() { loading = true; error = null; });
    final user = Provider.of<SessionProvider>(context, listen: false).user;
    final email = user?['email'];
    if (email == null) {
      setState(() { error = 'User email not found.'; loading = false; });
      return;
    }
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/transactions/user?email=$email'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        lending = data['lending'] ?? [];
        borrowing = data['borrowing'] ?? [];
        loading = false;
      });
    } else {
      setState(() { error = 'Failed to load transactions.'; loading = false; });
    }
  }

  Future<void> _deleteTransaction(String transactionId) async {
    final user = Provider.of<SessionProvider>(context, listen: false).user;
    final email = user?['email'];
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User email not found.')),
      );
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/transactions/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'transactionId': transactionId,
          'email': email,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Transaction deleted successfully!')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        
        // Refresh the transactions list
        await fetchTransactions();
      } else {
        // Show error message
        String errorMessage = data['error'] ?? 'Failed to delete transaction';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Network error: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showDeleteConfirmationDialog(String transactionId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with wave design
              Stack(
                children: [
                  ClipPath(
                    clipper: _TopWaveClipper(),
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.red[400]!, Colors.red[600]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.delete_forever, color: Colors.red[600], size: 40),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Delete Transaction',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.red[600],
                  ),
                ),
              ),
              SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Are you sure you want to delete this transaction? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteTransaction(transactionId);
                      },
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionCard(Map t, bool isLending) {
    List<Map<String, dynamic>> attachments = [];
    if (t['files'] != null && t['files'] is List && t['files'].isNotEmpty) {
      attachments = List<Map<String, dynamic>>.from(t['files']);
    } else if (t['photos'] != null && t['photos'] is List && t['photos'].isNotEmpty) {
      // For backward compatibility, treat photos as images
      attachments = t['photos'].map<Map<String, dynamic>>((p) => {'type': 'image/jpeg', 'data': p, 'name': 'Photo'}).toList();
    }
    List<Widget> fileWidgets = [];
    // Handle new 'files' array
    if (t['files'] != null && t['files'] is List && t['files'].isNotEmpty) {
      for (var file in t['files']) {
        if (file['type'] != null && file['type'].toString().startsWith('image/')) {
          // Image
          final bytes = base64Decode(file['data']);
          fileWidgets.add(GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.black,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: InteractiveViewer(
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(bytes, width: 60, height: 60, fit: BoxFit.cover),
            ),
          ));
        } else if (file['type'] == 'application/pdf') {
          // PDF
          fileWidgets.add(GestureDetector(
            onTap: () async {
              final bytes = base64Decode(file['data']);
              final tempDir = await getTemporaryDirectory();
              final tempFile = File('${tempDir.path}/${file['name'] ?? 'document.pdf'}');
              await tempFile.writeAsBytes(bytes, flush: true);
              await OpenFile.open(tempFile.path);
            },
            child: Column(
              children: [
                Icon(Icons.picture_as_pdf, size: 40, color: Colors.red),
                Text(file['name'] ?? 'PDF', style: TextStyle(fontSize: 10)),
              ],
            ),
          ));
        }
      }
      fileWidgets.add(SizedBox(height: 8));
    }
    // Fallback for old 'photos' array
    if (t['photos'] != null && t['photos'] is List && t['photos'].isNotEmpty) {
      fileWidgets.add(
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: t['photos'].length,
            separatorBuilder: (_, __) => SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final bytes = base64Decode(t['photos'][idx]);
              return GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.black,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: InteractiveViewer(
                          child: Image.memory(bytes, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(bytes, width: 60, height: 60, fit: BoxFit.cover),
                ),
              );
            },
          ),
        ),
      );
      fileWidgets.add(SizedBox(height: 8));
    }
    final user = Provider.of<SessionProvider>(context, listen: false).user;
    final email = user?['email'];
    final counterpartyEmail = t['counterpartyEmail'];
    final userEmail = t['userEmail'];
    bool youCleared = (isLending ? t['userCleared'] : t['counterpartyCleared']) == true;
    bool otherCleared = (isLending ? t['counterpartyCleared'] : t['userCleared']) == true;
    bool fullyCleared = youCleared && otherCleared;
    // Interest/return info
    List<Widget> interestWidgets = [];
    if (t['interestType'] != null && t['interestType'] != '' && t['interestRate'] != null && t['expectedReturnDate'] != null) {
      String typeLabel = t['interestType'] == 'simple' ? 'Simple Interest' : 'Compound Interest';
      double principal = t['amount'] is num ? t['amount'].toDouble() : double.tryParse(t['amount'].toString()) ?? 0.0;
      double rate = t['interestRate'] is num ? t['interestRate'].toDouble() : double.tryParse(t['interestRate'].toString()) ?? 0.0;
      DateTime start = t['date'] != null ? DateTime.tryParse(t['date']) ?? DateTime.now() : DateTime.now();
      DateTime end = DateTime.tryParse(t['expectedReturnDate']) ?? start;
      double years = end.difference(start).inDays / 365.0;
      double expectedAmount = principal;
      String freqLabel = '';
      if (t['interestType'] == 'simple') {
        expectedAmount = principal + (principal * rate * years / 100);
      } else if (t['interestType'] == 'compound') {
        int n = t['compoundingFrequency'] is int ? t['compoundingFrequency'] : int.tryParse(t['compoundingFrequency'].toString() ?? '') ?? 1;
        if (n == 1) freqLabel = 'Annually';
        else if (n == 2) freqLabel = 'Semi-annually';
        else if (n == 4) freqLabel = 'Quarterly';
        else if (n == 12) freqLabel = 'Monthly';
        else freqLabel = '${n}x/year';
        expectedAmount = principal * pow(1 + rate / 100 / n, n * years);
      }
      interestWidgets.add(SizedBox(height: 8));
      interestWidgets.add(Row(
        children: [
          Icon(Icons.percent, color: Colors.blue, size: 20),
          SizedBox(width: 6),
          Text('$typeLabel @ ${rate.toStringAsFixed(2)}%' + (freqLabel.isNotEmpty ? ' ($freqLabel)' : ''), style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ));
      interestWidgets.add(SizedBox(height: 4));
      interestWidgets.add(Row(
        children: [
          Icon(Icons.calendar_today, color: Colors.teal, size: 18),
          SizedBox(width: 6),
          Text('Expected Return Date: ${DateFormat('yyyy-MM-dd').format(end)}', style: TextStyle(fontSize: 14)),
        ],
      ));
      interestWidgets.add(SizedBox(height: 4));
      interestWidgets.add(Row(
        children: [
          Icon(Icons.attach_money, color: Colors.green, size: 20),
          SizedBox(width: 6),
          Text('Expected Amount: ${expectedAmount.toStringAsFixed(2)} ${t['currency']}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800])),
        ],
      ));
    }
    String dateStr = t['date'] != null ? t['date'].toString().substring(0, 10) : '';
    String timeStr = t['time'] != null ? t['time'].toString() : '';
    String counterparty = isLending ? t['counterpartyEmail'] : t['counterpartyEmail'];
    Color borderColor = fullyCleared
        ? Colors.green
        : (youCleared || otherCleared)
            ? Colors.orange
            : Colors.teal;
    
    // Add a subtle indicator for deletable transactions
    Widget? deleteIndicator;
    if (fullyCleared) {
      deleteIndicator = Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 16),
            SizedBox(width: 4),
            Text(
              'Ready to delete',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    List<Widget> statusWidgets = [];
    if (fullyCleared) {
      statusWidgets.add(Row(children: [Icon(Icons.verified, color: Colors.green), SizedBox(width: 6), Text('Fully Cleared', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]));
    } else if (youCleared && !otherCleared) {
      statusWidgets.add(Row(children: [Icon(Icons.check, color: Colors.orange), SizedBox(width: 6), Text('You cleared. Waiting for other party.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))]));
    } else if (!youCleared && otherCleared) {
      statusWidgets.add(Row(children: [Icon(Icons.check, color: Colors.orange), SizedBox(width: 6), Text('Other party cleared. Waiting for you.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))]));
    } else {
      statusWidgets.add(Row(children: [Icon(Icons.hourglass_empty, color: Colors.grey), SizedBox(width: 6), Text('Uncleared', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))]));
    }
    if (!youCleared) {
      statusWidgets.add(SizedBox(height: 8));
      statusWidgets.add(ElevatedButton(
        onPressed: () => _clearTransaction(t['transactionId']),
        child: Text('Clear Transaction'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
      ));
    }
    
    // Add helpful message for uncleared transactions
    if (!fullyCleared) {
      statusWidgets.add(SizedBox(height: 8));
      statusWidgets.add(Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Both parties must clear this transaction before it can be deleted.',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ));
    }
    // Always show See Description button
    Widget seeDescriptionButton = Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: OutlinedButton.icon(
        icon: Icon(Icons.info_outline, color: Colors.teal),
        label: Text('See Description', style: TextStyle(color: Colors.teal)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.teal),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          final desc = (t['description'] ?? '').trim();
          showDialog(
            context: context,
            builder: (_) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      ClipPath(
                        clipper: _TopWaveClipper(),
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
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.info_outline, color: Color(0xFF00B4D8), size: 40),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text('Transaction Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF00B4D8))),
                  SizedBox(height: 8),
                  Divider(thickness: 1, color: Colors.teal[100]),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Card(
                      color: Colors.teal.withOpacity(0.04),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          desc.isNotEmpty ? desc : 'No description to show.',
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF00B4D8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      icon: Icon(Icons.close, color: Colors.white),
                      label: Text('Close', style: TextStyle(color: Colors.white)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border(
          left: BorderSide(color: borderColor, width: 6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isLending ? Icons.arrow_upward : Icons.arrow_downward, color: isLending ? Colors.green : Colors.orange, size: 28),
                SizedBox(width: 10),
                // Only one profile icon for the logged-in user
                GestureDetector(
                  onTap: () async {
                    final profile = user;
                    final gender = profile?['gender'] ?? 'Other';
                    dynamic imageUrl = profile?['profileImage'];
                    if (imageUrl is Map && imageUrl['url'] != null) imageUrl = imageUrl['url'];
                    if (imageUrl != null && imageUrl is! String) imageUrl = null;
                    ImageProvider avatarProvider;
                    if (imageUrl != null && imageUrl.toString().isNotEmpty && imageUrl != 'null') {
                      avatarProvider = NetworkImage(imageUrl);
                    } else {
                      avatarProvider = AssetImage(
                        gender == 'Male'
                            ? 'assets/Male.png'
                            : gender == 'Female'
                                ? 'assets/Female.png'
                                : 'assets/Other.png',
                      );
                    }
                    final phoneStr = (profile?['phone'] ?? '').toString();
                    showDialog(
                      context: context,
                      builder: (_) => _StylishProfileDialog(
                        title: 'You',
                        name: profile?['name'] ?? 'You',
                        avatarProvider: avatarProvider,
                        email: profile?['email'],
                        phone: phoneStr,
                        gender: profile?['gender'],
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.teal.shade100,
                    child: Icon(Icons.person, color: Colors.teal, size: 22),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isLending ? 'Lending (You gave money)' : 'Borrowing (You took money)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: isLending ? Colors.green : Colors.orange, fontSize: 16),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            // Counterparty profile icon to the left of the counterparty email (remove right icon)
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    showDialog(
                      context: context,
                      builder: (_) => FutureBuilder<Map<String, dynamic>?>(
                        future: _fetchCounterpartyProfile(counterpartyEmail),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }
                          final profile = snapshot.data;
                          if (profile == null) {
                            return _StylishProfileDialog(
                              title: 'Counterparty Info',
                              name: 'No profile found.',
                              avatarProvider: AssetImage('assets/Other.png'),
                              email: counterpartyEmail,
                            );
                          }
                          final gender = profile['gender'] ?? 'Other';
                          dynamic imageUrl = profile['profileImage'];
                          if (imageUrl is Map && imageUrl['url'] != null) imageUrl = imageUrl['url'];
                          if (imageUrl != null && imageUrl is! String) imageUrl = null;
                          ImageProvider avatarProvider;
                          if (imageUrl != null && imageUrl.toString().isNotEmpty && imageUrl != 'null') {
                            avatarProvider = NetworkImage(imageUrl);
                          } else {
                            avatarProvider = AssetImage(
                              gender == 'Male'
                                  ? 'assets/Male.png'
                                  : gender == 'Female'
                                      ? 'assets/Female.png'
                                      : 'assets/Other.png',
                            );
                          }
                          final phoneStr = (profile['phone'] ?? '').toString();
                          return _StylishProfileDialog(
                            title: 'Counterparty',
                            name: profile['name'] ?? 'Counterparty',
                            avatarProvider: avatarProvider,
                            email: profile['email'],
                            phone: phoneStr,
                            gender: profile['gender'],
                          );
                        },
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.teal.shade100,
                    child: Icon(Icons.person_outline, color: Colors.teal, size: 16),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Counterparty: $counterpartyEmail', style: TextStyle(fontSize: 15, color: Colors.black87)),
                ),
              ],
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue, size: 18),
                SizedBox(width: 6),
                Text('Date: $dateStr', style: TextStyle(fontSize: 14)),
                SizedBox(width: 16),
                Icon(Icons.access_time, color: Colors.deepPurple, size: 18),
                SizedBox(width: 6),
                Text('Time: $timeStr', style: TextStyle(fontSize: 14)),
              ],
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.place, color: Colors.purple, size: 18),
                SizedBox(width: 6),
                Text('Place: ${t['place'] ?? ''}', style: TextStyle(fontSize: 14)),
              ],
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.confirmation_number, color: Colors.grey, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text('Transaction ID: ${t['transactionId']}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ),
              ],
            ),
            if (attachments.isNotEmpty) ...[
              SizedBox(height: 10),
              ElevatedButton.icon(
                icon: Icon(Icons.attach_file),
                label: Text('View Attachments'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => _AttachmentCarouselDialog(attachments: attachments),
                  );
                },
              ),
            ] else ...[
              SizedBox(height: 10),
              Text('No attachments', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
            ],
            if (fileWidgets.isNotEmpty) ...[
              SizedBox(height: 10),
              ...fileWidgets,
            ],
            if (interestWidgets.isNotEmpty) ...[
              SizedBox(height: 10),
              ...interestWidgets,
            ],
            if (deleteIndicator != null) deleteIndicator,
            seeDescriptionButton,
            SizedBox(height: 10),
            ...statusWidgets,
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.chat_bubble, color: Colors.white),
                    label: Text('Chat', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // Make the chat button green
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final transactionId = t != null && t['_id'] != null ? t['_id'] : '';
                      final session = Provider.of<SessionProvider>(context, listen: false);
                      final userObj = session.user;
                      final userEmail = userObj != null ? userObj['email'] : null;
                      String? counterpartyEmail;
                      if (t['userEmail'] == userEmail) {
                        counterpartyEmail = t['counterpartyEmail'];
                      } else {
                        counterpartyEmail = t['userEmail'];
                      }
                      print('transactionId: $transactionId');
                      print('userEmail: $userEmail');
                      print('counterpartyEmail: $counterpartyEmail');
                      if (transactionId != '' && counterpartyEmail != null) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChatPage(
                            transactionId: transactionId,
                            counterpartyEmail: counterpartyEmail!, // Use null assertion operator
                          ),
                        ));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Unable to open chat: missing transaction or user info')),
                        );
                      }
                    },
                  ),
                ),
                SizedBox(width: 8),
                // Delete button - only show if both parties have cleared
                if (fullyCleared)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.delete_forever, color: Colors.white),
                      label: Text('Delete', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        _showDeleteConfirmationDialog(t['transactionId']);
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: Text('All'),
          selected: filter == 'All',
          onSelected: (_) => setState(() => filter = 'All'),
          selectedColor: Color(0xFF00B4D8).withOpacity(0.2),
        ),
        SizedBox(width: 8),
        ChoiceChip(
          label: Text('Lending'),
          selected: filter == 'Lending',
          onSelected: (_) => setState(() => filter = 'Lending'),
          selectedColor: Colors.green.withOpacity(0.2),
          labelStyle: TextStyle(color: Colors.green[800]),
        ),
        SizedBox(width: 8),
        ChoiceChip(
          label: Text('Borrowing'),
          selected: filter == 'Borrowing',
          onSelected: (_) => setState(() => filter = 'Borrowing'),
          selectedColor: Colors.orange.withOpacity(0.2),
          labelStyle: TextStyle(color: Colors.orange[800]),
        ),
      ],
    );
  }

  Widget _buildClearanceFilterChips() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Tooltip(
                      message: 'Show all transactions',
                      child: ChoiceChip(
                        label: Text('All'),
                        selected: clearanceFilter == 'All',
                        onSelected: (_) => setState(() => clearanceFilter = 'All'),
                        selectedColor: Color(0xFF00B4D8).withOpacity(0.2),
                      ),
                    ),
                    SizedBox(width: 8),
                    Tooltip(
                      message: 'Both parties have cleared',
                      child: ChoiceChip(
                        label: Text('Totally Cleared'),
                        selected: clearanceFilter == 'Totally Cleared',
                        onSelected: (_) => setState(() => clearanceFilter = 'Totally Cleared'),
                        selectedColor: Colors.green.withOpacity(0.2),
                        labelStyle: TextStyle(color: Colors.green[800]),
                      ),
                    ),
                    SizedBox(width: 8),
                    Tooltip(
                      message: 'Neither party has cleared',
                      child: ChoiceChip(
                        label: Text('Totally Uncleared'),
                        selected: clearanceFilter == 'Totally Uncleared',
                        onSelected: (_) => setState(() => clearanceFilter = 'Totally Uncleared'),
                        selectedColor: Colors.orange.withOpacity(0.2),
                        labelStyle: TextStyle(color: Colors.orange[800]),
                      ),
                    ),
                    SizedBox(width: 8),
                    Tooltip(
                      message: 'Only one party has cleared',
                      child: ChoiceChip(
                        label: Text('Partially Cleared'),
                        selected: clearanceFilter == 'Partially Cleared',
                        onSelected: (_) => setState(() => clearanceFilter = 'Partially Cleared'),
                        selectedColor: Colors.blue.withOpacity(0.2),
                        labelStyle: TextStyle(color: Colors.blue[800]),
                      ),
                    ),
                  ],
                ),
              ),
              if (clearanceFilter == 'Partially Cleared')
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ToggleButtons(
                        isSelected: [partialClearedType == 'my', partialClearedType == 'other'],
                        onPressed: (idx) => setState(() => partialClearedType = idx == 0 ? 'my' : 'other'),
                        borderRadius: BorderRadius.circular(8),
                        selectedColor: Colors.white,
                        fillColor: Colors.teal,
                        color: Colors.teal,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(children: [Icon(Icons.person, size: 18), SizedBox(width: 6), Text('My Side')]),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(children: [Icon(Icons.people, size: 18), SizedBox(width: 6), Text('Other Party Side')]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Interest type filter chips
        Container(
          margin: EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: Text('All'),
                selected: interestTypeFilter == 'All',
                onSelected: (_) => setState(() => interestTypeFilter = 'All'),
                selectedColor: Color(0xFF00B4D8).withOpacity(0.2),
              ),
              SizedBox(width: 8),
              ChoiceChip(
                label: Text('Simple Interest'),
                selected: interestTypeFilter == 'simple',
                onSelected: (_) => setState(() => interestTypeFilter = 'simple'),
                selectedColor: Colors.green.withOpacity(0.2),
                labelStyle: TextStyle(color: Colors.green[800]),
              ),
              SizedBox(width: 8),
              ChoiceChip(
                label: Text('Compound Interest'),
                selected: interestTypeFilter == 'compound',
                onSelected: (_) => setState(() => interestTypeFilter = 'compound'),
                selectedColor: Colors.blue.withOpacity(0.2),
                labelStyle: TextStyle(color: Colors.blue[800]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Start Date',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Text(_startDate == null ? 'Any' : DateFormat('yyyy-MM-dd').format(_startDate!)),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _endDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'End Date',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Text(_endDate == null ? 'Any' : DateFormat('yyyy-MM-dd').format(_endDate!)),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Min Amount',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (val) => setState(() => _minAmount = double.tryParse(val)),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Max Amount',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: (val) => setState(() => _maxAmount = double.tryParse(val)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _transactionMatchesFilters(Map t) {
    final date = t['date'] != null ? DateTime.tryParse(t['date']) : null;
    final amount = t['amount'] is num ? t['amount'].toDouble() : double.tryParse(t['amount'].toString() ?? '');
    if (_startDate != null && (date == null || date.isBefore(_startDate!))) return false;
    if (_endDate != null && (date == null || date.isAfter(_endDate!))) return false;
    if (_minAmount != null && (amount == null || amount < _minAmount!)) return false;
    if (_maxAmount != null && (amount == null || amount > _maxAmount!)) return false;
    if (interestTypeFilter != 'All' && (t['interestType'] ?? '').toString().toLowerCase() != interestTypeFilter) return false;
    // Global fuzzy search
    if (globalSearch.isNotEmpty) {
      final q = globalSearch.toLowerCase();
      bool match(String? s) => s != null && s.toLowerCase().contains(q);
      bool fuzzyMatch(String? a, String? b) {
        if (a == null || b == null) return false;
        a = a.toLowerCase();
        b = b.toLowerCase();
        if (a.contains(b) || b.contains(a)) return true;
        return StringSimilarity.compareTwoStrings(a, b) > 0.6;
      }
      final isLending = t['role'] == 'lender' || (t['userEmail'] == Provider.of<SessionProvider>(context, listen: false).user?['email'] && t['role'] == 'lender');
      final isBorrowing = t['role'] == 'borrower' || (t['userEmail'] == Provider.of<SessionProvider>(context, listen: false).user?['email'] && t['role'] == 'borrower');
      if (
        fuzzyMatch(t['counterpartyEmail']?.toString(), q) ||
        fuzzyMatch(t['place']?.toString(), q) ||
        fuzzyMatch(t['interestType']?.toString(), q) ||
        fuzzyMatch(t['transactionId']?.toString(), q) ||
        (amount != null && amount.toString().contains(q)) ||
        (isLending && 'lending'.contains(q)) ||
        (isBorrowing && 'borrowing'.contains(q))
      ) {
        // pass
      } else {
        return false;
      }
    }
    return true;
  }

  Future<void> _clearTransaction(String transactionId) async {
    final user = Provider.of<SessionProvider>(context, listen: false).user;
    final email = user?['email'];
    if (email == null) return;
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/transactions/clear'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'transactionId': transactionId, 'email': email}),
    );
    if (res.statusCode == 200) {
      fetchTransactions();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to clear transaction')));
    }
  }

  List<Widget> _buildFilteredTransactionCards({int? limit}) {
    List<Widget> widgets = [];
    bool isTotallyCleared(t) => (t['userCleared'] == true && t['counterpartyCleared'] == true);
    bool isTotallyUncleared(t) => (t['userCleared'] != true && t['counterpartyCleared'] != true);
    bool isPartiallyClearedMySide(t) {
      final user = Provider.of<SessionProvider>(context, listen: false).user;
      final email = user?['email'];
      // If user is userEmail, check userCleared; if user is counterpartyEmail, check counterpartyCleared
      if (t['userEmail'] == email) {
        return t['userCleared'] == true && t['counterpartyCleared'] != true;
      } else if (t['counterpartyEmail'] == email) {
        return t['counterpartyCleared'] == true && t['userCleared'] != true;
      }
      return false;
    }
    bool isPartiallyClearedOtherSide(t) {
      final user = Provider.of<SessionProvider>(context, listen: false).user;
      final email = user?['email'];
      // If user is userEmail, check counterpartyCleared; if user is counterpartyEmail, check userCleared
      if (t['userEmail'] == email) {
        return t['counterpartyCleared'] == true && t['userCleared'] != true;
      } else if (t['counterpartyEmail'] == email) {
        return t['userCleared'] == true && t['counterpartyCleared'] != true;
      }
      return false;
    }
    // Apply clearance filter before other filters
    List lendingFiltered = lending;
    List borrowingFiltered = borrowing;
    if (clearanceFilter == 'Totally Cleared') {
      lendingFiltered = lending.where(isTotallyCleared).toList();
      borrowingFiltered = borrowing.where(isTotallyCleared).toList();
    } else if (clearanceFilter == 'Totally Uncleared') {
      lendingFiltered = lending.where(isTotallyUncleared).toList();
      borrowingFiltered = borrowing.where(isTotallyUncleared).toList();
    } else if (clearanceFilter == 'Partially Cleared') {
      if (partialClearedType == 'my') {
        lendingFiltered = lending.where(isPartiallyClearedMySide).toList();
        borrowingFiltered = borrowing.where(isPartiallyClearedMySide).toList();
      } else {
        lendingFiltered = lending.where(isPartiallyClearedOtherSide).toList();
        borrowingFiltered = borrowing.where(isPartiallyClearedOtherSide).toList();
      }
    }
    // --- Apply search filters ---
    bool matchesSearch(t) {
      bool fuzzyMatch(String a, String b) {
        if (a.isEmpty || b.isEmpty) return false;
        a = a.toLowerCase();
        b = b.toLowerCase();
        if (a.contains(b) || b.contains(a)) return true;
        return StringSimilarity.compareTwoStrings(a, b) > 0.6;
      }
      if (globalSearch.isNotEmpty) {
        final q = globalSearch.toLowerCase();
        bool match(String? s) => s != null && s.toLowerCase().contains(q);
        final isLending = t['role'] == 'lender' || (t['userEmail'] == Provider.of<SessionProvider>(context, listen: false).user?['email'] && t['role'] == 'lender');
        final isBorrowing = t['role'] == 'borrower' || (t['userEmail'] == Provider.of<SessionProvider>(context, listen: false).user?['email'] && t['role'] == 'borrower');
        if (
          fuzzyMatch((t['counterpartyEmail']?.toString() ?? ''), q) ||
          fuzzyMatch((t['place']?.toString() ?? ''), q) ||
          fuzzyMatch((t['interestType']?.toString() ?? ''), q) ||
          fuzzyMatch((t['transactionId']?.toString() ?? ''), q) ||
          (t['amount'] is num && (t['amount'] as num).toDouble().toString().contains(q)) ||
          (isLending && 'lending'.contains(q)) ||
          (isBorrowing && 'borrowing'.contains(q))
        ) {
          // pass
        } else {
          return false;
        }
      }
      return true;
    }
    // --- Sorting ---
    int sortCompare(a, b) {
      if (_sortBy == 'Date') {
        final da = a['date'] != null ? DateTime.tryParse(a['date']) : null;
        final db = b['date'] != null ? DateTime.tryParse(b['date']) : null;
        if (da == null && db == null) return 0;
        if (da == null) return _sortAsc ? -1 : 1;
        if (db == null) return _sortAsc ? 1 : -1;
        return _sortAsc ? da.compareTo(db) : db.compareTo(da);
      } else if (_sortBy == 'Amount') {
        final aa = a['amount'] is num ? a['amount'].toDouble() : double.tryParse(a['amount'].toString()) ?? 0.0;
        final ab = b['amount'] is num ? b['amount'].toDouble() : double.tryParse(b['amount'].toString()) ?? 0.0;
        return _sortAsc ? aa.compareTo(ab) : ab.compareTo(aa);
      } else if (_sortBy == 'Status') {
        final sa = (a['userCleared'] == true && a['counterpartyCleared'] == true) ? 2 : (a['userCleared'] == true || a['counterpartyCleared'] == true) ? 1 : 0;
        final sb = (b['userCleared'] == true && b['counterpartyCleared'] == true) ? 2 : (b['userCleared'] == true || b['counterpartyCleared'] == true) ? 1 : 0;
        return _sortAsc ? sa.compareTo(sb) : sb.compareTo(sa);
      }
      return 0;
    }
    if (filter == 'All' || filter == 'Lending') {
      var filteredLending = lendingFiltered.where((t) => _transactionMatchesFilters(t) && matchesSearch(t)).toList();
      filteredLending.sort(sortCompare);
      if (!showAllTransactions && limit != null && filteredLending.length > limit) {
        filteredLending = filteredLending.take(limit).toList();
      }
      if (filteredLending.isNotEmpty) {
        widgets.add(Text('Lending Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)));
        widgets.add(SizedBox(height: 8));
        widgets.addAll(filteredLending.map((t) => _buildTransactionCard(t, true)));
        widgets.add(SizedBox(height: 20));
      }
    }
    if (filter == 'All' || filter == 'Borrowing') {
      var filteredBorrowing = borrowingFiltered.where((t) => _transactionMatchesFilters(t) && matchesSearch(t)).toList();
      filteredBorrowing.sort(sortCompare);
      if (!showAllTransactions && limit != null && filteredBorrowing.length > limit) {
        filteredBorrowing = filteredBorrowing.take(limit).toList();
      }
      if (filteredBorrowing.isNotEmpty) {
        widgets.add(Text('Borrowing Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange)));
        widgets.add(SizedBox(height: 8));
        widgets.addAll(filteredBorrowing.map((t) => _buildTransactionCard(t, false)));
      }
    }
    if (widgets.isEmpty) {
      widgets.add(Center(child: Text('No transactions found.', style: TextStyle(color: Colors.grey))));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF00B4D8),
        elevation: 0,
        title: Text('Your Transactions', style: TextStyle(color: Colors.white)),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!, style: TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: TextField(
                        controller: _globalSearchController,
                        decoration: InputDecoration(
                          hintText: 'Search transactions... (email, place, type, id, amount, lending/borrowing)',
                          prefixIcon: Icon(Icons.search, color: Color(0xFF00B4D8)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Color(0xFF00B4D8), width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Color(0xFF00B4D8), width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Color(0xFF00B4D8), width: 2),
                          ),
                        ),
                        onChanged: (v) => setState(() => globalSearch = v),
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildFilterChips(),
                    SizedBox(height: 8),
                    _buildClearanceFilterChips(),
                    SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          if (showAllTransactions)
                            ..._buildFilteredTransactionCards(),
                          if (!showAllTransactions)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: ElevatedButton(
                                  onPressed: () => setState(() => showAllTransactions = true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF00B4D8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  ),
                                  child: Text('View All Transactions', style: TextStyle(color: Colors.white, fontSize: 16)),
                                ),
                              ),
                            ),
                          if (showAllTransactions)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: ElevatedButton(
                                  onPressed: () => setState(() => showAllTransactions = false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[300],
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  ),
                                  child: Text('Close', style: TextStyle(color: Color(0xFF00B4D8), fontSize: 16)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<Map<String, dynamic>?> _fetchCounterpartyProfile(String email) async {
    if (email.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/users/profile-by-email?email=$email'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return null;
  }
}

class _TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.8);
    path.quadraticBezierTo(
      size.width * 0.25, size.height,
      size.width * 0.5, size.height * 0.8,
    );
    path.quadraticBezierTo(
      size.width * 0.75, size.height * 0.6,
      size.width, size.height * 0.8,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _AttachmentCarouselDialog extends StatefulWidget {
  final List<Map<String, dynamic>> attachments;
  const _AttachmentCarouselDialog({required this.attachments});
  @override
  State<_AttachmentCarouselDialog> createState() => _AttachmentCarouselDialogState();
}

class _AttachmentCarouselDialogState extends State<_AttachmentCarouselDialog> {
  int _currentIndex = 0;
  PageController? _pageController;
  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }
  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final attachments = widget.attachments;
    return Dialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 350,
        height: 420,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: attachments.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (context, i) {
                  final file = attachments[i];
                  if (file['type'] != null && file['type'].toString().startsWith('image/')) {
                    final bytes = base64Decode(file['data']);
                    return InteractiveViewer(
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    );
                  } else if (file['type'] == 'application/pdf') {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
                          SizedBox(height: 16),
                          Text(file['name'] ?? 'PDF', style: TextStyle(color: Colors.white)),
                          SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: Icon(Icons.open_in_new),
                            label: Text('Open PDF'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                            onPressed: () async {
                              final bytes = base64Decode(file['data']);
                              final tempDir = await getTemporaryDirectory();
                              final tempFile = File('${tempDir.path}/${file['name'] ?? 'document.pdf'}');
                              await tempFile.writeAsBytes(bytes, flush: true);
                              await OpenFile.open(tempFile.path);
                            },
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Center(child: Text('Unsupported file', style: TextStyle(color: Colors.white)));
                  }
                },
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(attachments.length, (i) => Container(
                margin: EdgeInsets.symmetric(horizontal: 4),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _currentIndex ? Colors.teal : Colors.white24,
                ),
              )),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                  onPressed: () {
                    int newIndex = (_currentIndex - 1 + attachments.length) % attachments.length;
                    _pageController?.animateToPage(newIndex, duration: Duration(milliseconds: 300), curve: Curves.ease);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, color: Colors.white),
                  onPressed: () {
                    int newIndex = (_currentIndex + 1) % attachments.length;
                    _pageController?.animateToPage(newIndex, duration: Duration(milliseconds: 300), curve: Curves.ease);
                  },
                ),
              ],
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            ),
          ],
        ),
      ),
    );
  }
}

class _StylishProfileDialog extends StatelessWidget {
  final String title;
  final String name;
  final ImageProvider avatarProvider;
  final String? email;
  final String? phone;
  final String? gender;
  const _StylishProfileDialog({required this.title, required this.name, required this.avatarProvider, this.email, this.phone, this.gender});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color(0xFF00B4D8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                CircleAvatar(radius: 36, backgroundImage: avatarProvider),
                SizedBox(height: 12),
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
                SizedBox(height: 4),
                Text(title, style: TextStyle(fontSize: 14, color: Colors.white70)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (email != null) ...[
                  Row(children: [Icon(Icons.email, size: 18, color: Colors.teal), SizedBox(width: 8), Text(email!, style: TextStyle(fontSize: 16))]),
                  SizedBox(height: 10),
                ],
                if (phone != null && phone!.isNotEmpty) ...[
                  Row(children: [Icon(Icons.phone, size: 18, color: Colors.teal), SizedBox(width: 8), Text(phone!, style: TextStyle(fontSize: 16))]),
                  SizedBox(height: 10),
                ],
                if (gender != null) ...[
                  Row(children: [Icon(Icons.transgender, size: 18, color: Colors.teal), SizedBox(width: 8), Text(gender!, style: TextStyle(fontSize: 16))]),
                  SizedBox(height: 10),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF00B4D8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
        ],
      ),
    );
  }
} 