import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/manager/haptic_manager.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/screen/gift_sheet/gift_motion.dart';
import 'package:nimiro/screen/gift_sheet/gift_visuals.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';

/// TikTok-style animated gift overlay.
///
/// A gift is a short, punchy moment (1.9s–3s) that plays directly on top of
/// the post with a fully transparent background:
///   1. a quick flash + 3D pop-in (short spin, bounce),
///   2. a lively hold with rotating light rays, sparkles and rising coins,
///   3. a fast scale-up + fade so the post is never blocked for long.
/// A compact pill at the bottom shows "You sent <gift> xN" like TikTok.
class GiftAnimationOverlay {
  static final GiftAnimationOverlay shared = GiftAnimationOverlay._();
  GiftAnimationOverlay._();

  final List<Gift> _queue = <Gift>[];
  OverlayEntry? _entry;
  bool _busy = false;

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
        combo: combo,
        durationMs: _durationFor(gift),
        onDone: () {
          _entry?.remove();
          _entry = null;
          _next();
        },
      ),
    );
    try {
      overlay.insert(_entry!);
      Loggers.info('GiftAnimationOverlay: animation shown for gift ${gift.id}');
    } catch (e) {
      // Never let an animation failure crash or freeze the app.
      _entry = null;
      _busy = false;
      Loggers.error('GiftAnimationOverlay insert failed: $e');
    }
  }

  /// TikTok animations are short: cheap gifts flash by, big ones linger a bit.
  static int _durationFor(Gift gift) {
    final price = gift.coinPrice ?? 0;
    if (price >= 10000) return 3000;
    if (price >= 1000) return 2400;
    return 1900;
  }
}

class _GiftAnimation extends StatefulWidget {
  final Gift gift;
  final int combo;
  final int durationMs;
  final VoidCallback onDone;

  const _GiftAnimation({
    required this.gift,
    required this.combo,
    required this.durationMs,
    required this.onDone,
  });

  @override
  State<_GiftAnimation> createState() => _GiftAnimationState();
}

enum _ParticleKind { petal, heart, star, confetti, dust, pixel, orbit, coin }

