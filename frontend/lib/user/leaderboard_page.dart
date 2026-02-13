import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api_config.dart';
import '../utils/api_client.dart';
import 'session.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final Map<String, List<dynamic>> _rowsByType = {
    'quick': [],
    'group': [],
    'trxns': [],
  };

  bool _loading = true;
  bool _friendsOnly = false;
  String _activeType = 'quick';
  String _range = 'daily';
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final type = _typeFromIndex(_tabController.index);
      if (_activeType != type) {
        setState(() => _activeType = type);
        _loadLeaderboard();
      }
    });
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _typeFromIndex(int index) {
    if (index == 0) return 'quick';
    if (index == 1) return 'group';
    return 'trxns';
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _loading = true);
    final path =
        '/api/leaderboard?type=$_activeType&range=$_range&friendsOnly=$_friendsOnly';
    try {
      final res = await ApiClient.get(path);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final users = List<dynamic>.from(data['users'] ?? []);
        setState(() {
          _rowsByType[_activeType] = users;
          _fetchError = null;
          _loading = false;
        });
        if (users.isEmpty && mounted) {
          _showStylishMessage(
            title: 'No Rankings Yet',
            message:
                'No users are ranked for this filter right now. Rankings update as activity happens.',
            icon: Icons.info_outline,
            color: const Color(0xFF00B4D8),
          );
        }
      } else {
        final msg = 'Failed to load leaderboard (${res.statusCode}).';
        setState(() {
          _fetchError = msg;
          _loading = false;
        });
        if (mounted) {
          _showStylishMessage(
            title: 'Load Failed',
            message: msg,
            icon: Icons.error_outline,
            color: Colors.redAccent,
          );
        }
      }
    } catch (_) {
      const msg = 'Unable to load leaderboard right now. Please try again.';
      setState(() {
        _fetchError = msg;
        _loading = false;
      });
      if (mounted) {
        _showStylishMessage(
          title: 'Network Error',
          message: msg,
          icon: Icons.wifi_off_rounded,
          color: Colors.redAccent,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rowsByType[_activeType] ?? [];
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        title: const Text(
          'Leaderboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00B4D8),
          labelColor: const Color(0xFF00B4D8),
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: 'Quick'),
            Tab(text: 'Group'),
            Tab(text: 'Trxns'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 150,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00B4D8), Color(0xFF4CC9F0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      await _loadLeaderboard();
                      if (mounted && _fetchError == null) {
                        _showStylishMessage(
                          title: 'Refreshed',
                          message: 'Leaderboard updated for selected filters.',
                          icon: Icons.refresh,
                          color: const Color(0xFF00B4D8),
                        );
                      }
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        _buildFilters(),
                        _buildMetaBanner(),
                        _buildLegendBanner(),
                        _buildPodium(rows),
                        const SizedBox(height: 10),
                        _buildHintButtons(context),
                        const SizedBox(height: 12),
                        _buildTopList(rows),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return _triBorderCard(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'daily', label: Text('Daily')),
                ButtonSegment(value: 'weekly', label: Text('Weekly')),
                ButtonSegment(value: 'monthly', label: Text('Monthly')),
              ],
              selected: {_range},
              onSelectionChanged: (value) {
                final next = value.first;
                if (next == _range) return;
                setState(() => _range = next);
                _loadLeaderboard();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people_alt_outlined,
                    size: 18, color: Color(0xFF005F73)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Friends only',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: _friendsOnly,
                  activeColor: const Color(0xFF00B4D8),
                  onChanged: (v) {
                    setState(() => _friendsOnly = v);
                    _loadLeaderboard();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaBanner() {
    return _triBorderCard(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.insights_rounded,
                size: 16, color: Color(0xFF00B4D8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _fetchError ??
                    'Movement shows change vs previous ${_range == 'daily' ? 'day' : _range == 'weekly' ? 'week' : 'month'}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: _fetchError == null ? Colors.black87 : Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendBanner() {
    return _triBorderCard(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.tune_rounded, size: 16, color: Color(0xFF00B4D8)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Legend: Q = Quick, G = Group, T = Trxns',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium(List<dynamic> rows) {
    final first = rows.isNotEmpty ? rows[0] : null;
    final second = rows.length > 1 ? rows[1] : null;
    final third = rows.length > 2 ? rows[2] : null;
    return _triBorderCard(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFDFD),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _podiumPerson(second, 2, 30),
            _podiumPerson(first, 1, 40),
            _podiumPerson(third, 3, 30),
          ],
        ),
      ),
    );
  }

  Widget _podiumPerson(dynamic row, int fallbackRank, double radius) {
    final name = row?['name']?.toString() ?? '-';
    final points = row?['points']?.toString() ?? '0';
    final displayedRank = row?['rank'] is int ? row['rank'] as int : fallbackRank;
    return SizedBox(
      width: 95,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_rankLabel(displayedRank),
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 4),
          _avatar(row, radius),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text('$points pts',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4F5D75),
                  fontSize: 12)),
          const SizedBox(height: 2),
          _movementWidget(row),
        ],
      ),
    );
  }

  Widget _buildHintButtons(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            _showStylishMessage(
              title: 'How Points Work',
              message:
                  'Each transaction gives 10 points. Equal points share the same rank.',
              icon: Icons.stars_rounded,
              color: const Color(0xFF00B4D8),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CC9F0),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('How to earn points',
              style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () {
            final myId = Provider.of<SessionProvider>(context, listen: false)
                .user?['_id']
                ?.toString();
            dynamic myRow;
            if (myId != null && myId.isNotEmpty) {
              for (final row in (_rowsByType[_activeType] ?? [])) {
                if (row['userId']?.toString() == myId) {
                  myRow = row;
                  break;
                }
              }
            }
            final text = myRow == null
                ? 'You are not in rank 10 or above for this filter.'
                : 'Rank ${myRow['rank']}: ${myRow['points']} pts';
            _showStylishMessage(
              title: 'Your Points',
              message: text,
              icon: Icons.emoji_events_outlined,
              color: const Color(0xFF00B4D8),
            );
          },
          child: const Text('View my points'),
        ),
      ],
    );
  }

  Widget _buildTopList(List<dynamic> rows) {
    final others = rows.length > 3 ? rows.sublist(3) : <dynamic>[];
    if (others.isEmpty) {
      return _triBorderCard(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Center(
            child: Text(
              'No more users in this ranking window.',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    final myId =
        Provider.of<SessionProvider>(context, listen: false).user?['_id']?.toString();

    return _triBorderCard(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: others.map((row) {
            final isMe = myId != null && row['userId']?.toString() == myId;
            final breakdown = row['breakdown'] ?? {};
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFE6F7FF) : const Color(0xFFF1F5F9),
                border: isMe
                    ? Border.all(color: const Color(0xFF00B4D8), width: 1.2)
                    : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('${row['rank']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.black54)),
                      const SizedBox(width: 10),
                      _avatar(row, 14),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          row['name']?.toString() ?? 'Unknown User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      _movementWidget(row),
                      const SizedBox(width: 8),
                      Text('${row['points']} pts',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F5D75))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _chip('Q ${breakdown['quick'] ?? 0}'),
                      const SizedBox(width: 6),
                      _chip('G ${breakdown['group'] ?? 0}'),
                      const SizedBox(width: 6),
                      _chip('T ${breakdown['trxns'] ?? 0}'),
                      const SizedBox(width: 6),
                      _chip('All ${(breakdown['totalPoints'] ?? 0)} pts'),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7DEE8)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4F5D75),
        ),
      ),
    );
  }

  Widget _movementWidget(dynamic row) {
    final movement = row?['movement'] ?? {};
    final direction = (movement['direction'] ?? 'same').toString();
    final delta = (movement['delta'] ?? 0) as int;

    IconData icon = Icons.horizontal_rule;
    Color color = Colors.grey;
    String label = '0';
    if (direction == 'up') {
      icon = Icons.arrow_upward_rounded;
      color = Colors.green;
      label = '+$delta';
    } else if (direction == 'down') {
      icon = Icons.arrow_downward_rounded;
      color = Colors.redAccent;
      label = '-$delta';
    } else if (direction == 'new') {
      icon = Icons.fiber_new_rounded;
      color = const Color(0xFF00B4D8);
      label = 'new';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: Row(
        key: ValueKey('$direction-$delta'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _triBorderCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.white, Colors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }

  Widget _avatar(dynamic row, double radius) {
    final gender = (row?['gender'] ?? 'Other').toString();
    final userId = row?['userId']?.toString();
    final fallback = AssetImage(
      gender == 'Male'
          ? 'assets/Male.png'
          : gender == 'Female'
              ? 'assets/Female.png'
              : 'assets/Other.png',
    );

    if (userId == null || userId.isEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: fallback);
    }

    final url = '${ApiConfig.baseUrl}/api/users/$userId/profile-image';
    return Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(radius: radius, backgroundImage: fallback),
        ClipOval(
          child: Image.network(
            url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  String _rankLabel(int rank) {
    final mod100 = rank % 100;
    if (mod100 >= 11 && mod100 <= 13) return '${rank}th';
    switch (rank % 10) {
      case 1:
        return '${rank}st';
      case 2:
        return '${rank}nd';
      case 3:
        return '${rank}rd';
      default:
        return '${rank}th';
    }
  }

  void _showStylishMessage({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.white, Colors.green],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        const Text('OK', style: TextStyle(color: Colors.white)),
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
