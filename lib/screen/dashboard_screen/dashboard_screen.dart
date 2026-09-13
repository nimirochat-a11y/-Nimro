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
import 'package:nimiro/screen/live_stream/live_stream_search_screen/live_stream_search_screen.dart';
import 'package:nimiro/screen/message_screen/message_screen.dart';
import 'package:nimiro/screen/profile_screen/profile_screen.dart';
import 'package:nimiro/utilities/style_res.dart';
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
                index: controller.selectedPageIndex.value,
                children: [
                  IndexedStackChild(child: FeedScreen(myUser: myUser), preload: true),
                  IndexedStackChild(child: const HomeScreen(), preload: true),
                  IndexedStackChild(child: const LiveStreamSearchScreen(), preload: true),
                  IndexedStackChild(child: const ExploreScreen(), preload: true),
                  IndexedStackChild(child: const MessageScreen(), preload: true),
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
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF071326)
              : const Color(0xFF0B1D3A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, -5)),
          ],
        ),
        padding: const EdgeInsets.only(top: 9),
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
                color: Colors.white,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(height: 30, decoration: BoxDecoration(gradient: StyleRes.themeGradient)),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: LayoutBuilder(builder: (context, constraints) {
                        double progress = (constraints.maxWidth * postUpload.progress) / 100;
                        return AnimatedContainer(
                          height: 30,
                          width: constraints.maxWidth - progress,
                          duration: const Duration(milliseconds: 250),
                          decoration: BoxDecoration(color: textDarkGrey(context)),
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

      return SafeArea(
        bottom: isPostUploading ? false : true,
        child: InkWell(
          onTap: () => controller.onChanged(index),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 50,
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              gradient: isSelected ? StyleRes.themeGradient : null,
              color: isSelected ? null : Colors.white.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? Colors.white.withValues(alpha: .35) : Colors.transparent,
              ),
            ),
            child: AnimatedScale(
              scale: scaleValue,
              duration: const Duration(milliseconds: 300),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      isSelected ? Colors.white : Colors.white70,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(controller.bottomIconList[index], height: 30, width: 30),
                  ),
                  if (index == 4) _buildUnreadCount(controller, context),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildUnreadCount(
      DashboardScreenController controller, BuildContext context) {
    return Obx(() {
      final count = controller.unReadCount.value;
      return count > 0
          ? Text(count > 9 ? '9+' : '$count',
              style: TextStyleCustom.outFitRegular400(
                  color: whitePure(context), fontSize: 12))
          : const SizedBox();
    });
  }
}
