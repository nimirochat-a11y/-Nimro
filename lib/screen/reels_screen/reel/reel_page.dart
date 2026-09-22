import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
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
      // FIX(v12): default to autoplay. Reels that defaulted to `false` needed a
      // second tap before they would start, because the InkWell overlay above
      // the player swallowed the first one.
      this.autoPlay = true,
      this.postByIdData,
      this.isFromChat = false,
      required this.likeKey,
      required this.reelsScreenController,
      required this.onUpdateReelData,
      required this.isHomePage});

  @override
  State<ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<ReelPage> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _isDisposed = false;
  bool isPlaying = true;
  DateTime? _watchStartTime;
  late ReelController reelController;
  Rx<TapDownDetails?> details = Rx(null);
  final dashboardController = Get.find<DashboardScreenController>();

  @override
  void initState() {
    super.initState();

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
      _controller!.setLooping(true);
      _initialized = true;

      // FIX(v13): autoplay no longer waits for a "page visible" flag.
      // `isCurrentPageVisible` is only flipped by the reel-page observer, so a
      // reel opened from a notification, a profile or a shared link hit this
      // branch with the flag still false and sat paused on its first frame
      // until the user tapped it. Autoplay is now unconditional.
      if (widget.autoPlay) {
        await _controller!.play();
        isPlaying = true;
        if (dashboardController.selectedPageIndex.value == 0) {
          _increaseViewsCount(widget.reelData);
        }
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
    if (_watchStartTime != null) {
      final seconds = DateTime.now().difference(_watchStartTime!).inSeconds;
      if (seconds > 0) {
        PostService.instance.trackContentEvent(
          postId: widget.reelData.id ?? -1,
          eventType: 'view',
          watchSeconds: seconds,
        );
      }
    }
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!_initialized || _controller == null || !_controller!.value.isInitialized) return;

    if ((info.visibleFraction * 100) > 90) {
      if (!_controller!.value.isPlaying) {
        _controller!.play();
        isPlaying = true;
      }
    } else {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        isPlaying = false;
      }
    }
    setState(() {});
  }

  void onPlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    // FIX(v12): the first tap on a not-yet-started player used to be a no-op
    // because both branches toggled state that had not been set yet. Always
    // end up playing when the user taps a paused or never-started video.
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      isPlaying = false;
    } else {
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
    _watchStartTime = DateTime.now();
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
