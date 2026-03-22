import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Settings/privacy_settings_page.dart';
import '../../session.dart';
import '../../utils/api_client.dart';

class AnalyticsPage extends StatefulWidget {
  final List<dynamic>?
      transactions; // Not used anymore, but kept for compatibility
  const AnalyticsPage({Key? key, this.transactions}) : super(key: key);

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _secureAnalytics;
  Map<String, dynamic>? _groupAnalytics;
  bool _secureLoading = true;
  bool _groupLoading = true;
  String? _secureError;
  String? _groupError;
  bool? analyticsSharing;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAnalytics() async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final email = session.user?['email'];

    setState(() {
      _secureLoading = true;
      _groupLoading = true;
      _secureError = null;
      _groupError = null;
    });

    if (email == null) {
      setState(() {
        _secureError = 'User email not found.';
        _groupError = 'User email not found.';
        _secureLoading = false;
        _groupLoading = false;
      });
      return;
    }

    await Future.wait([
      _fetchSecureAnalytics(email),
      _fetchGroupAnalytics(email),
    ]);
  }

  Future<void> _fetchSecureAnalytics(String email) async {
    try {
      final res = await ApiClient.get('/api/analytics/user?email=$email');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['analyticsSharing'] == false) {
          setState(() {
            analyticsSharing = false;
            _secureAnalytics = null;
            _secureLoading = false;
          });
        } else {
          setState(() {
            analyticsSharing = true;
            _secureAnalytics = data;
            _secureLoading = false;
          });
        }
      } else {
        setState(() {
          _secureError = 'Failed to fetch secure transaction analytics.';
          _secureLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _secureError = 'Error: $e';
        _secureLoading = false;
      });
    }
  }

  Future<void> _fetchGroupAnalytics(String email) async {
    try {
      final res = await ApiClient.get('/api/analytics/group?email=$email');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['analyticsSharing'] == false) {
          setState(() {
            analyticsSharing = false;
            _groupAnalytics = null;
            _groupLoading = false;
          });
        } else {
          setState(() {
            analyticsSharing = true;
            _groupAnalytics = data;
            _groupLoading = false;
          });
        }
      } else {
        setState(() {
          _groupError = 'Failed to fetch group transaction analytics.';
          _groupLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _groupError = 'Error: $e';
        _groupLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: const Text('Analytics', style: TextStyle(color: Colors.black)),
        ),
      ),
      backgroundColor: const Color(0xFFF8F6FA),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopWaveClipper(),
              child: Container(
                height: 140,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00B4D8), Color(0xFF48CAE4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 44),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.white, Colors.green],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFF00B4D8),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF00B4D8),
                dividerColor: Colors.transparent,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: const [
                  Tab(text: 'Secure'),
                  Tab(text: 'Groups'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAnalyticsTab(
                analytics: _secureAnalytics,
                loading: _secureLoading,
                error: _secureError,
                labels: const _AnalyticsLabels(
                  summaryA: 'Total Lent',
                  summaryB: 'Total Borrowed',
                  summaryC: 'Interest',
                  countA: 'Cleared',
                  countB: 'Uncleared',
                  countC: 'Total',
                  compareTitle: 'Lent vs Borrowed',
                  progressTitle: 'Cleared Transactions',
                  monthlyTitle: 'Monthly Secure Activity',
                ),
              ),
              _buildAnalyticsTab(
                analytics: _groupAnalytics,
                loading: _groupLoading,
                error: _groupError,
                labels: const _AnalyticsLabels(
                  summaryA: 'Contributed',
                  summaryB: 'Your Share',
                  summaryC: 'Outstanding',
                  countA: 'Settled',
                  countB: 'Unsettled',
                  countC: 'Expenses',
                  compareTitle: 'Contribution vs Share',
                  progressTitle: 'Settled Group Splits',
                  monthlyTitle: 'Monthly Group Activity',
                ),
                headerBuilder: (analytics) => _buildGroupOverviewCard(
                  analytics['totalGroups'] ?? 0,
                ),
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildAnalyticsTab({
    required Map<String, dynamic>? analytics,
    required bool loading,
    required String? error,
    required _AnalyticsLabels labels,
    Widget Function(Map<String, dynamic> analytics)? headerBuilder,
  }) {
    if (loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
            ),
            SizedBox(height: 20),
            Text('Loading Analytics...',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
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
              Text('An Error Occurred',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red)),
              SizedBox(height: 10),
              Text(error,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
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
            Text('No analytics data available.',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    final totalLent = (analytics['totalLent'] as num?)?.toDouble() ?? 0.0;
    final totalBorrowed =
        (analytics['totalBorrowed'] as num?)?.toDouble() ?? 0.0;
    final totalInterest =
        (analytics['totalInterest'] as num?)?.toDouble() ?? 0.0;
    final cleared = analytics['cleared'] ?? 0;
    final uncleared = analytics['uncleared'] ?? 0;
    final total = analytics['total'] ?? 0;
    final clearedPercent = total == 0 ? 0.0 : cleared / total;
    final monthlyCounts = List<double>.from(
      (analytics['monthlyCounts'] ?? []).map((e) => (e as num).toDouble()),
    );
    final monthLabels = List<String>.from(analytics['months'] ?? []);

    return RefreshIndicator(
      onRefresh: _fetchAnalytics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (headerBuilder != null) ...[
              headerBuilder(analytics),
              SizedBox(height: 16),
            ],
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
                        _summaryTile(
                            labels.summaryA, totalLent, Colors.green, Icons.arrow_upward),
                        _summaryTile(labels.summaryB, totalBorrowed, Colors.orange,
                            Icons.arrow_downward),
                        _summaryTile(
                            labels.summaryC, totalInterest, Colors.blue, Icons.percent),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _countTile(labels.countA, cleared, Colors.green,
                            Icons.check_circle),
                        _countTile(
                            labels.countB, uncleared, Colors.red, Icons.cancel),
                        _countTile(labels.countC, total, Colors.teal,
                            Icons.functions),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text(labels.progressTitle,
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
                    Text('${(clearedPercent * 100).toStringAsFixed(1)}% cleared',
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
                    _buildSectionHeader(labels.compareTitle, Icons.pie_chart),
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
                                title: totalLent.toStringAsFixed(2),
                                radius: 60,
                                titleStyle: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              PieChartSectionData(
                                color: Colors.orange,
                                value: totalBorrowed,
                                title: totalBorrowed.toStringAsFixed(2),
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
            _buildMonthlyChartCard(monthlyCounts, monthLabels, labels.monthlyTitle),
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
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyChartCard(
      List<double> monthlyCounts, List<String> monthLabels, String title) {
    return _buildTricolorCard(
      color: _getNoteColor(3),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(title, Icons.show_chart),
            SizedBox(height: 16),
            if (monthlyCounts.every((value) => value == 0))
              Center(
                  child:
                      Text('No data to show', style: TextStyle(color: Colors.grey))),
            if (monthlyCounts.any((value) => value > 0))
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: monthlyCounts.reduce((a, b) => a > b ? a : b) + 1,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= monthLabels.length) {
                              return const SizedBox.shrink();
                            }
                            final label = monthLabels[index];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                label.length >= 7 ? label.substring(5) : label,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: monthlyCounts.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value,
                            width: 14,
                            borderRadius: BorderRadius.circular(8),
                            gradient: const LinearGradient(
                              colors: [
                                Colors.orange,
                                Color(0xFF00B4D8),
                                Colors.green,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupOverviewCard(int totalGroups) {
    return _buildTricolorCard(
      color: _getNoteColor(4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.groups_2_outlined, color: Color(0xFF00B4D8)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text('Group Analytics Overview',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$totalGroups groups',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
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
                    builder: (_) => FutureBuilder<Map<String, dynamic>?>(
                      future: _fetchCounterpartyProfile(counterparty['email']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        final profile = snapshot.data;
                        if (profile == null) {
                          return _StylishProfileDialog(
                            title: 'Counterparty Info',
                            name: 'No profile found.',
                            avatarProvider: AssetImage('assets/Other.png'),
                            email: counterparty['email'],
                          );
                        }
                        final gender = profile['gender'] ?? 'Other';
                        dynamic imageUrl = profile['profileImage'];
                        if (imageUrl is Map && imageUrl['url'] != null)
                          imageUrl = imageUrl['url'];
                        if (imageUrl != null && imageUrl is! String)
                          imageUrl = null;
                        ImageProvider avatarProvider;
                        if (imageUrl != null &&
                            imageUrl.toString().isNotEmpty &&
                            imageUrl != 'null') {
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
                  child:
                      Icon(Icons.person_outline, color: Colors.teal, size: 16),
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
                        fontWeight: FontWeight.bold, color: Colors.white)),
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
      final res = await ApiClient.get(
          '/api/users/profile-by-email?email=$email'); // changed
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
                      child: CircleAvatar(
                          radius: 36, backgroundImage: avatarProvider),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (email != null) ...[
                      _buildInfoCard(Icons.email, email!, Colors.blue.shade100),
                      SizedBox(height: 10),
                    ],
                    if (phone != null && phone!.isNotEmpty) ...[
                      _buildInfoCard(
                          Icons.phone, phone!, Colors.green.shade100),
                      SizedBox(height: 10),
                    ],
                    if (gender != null) ...[
                      _buildInfoCard(
                          Icons.transgender, gender!, Colors.purple.shade100),
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

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    path.lineTo(0, size.height * 0.4);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.5,
      size.width * 0.5,
      size.height * 0.4,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.3,
      size.width,
      size.height * 0.4,
    );
    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _AnalyticsLabels {
  final String summaryA;
  final String summaryB;
  final String summaryC;
  final String countA;
  final String countB;
  final String countC;
  final String compareTitle;
  final String progressTitle;
  final String monthlyTitle;

  const _AnalyticsLabels({
    required this.summaryA,
    required this.summaryB,
    required this.summaryC,
    required this.countA,
    required this.countB,
    required this.countC,
    required this.compareTitle,
    required this.progressTitle,
    required this.monthlyTitle,
  });
}
