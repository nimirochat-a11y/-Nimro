import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:proste_indexed_stack/proste_indexed_stack.dart';
import 'package:nimiro/common/widget/banner_ads_custom.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:nimiro/screen/explore_screen/explore_screen.dart';
import 'package:nimiro/screen/feed_screen/feed_screen.dart';
import 'package:nimiro/screen/home_screen/home_screen.dart';
import 'package:nimiro/screen/profile_screen/profile_screen.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class DashboardScreen extends StatelessWidget {
  final User? myUser;

  const DashboardScreen({super.key, this.myUser});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DashboardScreenController());
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor(context),
      resizeToAvoidBottomInset: true,
      body: Obx(() {
        return Column(
          children: [
            Expanded(
              child: ProsteIndexedStack(
                index: controller.contentPageIndex,
                children: [
                  IndexedStackChild(child: FeedScreen(myUser: myUser), preload: true),
                  IndexedStackChild(child: const HomeScreen(), preload: false),
                  IndexedStackChild(child: const ExploreScreen(), preload: true),
                  IndexedStackChild(
                      child: ProfileScreen(isDashBoard: false, user: myUser,
                          isTopBarVisible: false),
                      preload: true)
                ],
              ),
            ),
            if (controller.selectedPageIndex.value != 0)
              const BannerAdsCustom(),
          ],
        );
      }),
      bottomNavigationBar: _buildBottomNavigationBar(context, controller),
    );
  }

  Widget _buildBottomNavigationBar(
      BuildContext context, DashboardScreenController controller) {
    return Obx(() {
      PostUploadingProgress postUpload = controller.postProgress.value;
      bool isPostUploading =
          postUpload.uploadType == UploadType.none ? false : true;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
              scaffoldBackgroundColor(context),
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: .55)),
          ),
        ),
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(
                controller.bottomIconList.length,
                (index) {
                  return _buildBottomNavItem(
                      context, controller, index, isPostUploading);
                },
              ),
            ),
            SafeArea(
              top: false,
              bottom: isPostUploading ? true : false,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                height: isPostUploading ? 30 : 0,
                margin: Platform.isAndroid || !isPostUploading
                    ? EdgeInsets.zero
                    : const EdgeInsets.only(bottom: 20, top: 5),
                    color: scaffoldBackgroundColor(context),
                    child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 30,
                      color: themeAccentSolid(context).withValues(alpha: .9),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: LayoutBuilder(builder: (context, constraints) {
                        double progress = (constraints.maxWidth * postUpload.progress) / 100;
                        return AnimatedContainer(
                          height: 30,
                          width: constraints.maxWidth - progress,
                          duration: const Duration(milliseconds: 250),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.black.withValues(alpha: .28)
                                : Colors.white.withValues(alpha: .35),
                          ),
                        );
                      }),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (postUpload.uploadType != UploadType.error)
                            Text('${postUpload.progress.toInt()}%',
                                style: TextStyleCustom.outFitMedium500(
                                  color: whitePure(context),
                                  fontSize: 16,
                                )),
                          Text(' ${postUpload.uploadType.title(postUpload.type)}',
                              style: TextStyleCustom.outFitLight300(color: whitePure(context), fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      );
    });
  }

  Widget _buildBottomNavItem(BuildContext context,
      DashboardScreenController controller, int index, bool isPostUploading) {
    return Obx(() {
      final isSelected = controller.selectedPageIndex.value == index;
      final scaleValue = isSelected ? controller.scaleValue.value : 1.0;
      final selectedColor = themeAccentSolid(context);
      final inactiveColor = textLightGrey(context);

      return SafeArea(
        bottom: isPostUploading ? false : true,
        child: InkWell(
          onTap: () => controller.onChanged(index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 50,
            height: 46,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: isSelected ? selectedColor.withValues(alpha: .12) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedScale(
              scale: scaleValue,
              duration: const Duration(milliseconds: 300),
              child: Stack(
                alignment: Alignment.center,
                  children: [
                  if (index == 2)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : textDarkGrey(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 25,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black
                            : Colors.white,
                      ),
                    )
                  else if (index == 3)
                    Icon(
                      Icons.search_rounded,
                      size: 28,
                      color: isSelected ? selectedColor : inactiveColor,
                    )
                  else
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        isSelected ? selectedColor : inactiveColor,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(controller.bottomIconList[index], height: 27, width: 27),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

}
