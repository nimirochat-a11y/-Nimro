import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/manager/haptic_manager.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/screen/gift_sheet/gift_artwork.dart';
import 'package:nimiro/utilities/text_style_custom.dart';

/// TikTok-style gift overlay backed by real SVGA video animations.
///
/// Every gift is its own keyframed scene (120-192 frames @ 30fps, 4.0-6.4s):
/// a unique entrance, idle motion and exit plus its own particles and
/// shockwaves. The entrance itself is absolute (0.55s) so the gift becomes
/// visible almost immediately and then holds at full size for several seconds.
/// Playback is driven by a dedicated [Ticker] instead of
/// `AnimationController.forward()`, so Android's "Remove animations" setting
/// cannot shorten the scene to a 0.05x flash.
///
/// The real gift artwork is ALSO drawn as a Flutter layer on top of the SVGA
/// scene. Some Android devices fail to decode the embedded PNG/WebP bitmaps of
/// the movie in release mode (the library swallows the error and paints only
/// the vector rings), which is exactly what users saw: the caption banner and
/// the golden rings, but no gift. The artwork layer is bundled in the APK and
/// is the same image the gift sheet already renders, so it cannot fail with the
/// movie. The movie's own `gift` sprite is removed so devices where bitmaps do
/// work never show a second copy.
///
/// It is played once over the whole application, directly on top of the
/// current screen. The background is fully transparent, touches pass
/// through to the app underneath, and the scene is bundled inside the APK so it
/// plays offline and starts on the very next frame.
///
/// DESIGN: this used to insert an [OverlayEntry] through
/// `Get.key.currentState?.overlay`. That was fragile: right after `Get.back()`
/// (which closes the gift sheet) the navigator's overlay can still be `null`
/// or can belong to a route that is being popped, so the entry was silently
/// dropped and no gift was ever shown. Instead, [GiftAnimationHost] is mounted
/// once in `MyApp.build` above the whole app and listens to a broadcast stream
/// here. It cannot depend on navigator/route lifecycle at all.
class GiftAnimationOverlay {
  static final GiftAnimationOverlay shared = GiftAnimationOverlay._();
  GiftAnimationOverlay._();
  final StreamController<Gift> _controller = StreamController<Gift>.broadcast();

  /// Emits gifts in the order they should be played.
  Stream<Gift> get stream => _controller.stream;

  /// Every SVGA scene ships inside the APK (`assets/gifts/svga/`). Playing
  /// from the bundle removes the download, the 7-day disk cache and every
  /// network failure path from the animation: it is available offline, starts
  /// immediately and always matches this build of the app.
  static String? svgaAssetFor(Gift gift) {
    final id = gift.id;
    if (id == null || id < 5 || id > 28) return null;
    return 'assets/gifts/svga/gift_$id.svga';
  }

  /// The 250x250 gift artwork extracted from each bundled scene, shipped as a
  /// normal asset and decoded by Flutter's image pipeline instead of the
  /// library's bitmap decoder (which silently fails on some Android devices).
  static String? heroAssetFor(Gift gift) {
    final id = gift.id;
    if (id == null || id < 5 || id > 28) return null;
    return 'assets/gifts/hero/gift_$id.png';
  }

  /// Enqueue a gift to be played. Safe to call from any screen, at any time —
  /// including right after `Get.back()` or while another animation is running.
  void enqueue(Gift gift) {
    if (_controller.isClosed) return;
    _controller.add(gift);
  }

  void dispose() {
    if (!_controller.isClosed) _controller.close();
  }
}

/// Mounted once near the root of the app. Owns the queue so duplicate/missing
/// animations cannot happen due to route changes or `Get.back()`.
class GiftAnimationHost extends StatefulWidget {
  final Widget child;

  const GiftAnimationHost({super.key, required this.child});

  @override
  State<GiftAnimationHost> createState() => _GiftAnimationHostState();
}

