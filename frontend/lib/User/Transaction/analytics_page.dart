import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Settings/privacy_settings_page.dart';
import '../../session.dart';
import '../../utils/api_client.dart';

class AnalyticsPage extends StatefulWidget {
  final List<dynamic>? transactions;

  const AnalyticsPage({Key? key, this.transactions}) : super(key: key);

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
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
        _secureLoading = false;
        _groupLoading = false;
        _secureError = 'User email not found.';
        _groupError = 'User email not found.';
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
      final res = await ApiClient.get('/api/analytics/secure?email=$email');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['analyticsSharing'] == false) {
          setState(() {
            analyticsSharing = false;
            _secureAnalytics = null;
            _secureLoading = false;
          });
          return;
        }

        setState(() {
          analyticsSharing = true;
          _secureAnalytics = data;
          _secureLoading = false;
        });
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
      final res = await ApiClient.get('/api/analytics/groups?email=$email');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['analyticsSharing'] == false) {
          setState(() {
            analyticsSharing = false;
            _groupAnalytics = null;
            _groupLoading = false;
          });
          return;
        }

        setState(() {
          analyticsSharing = true;
          _groupAnalytics = data;
          _groupLoading = false;
        });
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
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          title: const Text(
            'Analytics',
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF7F8FC),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopWaveClipper(),
              child: Container(
                height: 150,
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
              padding: const EdgeInsets.only(top: 40),
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 64,
                color: Color(0xFF00B4D8),
              ),
              const SizedBox(height: 24),
              const Text(
                'Analytics is disabled in your privacy settings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enable analytics sharing to view your secure and group transaction insights.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrivacySettingsPage(),
                    ),
                  ).then((_) => _fetchAnalytics());
                },
                icon: const Icon(Icons.settings, color: Colors.white),
                label: const Text(
                  'Open Privacy Settings',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
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
              borderRadius: BorderRadius.circular(24),
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
                borderRadius: BorderRadius.circular(22),
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
                  borderRadius: BorderRadius.circular(18),
                  color: const Color(0xFF00B4D8),
                ),
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF00B4D8),
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: const [
                  Tab(text: 'Secure'),
                  Tab(text: 'Groups'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTabContent(
                analytics: _secureAnalytics,
                loading: _secureLoading,
                error: _secureError,
                config: const _AnalyticsTabConfig(
                  tabTitle: 'Secure Analytics',
                  tabSubtitle: 'See the most important lending and borrowing signals.',
                  metrics: [
                    _MetricDefinition(
                      id: 'totalLent',
                      title: 'Total Lent',
                      subtitle: 'Amount shared by you',
                      icon: Icons.arrow_upward_rounded,
                      colors: [Color(0xFF7C9DFF), Color(0xFFA9B8FF)],
                      isCurrency: true,
                    ),
                    _MetricDefinition(
                      id: 'totalBorrowed',
                      title: 'Total Borrowed',
                      subtitle: 'Amount taken by you',
                      icon: Icons.arrow_downward_rounded,
                      colors: [Color(0xFFFF8B7B), Color(0xFFFFC2AE)],
                      isCurrency: true,
                    ),
                    _MetricDefinition(
                      id: 'totalInterest',
                      title: 'Interest',
                      subtitle: 'Interest tracked so far',
                      icon: Icons.percent_rounded,
                      colors: [Color(0xFF58C4DD), Color(0xFF89E0EF)],
                      isCurrency: true,
                    ),
                    _MetricDefinition(
                      id: 'cleared',
                      title: 'Cleared',
                      subtitle: 'Fully cleared transactions',
                      icon: Icons.check_circle_outline_rounded,
                      colors: [Color(0xFF6BCB91), Color(0xFFA9E4A7)],
                    ),
                    _MetricDefinition(
                      id: 'uncleared',
                      title: 'Uncleared',
                      subtitle: 'Pending transactions',
                      icon: Icons.pending_actions_rounded,
                      colors: [Color(0xFFFFB562), Color(0xFFFFD9A0)],
                    ),
                    _MetricDefinition(
                      id: 'total',
                      title: 'Total Transactions',
                      subtitle: 'All secure records',
                      icon: Icons.receipt_long_rounded,
                      colors: [Color(0xFF57A4FF), Color(0xFF90C6FF)],
                    ),
                    _MetricDefinition(
                      id: 'monthly',
                      title: 'Monthly Activity',
                      subtitle: '12-month transaction trend',
                      icon: Icons.show_chart_rounded,
                      colors: [Color(0xFF6B7CFF), Color(0xFFB3BCFF)],
                      isTrend: true,
                    ),
                  ],
                ),
              ),
              _buildTabContent(
                analytics: _groupAnalytics,
                loading: _groupLoading,
                error: _groupError,
                config: const _AnalyticsTabConfig(
                  tabTitle: 'Group Analytics',
                  tabSubtitle: 'Track contributions, dues, expenses, and group movement.',
                  metrics: [
                    _MetricDefinition(
                      id: 'totalLent',
                      title: 'Contributed',
                      subtitle: 'What you paid into groups',
                      icon: Icons.volunteer_activism_outlined,
                      colors: [Color(0xFF7C9DFF), Color(0xFFA9B8FF)],
                      isCurrency: true,
                    ),
                    _MetricDefinition(
                      id: 'totalBorrowed',
                      title: 'Your Share',
                      subtitle: 'What belongs to you',
                      icon: Icons.pie_chart_outline_rounded,
                      colors: [Color(0xFFFF8B7B), Color(0xFFFFC2AE)],
                      isCurrency: true,
                    ),
                    _MetricDefinition(
                      id: 'totalInterest',
                      title: 'Outstanding',
                      subtitle: 'Amount still unsettled',
                      icon: Icons.account_balance_wallet_outlined,
                      colors: [Color(0xFF58C4DD), Color(0xFF89E0EF)],
                      isCurrency: true,
                    ),
                    _MetricDefinition(
                      id: 'cleared',
                      title: 'Settled',
                      subtitle: 'Splits already settled',
                      icon: Icons.task_alt_rounded,
                      colors: [Color(0xFF6BCB91), Color(0xFFA9E4A7)],
                    ),
                    _MetricDefinition(
                      id: 'uncleared',
                      title: 'Unsettled',
                      subtitle: 'Splits still pending',
                      icon: Icons.hourglass_bottom_rounded,
                      colors: [Color(0xFFFFB562), Color(0xFFFFD9A0)],
                    ),
                    _MetricDefinition(
                      id: 'total',
                      title: 'Expenses',
                      subtitle: 'Tracked group expenses',
                      icon: Icons.receipt_rounded,
                      colors: [Color(0xFF57A4FF), Color(0xFF90C6FF)],
                    ),
                    _MetricDefinition(
                      id: 'totalGroups',
                      title: 'Groups',
                      subtitle: 'Groups included in analytics',
                      icon: Icons.groups_2_outlined,
                      colors: [Color(0xFF7E74F1), Color(0xFFC0BCFF)],
                    ),
                    _MetricDefinition(
                      id: 'monthly',
                      title: 'Monthly Activity',
                      subtitle: '12-month group trend',
                      icon: Icons.show_chart_rounded,
                      colors: [Color(0xFF6B7CFF), Color(0xFFB3BCFF)],
                      isTrend: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent({
    required Map<String, dynamic>? analytics,
    required bool loading,
    required String? error,
    required _AnalyticsTabConfig config,
  }) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
      );
    }

    if (error != null) {
      return _buildEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Unable to load analytics',
        message: error,
      );
    }

    if (analytics == null) {
      return _buildEmptyState(
        icon: Icons.analytics_outlined,
        title: 'No analytics available',
        message: 'We could not find enough data for this tab yet.',
      );
    }

    final metrics = _buildMetrics(config.metrics, analytics);
    final heroMetrics = metrics.take(2).toList();

    return RefreshIndicator(
      onRefresh: _fetchAnalytics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(config, analytics),
            const SizedBox(height: 18),
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: heroMetrics.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) => _buildHeroMetricCard(
                  metric: heroMetrics[index],
                  analytics: analytics,
                  allMetrics: metrics,
                  tabTitle: config.tabTitle,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Analytics Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Open any option to view charts and related details.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: metrics.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) => _buildOptionCard(
                metric: metrics[index],
                analytics: analytics,
                allMetrics: metrics,
                tabTitle: config.tabTitle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    _AnalyticsTabConfig config,
    Map<String, dynamic> analytics,
  ) {
    final total = ((analytics['total'] as num?) ?? 0).toInt();
    final monthlyCounts = (analytics['monthlyCounts'] as List<dynamic>? ?? const [])
        .map((value) => (value as num).toDouble())
        .toList();
    final peakMonth = monthlyCounts.isEmpty
        ? 0.0
        : monthlyCounts.reduce((a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.tabTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  config.tabSubtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F2FF), Color(0xFFF7FBFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B58B8),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Records',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Peak ${peakMonth.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00B4D8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetricCard({
    required _AnalyticsMetric metric,
    required Map<String, dynamic> analytics,
    required List<_AnalyticsMetric> allMetrics,
    required String tabTitle,
  }) {
    return GestureDetector(
      onTap: () => _openMetricPage(metric, analytics, allMetrics, tabTitle),
      child: Container(
        width: 164,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: metric.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: metric.colors.first.withOpacity(0.30),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(metric.icon, color: Colors.white, size: 26),
            const Spacer(),
            Text(
              metric.displayValue,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              metric.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required _AnalyticsMetric metric,
    required Map<String, dynamic> analytics,
    required List<_AnalyticsMetric> allMetrics,
    required String tabTitle,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openMetricPage(metric, analytics, allMetrics, tabTitle),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: metric.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(metric.icon, color: Colors.white),
              ),
              const Spacer(),
              Text(
                metric.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                metric.displayValue,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: metric.colors.first,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                metric.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_AnalyticsMetric> _buildMetrics(
    List<_MetricDefinition> definitions,
    Map<String, dynamic> analytics,
  ) {
    final monthlyCounts = (analytics['monthlyCounts'] as List<dynamic>? ?? const [])
        .map((value) => (value as num).toDouble())
        .toList();

    return definitions.map((definition) {
      final rawValue = definition.id == 'monthly'
          ? monthlyCounts.fold<double>(0.0, (sum, value) => sum + value)
          : ((analytics[definition.id] as num?) ?? 0).toDouble();

      return _AnalyticsMetric(
        id: definition.id,
        title: definition.title,
        subtitle: definition.subtitle,
        icon: definition.icon,
        colors: definition.colors,
        value: rawValue,
        displayValue: definition.isTrend
            ? '${rawValue.toStringAsFixed(0)} events'
            : definition.isCurrency
                ? _formatAmount(rawValue)
                : rawValue.toStringAsFixed(0),
        isCurrency: definition.isCurrency,
        isTrend: definition.isTrend,
      );
    }).toList();
  }

  void _openMetricPage(
    _AnalyticsMetric metric,
    Map<String, dynamic> analytics,
    List<_AnalyticsMetric> allMetrics,
    String tabTitle,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AnalyticsDetailPage(
          tabTitle: tabTitle,
          metric: metric,
          analytics: analytics,
          allMetrics: allMetrics,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF00B4D8), size: 60),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double value) {
    return 'Rs ${value.toStringAsFixed(2)}';
  }
}

class _AnalyticsDetailPage extends StatelessWidget {
  final String tabTitle;
  final _AnalyticsMetric metric;
  final Map<String, dynamic> analytics;
  final List<_AnalyticsMetric> allMetrics;

  const _AnalyticsDetailPage({
    required this.tabTitle,
    required this.metric,
    required this.analytics,
    required this.allMetrics,
  });

  @override
  Widget build(BuildContext context) {
    final months = List<String>.from(analytics['months'] ?? const []);
    final monthlyCounts = (analytics['monthlyCounts'] as List<dynamic>? ?? const [])
        .map((value) => (value as num).toDouble())
        .toList();
    final total = ((analytics['total'] as num?) ?? 0).toDouble();
    final cleared = ((analytics['cleared'] as num?) ?? 0).toDouble();
    final pending = ((analytics['uncleared'] as num?) ?? 0).toDouble();
    final ratio = total == 0 ? 0.0 : (cleared / total).clamp(0.0, 1.0);

    final secondaryMetrics = allMetrics
        .where((item) => item.id != metric.id)
        .take(2)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          metric.title,
          style: const TextStyle(color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  colors: metric.colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: metric.colors.first.withOpacity(0.30),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tabTitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    metric.displayValue,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metric.subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Quick Facts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniInfoCard(
                    title: 'Records',
                    value: total.toStringAsFixed(0),
                    color: const Color(0xFF1B58B8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniInfoCard(
                    title: 'Completion',
                    value: '${(ratio * 100).toStringAsFixed(0)}%',
                    color: const Color(0xFF00B4D8),
                  ),
                ),
              ],
            ),
            if (secondaryMetrics.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: secondaryMetrics
                    .map(
                      (item) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: item == secondaryMetrics.first &&
                                    secondaryMetrics.length > 1
                                ? 12
                                : 0,
                          ),
                          child: _MiniInfoCard(
                            title: item.title,
                            value: item.displayValue,
                            color: item.colors.first,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 22),
            _ChartShell(
              title: "Today's Stats",
              trailing: metric.isTrend
                  ? const Text(
                      '12 months',
                      style: TextStyle(
                        color: Color(0xFF00B4D8),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LegendDot(color: const Color(0xFF7C9DFF), label: 'Cleared'),
                        const SizedBox(width: 12),
                        _LegendDot(color: const Color(0xFFFF8B7B), label: 'Pending'),
                      ],
                    ),
              child: SizedBox(
                height: 220,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: 5,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= months.length) {
                              return const SizedBox.shrink();
                            }

                            final label = months[index];
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                label.length >= 7 ? label.substring(5) : label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      _buildPrimaryLine(monthlyCounts),
                      if (!metric.isTrend)
                        _buildSecondaryLine(cleared, pending, months.length),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _ChartShell(
              title: 'Needed Info',
              child: Column(
                children: [
                  _InfoRow(
                    label: metric.title,
                    value: metric.displayValue,
                  ),
                  _InfoRow(
                    label: 'Total Records',
                    value: total.toStringAsFixed(0),
                  ),
                  _InfoRow(
                    label: 'Cleared',
                    value: cleared.toStringAsFixed(0),
                  ),
                  _InfoRow(
                    label: 'Pending',
                    value: pending.toStringAsFixed(0),
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _buildPrimaryLine(List<double> monthlyCounts) {
    final points = monthlyCounts.isEmpty
        ? [const FlSpot(0, 0)]
        : monthlyCounts
            .asMap()
            .entries
            .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
            .toList();

    return LineChartBarData(
      spots: points,
      isCurved: true,
      color: const Color(0xFF7C9DFF),
      barWidth: 3,
      isStrokeCapRound: true,
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C9DFF).withOpacity(0.25),
            const Color(0xFF7C9DFF).withOpacity(0.03),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 4,
          color: Colors.white,
          strokeWidth: 2.5,
          strokeColor: const Color(0xFF7C9DFF),
        ),
      ),
    );
  }

  LineChartBarData _buildSecondaryLine(
    double cleared,
    double pending,
    int length,
  ) {
    final count = length <= 0 ? 1 : length;
    final step = count == 1 ? 0.0 : 1.0 / (count - 1);

    final points = List.generate(count, (index) {
      final progress = step * index;
      final value = (cleared * (1 - progress)) + (pending * progress);
      return FlSpot(index.toDouble(), value);
    });

    return LineChartBarData(
      spots: points,
      isCurved: true,
      color: const Color(0xFFFF8B7B),
      barWidth: 2,
      dashArray: const [6, 4],
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF8B7B).withOpacity(0.16),
            const Color(0xFFFF8B7B).withOpacity(0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}

class _MiniInfoCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MiniInfoCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartShell extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _ChartShell({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsTabConfig {
  final String tabTitle;
  final String tabSubtitle;
  final List<_MetricDefinition> metrics;

  const _AnalyticsTabConfig({
    required this.tabTitle,
    required this.tabSubtitle,
    required this.metrics,
  });
}

class _MetricDefinition {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final bool isCurrency;
  final bool isTrend;

  const _MetricDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    this.isCurrency = false,
    this.isTrend = false,
  });
}

class _AnalyticsMetric {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final double value;
  final String displayValue;
  final bool isCurrency;
  final bool isTrend;

  const _AnalyticsMetric({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.value,
    required this.displayValue,
    required this.isCurrency,
    required this.isTrend,
  });
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
