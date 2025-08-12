import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import '../api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ManageTransactionsPage extends StatefulWidget {
  @override
  _ManageTransactionsPageState createState() => _ManageTransactionsPageState();
}

class _ManageTransactionsPageState extends State<ManageTransactionsPage> {
  List<dynamic> transactions = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    setState(() { loading = true; error = null; });
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    if (token == null) {
      setState(() { error = 'Authentication token not found.'; loading = false; });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/transactions'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          transactions = data['transactions'] ?? [];
          loading = false;
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() { error = data['error'] ?? 'Failed to load transactions.'; loading = false; });
      }
    } catch (e) {
      setState(() { error = 'An error occurred: $e'; loading = false; });
    }
  }

  Future<void> _updateTransaction(String transactionId, Map<String, dynamic> updateData) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication token not found.')),
      );
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/transactions/$transactionId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaction updated successfully.')),
        );
        fetchTransactions();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to update transaction.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  void _showEditTransactionDialog(Map<String, dynamic> transaction) {
    final _amountController = TextEditingController(text: transaction['amount'].toString());
    final _currencyController = TextEditingController(text: transaction['currency']);
    final _userEmailController = TextEditingController(text: transaction['userEmail']);
    final _counterpartyEmailController = TextEditingController(text: transaction['counterpartyEmail']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Transaction'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _amountController,
                decoration: InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _currencyController,
                decoration: InputDecoration(labelText: 'Currency'),
              ),
              TextField(
                controller: _userEmailController,
                decoration: InputDecoration(labelText: 'Lender Email'),
              ),
              TextField(
                controller: _counterpartyEmailController,
                decoration: InputDecoration(labelText: 'Borrower Email'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final updateData = {
                'amount': double.tryParse(_amountController.text) ?? transaction['amount'],
                'currency': _currencyController.text,
                'userEmail': _userEmailController.text,
                'counterpartyEmail': _counterpartyEmailController.text,
              };
              Navigator.of(context).pop();
              _updateTransaction(transaction['_id'], updateData);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(String transactionId) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final token = session.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication token not found.')),
      );
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/transactions/$transactionId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaction deleted successfully.')),
        );
        fetchTransactions();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Failed to delete transaction.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  void _showDeleteConfirmationDialog(String transactionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Transaction'),
        content: Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteTransaction(transactionId);
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Transactions'),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!, style: TextStyle(color: Colors.red)))
              : ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    return Card(
                      margin: EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text('Amount: ${t['amount']} ${t['currency']}'),
                        subtitle: Text('Lender: ${t['userEmail']}\nBorrower: ${t['counterpartyEmail']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () {
                                _showEditTransactionDialog(t);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () {
                                _showDeleteConfirmationDialog(t['_id']);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