class _GiftAnimationHostState extends State<GiftAnimationHost> {
  StreamSubscription<Gift>? _subscription;
  final List<Gift> _queue = <Gift>[];
  Gift? _current;
  int _combo = 1;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _subscription = GiftAnimationOverlay.shared.stream.listen(_onGift);
  }

  void _onGift(Gift gift) {
    final id = gift.id;
    // Merge rapid repeats of the SAME gift into one "xN" combo, but only when
    // it is consecutive. Never drop a different gift that is still queued.
    if (_current != null && _current!.id == id) {
      if (mounted) setState(() => _combo++);
      return;
    }
    if (_queue.isNotEmpty && _queue.last.id == id) {
      // The last queued gift has not started yet; just bump its combo.
      return;
    }
    _queue.add(gift);
    _pump();
  }

  void _pump() {
    if (_current != null || _queue.isEmpty || !mounted) return;
    final gift = _queue.removeAt(0);
    var combo = 1;
    while (_queue.isNotEmpty && _queue.first.id == gift.id) {
      _queue.removeAt(0);
      combo++;
    }
    setState(() {
      _current = gift;
      _combo = combo;
      _generation++;
    });
  }

  void _onDone(int generation) {
    if (!mounted || generation != _generation) return;
    setState(() => _current = null);
    _pump();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gift = _current;
    return Stack(
      children: [
        widget.child,
        if (gift != null)
          _GiftSvgaAnimation(
            key: ValueKey<int>(_generation),
            gift: gift,
            source: GiftAnimationOverlay.svgaAssetFor(gift) ?? '',
            combo: _combo,
            onDone: () => _onDone(_generation),
          ),
      ],
    );
  }
}

class _GiftSvgaAnimation extends StatefulWidget {
  final Gift gift;
  final String source;
  final int combo;
  final VoidCallback onDone;

  const _GiftSvgaAnimation({
    super.key,
    required this.gift,
    required this.source,
    required this.combo,
    required this.onDone,
  });

  @override
  State<_GiftSvgaAnimation> createState() => _GiftSvgaAnimationState();
}

