import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import '../api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:math';

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

  @override
  void initState() {
    super.initState();
    fetchTransactions();
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

  Widget _buildTransactionCard(Map t, bool isLending) {
    List<Widget> photoWidgets = [];
    if (t['photos'] != null && t['photos'] is List && t['photos'].isNotEmpty) {
      photoWidgets.add(
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
      photoWidgets.add(SizedBox(height: 8));
    }
    final user = Provider.of<SessionProvider>(context, listen: false).user;
    final email = user?['email'];
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
                Expanded(
                  child: Text(
                    isLending ? 'Lending (You gave money)' : 'Borrowing (You took money)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: isLending ? Colors.green : Colors.orange, fontSize: 16),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: borderColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.currency_rupee, color: borderColor, size: 20),
                      Text('${t['amount']} ${t['currency']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: borderColor)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person, color: Colors.teal, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text('Counterparty: $counterparty', style: TextStyle(fontSize: 15, color: Colors.black87)),
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
            if (photoWidgets.isNotEmpty) ...[
              SizedBox(height: 10),
              ...photoWidgets,
            ],
            if (interestWidgets.isNotEmpty) ...[
              SizedBox(height: 10),
              ...interestWidgets,
            ],
            seeDescriptionButton,
            SizedBox(height: 10),
            ...statusWidgets,
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
    return Container(
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

  List<Widget> _buildFilteredTransactionCards() {
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
    if (filter == 'All' || filter == 'Lending') {
      final filteredLending = lendingFiltered.where((t) => _transactionMatchesFilters(t)).toList();
      if (filteredLending.isNotEmpty) {
        widgets.add(Text('Lending Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)));
        widgets.add(SizedBox(height: 8));
        widgets.addAll(filteredLending.map((t) => _buildTransactionCard(t, true)));
        widgets.add(SizedBox(height: 20));
      }
    }
    if (filter == 'All' || filter == 'Borrowing') {
      final filteredBorrowing = borrowingFiltered.where((t) => _transactionMatchesFilters(t)).toList();
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
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchTransactions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Wavy blue background at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: _TopWaveClipper(),
              child: Container(
                height: 160,
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
          Padding(
            padding: EdgeInsets.only(top: 120),
            child: loading
                ? Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(child: Text(error!, style: TextStyle(color: Colors.red)))
                    : RefreshIndicator(
                        onRefresh: fetchTransactions,
                        child: ListView(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: [
                            _buildFilterChips(),
                            SizedBox(height: 12),
                            _buildClearanceFilterChips(),
                            SizedBox(height: 12),
                            _buildAdvancedFilters(),
                            SizedBox(height: 16),
                            ..._buildFilteredTransactionCards(),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
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