class _GiftAnimationState extends State<_GiftAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _enter; // 0 -> 1: 3D pop-in
  late final AnimationController _loop; // ambient sway / particles
  late final AnimationController _rays; // rotating light rays
  late final AnimationController _exit; // fast fade at the end

  late final List<_Particle> _particles;
  late final List<_Particle> _coins;

  Timer? _exitTimer;
  Timer? _doneTimer;

  bool get _isArabic => SessionLanguage.isArabic;
  int get _price => widget.gift.coinPrice ?? 0;
  double get _giftSize => _price >= 10000 ? 250 : (_price >= 1000 ? 210 : 175);

  GiftMotion get _motion => motionFor(widget.gift.id ?? 0);
  Color get _accent => GiftVisuals.accentFor(widget.gift);
  _ParticleKind get _kind => _particleKindFor(widget.gift.id ?? 0);

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    _loop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _rays = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3600));
    _exit = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));

    _loop.repeat();
    _rays.repeat();

    final random = math.Random();
    final count = _price >= 1000 ? 16 : 12;
    _particles = List<_Particle>.generate(count, (i) {
      return _Particle(
        angle: random.nextDouble() * math.pi * 2,
        distance: 70 + random.nextDouble() * 110,
        size: (i % 4 == 0 ? 16.0 : 9.0) + random.nextDouble() * 6,
        delay: random.nextDouble(),
        color: _particleColor(i),
      );
    });

    _coins = List<_Particle>.generate(_price >= 1000 ? 10 : 0, (i) {
      return _Particle(
        angle: (i / 10) * math.pi * 2,
        distance: 40 + random.nextDouble() * 70,
        size: 14 + random.nextDouble() * 8,
        delay: random.nextDouble(),
        color: const Color(0xFFFFD54F),
      );
    });

    _enter.forward();
    _exitTimer = Timer(Duration(milliseconds: widget.durationMs), () {
      _exit.forward();
      _doneTimer = Timer(const Duration(milliseconds: 320), widget.onDone);
    });
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _doneTimer?.cancel();
    _enter.dispose();
    _loop.dispose();
    _rays.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        // Taps go through to the post underneath.
        ignoring: true,
        child: AnimatedBuilder(
          animation: Listenable.merge([_enter, _loop, _rays, _exit]),
          builder: (context, _) {
            final enter = Curves.easeOutCubic.transform(_enter.value);
            final exit = _exit.value;
            final screen = MediaQuery.sizeOf(context);
            final padding = MediaQuery.paddingOf(context);
            final spin = (1 - enter) * math.pi * 1.5;
            final sway = math.sin(_loop.value * math.pi * 2) * .12;
            final tilt = math.sin(_loop.value * math.pi * 1.3) * .07;

            final matrix = Matrix4.identity()
              ..setEntry(3, 2, .0014)
              ..rotateY(spin + sway)
              ..rotateX(tilt);

            final entrance = motionEntranceOffset(
              _motion,
              _enter.value,
              enter,
              screen,
            );

            final scale = motionEntranceScale(_motion, enter) *
                motionAmbientScale(_motion, _loop.value) *
                (1 + exit * .12);

            final flash = (1 - enter * 4).clamp(0.0, .22);
            final showParticles = ((enter - .15) / .85).clamp(0.0, 1.0);

            return Stack(
              children: [
                // Quick white flash at launch (subtle, never a dark backdrop).
                if (flash > 0)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: flash),
                    ),
                  ),
                // Rotating light rays behind the gift.
                Center(
                  child: Opacity(
                    opacity: .55 * enter * (1 - exit),
                    child: CustomPaint(
                      size: const Size(340, 340),
                      painter: _RaysPainter(
                        color: _accent,
                        progress: _rays.value,
                      ),
                    ),
                  ),
                ),
                // Rising coins (only when the gift is worth >= 1000 coins).
                for (final c in _coins) _buildCoin(c, showParticles, exit),
                // The gift itself: 3D pop-in + lively float.
                Center(
                  child: Transform.translate(
                    offset: entrance +
                        motionAmbientOffset(_motion, _loop.value) * enter +
                        Offset(0, -40 - exit * 34),
                    child: Transform.scale(
                      scale: scale,
                      child: Transform(
                        transform: matrix,
                        alignment: Alignment.center,
                        child: _buildGiftImage(),
                      ),
                    ),
                  ),
                ),
                // Sparkles / petals / hearts bursting around the gift.
                Center(
                  child: SizedBox(
                    width: 360,
                    height: 360,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        for (final p in _particles)
                          _buildParticle(p, showParticles, exit),
                      ],
                    ),
                  ),
                ),
                // Compact TikTok-style sender pill at the bottom.
                _buildBanner(padding, enter, exit),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGiftImage() {
    final url = widget.gift.image?.addBaseURL() ?? '';
    final fallback = Icon(
      Icons.card_giftcard_rounded,
      size: _giftSize * .55,
      color: Colors.white,
    );
    return SizedBox(
      width: _giftSize,
      height: _giftSize,
      child: url.startsWith('http')
          ? CachedNetworkImage(
              imageUrl: url,
              cacheKey: url,
              fit: BoxFit.contain,
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => fallback,
            )
          : fallback,
    );
  }

  Widget _buildBanner(EdgeInsets padding, double enter, double exit) {
    final t = ((enter - .55) / .45).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(t);
    final name = widget.gift.nameFor(isArabic: _isArabic);
    final sender = _isArabic ? 'أنت' : 'You';
    final text = _isArabic ? '$sender أرسل $name' : '$sender sent $name';

    return Positioned(
      left: 0,
      right: 0,
      bottom: padding.bottom + 84,
      child: Center(
        child: Opacity(
          opacity: ((1 - exit) * t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .58),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _accent.withValues(alpha: .55),
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
                      color: _accent.withValues(alpha: .3),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.person, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    text,
                    style: TextStyleCustom.outFitMedium500(
                        fontSize: 12.5, color: Colors.white),
                  ),
                  if (widget.combo > 1) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _accent,
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
      ),
    );
  }

  Widget _buildParticle(_Particle p, double show, double exit) {
    final t = ((_loop.value + p.delay) % 1.0);
    final dx = math.cos(p.angle) * p.distance * t;
    final dy = math.sin(p.angle) * p.distance * t + 24 * t * t;
    final opacity = (1 - t) * show * (1 - exit);
    if (opacity <= 0) return const SizedBox.shrink();

    Widget child;
    switch (_kind) {
      case _ParticleKind.petal:
        child = Transform.rotate(
          angle: t * math.pi * 2,
          child: Container(
            width: p.size,
            height: p.size * .6,
            decoration: BoxDecoration(
              color: p.color.withValues(alpha: .9),
              borderRadius: BorderRadius.circular(p.size),
            ),
          ),
        );
        break;
      case _ParticleKind.heart:
        child = Icon(Icons.favorite_rounded,
            size: p.size, color: p.color.withValues(alpha: .9));
        break;
      case _ParticleKind.star:
        child = Icon(Icons.star_rounded,
            size: p.size, color: p.color.withValues(alpha: .95));
        break;
      case _ParticleKind.confetti:
        child = Transform.rotate(
          angle: t * math.pi * 3,
          child: Container(
            width: p.size * .55,
            height: p.size,
            color: p.color.withValues(alpha: .9),
          ),
        );
        break;
      case _ParticleKind.dust:
        child = Container(
          width: p.size,
          height: p.size,
          decoration: BoxDecoration(
            color: p.color.withValues(alpha: .5),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: p.color.withValues(alpha: .35), blurRadius: 8)
            ],
          ),
        );
        break;
      case _ParticleKind.pixel:
        child = Container(
          width: p.size * .7,
          height: p.size * .7,
          color: p.color.withValues(alpha: .9),
        );
        break;
      case _ParticleKind.orbit:
        child = Container(
          width: p.size * .6,
          height: p.size * .6,
          decoration: BoxDecoration(
            color: p.color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: p.color, blurRadius: 6)],
          ),
        );
        break;
      case _ParticleKind.coin:
        child = Image.asset(AssetRes.icCoin, width: p.size, height: p.size);
        break;
    }

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(opacity: opacity, child: child),
    );
  }

  Widget _buildCoin(_Particle c, double show, double exit) {
    final t = ((_loop.value + c.delay) % 1.0);
    final rise = 120 * t;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: Center(
        child: Transform.translate(
          offset: Offset(c.distance * (1 - t), 70 + rise),
          child: Opacity(
            opacity: (1 - t) * show * (1 - exit),
            child: Image.asset(AssetRes.icCoin, width: c.size, height: c.size),
          ),
        ),
      ),
    );
  }

  Color _particleColor(int i) {
    switch (_kind) {
      case _ParticleKind.petal:
        return i.isEven ? const Color(0xFFFF4D6D) : const Color(0xFFFFC1CC);
      case _ParticleKind.heart:
        return const Color(0xFFFF4D6D);
      case _ParticleKind.confetti:
        return [
          _accent,
          const Color(0xFFFFD54F),
          Colors.white,
          Color.lerp(_accent, Colors.white, .5)!,
        ][i % 4];
      case _ParticleKind.dust:
        return const Color(0xFFD7B98E);
      case _ParticleKind.pixel:
        return [
          const Color(0xFF69F0AE),
          const Color(0xFFB388FF),
          const Color(0xFFFFD54F),
        ][i % 3];
      case _ParticleKind.orbit:
        return Color.lerp(_accent, Colors.white, .4)!;
      default:
        return [
          const Color(0xFFFFD54F),
          _accent,
          Colors.white,
        ][i % 3];
    }
  }
}

