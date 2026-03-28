import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class UserAdPopupDialog extends StatefulWidget {
  final Map<String, dynamic> ad;

  const UserAdPopupDialog({super.key, required this.ad});

  @override
  State<UserAdPopupDialog> createState() => _UserAdPopupDialogState();
}

class _UserAdPopupDialogState extends State<UserAdPopupDialog> {
  bool _videoCanClose = false;

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
        onPressed: () => Navigator.of(context).pop(),
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

  const _AdVideoPlayer({
    required this.url,
    required this.closeAtPercent,
    required this.onCloseUnlocked,
  });

  @override
  State<_AdVideoPlayer> createState() => _AdVideoPlayerState();
}

class _AdVideoPlayerState extends State<_AdVideoPlayer> {
  late final VideoPlayerController _controller;
  Timer? _refreshTimer;
  bool _ready = false;
  bool _closeUnlocked = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller
          ..setLooping(true)
          ..play();
        _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted || !_controller.value.isInitialized) return;
          _checkCloseUnlock();
          setState(() {});
        });
      });
  }

  void _checkCloseUnlock() {
    if (_closeUnlocked) return;
    final duration = _controller.value.duration;
    final position = _controller.value.position;
    if (duration.inMilliseconds <= 0) return;
    final unlockAtMs =
        (duration.inMilliseconds * widget.closeAtPercent / 100).round();
    if (position.inMilliseconds >= unlockAtMs) {
      _closeUnlocked = true;
      widget.onCloseUnlocked();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Container(
        height: 210,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
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
