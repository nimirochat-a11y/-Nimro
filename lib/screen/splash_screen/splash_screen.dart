import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/screen/splash_screen/splash_screen_controller.dart';
import 'package:nimiro/utilities/asset_res.dart';

/// The first Flutter screen.
///
/// It deliberately starts as a pixel match of the Android 12+ system splash:
/// same background colour, same icon, same size and same position. The wordmark
/// then fades in underneath, so the hand-off from the OS splash to Flutter reads
/// as one continuous splash instead of two consecutive screens.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal;

  @override
  void initState() {
    super.initState();
    Get.put(SplashScreenController());
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    // Give the system splash a moment to hand over, then reveal the wordmark.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _reveal.forward();
      });
    });
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, _) => SplashArtwork(reveal: _reveal.value),
    );
  }
}

/// The splash artwork, separated from the startup controller so it can be
/// rendered deterministically (and tested) at any point of the reveal.
class SplashArtwork extends StatelessWidget {
  const SplashArtwork({super.key, required this.reveal});

  /// 0 = exactly the Android 12+ system splash, 1 = full Nimiro logo.
  final double reveal;

  /// Matches `nimiro_launch_background` / `ic_launcher_background` in
  /// android/app/src/main/res/values/ic_launcher_background.xml.
  static const Color background = Color(0xFF07152F);

  /// Android 12+ renders the adaptive icon's safe zone (66/108 of the 240dp
  /// splash canvas), which is ~147dp on the production device.
  static const double _systemIconSize = 147;

  /// Final branded size once the wordmark has been revealed.
  static const double _finalIconSize = 200;
  static const double _finalWordmarkWidth = 240;
  static const double _wordmarkGap = 10;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeInOutCubic.transform(reveal.clamp(0.0, 1.0));
    final wordmarkT = Curves.easeOutCubic.transform(
      ((reveal - .15) / .85).clamp(0.0, 1.0),
    );
    final iconSize = _systemIconSize + (_finalIconSize - _systemIconSize) * t;
    final wordmarkWidth = _finalWordmarkWidth * wordmarkT;
    final wordmarkHeight = wordmarkWidth * (324 / 1024);
    final gap = _wordmarkGap * wordmarkT;

    // The whole composition is centred. At t=0 the icon is exactly where the
    // system splash left it; it lifts only as the wordmark appears.
    final iconOffset = -(gap + wordmarkHeight) / 2;
    final wordmarkOffset = (iconSize + gap) / 2;

    return ColoredBox(
      color: background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(0, wordmarkOffset),
              child: Opacity(
                opacity: wordmarkT,
                child: Transform.translate(
                  offset: Offset(0, (1 - wordmarkT) * 12),
                  child: Image.asset(
                    AssetRes.nimiroWordmark,
                    width: wordmarkWidth,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(0, iconOffset),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(iconSize * .22),
                child: Image.asset(
                  AssetRes.nimiroSplashIcon,
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