_ParticleKind _particleKindFor(int id) {
  switch (id) {
    case 5:
    case 18:
    case 24:
      return _ParticleKind.petal;
    case 6:
    case 7:
    case 20:
      return _ParticleKind.heart;
    case 15:
      return _ParticleKind.orbit;
    case 12:
      return _ParticleKind.pixel;
    case 10:
    case 11:
      return _ParticleKind.dust;
    case 17:
    case 21:
    case 23:
      return _ParticleKind.confetti;
    default:
      return _ParticleKind.star;
  }
}

class _Particle {
  final double angle;
  final double distance;
  final double size;
  final double delay;
  final Color color;

  _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
    required this.color,
  });
}

class _RaysPainter extends CustomPainter {
  final Color color;
  final double progress;

  _RaysPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.width * .5;
    const rays = 14;
    for (var i = 0; i < rays; i++) {
      final a0 = progress * math.pi * 2 + i * (math.pi * 2 / rays);
      final a1 = a0 + math.pi / 22;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a0) * radius, c.dy + math.sin(a0) * radius)
        ..lineTo(c.dx + math.cos(a1) * radius, c.dy + math.sin(a1) * radius)
        ..close();
      final alpha =
          .10 + .07 * (0.5 + 0.5 * math.sin(progress * math.pi * 2 + i));
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));
    }
    // Soft core glow.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: .30),
          color.withValues(alpha: .10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: c, radius: radius * .8));
    canvas.drawCircle(c, radius * .8, glow);
  }

  @override
  bool shouldRepaint(covariant _RaysPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Small helper so the overlay does not need a BuildContext for language.
class SessionLanguage {
  static bool get isArabic =>
      SessionManager.instance.getLang() == 'ar' ||
      Get.locale?.languageCode == 'ar';
}
