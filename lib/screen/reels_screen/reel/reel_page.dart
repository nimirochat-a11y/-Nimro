import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/manager/activity_tracker.dart';
import 'package:nimiro/common/service/api/post_service.dart';
import 'package:nimiro/common/widget/black_gradient_shadow.dart';
import 'package:nimiro/common/widget/double_tap_detector.dart';
import 'package:nimiro/model/post_story/post_by_id.dart';
import 'package:nimiro/model/post_story/post_model.dart';
import 'package:nimiro/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:nimiro/screen/reels_screen/reel/reel_page_controller.dart';
import 'package:nimiro/screen/reels_screen/reel/widget/reel_animation_like.dart';
import 'package:nimiro/screen/reels_screen/reel/widget/reel_seek_bar.dart';
import 'package:nimiro/screen/reels_screen/reel/widget/side_bar_list.dart';
import 'package:nimiro/screen/reels_screen/reel/widget/user_information.dart';
import 'package:nimiro/screen/reels_screen/reels_screen_controller.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/theme_res.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

// ---------------------------------------------------------------
// REEL PAGE
// ---------------------------------------------------------------
class ReelPage extends StatefulWidget {
  final Post reelData;
  final bool autoPlay;
  final PostByIdData? postByIdData;
  final bool isFromChat;
  final GlobalKey likeKey;
  final ReelsScreenController reelsScreenController;
  final Function(Post reel) onUpdateReelData;
  final bool isHomePage;

  const ReelPage(
      {super.key,
      required this.reelData,
      this.autoPlay = false,
      this.postByIdData,
      this.isFromChat = false,
      required this.likeKey,
      required this.reelsScreenController,
      required this.onUpdateReelData,
      required this.isHomePage});

  @override
  State<ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<ReelPage> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isDisposed = false;
  bool isPlaying = true;

  // --- For You ranking signals (phase 1) --------------------------------
  // One impression per appearance, total watch time across pauses, one
  // "complete" when >=92% of the reel was seen, and "skip" when the user
  // leaves before 2 seconds. These are analytics signals only: the public
  // view counter is still incremented once by _increaseViewsCount().
  DateTime? _watchSegmentStart;
  int _watchedSeconds = 0;
  bool _impressionLogged = false;
  bool _completeLogged = false;
  bool _visible = false;
  DateTime? _lastEmitAt;
  double _maxPositionFraction = 0;
  int _reelDurationSeconds = 0;

