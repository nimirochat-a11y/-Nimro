import 'dart:ui';

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/widget/custom_image.dart';
import 'package:nimiro/common/widget/full_name_with_blue_tick.dart';
import 'package:nimiro/common/widget/gradient_text.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/livestream/livestream_user_state.dart';
import 'package:nimiro/screen/live_stream/livestream_screen/widget/live_stream_background_blur_image.dart';
import 'package:nimiro/utilities/style_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';
import 'package:nimiro/utilities/color_res.dart';

class LivestreamEndSheet extends StatelessWidget {
  final LivestreamUserState? userState;
  final VoidCallback? onTap;

  const LivestreamEndSheet({super.key, this.userState, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : ColorRes.textDarkGrey;
    final mutedText = isDark ? Colors.white70 : ColorRes.textLightGrey;
    return SizedBox(
      height: Get.height / 1.5,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaY: 10, sigmaX: 10),
        child: Stack(
          children: [
            const LiveStreamBlurBackgroundImage(),
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      CustomImage(
                          size: const Size(137, 137),
                          image: userState?.user?.profile?.addBaseURL(),
                          fullName: userState?.user?.fullname,
                          strokeColor: isDark ? Colors.white : ColorRes.themeAccentSolid,
                          strokeWidth: 6),
                      const SizedBox(height: 11),
                      FullNameWithBlueTick(
                        username: userState?.user?.fullname ?? 'Unknown',
                        fontSize: 14,
                        fontColor: primaryText,
                        isVerify: userState?.user?.isVerify,
                        iconSize: 18,
                      ),
                      Text(userState?.user?.fullname ?? 'unknown',
                          style: TextStyleCustom.outFitRegular400(
                              fontSize: 16, color: mutedText)),
                      Padding(
                        padding: const EdgeInsets.only(top: 30.0, bottom: 5),
                        child: Text(
                          LKey.streamEnded.tr,
                          style: TextStyleCustom.unboundedRegular400(
                              fontSize: 20, color: primaryText),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Get.back();
                      onTap?.call();
                    },
                    child: Container(
                      height: 57,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                          shape: SmoothRectangleBorder(
                              borderRadius: SmoothBorderRadius(
                                  cornerRadius: 10, cornerSmoothing: 1),
                              side: BorderSide.none),
                          color: ColorRes.whitePure),
                    child: GradientText(
                        LKey.getBack.tr,
                        gradient: StyleRes.themeGradient,
                        style: TextStyleCustom.unboundedMedium500(fontSize: 17),
                      ),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class BuildTextAndValueTiles extends StatelessWidget {
  final Widget? widget;
  final String title;
  final String value;

  const BuildTextAndValueTiles(
      {super.key, this.widget, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileText = (isDark ? Colors.white : ColorRes.textDarkGrey).withValues(alpha: .7);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: .5),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
      color: (isDark ? Colors.white : ColorRes.textDarkGrey).withValues(alpha: .04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyleCustom.outFitLight300(
                    color: tileText,
                    fontSize: 16),
              ),
              Text(
                value,
                style: TextStyleCustom.outFitMedium500(
                    color: tileText,
                    fontSize: 18),
              ),
            ],
          ),
          if (widget != null) widget!
        ],
      ),
    );
  }
}
