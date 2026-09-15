import 'dart:ui';

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/theme_res.dart';

class LiveStreamBlurBackgroundImage extends StatelessWidget {
  const LiveStreamBlurBackgroundImage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: Get.width,
      height: Get.height,
      color: scaffoldBackgroundColor(context),
      child: isDark
          ? ClipSmoothRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(AssetRes.icBattleView, fit: BoxFit.cover),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 160, sigmaY: 160),
                    child: Container(color: Colors.black.withValues(alpha: .25)),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
