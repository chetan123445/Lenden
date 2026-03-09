import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/api_client.dart';
import '../user/session.dart';

class UserOffersPage extends StatefulWidget {
  const UserOffersPage({super.key});

  @override
  State<UserOffersPage> createState() => _UserOffersPageState();
}

class _UserOffersPageState extends State<UserOffersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _offers = [];
  List<dynamic> _claimHistory = [];
  bool _loadingOffers = true;
  bool _loadingHistory = true;
  final Set<String> _accepting = {};
  String _sortBy = 'endsAt';
  String _order = 'asc';
  String _claimStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchOffers();
    _fetchHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showStylishMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Colors.orange, Colors.white, Colors.green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: isError ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle,
                  color: isError ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _countdownLabel(int remainingMs) {
    if (remainingMs <= 0) return 'Ended';
    final mins = (remainingMs / (1000 * 60)).floor();
    final days = mins ~/ (60 * 24);
    final hours = (mins % (60 * 24)) ~/ 60;
    final minutes = mins % 60;
    if (days > 0) return '$days d $hours h left';
    if (hours > 0) return '$hours h $minutes m left';
    return '$minutes m left';
  }

  Color _urgencyColor(int remainingMs) {
    if (remainingMs <= 0) return Colors.grey;
    final hours = remainingMs / (1000 * 60 * 60);
    if (hours <= 6) return Colors.red;
    if (hours <= 24) return Colors.orange;
    return Colors.green;
  }

  Future<void> _fetchOffers() async {
    setState(() => _loadingOffers = true);
    final path =
        '/api/offers/available?sortBy=$_sortBy&order=$_order&claimStatus=$_claimStatus';
    final res = await ApiClient.get(path);
    if (!mounted) return;
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        _offers = List<dynamic>.from(data['items'] ?? []);
        _loadingOffers = false;
      });
      return;
    }
    setState(() => _loadingOffers = false);
    _showStylishMessage('Failed to fetch offers', isError: true);
  }

  Future<void> _fetchHistory() async {
    setState(() => _loadingHistory = true);
    final res = await ApiClient.get('/api/offers/my-claims?includeRevoked=true');
    if (!mounted) return;
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        _claimHistory = List<dynamic>.from(data['items'] ?? []);
        _loadingHistory = false;
      });
      return;
    }
    setState(() => _loadingHistory = false);
    _showStylishMessage('Failed to fetch claim history', isError: true);
  }

  Future<void> _acceptOffer(Map<String, dynamic> offer) async {
    final offerId = offer['_id'].toString();
    final offerVersion = (offer['version'] ?? 1).toString();
    setState(() => _accepting.add(offerId));
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final res = await ApiClient.post(
        '/api/offers/$offerId/accept',
        body: {'idempotencyKey': 'offer-$offerId-v$offerVersion-$now'},
      );
      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final session = Provider.of<SessionProvider>(context, listen: false);
        if (body['totalCoins'] != null) {
          session.updateUserCoins(body['totalCoins']);
        } else {
          await session.loadFreebieCounts();
        }
        final msg = body['alreadyAccepted'] == true
            ? 'Already accepted for this version.'
            : 'Offer accepted: +${body['coinsAwarded']} LenDen coins';
        _showStylishMessage(msg);
        await _fetchOffers();
        await _fetchHistory();
      } else {
        String msg = 'Failed to accept offer';
        try {
          msg = (jsonDecode(res.body)['error'] ?? msg).toString();
        } catch (_) {}
        _showStylishMessage(msg, isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      _showStylishMessage(
        'Network/server issue while accepting offer. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _accepting.remove(offerId));
      }
    }
  }

  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.white, Colors.green],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DropdownButton<String>(
              value: _claimStatus,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'unclaimed', child: Text('Unclaimed')),
                DropdownMenuItem(value: 'claimed', child: Text('Claimed')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _claimStatus = v);
                _fetchOffers();
              },
            ),
            DropdownButton<String>(
              value: _sortBy,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'endsAt', child: Text('Deadline')),
                DropdownMenuItem(value: 'coins', child: Text('Coins')),
                DropdownMenuItem(value: 'createdAt', child: Text('Newest')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _sortBy = v);
                _fetchOffers();
              },
            ),
            DropdownButton<String>(
              value: _order,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'asc', child: Text('Asc')),
                DropdownMenuItem(value: 'desc', child: Text('Desc')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _order = v);
                _fetchOffers();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTab() {
    if (_loadingOffers) return const Center(child: CircularProgressIndicator());
    if (_offers.isEmpty) {
      return const Center(
        child: Text(
          'No offers found for selected filters.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchOffers,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _offers.length,
        itemBuilder: (context, index) {
          final offer = _offers[index] as Map<String, dynamic>;
          final offerId = offer['_id'].toString();
          final claimed = offer['claimed'] == true;
          final remainingMs = (offer['timeRemainingMs'] ?? 0) as int;
          final endsAt = DateTime.tryParse('${offer['endsAt']}');
          final urgency = _urgencyColor(remainingMs);
          final bgColor =
              index.isEven ? const Color(0xFFFFF4E6) : const Color(0xFFE8F5E9);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.white, Colors.green],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: bgColor,
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          offer['name']?.toString() ?? 'Offer',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      Chip(
                        backgroundColor: urgency.withValues(alpha: 0.15),
                        label: Text(
                          _countdownLabel(remainingMs),
                          style: TextStyle(color: urgency, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  if ((offer['description'] ?? '').toString().trim().isNotEmpty)
                    Text(offer['description'].toString()),
                  const SizedBox(height: 8),
                  Text(
                    'Reward: +${offer['coins']} LenDen coins',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text('Version: v${offer['version'] ?? 1}'),
                  Text('Deadline: ${endsAt?.toLocal().toString().substring(0, 16) ?? '-'}'),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: claimed
                        ? const Chip(
                            label: Text('Accepted'),
                            backgroundColor: Color(0xFFE8F5E9),
                          )
                        : ElevatedButton(
                            onPressed: _accepting.contains(offerId)
                                ? null
                                : () => _acceptOffer(offer),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00B4D8)),
                            child: _accepting.contains(offerId)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Accept Offer',
                                    style: TextStyle(color: Colors.white)),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_loadingHistory) return const Center(child: CircularProgressIndicator());
    if (_claimHistory.isEmpty) return const Center(child: Text('No claim history yet.'));

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _claimHistory.length,
        itemBuilder: (context, index) {
          final claim = _claimHistory[index] as Map<String, dynamic>;
          final offer = (claim['offer'] ?? {}) as Map<String, dynamic>;
          final revoked = claim['revoked'] == true;
          final claimedAt = DateTime.tryParse('${claim['claimedAt']}');
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.white, Colors.green],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: revoked ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (offer['name'] ?? 'Offer').toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Chip(
                        label: Text(revoked ? 'Revoked' : 'Claimed'),
                        backgroundColor: revoked
                            ? Colors.red.withValues(alpha: 0.15)
                            : Colors.green.withValues(alpha: 0.15),
                      ),
                    ],
                  ),
                  Text('Coins: +${claim['coinsAwarded'] ?? 0}'),
                  Text('Version: v${claim['offerVersion'] ?? '-'}'),
                  Text('Claimed: ${claimedAt?.toLocal().toString().substring(0, 16) ?? '-'}'),
                  if (revoked) Text('Reason: ${claim['revokedReason'] ?? 'Offer updated'}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6),
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
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Offers',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF00B4D8),
                    unselectedLabelColor: Colors.black54,
                    indicatorColor: const Color(0xFF00B4D8),
                    tabs: const [
                      Tab(text: 'Active Offers'),
                      Tab(text: 'Claim History'),
                    ],
                  ),
                ),
                if (_tabController.index == 0) _buildFilterBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveTab(),
                      _buildHistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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

