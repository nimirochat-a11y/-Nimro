import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
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
  Duration _sceneDuration = Duration.zero;
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
    // Do NOT gate this on the navigator being ready — the host is mounted
    // above the whole app, so the animation can always be created.
    _controller = SVGAAnimationController(vsync: this);

    // The movie is bundled, so this is only a safety net for a corrupted
    // asset; it is not a network timeout any more.
    _safetyTimer = Timer(const Duration(milliseconds: 12000), _finish);

    HapticManager.shared.medium();
    final source = widget.source;
    final movieFuture = source.startsWith('http')
        ? SVGAParser.shared.decodeFromURL(source)
        : SVGAParser.shared.decodeFromAssets(source);
    movieFuture.then(_onDecoded).catchError((e) {
      Loggers.error('GiftAnimationOverlay: SVGA decode failed ($source): $e');
      if (mounted && !_finished) setState(() => _svgaFailed = true);
      _safetyTimer?.cancel();
      _safetyTimer = Timer(const Duration(milliseconds: 1200), _finish);
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

    controller.videoItem = movie;

    // The scenes are authored at the full 30fps (120-192 frames = 4.0-6.4s),
    // with a 0.55s entrance. We deliberately do NOT call controller.forward():
    // when the phone has "Remove animations" enabled (or the developer animator
    // scale is off), Flutter multiplies every AnimationController duration by
    // 0.05 — a 4.8s gift became a 0.24s flash. Driving the controller from our
    // own Ticker keeps the whole scene regardless of that setting.
    final fps = movie.params.fps == 0 ? 20 : movie.params.fps;
    final playMs = (movie.params.frames / fps * 1000).toInt();
    _sceneDuration = Duration(milliseconds: playMs);
    _viewBoxSize = Size(
      movie.params.viewBoxWidth > 0 ? movie.params.viewBoxWidth : 300,
      movie.params.viewBoxHeight > 0 ? movie.params.viewBoxHeight : 300,
    );
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
      _startScene(controller);
    });
  }

  void _startScene(SVGAAnimationController controller) {
    _ticker?.dispose();
    _ticker = null;
    _tickerStart = null;
    controller.value = 0;
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
    _tickerStart ??= elapsed;
    final totalUs = _sceneDuration.inMicroseconds;
    final elapsedUs = (elapsed - _tickerStart!).inMicroseconds;
    final progress =
        totalUs <= 0 ? 1.0 : (elapsedUs / totalUs).clamp(0.0, 1.0).toDouble();
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
                child: _svgaReady && !_svgaFailed && _controller != null
                    // SVGAImage always paints at the movie's viewBox size
                    // (300x300), so the SizedBox alone does not enlarge it.
                    // FittedBox scales the rendered scene to the full box.
                    ? FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: _viewBoxSize.width,
                          height: _viewBoxSize.height,
                          child: SVGAImage(_controller!, fit: BoxFit.contain),
                        ),
                      )
                    : _buildFallbackImage(),
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
