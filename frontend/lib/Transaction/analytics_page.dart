import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'dart:convert';

class AnalyticsPage extends StatefulWidget {
  final List<dynamic>? transactions; // Not used anymore, but kept for compatibility
  const AnalyticsPage({Key? key, this.transactions}) : super(key: key);

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _filter = 'All'; // 'All', 'Lending', 'Borrowing'
  Map<String, dynamic>? analytics;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() { loading = true; error = null; });
    final session = Provider.of<SessionProvider>(context, listen: false);
    final email = session.user?['email'];
    if (email == null) {
      setState(() { error = 'User email not found.'; loading = false; });
      return;
    }
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/analytics/user?email=$email'));
      if (res.statusCode == 200) {
        setState(() {
          analytics = jsonDecode(res.body);
          loading = false;
        });
      } else {
        setState(() { error = 'Failed to fetch analytics.'; loading = false; });
      }
    } catch (e) {
      setState(() { error = 'Error: $e'; loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF00B4D8),
          elevation: 0,
          title: Text('Analytics', style: TextStyle(color: Colors.white)),
        ),
        backgroundColor: Color(0xFFF8F6FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF00B4D8),
          elevation: 0,
          title: Text('Analytics', style: TextStyle(color: Colors.white)),
        ),
        backgroundColor: Color(0xFFF8F6FA),
        body: Center(child: Text(error!, style: TextStyle(color: Colors.red))),
      );
    }
    final a = analytics!;
    final totalLent = (a['totalLent'] as num?)?.toDouble() ?? 0.0;
    final totalBorrowed = (a['totalBorrowed'] as num?)?.toDouble() ?? 0.0;
    final totalInterest = (a['totalInterest'] as num?)?.toDouble() ?? 0.0;
    final cleared = a['cleared'] ?? 0;
    final uncleared = a['uncleared'] ?? 0;
    final total = a['total'] ?? 0;
    final clearedPercent = total == 0 ? 0.0 : cleared / total;
    final monthlyCounts = List<double>.from((a['monthlyCounts'] ?? []).map((e) => (e as num).toDouble()));
    final monthLabels = List<String>.from(a['months'] ?? []);
    final topCounterparties = List<Map<String, dynamic>>.from(a['topCounterparties'] ?? []);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF00B4D8),
        elevation: 0,
        title: Text('Analytics', style: TextStyle(color: Colors.white)),
      ),
      backgroundColor: Color(0xFFF8F6FA),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF00B4D8))),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _summaryTile('Total Lent', totalLent, Colors.green),
                        _summaryTile('Total Borrowed', totalBorrowed, Colors.orange),
                        _summaryTile('Interest', totalInterest, Colors.blue),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _countTile('Cleared', cleared, Colors.green),
                        _countTile('Uncleared', uncleared, Colors.red),
                        _countTile('Total', total, Colors.teal),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text('Cleared Transactions', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: clearedPercent,
                      minHeight: 12,
                      backgroundColor: Colors.teal.shade50,
                      color: Colors.green,
                    ),
                    SizedBox(height: 6),
                    Text('${(clearedPercent * 100).toStringAsFixed(1)}% cleared', style: TextStyle(color: Colors.teal)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lent vs Borrowed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF00B4D8))),
                    SizedBox(height: 16),
                    if (totalLent == 0 && totalBorrowed == 0)
                      Center(child: Text('No data to show', style: TextStyle(color: Colors.grey))),
                    if (totalLent != 0 || totalBorrowed != 0)
                      SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                color: Colors.green,
                                value: totalLent,
                                title: 'Lent',
                                radius: 60,
                                titleStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              PieChartSectionData(
                                color: Colors.orange,
                                value: totalBorrowed,
                                title: 'Borrowed',
                                radius: 60,
                                titleStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                            sectionsSpace: 4,
                            centerSpaceRadius: 40,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cleared vs Uncleared', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF00B4D8))),
                    SizedBox(height: 16),
                    if (cleared == 0 && uncleared == 0)
                      Center(child: Text('No data to show', style: TextStyle(color: Colors.grey))),
                    if (cleared != 0 || uncleared != 0)
                      SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                color: Colors.green,
                                value: cleared.toDouble(),
                                title: 'Cleared',
                                radius: 60,
                                titleStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              PieChartSectionData(
                                color: Colors.red,
                                value: uncleared.toDouble(),
                                title: 'Uncleared',
                                radius: 60,
                                titleStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                            sectionsSpace: 4,
                            centerSpaceRadius: 40,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Top Counterparties', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF00B4D8))),
                    SizedBox(height: 16),
                    ...topCounterparties.take(5).map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          // Profile icon to the left of the email
                          GestureDetector(
                            onTap: () async {
                              showDialog(
                                context: context,
                                builder: (_) => FutureBuilder<Map<String, dynamic>?>(
                                  future: _fetchCounterpartyProfile(e['email']),
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
                                        email: e['email'],
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
                          SizedBox(width: 10),
                          Expanded(child: Text(e['email'], style: TextStyle(fontSize: 15))),
                          Text('${e['count']} txns', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00B4D8))),
                        ],
                      ),
                    )),
                    if (topCounterparties.isEmpty)
                      Text('No counterparties found.', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            // Add more analytics or filters here if needed
          ],
        ),
      ),
    );
  }

  Widget _summaryTile(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        SizedBox(height: 6),
        Text(value.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
      ],
    );
  }

  Widget _countTile(String label, int count, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        SizedBox(height: 6),
        Text(count.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
      ],
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