  late ReelController reelController;
  Rx<TapDownDetails?> details = Rx(null);
  final dashboardController = Get.find<DashboardScreenController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ✅ Setup Reel Controller
    if (Get.isRegistered<ReelController>(tag: '${widget.reelData.id}')) {
      reelController = Get.find<ReelController>(tag: '${widget.reelData.id}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!widget.isFromChat) {
          reelController.updateReelData(reel: widget.reelData);
        }
        reelController.notifyCommentSheet(widget.postByIdData);
      });
    } else {
      reelController = Get.put(
        ReelController(widget.reelData.obs, widget.onUpdateReelData),
        tag: '${widget.reelData.id}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        reelController.notifyCommentSheet(widget.postByIdData);
      });
    }

    _initializeAndPlayVideo();
  }

  Future<void> _initializeAndPlayVideo({int retryCount = 0}) async {
    if (_isDisposed) return;

    try {
      final url = Uri.parse(widget.reelData.video?.addBaseURL() ?? '');
      _controller = VideoPlayerController.networkUrl(url);

      await _controller!.initialize();

      if (_isDisposed) return;
      final durationSeconds = _controller!.value.duration.inSeconds;
      if (durationSeconds > 0) _reelDurationSeconds = durationSeconds;
      _controller!.setLooping(true);
      _controller!.addListener(_onVideoProgress);

      // FIX(v13): autoplay no longer waits for a "page visible" flag.
      // `isCurrentPageVisible` is only flipped by the reel-page observer, so a
      // reel opened from a notification, a profile or a shared link hit this
      // branch with the flag still false and sat paused on its first frame
      // until the user tapped it. Autoplay is now unconditional.
      if (widget.autoPlay) {
        await _controller!.play();
        _increaseViewsCount(widget.reelData);
        isPlaying = true;
      }

      setState(() {});
    } catch (e) {
      debugPrint('Video init error: $e');

      // 🔁 Retry if failed (max 3 retries with small delay)
      if (retryCount < 3 && !_isDisposed) {
        await Future.delayed(const Duration(milliseconds: 500));
        _initializeAndPlayVideo(retryCount: retryCount + 1);
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _endWatchSegment(emit: true);
    _controller?.removeListener(_onVideoProgress);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app mid-reel: keep the seconds already watched and report
    // them now, otherwise they would be lost when the process is killed.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _endWatchSegment(emit: true);
      // Send now: the process may be killed while in the background.
      ActivityTracker.instance.flushEvents(force: true);
    } else if (state == AppLifecycleState.resumed && _visible) {
      // The visibility fraction does not change when the app is resumed, so
      // start a fresh signal window explicitly for the reel still on screen.
      _logImpression();
      _startWatchSegment();
    }
  }

  // --- For You ranking signals (phase 1) --------------------------------
  void _startWatchSegment() {
    _watchSegmentStart ??= DateTime.now();
  }

  int get _currentWatchSeconds {
    final segment = _watchSegmentStart;
    if (segment == null) return _watchedSeconds;
    return _watchedSeconds + DateTime.now().difference(segment).inSeconds;
  }

  void _logImpression() {
    if (_impressionLogged) return;
    final reelId = widget.reelData.id;
    if ((reelId ?? 0) <= 0) return;
    // A page can bounce back into view for a moment while swiping; do not
    // count that as a second appearance.
    final lastEmit = _lastEmitAt;
    if (lastEmit != null &&
        DateTime.now().difference(lastEmit).inSeconds < 5) {
      return;
    }
    _impressionLogged = true;
    ActivityTracker.instance.addContentEvent(
        postId: reelId!,
        eventType: 'impression',
        durationSeconds: _reelDurationSeconds);
  }

  void _endWatchSegment({bool emit = false}) {
    final segment = _watchSegmentStart;
    if (segment != null) {
      _watchSegmentStart = null;
      final seconds = DateTime.now().difference(segment).inSeconds;
      if (seconds > 0) _watchedSeconds += seconds;
    }
    if (!emit) return;

    final reelId = widget.reelData.id;
    if ((reelId ?? 0) <= 0) return;

    // A page that was never actually shown (built as an off-screen neighbour
    // and then disposed) has nothing to report. Emitting here used to create
    // phantom "skip 0" events for reels the user never saw.
    if (!_impressionLogged && _watchedSeconds == 0) return;

    final watched = _watchedSeconds;
    _lastEmitAt = DateTime.now();

    if (watched >= 1) {
      ActivityTracker.instance.addContentEvent(
          postId: reelId!,
          eventType: 'view',
          watchSeconds: watched,
          durationSeconds: _reelDurationSeconds);
    }
    if (watched < 2) {
      ActivityTracker.instance.addContentEvent(
          postId: reelId!,
          eventType: 'skip',
          watchSeconds: watched,
          durationSeconds: _reelDurationSeconds);
    }

    // A new appearance starts a new signal window (rewatching the same reel
    // later is a fresh impression, not a continuation).
    _watchedSeconds = 0;
    _impressionLogged = false;
    _completeLogged = false;
    _maxPositionFraction = 0;
  }

  void _onVideoProgress() {
    final value = _controller?.value;
    if (value == null || !value.isInitialized) return;
    final totalMs = value.duration.inMilliseconds;
    if (totalMs <= 0) return;

    final fraction = value.position.inMilliseconds / totalMs;
    if (fraction > _maxPositionFraction) _maxPositionFraction = fraction;
    if (_reelDurationSeconds <= 0) {
      final seconds = value.duration.inSeconds;
      if (seconds > 0) _reelDurationSeconds = seconds;
    }

    if (_completeLogged || !_impressionLogged) return;
    if (_maxPositionFraction < 0.92) return;
    final watched = _currentWatchSeconds;
    if (watched < 2) return;

    _completeLogged = true;
    final reelId = widget.reelData.id;
    if ((reelId ?? 0) > 0) {
      ActivityTracker.instance.addContentEvent(
          postId: reelId!,
          eventType: 'complete',
          watchSeconds: watched,
          durationSeconds: _reelDurationSeconds);
    }
  }
  // ---------------------------------------------------------------------

  void _handleVisibilityChanged(VisibilityInfo info) {
    final double visible = info.visibleFraction * 100;
    final bool playerReady =
        _controller != null && _controller!.value.isInitialized;

    // FIX(v14): the old thresholds were `> 90` to play and `else` (i.e. ANY
    // fraction below 90) to pause. On first build the detector fires while the
    // page is still being laid out, so a reel could be played by autoplay and
    // then immediately paused by a sub-90% callback — the user saw a frozen
    // first frame and had to tap. Only a genuinely off-screen page pauses now.
    if (visible > 60) {
      _visible = true;
      _logImpression();
      _startWatchSegment();
      if (playerReady && !_controller!.value.isPlaying) {
        _controller!.play();
        isPlaying = true;
      }
    } else if (visible < 20) {
      _visible = false;
      _endWatchSegment(emit: true);
      if (playerReady && _controller!.value.isPlaying) {
        _controller!.pause();
        isPlaying = false;
      }
    } else {
      // Partially visible: keep whatever state the player is already in.
      return;
    }
    if (mounted) setState(() {});
  }

  void onPlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isPlaying) {
      _endWatchSegment();
      _controller!.pause();
      isPlaying = false;
    } else {
      _startWatchSegment();
      _controller!.play();
      isPlaying = true;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DoubleTapDetector(
      onDoubleTap: (value) {
        if (details.value != null) return;
        details.value = value;
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          /// 🎬 Directly play video (no thumbnail, no loader)
          if (_controller != null) buildContent(),

          /// 🕹 Tap Overlay (pause/play)
          InkWell(onTap: onPlayPause, child: const BlackGradientShadow()),

          /// ▶ Play/Pause Icon overlay
          if (_controller != null)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: isPlaying ? 0.0 : 1.0,
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  height: 60,
                  width: 60,
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  alignment: const Alignment(0.25, 0),
                  child: Image.asset(isPlaying ? AssetRes.icPause : AssetRes.icPlay,
                      width: 45, height: 45, color: bgGrey(context)),
                ),
              ),
            ),

          /// ℹ️ Reel Info Section
          ReelInfoSection(
            controller: reelController,
            likeKey: widget.likeKey,
            videoPlayerPlusController: _controller,
          ),

          /// 💖 Like Animation
          Obx(() {
            if (details.value == null) return const SizedBox();
            return ReelAnimationLike(
              likeKey: widget.likeKey,
              position: details.value!.globalPosition,
              size: const Size(50, 50),
              leftRightPosition: 8,
              onLikeCall: () {
                if (reelController.reelData.value.isLiked == true) return;
                reelController.onLikeTap();
              },
              onCompleteAnimation: () => details.value = null,
            );
          }),
        ],
      ),
    );
  }

  Widget buildContent() {
    Size size = _controller!.value.size;
    return VisibilityDetector(
      key: Key('reel_${widget.reelData.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: InkWell(
        onTap: onPlayPause,
        child: ClipRRect(
          child: SizedBox.expand(
            child: FittedBox(
              fit: (size.width < size.height) ? BoxFit.cover : BoxFit.fitWidth,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _increaseViewsCount(Post reelData) {
    PostService.instance.increaseViewsCount(postId: reelData.id).then((value) {
      if (value.status == true) {
        reelController.updateReelData(reel: reelData, isIncreaseCoin: true);
      }
    });
  }
}

class ReelInfoSection extends StatelessWidget {
  final ReelController controller;
  final GlobalKey likeKey;
  final VideoPlayerController? videoPlayerPlusController;

  const ReelInfoSection({super.key,
    required this.controller,
    required this.likeKey,
    required this.videoPlayerPlusController});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ReelInfoRow(controller: controller, likeKey: likeKey),
        ReelSeekBar(videoController: videoPlayerPlusController, controller: controller),
      ],
    );
  }
}

class ReelInfoRow extends StatelessWidget {
  final ReelController controller;
  final GlobalKey likeKey;

  const ReelInfoRow({super.key, required this.controller, required this.likeKey});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: UserInformation(controller: controller)),
        SideBarList(controller: controller, likeKey: likeKey),
      ],
    );
  }
}
