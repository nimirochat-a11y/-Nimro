import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/widget/custom_popup_menu_button.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:nimiro/screen/feed_screen/feed_screen_controller.dart';
import 'package:nimiro/screen/message_screen/message_screen.dart';
import 'package:nimiro/screen/notification_screen/notification_screen.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class FeedTopView extends StatelessWidget {
  final FeedScreenController controller;

  const FeedTopView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scaffoldBackgroundColor(context),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CustomPopupMenuButton(
                items: [
                  MenuItem(LKey.discover.tr,
                      () => controller.onChangeCategory(PostCategory.discover)),
                  MenuItem(LKey.nearby.tr,
                      () => controller.onChangeCategory(PostCategory.nearby)),
                  MenuItem(
                      LKey.following.tr,
                      () =>
                          controller.onChangeCategory(PostCategory.following)),
                ],
                child: Obx(
                  () => Row(
                    children: [
                      Text(
                          controller.selectedPostCategory.value.title
                              .toUpperCase(),
                          style: TextStyleCustom.unboundedBold700(
                              color: textDarkGrey(context), fontSize: 15)),
                      const SizedBox(width: 3),
                      Image.asset(AssetRes.icDownArrow,
                          color: textDarkGrey(context), height: 8, width: 8),
                    ],
                  ),
                )),
            Row(
              children: [
                _TopActionButton(
                  icon: AssetRes.icNotification,
                  count: SessionManager.instance.notifyCount,
                  onTap: () {
                    Get.to(() => const NotificationScreen());
                    int count = SessionManager.instance.notifyCount.value;
                    SessionManager.instance.setNotifyCount(-count);
                    SessionManager.instance.notifyCount.value = 0;
                  },
                ),
                const SizedBox(width: 10),
                _TopActionButton(
                  icon: AssetRes.icChat,
                  count: Get.find<DashboardScreenController>().unReadCount,
                  onTap: () => Get.to(() => const MessageScreen()),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  final String icon;
  final RxInt count;
  final VoidCallback onTap;

  const _TopActionButton({required this.icon, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : textDarkGrey(context),
                BlendMode.srcIn,
              ),
              child: Image.asset(icon, width: 24, height: 24),
            ),
            Obx(() {
              final value = count.value;
              if (value <= 0) return const SizedBox();
              return Align(
                alignment: Alignment.topRight,
                child: Container(
                  height: 18,
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: themeAccentSolid(context), shape: BoxShape.circle),
                  child: Text(value > 9 ? '9+' : '$value',
                      style: TextStyleCustom.outFitRegular400(color: whitePure(context), fontSize: 11)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
