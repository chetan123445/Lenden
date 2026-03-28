import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../utils/api_client.dart';
import '../Digitise/subscriptions_page.dart';

class UserAdPopupDialog extends StatefulWidget {
  final Map<String, dynamic> ad;

  const UserAdPopupDialog({super.key, required this.ad});

  @override
  State<UserAdPopupDialog> createState() => _UserAdPopupDialogState();
}

class _UserAdPopupDialogState extends State<UserAdPopupDialog> {
  bool _videoCanClose = false;
  bool _impressionTracked = false;

  @override
  void initState() {
    super.initState();
    unawaited(_trackAdEvent('impression'));
  }

  Future<void> _trackAdEvent(String type, {int watchSeconds = 0}) async {
    final adId = widget.ad['_id']?.toString();
    if (adId == null || adId.isEmpty) return;
    if (type == 'impression' && _impressionTracked) return;
    try {
      await ApiClient.post(
        '/api/ads/$adId/events',
        body: {
          'type': type,
          'watchSeconds': watchSeconds,
          'metadata': {'mediaKind': (widget.ad['mediaKind'] ?? 'none').toString()},
        },
      );
      if (type == 'impression') {
        _impressionTracked = true;
      }
    } catch (_) {}
  }

  int _watchSeconds() =>
      int.tryParse((widget.ad['_watchSeconds'] ?? '0').toString()) ?? 0;