class _GiftSvgaAnimationState extends State<_GiftSvgaAnimation>
    with TickerProviderStateMixin {
  SVGAAnimationController? _controller;
  Timer? _safetyTimer;
  Ticker? _ticker;
  Duration? _tickerStart;
  Duration? _lastTick;

  /// 0..1 clock for the Flutter-side artwork. It starts on the first frame,
  /// independently of the SVGA decode, so the gift is never late.
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  /// Replaced with the real movie length as soon as the decode completes.
  Duration _sceneDuration = const Duration(milliseconds: 4800);
  Size _viewBoxSize = const Size(300, 300);
  bool _finished = false;
  bool _svgaReady = false;
  bool _svgaFailed = false;

  bool get _isArabic =>
      SessionManager.instance.getLang() == 'ar' ||
      Get.locale?.languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    // The movies are bundled assets. The library's disk cache only stores a
    // second copy keyed by asset path, adding a file read (and a stale-data
    // risk) without saving any decode work. Keep it off.
    SVGACache.shared.setEnabled(false);

    // Do NOT gate this on the navigator being ready — the host is mounted
    // above the whole app, so the animation can always be created.
    _controller = SVGAAnimationController(vsync: this);

    // The movie is bundled, so this is only a safety net for a corrupted
    // asset; it is not a network timeout any more.
    _safetyTimer = Timer(const Duration(milliseconds: 12000), _finish);

    HapticManager.shared.medium();

    // Start the clock immediately. The artwork layer is pure Flutter and does
    // not wait for the movie, so the gift enters even if the SVGA file takes
    // long to decode or fails completely.
    _startScene();

    final source = widget.source;
    final movieFuture = source.startsWith('http')
        ? SVGAParser.shared.decodeFromURL(source)
        : SVGAParser.shared.decodeFromAssets(source);
    movieFuture.then(_onDecoded).catchError((e) {
      Loggers.error(
          'GiftDiag id=${widget.gift.id} decode=failed source=$source '
          'error=$e');
      if (mounted && !_finished) setState(() => _svgaFailed = true);
      // Keep the default 4.8s clock: the artwork layer still plays in full.
    });
  }

  void _onDecoded(MovieEntity movie) {
    if (!mounted || _controller == null || _finished) {
      // Nobody is showing this movie: release it ourselves. When it is handed
      // to the controller instead, the controller owns it and its dispose()
      // releases it (MovieEntity.autorelease).
      movie.dispose();
      _finish();
      return;
    }
    final controller = _controller!;

    // Diagnostics: `bitmapCache` is the only place decoded bitmaps live. If it
    // is empty (or is missing sprite keys) this device cannot decode the
    // embedded images in release mode, which is the exact failure users hit.
    final spriteKeys = movie.sprites.map((s) => s.imageKey).toSet();
    final bitmapKeys = movie.bitmapCache.keys.toSet();
    final missingBitmaps = spriteKeys
        .where((k) => !k.contains('.vector') && !bitmapKeys.contains(k))
        .toList()
      ..sort();
    Loggers.error('GiftDiag id=${widget.gift.id} bitmaps=${bitmapKeys.length} '
        'missing=${missingBitmaps.join("|")} sprites=${movie.sprites.length} '
        'frames=${movie.params.frames} fps=${movie.params.fps} '
        'viewBox=${movie.params.viewBoxWidth}x${movie.params.viewBoxHeight}');

    // The Flutter artwork layer always draws the real gift on top. Remove the
    // movie's own gift sprite so it can never appear twice on devices where
    // bitmap decoding does work.
    movie.sprites.removeWhere((s) => s.imageKey == 'gift');

    controller.videoItem = movie;

    // The scenes are authored at the full 30fps (120-192 frames = 4.0-6.4s),
    // with a 0.55s entrance. We deliberately do NOT call controller.forward():
    // when the phone has "Remove animations" enabled (or the developer animator
    // scale is off), Flutter multiplies every AnimationController duration by
    // 0.05 — a 4.8s gift became a 0.24s flash. Driving the controller from our
    // own Ticker keeps the whole scene regardless of that setting.
    final fps = movie.params.fps == 0 ? 20 : movie.params.fps;
    final playMs = (movie.params.frames / fps * 1000).toInt();
    final previousProgress = _progress.value;
    final previousDuration = _sceneDuration;
    _sceneDuration = Duration(milliseconds: playMs);
    _viewBoxSize = Size(
      movie.params.viewBoxWidth > 0 ? movie.params.viewBoxWidth : 300,
      movie.params.viewBoxHeight > 0 ? movie.params.viewBoxHeight : 300,
    );

    // Keep the artwork's current position when the real duration arrives a
    // few frames into the scene; without this remap it would jump backwards.
    if (_tickerStart != null &&
        _lastTick != null &&
        previousDuration != _sceneDuration) {
      _tickerStart = _lastTick! -
          Duration(
            microseconds:
                (previousProgress * _sceneDuration.inMicroseconds).round(),
          );
    }
    // `videoItem=` resets the controller to 0; restore the shared clock.
    controller.value = previousProgress;

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    Loggers.info(
        'Gift ${widget.gift.id}: playing ${movie.params.frames} frames '
        '@${fps}fps (${playMs}ms), disableAnimations=$disableAnimations');

    // The computed timer is the authoritative end of the scene: the last
    // frames are fully transparent, so listening for "completed" is unreliable.
    setState(() => _svgaReady = true);
    // Start after the build that mounts SVGAImage, so the painter is attached
    // before the first value is written.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _finished || _controller != controller) return;
      _safetyTimer?.cancel();
      _safetyTimer =
          Timer(_sceneDuration + const Duration(milliseconds: 400), _finish);
      controller.value = _progress.value;
    });
  }

  void _startScene() {
    _ticker?.dispose();
    _ticker = null;
    _tickerStart = null;
    _lastTick = null;
    _controller?.value = 0;
    final ticker = createTicker(_onTick);
    _ticker = ticker;
    ticker.start();
  }

  void _onTick(Duration elapsed) {
    final controller = _controller;
    if (!mounted || _finished || controller == null) {
      _ticker?.stop();
      return;
    }
    _lastTick = elapsed;
    _tickerStart ??= elapsed;
    final totalUs = _sceneDuration.inMicroseconds;
    final elapsedUs = (elapsed - _tickerStart!).inMicroseconds;
    final progress =
        totalUs <= 0 ? 1.0 : (elapsedUs / totalUs).clamp(0.0, 1.0).toDouble();
    _progress.value = progress;
    controller.value = progress;
    if (progress >= 1.0) {
      // Stop here; dispose() releases the ticker after the host unmounts us.
      _ticker?.stop();
      _tickerStart = null;
      _finish();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _safetyTimer?.cancel();
    _ticker?.stop();
    widget.onDone();
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _ticker?.dispose();
    // SVGAAnimationController.dispose() releases its videoItem (autorelease).
    _controller?.dispose();
    _progress.dispose();
    super.dispose();
  }

  Widget _buildFallbackImage() {
    final placeholder = Align(
      alignment: Alignment.center,
      child: Container(
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFFFF4D6D).withValues(alpha: .10),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.card_giftcard_rounded,
            size: 110, color: Colors.white.withValues(alpha: .92)),
      ),
    );
    // The 24 built-in gifts are bundled, so the first frame is shown without
    // any network request while the SVGA controller decodes the movie.
    final local = bundledGiftImage(widget.gift.image);
    if (local != null) {
      return Image.asset(
        local,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    final url = widget.gift.image?.addBaseURL() ?? '';
    if (!url.startsWith('http')) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: url,
      fit: BoxFit.contain,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.gift.nameFor(isArabic: _isArabic).trim();
    final displayName = name.isEmpty ? (_isArabic ? 'هدية' : 'Gift') : name;
    final sender = _isArabic ? 'أنت' : 'You';
    final text =
        _isArabic ? '$sender أرسلت $displayName' : '$sender sent $displayName';
    // The host sits above GetMaterialApp, so a MediaQuery may not exist yet
    // (e.g. very early startup). Fall back to zero instead of throwing.
    final padding = MediaQuery.maybePaddingOf(context) ?? EdgeInsets.zero;
    final bottom = padding.bottom + 84.0;
    // 92% of the screen width, capped so it looks right on tiny phones and
    // tablets. The old fixed 300x300 box made the 250px gift look small and
    // easy to miss on a 1080p phone.
    final screenWidth = MediaQuery.maybeSizeOf(context)?.width ?? 400.0;
    final giftSide = (screenWidth * 0.92).clamp(280.0, 420.0).toDouble();
    // Prefer the scene's own 250x250 artwork; fall back to the gift sheet image
    // for any gift added later from the admin panel.
    final artworkImage = GiftAnimationOverlay.heroAssetFor(widget.gift) ??
        bundledGiftImage(widget.gift.image);

    // IMPORTANT: no Material/Container/ColoredBox backdrop here. The layer is
    // fully transparent and IgnorePointer makes every touch pass through to
    // the post/video underneath, including its buttons.
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: SizedBox(
                width: giftSide,
                height: giftSide,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_svgaReady && !_svgaFailed && _controller != null)
                      // SVGAImage always paints at the movie's viewBox size
                      // (300x300), so the SizedBox alone does not enlarge it.
                      // FittedBox scales the rendered scene to the full box.
                      FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: _viewBoxSize.width,
                          height: _viewBoxSize.height,
                          child: SVGAImage(_controller!, fit: BoxFit.contain),
                        ),
                      )
                    else if (artworkImage == null)
                      _buildFallbackImage(),
                    // The guaranteed gift layer. It is the exact 250x250 art
                    // the movie was authored with, decoded by Flutter's asset
                    // pipeline, so it works even when the movie's bitmap
                    // decode fails on this device.
                    if (artworkImage != null)
                      _GiftArtworkLayer(
                        progress: _progress,
                        image: artworkImage,
                        side: giftSide,
                        duration: _sceneDuration,
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottom,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  constraints: BoxConstraints(
                    maxWidth:
                        (MediaQuery.maybeSizeOf(context)?.width ?? 400) * .82,
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

/// Draws the real gift artwork with its own entrance / hold / exit timeline,
/// a soft golden glow and a few twinkling stars. Everything is transparent and
/// non-interactive, so it sits over the post without hiding any button.
class _GiftArtworkLayer extends StatelessWidget {
  final ValueListenable<double> progress;
  final String image;
  final double side;
  final Duration duration;

  const _GiftArtworkLayer({
    required this.progress,
    required this.image,
    required this.side,
    required this.duration,
  });

  // x/y are fractions of [side] around the centre, then phase and size.
  static const List<List<double>> _stars = <List<double>>[
    <double>[-0.40, -0.30, 0.0, 15],
    <double>[0.36, -0.36, 1.3, 12],
    <double>[-0.34, 0.30, 2.1, 11],
    <double>[0.42, 0.22, 3.0, 16],
    <double>[-0.46, 0.02, 4.2, 10],
    <double>[0.10, -0.46, 5.1, 13],
    <double>[-0.12, 0.44, 0.8, 12],
    <double>[0.46, -0.06, 2.6, 10],
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: side,
      height: side,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          final totalMs = math.max(duration.inMilliseconds, 1).toDouble();
          final elapsed = (progress.value * totalMs).clamp(0.0, totalMs);
          const enterMs = 550.0;
          const exitMs = 700.0;

          // easeOutBack entrance: 0.55 -> 1.0 over the first 0.55s.
          final t = (elapsed / enterMs).clamp(0.0, 1.0).toDouble();
          const c1 = 1.70158;
          const c3 = c1 + 1.0;
          final eased =
              (1.0 + c3 * math.pow(t - 1.0, 3) + c1 * math.pow(t - 1.0, 2))
                  .toDouble();
          final entranceScale = 0.55 + 0.45 * eased;

          // Fade out over the last 0.7s while growing slightly.
          final remaining = totalMs - elapsed;
          final exitT =
              ((exitMs - remaining) / exitMs).clamp(0.0, 1.0).toDouble();
          final opacity = (t * (1.0 - exitT)).clamp(0.0, 1.0).toDouble();
          final exitScale = 1.0 + 0.16 * exitT;

          // Gentle idle pulse so the artwork feels alive while it holds.
          final pulse = 1.0 + 0.035 * math.sin(elapsed / 260.0);
          final glowStrength =
              ((0.55 + 0.25 * math.sin(elapsed / 300.0)) * opacity)
                  .clamp(0.0, 1.0)
                  .toDouble();

          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: entranceScale * exitScale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: side * 0.92,
                    height: side * 0.92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          Color.fromRGBO(255, 216, 107, 0.42 * glowStrength),
                          Color.fromRGBO(255, 150, 70, 0.20 * glowStrength),
                          Colors.transparent,
                        ],
                        stops: const <double>[0.0, 0.48, 1.0],
                      ),
                    ),
                  ),
                  for (final star in _stars)
                    Positioned(
                      left: side / 2 + star[0] * side - star[3] / 2,
                      top: side / 2 + star[1] * side - star[3] / 2,
                      child: Opacity(
                        opacity: (0.35 +
                                0.65 *
                                    (0.5 +
                                        0.5 *
                                            math.sin(
                                                elapsed / 190.0 + star[2])))
                            .clamp(0.0, 1.0)
                            .toDouble(),
                        child: Transform.rotate(
                          angle: math.sin(elapsed / 420.0 + star[2]) * 0.35,
                          child: Icon(
                            Icons.star_rounded,
                            size: star[3],
                            color: const Color(0xFFFFE082),
                          ),
                        ),
                      ),
                    ),
                  Transform.scale(
                    scale: pulse,
                    child: Image.asset(
                      image,
                      width: side * 0.8333,
                      height: side * 0.8333,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
}
