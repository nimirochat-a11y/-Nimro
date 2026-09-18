import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/profile_screen/profile_screen_controller.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

/// The two profile sections. Each tab shows its icon AND its label, so the
/// section is readable without having to recognise a glyph — the reference
/// design does the same. Colour comes from the app accent, and the indicator is
/// a single accent line under the active tab.
class ProfileTabs extends StatelessWidget {
  final ProfileScreenController controller;

  const ProfileTabs({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: .5, color: textLightGrey(context).withValues(alpha: .3)),
        TabBar(
          onTap: (value) {
            controller.userData.value?.checkIsBlocked(() {
              controller.onTabChanged(value);
              controller.pageController.animateToPage(value,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.linear);
            });
          },
          indicatorColor: themeAccentSolid(context),
          indicatorWeight: 2,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelPadding: EdgeInsets.zero,
          tabs: List.generate(2, (index) {
            return Obx(() {
              final bool selected = controller.selectedTabIndex.value == index;
              final Color color =
                  selected ? themeAccentSolid(context) : disableGrey(context);
              return Tab(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // index 0 = reels, 1 = posts
                    Image.asset(
                      index == 0 ? AssetRes.icReel : AssetRes.icPost,
                      height: 20,
                      width: 20,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      index == 0 ? LKey.reels.tr : LKey.posts.tr,
                      style: TextStyleCustom.outFitMedium500(
                          color: color, fontSize: 15),
                    ),
                  ],
                ),
              );
            });
          }),
        ),
        Container(height: .5, color: textLightGrey(context).withValues(alpha: .3)),
      ],
    );
  }
}
