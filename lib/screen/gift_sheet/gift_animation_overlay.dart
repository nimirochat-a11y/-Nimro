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

/// TikTok-style animated gift overlay.
///
/// Each gift plays a full, clearly visible animation:
///   1. spring pop-in from the bottom,
///   2. a long "hero" hold with continuous floating + pulsing + rotating halo,
///   3. a smooth fade-out at the very end.
/// Fast consecutive gifts are queued so every one gets its full moment.
class GiftAnimationOverlay {
  static final GiftAnimationOverlay shared = GiftAnimationOverlay._();
  GiftAnimationOverlay._();

  final List<Gift> _queue = <Gift>[];
  OverlayEntry? _entry;
  bool _busy = false;

  // Long enough to actually see and enjoy the gift (TikTok keeps gifts ~4-5s).
  static const Duration _duration = Duration(milliseconds: 4800);

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

    // Use the root navigator's overlay, NOT Get.context, which may be null or
    // may point at the just-dismissed gift bottom sheet.
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
    with TickerProviderStateMixin {
  late final AnimationController _enter; // pop-in
  late final AnimationController _float; // continuous float loop
  late final AnimationController _halo; // continuous halo pulse loop
  late final AnimationController _exit; // fade-out at the end
  late final List<_Particle> _particles;

  bool get _isArabic => SessionLanguage.isArabic;
  int get _price => widget.gift.coinPrice ?? 0;
  bool get _expensive => _price >= 5000;

  Timer? _holdTimer;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _float = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _halo = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _exit = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    // Continuous loops for the whole time the gift is on screen.
    _float.repeat(reverse: true);
    _halo.repeat(reverse: true);

    final random = math.Random();
    final count = _expensive ? 30 : 18;
    _particles = List<_Particle>.generate(count, (i) {
      return _Particle(
        angle: (i / count) * math.pi * 2 + random.nextDouble() * .3,
        distance: 90 + random.nextDouble() * 130,
        size: 4 + random.nextDouble() * 6,
        delay: random.nextDouble() * .25,
        isCoin: i % 3 == 0,
        color: [
          const Color(0xFFFFD54F),
          const Color(0xFFFE2C55),
          const Color(0xFFFF7BA2),
          Colors.white,
        ][i % 4],
      );
    });

    _enter.forward();

    // Keep the gift fully visible for the "hold" phase, then fade out.
    _exitTimer = Timer(GiftAnimationOverlay._duration, () {
      _exit.forward();
      _holdTimer = Timer(const Duration(milliseconds: 500), widget.onDone);
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _exitTimer?.cancel();
    _enter.dispose();
    _float.dispose();
    _halo.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDone,
        child: AnimatedBuilder(
          animation: Listenable.merge([_enter, _float, _halo, _exit]),
          builder: (context, _) {
            final exit = _exit.value;
            final enter = CurvedAnimation(
              parent: _enter,
              curve: Curves.elasticOut,
            ).value;
            final float = math.sin(_float.value * math.pi * 2);
            final haloPulse = math.sin(_halo.value * math.pi * 2);

            return Container(
              color: const Color(0xAA000000).withValues(alpha: 1 - exit),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rotating, pulsing halo rings (TikTok-style glow).
                  Opacity(
                    opacity: (1 - exit) * (.6 + haloPulse * .2),
                    child: Transform.scale(
                      scale: 1 + haloPulse * .12,
                      child: Transform.rotate(
                        angle: _halo.value * math.pi,
                        child: Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFFE2C55).withValues(alpha: .55),
                                const Color(0xFFFF7BA2).withValues(alpha: .22),
                                Colors.transparent,
                              ],
                              stops: const [.35, .65, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Inner bright halo.
                  Opacity(
                    opacity: (1 - exit) * (.5 + haloPulse * .25),
                    child: Transform.scale(
                      scale: .8 + haloPulse * .1,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: .35),
                              const Color(0xFFFE2C55).withValues(alpha: .18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Golden particles / coins bursting outwards.
                  for (final p in _particles) _buildParticle(p, exit),
                  // Gift card: pop-in, continuous float, fade only at the end.
                  Opacity(
                    opacity: 1 - exit,
                    child: Transform.translate(
                      offset: Offset(0, (1 - enter) * 160 + float * 8),
                      child: Transform.scale(
                        scale: enter * (1 + haloPulse * .015),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0x33FE2C55),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFE2C55)
                                        .withValues(alpha: .6 + haloPulse * .2),
                                    blurRadius: 40,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                              child: Image.network(
                                widget.gift.image?.addBaseURL() ?? '',
                                width: _expensive ? 150 : 120,
                                height: _expensive ? 150 : 120,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.card_giftcard_rounded,
                                  size: 110,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            // Name + price banner with TikTok gradient.
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFE2C55),
                                    Color(0xFFFF7BA2)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFE2C55)
                                        .withValues(alpha: .5),
                                    blurRadius: 18,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.gift.nameFor(isArabic: _isArabic),
                                    style: TextStyleCustom.outFitBold700(
                                        fontSize: 17, color: Colors.white),
                                  ),
                                  const SizedBox(width: 10),
                                  Image.asset(AssetRes.icCoin,
                                      width: 17, height: 17),
                                  const SizedBox(width: 5),
                                  Text(
                                    '$_price',
                                    style: TextStyleCustom.outFitBold700(
                                        fontSize: 15, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isArabic ? 'أُرسلت الهدية!' : 'Gift sent!',
                              style: TextStyleCustom.outFitSemiBold600(
                                  fontSize: 16, color: const Color(0xFFFF7BA2)),
                            ),
                          ],
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

  Widget _buildParticle(_Particle p, double exit) {
    // Particles animate on a loop during the hold phase.
    final t = ((_float.value + p.delay) % 1.0);
    final dx = math.cos(p.angle) * p.distance * t;
    final dy = math.sin(p.angle) * p.distance * t + 70 * t * t;
    return Opacity(
      opacity: (1 - t) * (1 - exit),
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
                  boxShadow: [BoxShadow(color: p.color, blurRadius: 10)],
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
