import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/widget/theme_blur_bg.dart';
import 'package:nimiro/screen/splash_screen/splash_screen_controller.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/theme_res.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(SplashScreenController());
    return Scaffold(
      body: Stack(
        children: [
          const ThemeBlurBg(),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 42),
              child: Image.asset(
                AssetRes.nimiroLogo,
                width: 290,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => Text(
                  'NIMIRO',
                  style: TextStyle(
                    color: whitePure(context),
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
