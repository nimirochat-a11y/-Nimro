import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/manager/haptic_manager.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';

/// Full-screen, TikTok-style animated gift overlay.
///
/// Replaces the old static white dialog. Gifts animate in with a spring,
/// float and rotate, emit a glowing halo plus particles and coins, and are
/// dismissed automatically (or by tap). Fast consecutive gifts are queued so
/// every animation plays fully instead of being replaced.
class GiftAnimationOverlay {
  static final GiftAnimationOverlay shared = GiftAnimationOverlay._();
  GiftAnimationOverlay._();

  final List<Gift> _queue = <Gift>[];
  OverlayEntry? _entry;
  bool _busy = false;

  static const Duration _duration = Duration(milliseconds: 2600);

  /// Enqueue a gift animation. Safe to call rapidly / from any screen.
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

    // Use the root navigator's overlay, NOT Get.context. When the gift sheet
    // is closed with Get.back(), Get.context may still point at the disposed
    // bottom-sheet context, so the overlay was never visible. Get.key is the
    // stable navigator key registered on GetMaterialApp in main.dart.
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
    _entry = OverlayEntry(
      builder: (_) => _GiftAnimation(
        gift: gift,
        onDone: () {
          _entry?.remove();
          _entry = null;
          _next();
        },
      ),
    );
    overlay.insert(_entry!);
    Loggers.info('GiftAnimationOverlay: animation shown for gift ${gift.id}');
  }
}

class _GiftAnimation extends StatefulWidget {
  final Gift gift;
  final VoidCallback onDone;

  const _GiftAnimation({required this.gift, required this.onDone});

  @override
  State<_GiftAnimation> createState() => _GiftAnimationState();
}

class _GiftAnimationState extends State<_GiftAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _rotation;
  late final Animation<double> _halo;
  late final List<_Particle> _particles;

  bool get _isArabic => SessionLanguage.isArabic;
  int get _price => widget.gift.coinPrice ?? 0;
  bool get _expensive => _price >= 5000;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: GiftAnimationOverlay._duration);

    _scale = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, .26, curve: Curves.elasticOut),
    ).drive(Tween<double>(begin: .15, end: 1));
    _fade = CurvedAnimation(
      parent: _c,
      curve: const Interval(.72, 1, curve: Curves.easeIn),
    ).drive(Tween<double>(begin: 1, end: 0));
    _slide = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, .32, curve: Curves.easeOutBack),
    ).drive(Tween<Offset>(begin: const Offset(0, .55), end: Offset.zero));
    _rotation = Tween<double>(begin: -.12, end: .12).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOutSine),
    );
    _halo = Tween<double>(begin: .7, end: 1.35).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );

    final random = math.Random();
    _particles = List<_Particle>.generate(_expensive ? 22 : 12, (i) {
      final angle = (i / (_expensive ? 22 : 12)) * math.pi * 2;
      return _Particle(
        angle: angle,
        distance: 70 + random.nextDouble() * 90,
        size: 3 + random.nextDouble() * 5,
        delay: .08 + random.nextDouble() * .18,
        isCoin: i % 3 == 0,
        color: Color(0xFFFFD54F + (i % 2) * 0x000101),
      );
    });

    _c.forward();
    Timer(GiftAnimationOverlay._duration, widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDone,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Container(
              color: const Color(0x99000000),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glowing halo behind the gift.
                  Opacity(
                    opacity: (1 - _c.value) * .9,
                    child: Transform.scale(
                      scale: _halo.value,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFFE2C55).withValues(alpha: .55),
                              const Color(0xFFFE2C55).withValues(alpha: .12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Particles / coins flying outwards.
                  for (final p in _particles) _buildParticle(p),
                  // The gift itself: spring pop-in + float + rotate + fade.
                  FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: ScaleTransition(
                        scale: _scale,
                        child: RotationTransition(
                          turns: _rotation,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0x33FE2C55),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFE2C55)
                                          .withValues(alpha: .55),
                                      blurRadius: 34,
                                      spreadRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Image.network(
                                  widget.gift.image?.addBaseURL() ?? '',
                                  width: _expensive ? 132 : 104,
                                  height: _expensive ? 132 : 104,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.card_giftcard_rounded,
                                    size: 96,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xE60B0B0F),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                      color: const Color(0xFFFE2C55),
                                      width: 1.4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.gift.nameFor(isArabic: _isArabic),
                                      style: TextStyleCustom.outFitBold700(
                                          fontSize: 16, color: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                    Image.asset(AssetRes.icCoin,
                                        width: 16, height: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_price',
                                      style: TextStyleCustom.outFitBold700(
                                          fontSize: 14,
                                          color: const Color(0xFFFFD54F)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isArabic ? 'أُرسلت الهدية!' : 'Gift sent!',
                                style: TextStyleCustom.outFitSemiBold600(
                                    fontSize: 15,
                                    color: const Color(0xFFFE2C55)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildParticle(_Particle p) {
    final t = ((_c.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
    if (t <= 0) return const SizedBox();
    final dx = math.cos(p.angle) * p.distance * t;
    final dy = math.sin(p.angle) * p.distance * t + 60 * t * t;
    return Opacity(
      opacity: (1 - t) * .95,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: p.isCoin
            ? Image.asset(AssetRes.icCoin,
                width: p.size * 2.2, height: p.size * 2.2)
            : Container(
                width: p.size,
                height: p.size,
                decoration: BoxDecoration(
                  color: p.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: p.color, blurRadius: 8),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double distance;
  final double size;
  final double delay;
  final bool isCoin;
  final Color color;

  _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
    required this.isCoin,
    required this.color,
  });
}

/// Small helper so the overlay does not need a BuildContext for language.
class SessionLanguage {
  static bool get isArabic =>
      SessionManager.instance.getLang() == 'ar' ||
      Get.locale?.languageCode == 'ar';
}
