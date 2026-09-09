import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/screen/splash_screen/splash_screen_controller.dart';
import 'package:nimiro/utilities/asset_res.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    Get.put(SplashScreenController());
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050B1A),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 + (_controller.value * .035);
          return Center(
            child: Transform.scale(
              scale: scale,
              child: Image.asset(
                AssetRes.nimiroLogo,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          );
        },
      ),
    );
  }
}