  void _closeAd(BuildContext context, {String eventType = 'close'}) {
    unawaited(_trackAdEvent(eventType, watchSeconds: _watchSeconds()));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final mediaKind = (ad['mediaKind'] ?? 'none').toString();
    final mediaUrl = (ad['mediaUrl'] ?? '').toString();
    final ctaText = (ad['callToActionText'] ?? '').toString();
    final ctaUrl = (ad['callToActionUrl'] ?? '').toString();
    final allowImmediateClose = mediaKind != 'video';
    final videoCloseAtPercent =
        int.tryParse((ad['videoCloseAtPercent'] ?? '100').toString()) ?? 100;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Colors.orange, Colors.white, Colors.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sponsored',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          allowImmediateClose
                              ? 'You can close this ad anytime.'
                              : 'Close unlocks after ${_closeUnlockLabel(videoCloseAtPercent)}.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (allowImmediateClose || _videoCanClose)
                    _buildCloseButton(context)
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        color: Color(0xFF00B4D8),
                      ),
                    ),
                ],
              ),
              if ((ad['title'] ?? '').toString().trim().isNotEmpty)
                Text(
                  ad['title'].toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if ((ad['body'] ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  ad['body'].toString(),
                  style: const TextStyle(height: 1.45),
                ),
              ],
              if (mediaKind != 'none' && mediaUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: mediaKind == 'video'
                      ? _AdVideoPlayer(
                          url: mediaUrl,
                          closeAtPercent: videoCloseAtPercent,
                          onCloseUnlocked: () {
                            if (!mounted || _videoCanClose) return;
                            setState(() => _videoCanClose = true);
                          },
                          onWatchSecondsChanged: (seconds) {
                            widget.ad['_watchSeconds'] = seconds;
                          },
                        )
                      : Image.network(
                          mediaUrl,
                          height: 210,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
              ],
              if (ctaText.trim().isNotEmpty && ctaUrl.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final uri = Uri.tryParse(ctaUrl);
                      if (uri != null) {
                        await _trackAdEvent('click', watchSeconds: _watchSeconds());
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B4D8),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(ctaText),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFBDE7F3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.workspace_premium_outlined,
                          color: Color(0xFF00B4D8),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Subscribe to remove ads',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0077B6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upgrade once to enjoy an ad-free experience across your account.',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => _closeAd(context, eventType: 'hide'),
                            child: const Text('Hide Today'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SubscriptionsPage(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0077B6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: const Text('Subscribe'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: IconButton(
        icon: const Icon(Icons.close, color: Color(0xFF00B4D8)),
        onPressed: () => _closeAd(context),
      ),
    );
  }

  String _closeUnlockLabel(int percent) {
    switch (percent) {
      case 25:
        return '25% of the video has played';
      case 50:
        return '50% of the video has played';
      case 75:
        return '75% of the video has played';
      default:
        return 'the video ends';
    }
  }
}

class _AdVideoPlayer extends StatefulWidget {
  final String url;
  final int closeAtPercent;
  final VoidCallback onCloseUnlocked;
  final ValueChanged<int>? onWatchSecondsChanged;

  const _AdVideoPlayer({
    required this.url,
    required this.closeAtPercent,
    required this.onCloseUnlocked,
    this.onWatchSecondsChanged,
  });

  @override
  State<_AdVideoPlayer> createState() => _AdVideoPlayerState();
}

class _AdVideoPlayerState extends State<_AdVideoPlayer> {
  late final VideoPlayerController _controller;
  Timer? _refreshTimer;
  Timer? _loadingCountdownTimer;
  bool _ready = false;
  bool _closeUnlocked = false;
  bool _loadFailed = false;
  late int _fallbackUnlockSeconds;

  @override
  void initState() {
    super.initState();
    _fallbackUnlockSeconds = _fallbackSecondsFor(widget.closeAtPercent);
    _loadingCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _ready || _closeUnlocked) return;
      if (_fallbackUnlockSeconds > 0) {
        setState(() => _fallbackUnlockSeconds -= 1);
      }
      if (_fallbackUnlockSeconds <= 0) {
        _unlockClose();
      }
    });
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _ready = true;
          _loadFailed = false;
        });
        _controller
          ..setLooping(true)
          ..play();
        _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted || !_controller.value.isInitialized) return;
          _checkCloseUnlock();
          widget.onWatchSecondsChanged?.call(
            _controller.value.position.inSeconds.clamp(0, 86400),
          );
          setState(() {});
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _loadFailed = true);
      });
  }

  int _fallbackSecondsFor(int closeAtPercent) {
    switch (closeAtPercent) {
      case 25:
        return 4;
      case 50:
        return 8;
      case 75:
        return 12;
      default:
        return 16;
    }
  }

  void _unlockClose() {
    if (_closeUnlocked) return;
    _closeUnlocked = true;
    widget.onCloseUnlocked();
  }

  void _checkCloseUnlock() {
    if (_closeUnlocked) return;
    final duration = _controller.value.duration;
    final position = _controller.value.position;
    if (duration.inMilliseconds <= 0) return;
    final unlockAtMs =
        (duration.inMilliseconds * widget.closeAtPercent / 100).round();
    if (position.inMilliseconds >= unlockAtMs) {
      _unlockClose();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _loadingCountdownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Container(
        height: 210,
        color: Colors.black12,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 14),
                  Text(
                    _loadFailed
                        ? 'Video is taking too long to load.'
                        : 'Loading video...',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _closeUnlocked
                        ? 'You can close this ad now.'
                        : 'Close unlocks in ${_fallbackUnlockSeconds.clamp(0, 999)}s.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.62),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _closeUnlocked
                      ? '0s'
                      : '${_fallbackUnlockSeconds.clamp(0, 999)}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final duration = _controller.value.duration;
    final position = _controller.value.position;
    final totalSeconds = duration.inSeconds > 0 ? duration.inSeconds : 0;
    final remainingSeconds =
        (duration - position).inSeconds.clamp(0, totalSeconds);
    final unlockAtMs =
        (duration.inMilliseconds * widget.closeAtPercent / 100).round();
    final closeRemainingSeconds =
        ((unlockAtMs - position.inMilliseconds) / 1000).ceil().clamp(0, totalSeconds);

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.62),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${remainingSeconds}s',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.62),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _closeUnlocked
                  ? 'Close button is now available.'
                  : widget.closeAtPercent == 100
                      ? 'Close will appear after the video finishes.'
                      : 'Close unlocks in ${closeRemainingSeconds}s.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
