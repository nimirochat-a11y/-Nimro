import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

/// Full-screen gift video viewer. Video gifts render their thumbnail in the
/// bubbles/grid with a play badge; tapping opens this lightweight player so
/// we never keep multiple video controllers alive at once.
class GiftMediaViewer extends StatefulWidget {
  final String videoUrl;

  const GiftMediaViewer({super.key, required this.videoUrl});

  static void open(BuildContext context, String videoUrl) {
    Get.to(() => GiftMediaViewer(videoUrl: videoUrl));
  }

  @override
  State<GiftMediaViewer> createState() => _GiftMediaViewerState();
}

class _GiftMediaViewerState extends State<GiftMediaViewer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _playing = true;

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    try {
      await controller.initialize();
      controller.setLooping(true);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _ready = true;
      });
    } catch (e) {
      await controller.dispose();
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!_ready && !_failed)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            if (_failed)
              const Center(
                child: Text(
                  'Could not play this video',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            if (_ready && _controller != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _playing = !_playing;
                    _playing
                        ? _controller!.play()
                        : _controller!.pause();
                  });
                },
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            if (_ready && !_playing)
              const Icon(Icons.play_circle_fill,
                  size: 72, color: Colors.white70),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Get.back(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black38,
                ),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
