import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../user/session.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'dart:convert';
import '../Settings/privacy_settings_page.dart';

class AnalyticsPage extends StatefulWidget {
  final List<dynamic>?
      transactions; // Not used anymore, but kept for compatibility
  const AnalyticsPage({Key? key, this.transactions}) : super(key: key);

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _filter = 'All'; // 'All', 'Lending', 'Borrowing'
  Map<String, dynamic>? analytics;
  bool loading = true;
  String? error;
  bool? analyticsSharing; // <-- add this

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() {
      loading = true;
      error = null;
    });
    final session = Provider.of<SessionProvider>(context, listen: false);
    final email = session.user?['email'];
    if (email == null) {
      setState(() {
        error = 'User email not found.';
        loading = false;
      });
      return;
    }
    try {
      final res = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/analytics/user?email=$email'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // If analyticsSharing is explicitly false, do not set analytics data
        if (data['analyticsSharing'] == false) {
          setState(() {
            analyticsSharing = false;
            analytics = null;
            loading = false;
          });
        } else {
          analyticsSharing = true;
          setState(() {
            analytics = data;
            loading = false;
          });
        }
      } else {
        setState(() {
          error = 'Failed to fetch analytics.';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade300, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text('Analytics', style: TextStyle(color: Colors.black)),
          ),
        ),
      ),
      backgroundColor: Color(0xFFF8F6FA),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
            ),
            SizedBox(height: 20),
            Text('Loading Analytics...', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          ],
        ),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 60),
              SizedBox(height: 20),
              Text('An Error Occurred', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
              SizedBox(height: 10),
              Text(error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
            ],
          ),
        ),
      );
    }

    if (analyticsSharing == false) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, size: 64, color: Colors.blue),
              SizedBox(height: 24),
              Text(
                'Analytics is disabled in your privacy settings.',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Enable analytics sharing in your privacy settings to view your visual analytics.',
                style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                icon: Icon(Icons.settings, color: Colors.white),
                label: Text('Open Privacy Settings',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00B4D8),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PrivacySettingsPage()),
                  ).then((_) => _fetchAnalytics());
                },
              ),
            ],
          ),
        ),
      );
    }

    if (analytics == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade400, size: 60),
            SizedBox(height: 20),
            Text('No analytics data available.', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          ],
        ),
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
    final monthlyCounts = List<double>.from(
        (a['monthlyCounts'] ?? []).map((e) => (e as num).toDouble()));
    final monthLabels = List<String>.from(a['months'] ?? []);
    final topCounterparties =
        List<Map<String, dynamic>>.from(a['topCounterparties'] ?? []);

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTricolorCard(
            color: _getNoteColor(0),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Summary', Icons.dashboard),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _summaryTile('Total Lent', totalLent, Colors.green, Icons.arrow_upward),
                      _summaryTile('Total Borrowed', totalBorrowed, Colors.orange, Icons.arrow_downward),
                      _summaryTile('Interest', totalInterest, Colors.blue, Icons.percent),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _countTile('Cleared', cleared, Colors.green, Icons.check_circle),
                      _countTile('Uncleared', uncleared, Colors.red, Icons.cancel),
                      _countTile('Total', total, Colors.teal, Icons.functions),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text('Cleared Transactions',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.teal)),
                  SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: clearedPercent,
                    minHeight: 12,
                    backgroundColor: Colors.teal.shade50,
                    color: Colors.green,
                  ),
                  SizedBox(height: 6),
                  Text(
                      '${(clearedPercent * 100).toStringAsFixed(1)}% cleared',
                      style: TextStyle(color: Colors.teal)),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
          _buildTricolorCard(
            color: _getNoteColor(1),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Lent vs Borrowed', Icons.pie_chart),
                  SizedBox(height: 16),
                  if (totalLent == 0 && totalBorrowed == 0)
                    Center(
                        child: Text('No data to show',
                            style: TextStyle(color: Colors.grey))),
                  if (totalLent != 0 || totalBorrowed != 0)
                    SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              color: Colors.green,
                              value: totalLent,
                              title: '${totalLent.toStringAsFixed(2)}',
                              radius: 60,
                              titleStyle: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            PieChartSectionData(
                              color: Colors.orange,
                              value: totalBorrowed,
                              title: '${totalBorrowed.toStringAsFixed(2)}',
                              radius: 60,
                              titleStyle: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
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
          _buildTricolorCard(
            color: _getNoteColor(2),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Cleared vs Uncleared', Icons.bar_chart),
                  SizedBox(height: 16),
                  if (cleared == 0 && uncleared == 0)
                    Center(
                        child: Text('No data to show',
                            style: TextStyle(color: Colors.grey))),
                  if (cleared != 0 || uncleared != 0)
                    SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              color: Colors.green,
                              value: cleared.toDouble(),
                              title: '$cleared',
                              radius: 60,
                              titleStyle: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            PieChartSectionData(
                              color: Colors.red,
                              value: uncleared.toDouble(),
                              title: '$uncleared',
                              radius: 60,
                              titleStyle: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
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
          _buildTricolorCard(
            color: _getNoteColor(3),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Top Counterparties', Icons.people),
                  SizedBox(height: 16),
                  ...topCounterparties.take(5).toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final counterparty = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: _buildCounterpartyTile(counterparty, index),
                    );
                  }),
                  if (topCounterparties.isEmpty)
                    Text('No counterparties found.',
                        style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTricolorCard({required Widget child, Color? color}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Colors.orange, Colors.white, Colors.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: color ?? Theme.of(context).cardColor,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade300, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        SizedBox(width: 12),
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF00B4D8))),
      ],
    );
  }

  Widget _summaryTile(String label, double value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [color.withOpacity(0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        SizedBox(height: 8),
        Text(label,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        SizedBox(height: 6),
        Text(value.toStringAsFixed(2),
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: color)),
      ],
    );
  }

  Widget _countTile(String label, int count, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [color.withOpacity(0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        SizedBox(height: 8),
        Text(label,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        SizedBox(height: 6),
        Text(count.toString(),
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: color)),
      ],
    );
  }

  Widget _buildCounterpartyTile(Map<String, dynamic> counterparty, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.white, Colors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: _getNoteColor(index),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  showDialog(
                    context: context,
                    builder: (_) =>
                        FutureBuilder<Map<String, dynamic>?>(
                      future:
                          _fetchCounterpartyProfile(counterparty['email']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                              child:
                                  CircularProgressIndicator());
                        }
                        final profile = snapshot.data;
                        if (profile == null) {
                          return _StylishProfileDialog(
                            title: 'Counterparty Info',
                            name: 'No profile found.',
                            avatarProvider:
                                AssetImage('assets/Other.png'),
                            email: counterparty['email'],
                          );
                        }
                        final gender =
                            profile['gender'] ?? 'Other';
                        dynamic imageUrl =
                            profile['profileImage'];
                        if (imageUrl is Map &&
                            imageUrl['url'] != null)
                          imageUrl = imageUrl['url'];
                        if (imageUrl != null &&
                            imageUrl is! String)
                          imageUrl = null;
                        ImageProvider avatarProvider;
                        if (imageUrl != null &&
                            imageUrl.toString().isNotEmpty &&
                            imageUrl != 'null') {
                          avatarProvider =
                              NetworkImage(imageUrl);
                        } else {
                          avatarProvider = AssetImage(
                            gender == 'Male'
                                ? 'assets/Male.png'
                                : gender == 'Female'
                                    ? 'assets/Female.png'
                                    : 'assets/Other.png',
                          );
                        }
                        final phoneStr =
                            (profile['phone'] ?? '').toString();
                        return _StylishProfileDialog(
                          title: 'Counterparty',
                          name:
                              profile['name'] ?? 'Counterparty',
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
                  child: Icon(Icons.person_outline,
                      color: Colors.teal, size: 16),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                  child: Text(counterparty['email'],
                      style: TextStyle(fontSize: 15))),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFF00B4D8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${counterparty['count']} txns',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _fetchCounterpartyProfile(String email) async {
    if (email.isEmpty) return null;
    try {
      final res = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/api/users/profile-by-email?email=$email'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return null;
  }

  Color _getNoteColor(int index) {
    final colors = [
      Color(0xFFFCE4EC), // Light pink
      Color(0xFFFFF4E6), // Cream
      Color(0xFFE8F5E9), // Light green
      Color(0xFFE3F2FD), // Light blue
      Color(0xFFFFF9C4), // Light yellow
      Color(0xFFF3E5F5), // Light purple
    ];
    return colors[index % colors.length];
  }
}

class _StylishProfileDialog extends StatelessWidget {
  final String title;
  final String name;
  final ImageProvider avatarProvider;
  final String? email;
  final String? phone;
  final String? gender;
  const _StylishProfileDialog(
      {required this.title,
      required this.name,
      required this.avatarProvider,
      this.email,
      this.phone,
      this.gender});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.orange, Colors.white, Colors.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Container(
          margin: EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade300, Colors.blue.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Colors.orange, Colors.white, Colors.green],
                        ),
                      ),
                      child: CircleAvatar(radius: 36, backgroundImage: avatarProvider),
                    ),
                    SizedBox(height: 12),
                    Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Colors.white)),
                    SizedBox(height: 4),
                    Text(title,
                        style: TextStyle(fontSize: 14, color: Colors.white70)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (email != null) ...[
                      _buildInfoCard(Icons.email, email!, Colors.blue.shade100),
                      SizedBox(height: 10),
                    ],
                    if (phone != null && phone!.isNotEmpty) ...[
                      _buildInfoCard(Icons.phone, phone!, Colors.green.shade100),
                      SizedBox(height: 10),
                    ],
                    if (gender != null) ...[
                      _buildInfoCard(Icons.transgender, gender!, Colors.purple.shade100),
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
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00B4D8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String text, Color color) {
    return Card(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, size: 18, color: Colors.black54),
          SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 16, color: Colors.black87))
        ]),
      ),
    );
  }
}
