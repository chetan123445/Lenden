import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/api_client.dart';
import 'session.dart';

class UserOffersPage extends StatefulWidget {
  const UserOffersPage({super.key});

  @override
  State<UserOffersPage> createState() => _UserOffersPageState();
}

class _UserOffersPageState extends State<UserOffersPage> {
  List<dynamic> _offers = [];
  bool _loading = true;
  final Set<String> _accepting = {};

  @override
  void initState() {
    super.initState();
    _fetchOffers();
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

  Future<void> _fetchOffers() async {
    setState(() => _loading = true);
    final res = await ApiClient.get('/api/offers/available');
    if (!mounted) return;
    if (res.statusCode == 200) {
      setState(() {
        _offers = jsonDecode(res.body) as List<dynamic>;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
    _showStylishMessage('Failed to fetch offers', isError: true);
  }

  Future<void> _acceptOffer(String offerId) async {
    setState(() => _accepting.add(offerId));
    final res = await ApiClient.post('/api/offers/$offerId/accept');
    if (!mounted) return;

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final session = Provider.of<SessionProvider>(context, listen: false);
      if (body['totalCoins'] != null) {
        session.updateUserCoins(body['totalCoins']);
      } else {
        await session.loadFreebieCounts();
      }
      _showStylishMessage('Offer accepted: +${body['coinsAwarded']} LenDen coins');
      await _fetchOffers();
    } else {
      String msg = 'Failed to accept offer';
      try {
        msg = (jsonDecode(res.body)['error'] ?? msg).toString();
      } catch (_) {}
      _showStylishMessage(msg, isError: true);
    }

    if (mounted) {
      setState(() => _accepting.remove(offerId));
    }
  }

  Widget _buildOfferCard(Map<String, dynamic> offer, int index) {
    final offerId = offer['_id'].toString();
    final claimed = offer['claimed'] == true;
    final endsAt = DateTime.tryParse('${offer['endsAt']}');
    final startsAt = DateTime.tryParse('${offer['startsAt']}');
    final bgColor = index.isEven ? const Color(0xFFFFF4E6) : const Color(0xFFE8F5E9);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.white, Colors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
            Text(
              offer['name']?.toString() ?? 'Offer',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 6),
            if ((offer['description'] ?? '').toString().trim().isNotEmpty)
              Text(offer['description'].toString()),
            const SizedBox(height: 8),
            Text(
              'Reward: +${offer['coins']} LenDen coins',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Starts: ${startsAt?.toLocal().toString().substring(0, 16) ?? '-'}',
              style: const TextStyle(color: Colors.black54),
            ),
            Text(
              'Deadline: ${endsAt?.toLocal().toString().substring(0, 16) ?? '-'}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: claimed
                  ? const Chip(
                      label: Text('Accepted'),
                      backgroundColor: Color(0xFFE8F5E9),
                    )
                  : ElevatedButton(
                      onPressed: _accepting.contains(offerId) ? null : () => _acceptOffer(offerId),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B4D8)),
                      child: _accepting.contains(offerId)
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Accept Offer', style: TextStyle(color: Colors.white)),
                    ),
            ),
          ],
        ),
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
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _offers.isEmpty
                          ? const Center(
                              child: Text(
                                'No active offers right now.\nCheck notifications for upcoming offers.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _fetchOffers,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(14),
                                itemCount: _offers.length,
                                itemBuilder: (context, index) {
                                  final offer = _offers[index] as Map<String, dynamic>;
                                  return _buildOfferCard(offer, index);
                                },
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
