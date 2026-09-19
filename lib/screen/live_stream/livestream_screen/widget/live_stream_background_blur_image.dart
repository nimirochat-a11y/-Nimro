import 'dart:ui';

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/color_res.dart';

class LiveStreamBlurBackgroundImage extends StatelessWidget {
  const LiveStreamBlurBackgroundImage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: Get.width,
      height: Get.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF050505), Color(0xFF151515)]
              : const [Color(0xFFF7F9FC), ColorRes.whitePure],
        ),
      ),
      child: isDark
          ? ClipSmoothRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(AssetRes.icBattleView, fit: BoxFit.cover),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 160, sigmaY: 160),
                    child: Container(color: Colors.black.withValues(alpha: .35)),
                  ),
                ],
              ),
            )
          : Container(color: ColorRes.themeAccentSolid.withValues(alpha: .025)),
    );
  }
}
