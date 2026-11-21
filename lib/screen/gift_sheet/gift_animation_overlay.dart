import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/manager/haptic_manager.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/utilities/text_style_custom.dart';

/// TikTok-style gift overlay backed by real SVGA video animations.
///
/// Each gift is a genuine keyframed SVGA movie (24 frames @ 30fps, ~0.8s)
/// played once with [SVGAAnimationController] directly on top of the post.
/// The background is fully transparent and touches pass through to the post.
class GiftAnimationOverlay {
  static final GiftAnimationOverlay shared = GiftAnimationOverlay._();
  GiftAnimationOverlay._();

  final List<Gift> _queue = <Gift>[];
  OverlayEntry? _entry;
  bool _busy = false;

  /// Public R2 bucket base for SVGA gift movies.
  static const String svgaBase =
      'https://pub-e25da76c2db546e780c87294e2c9ff0f.r2.dev/gifts/svga/';

  static String? svgaUrlFor(Gift gift) {
    final id = gift.id;
    if (id == null || id < 5 || id > 28) return null;
    return '${svgaBase}gift_$id.svga';
  }

  void enqueue(Gift gift) {
    _queue.add(gift);
    if (!_busy) _next();
  }

  void _next() {
    if (_queue.isEmpty || _entry != null) {
      if (_entry == null) _busy = false;
      return;
    }
    _busy = true;
    final gift = _queue.removeAt(0);

    // Merge rapid repeats of the same gift into one "xN" combo, like TikTok.
    var combo = 1;
    while (_queue.isNotEmpty && _queue.first.id == gift.id) {
      _queue.removeAt(0);
      combo++;
    }

    OverlayState? overlay;
    try {
      overlay = Get.key.currentState?.overlay;
    } catch (_) {
      overlay = null;
    }
    if (overlay == null) {
      Loggers.error('GiftAnimationOverlay: root navigator overlay is null');
      _busy = false;
      return;
    }

    HapticManager.shared.medium();
    final url = svgaUrlFor(gift) ?? '';
    _entry = OverlayEntry(
      builder: (_) => _GiftSvgaAnimation(
        gift: gift,
        url: url,
        combo: combo,
        onDone: () {
          _entry?.remove();
          _entry = null;
          _next();
        },
      ),
    );
    try {
      overlay.insert(_entry!);
      Loggers.info(
          'GiftAnimationOverlay: SVGA animation shown for gift ${gift.id}');
    } catch (e) {
      _entry = null;
      _busy = false;
      Loggers.error('GiftAnimationOverlay insert failed: $e');
    }
  }
}

class _GiftSvgaAnimation extends StatefulWidget {
  final Gift gift;
  final String url;
  final int combo;
  final VoidCallback onDone;

  const _GiftSvgaAnimation({
    required this.gift,
    required this.url,
    required this.combo,
    required this.onDone,
  });

  @override
  State<_GiftSvgaAnimation> createState() => _GiftSvgaAnimationState();
}

class _GiftSvgaAnimationState extends State<_GiftSvgaAnimation>
    with TickerProviderStateMixin {
  SVGAAnimationController? _controller;
  MovieEntity? _movie;
  Timer? _safetyTimer;
  bool _finished = false;

  bool get _isArabic =>
      SessionManager.instance.getLang() == 'ar' ||
      Get.locale?.languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);

    // Safety timeout: never block the post for more than 2.2s even if the
    // network is slow or decoding fails.
    _safetyTimer = Timer(const Duration(milliseconds: 2200), _finish);

    if (widget.url.startsWith('http')) {
      SVGAParser.shared
          .decodeFromURL(widget.url)
          .then(_onDecoded)
          .catchError((_) {
        _finish();
      });
    } else {
      _finish();
    }
  }

  void _onDecoded(MovieEntity movie) {
    if (!mounted || _controller == null) {
      movie.dispose();
      _finish();
      return;
    }
    setState(() => _movie = movie);
    final controller = _controller!;
    controller.videoItem = movie;
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
    controller.forward(from: 0);
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _safetyTimer?.cancel();
    widget.onDone();
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _controller?.dispose();
    _movie?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final rawName = widget.gift.nameFor(isArabic: _isArabic).trim();
    final name = rawName.isEmpty ? (_isArabic ? 'هدية' : 'Gift') : rawName;
    final sender = _isArabic ? 'أنت' : 'You';
    final text = _isArabic ? '$sender أرسلت $name' : '$sender sent $name';

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The real SVGA gift movie (transparent, plays once).
            Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: _controller != null
                    ? SVGAImage(_controller!, fit: BoxFit.contain)
                    : const SizedBox.shrink(),
              ),
            ),
            // Compact TikTok-style sender pill at the bottom.
            Positioned(
              left: 0,
              right: 0,
              bottom: padding.bottom + 84,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * .82,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .58),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFFFF4D6D).withValues(alpha: .55),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4D6D).withValues(alpha: .3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person,
                            size: 14, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyleCustom.outFitMedium500(
                              fontSize: 12.5, color: Colors.white),
                        ),
                      ),
                      if (widget.combo > 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4D6D),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            'x${widget.combo}',
                            style: TextStyleCustom.outFitBold700(
                                fontSize: 11, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
