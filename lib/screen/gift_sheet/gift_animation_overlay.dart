import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/manager/haptic_manager.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/utilities/text_style_custom.dart';

/// TikTok-style gift overlay backed by real SVGA video animations.
///
/// Every gift is its own keyframed scene (30-48 frames @ 30fps, 1.0-1.6s):
/// a unique entrance, idle motion and exit plus its own particles and
/// shockwaves. It is played once over the whole application, directly on top
/// of the current screen. The background is fully transparent, touches pass
/// through to the app underneath, and a still image is shown immediately while
/// the movie loads so the gift is never invisible.
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

  /// Public R2 bucket base for SVGA gift movies (v2 scenes).
  static const String svgaBase =
      'https://pub-e25da76c2db546e780c87294e2c9ff0f.r2.dev/gifts/svga2/';

  /// Bumped whenever the scene files change. flutter_svga caches decoded
  /// movies on disk keyed by the FULL URL for 7 days without any way to
  /// invalidate a single entry, so a new version query forces a fresh fetch.
  static const int _sceneVersion = 2;

  static String? svgaUrlFor(Gift gift) {
    final id = gift.id;
    if (id == null || id < 5 || id > 28) return null;
    return '${svgaBase}gift_$id.svga?v=$_sceneVersion';
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
            url: GiftAnimationOverlay.svgaUrlFor(gift) ?? '',
            combo: _combo,
            onDone: () => _onDone(_generation),
          ),
      ],
    );
  }
}

class _GiftSvgaAnimation extends StatefulWidget {
  final Gift gift;
  final String url;
  final int combo;
  final VoidCallback onDone;

  const _GiftSvgaAnimation({
    super.key,
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
  Timer? _safetyTimer;
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

    // Hard cap while the movie downloads. The still image is visible from the
    // first frame, so no gift is ever invisible or blocks the post forever.
    // Generous enough for a slow mobile connection to fetch a ~150KB scene.
    _safetyTimer = Timer(const Duration(milliseconds: 12000), _finish);

    HapticManager.shared.medium();
    if (widget.url.startsWith('http')) {
      SVGAParser.shared
          .decodeFromURL(widget.url)
          .then(_onDecoded)
          .catchError((e) {
        Loggers.error('GiftAnimationOverlay: SVGA decode failed: $e');
        if (mounted && !_finished) setState(() => _svgaFailed = true);
        _safetyTimer?.cancel();
        _safetyTimer = Timer(const Duration(milliseconds: 1200), _finish);
      });
    } else {
      _svgaFailed = true;
      _safetyTimer?.cancel();
      _safetyTimer = Timer(const Duration(milliseconds: 1200), _finish);
    }
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

    // Play the 1.2-1.6s scene slower so it reads like a real TikTok gift
    // moment instead of a flash. Stretching the controller duration keeps every
    // keyframe and particle intact — only the pacing changes.
    const double playbackSlowdown = 1.75;
    final fps = movie.params.fps == 0 ? 20 : movie.params.fps;
    final nativeMs = (movie.params.frames / fps * 1000).toInt();
    final playMs = (nativeMs * playbackSlowdown).toInt();
    controller.duration = Duration(milliseconds: playMs);
    Loggers.info(
        'Gift ${widget.gift.id}: playing ${movie.params.frames} frames '
        '@${fps}fps (${playMs}ms)');

    // The status listener can fire early if the last frames are transparent
    // (our exit animations end fully faded out), so the computed timer below
    // is the authoritative end of the scene.
    setState(() => _svgaReady = true);
    // Start after the build that mounts SVGAImage, so the painter already has
    // a listener attached when the first tick arrives.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _finished || _controller != controller) return;
      _safetyTimer?.cancel();
      _safetyTimer = Timer(Duration(milliseconds: playMs + 1500), _finish);
      if (!controller.isAnimating) controller.forward(from: 0);
    });
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
    // SVGAAnimationController.dispose() releases its videoItem (autorelease).
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildFallbackImage() {
    final url = widget.gift.image?.addBaseURL() ?? '';
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
                width: 300,
                height: 300,
                child: _svgaReady && !_svgaFailed && _controller != null
                    ? SVGAImage(_controller!, fit: BoxFit.contain)
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
