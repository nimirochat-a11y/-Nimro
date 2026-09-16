import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:nimiro/screen/feed_screen/feed_screen_controller.dart';
import 'package:nimiro/screen/live_stream/live_stream_search_screen/live_stream_search_screen.dart';
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
          children: [
            Expanded(
              child: SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  children: [
                    ...const [PostCategory.discover, PostCategory.following, PostCategory.nearby]
                        .map((category) => Obx(() {
                          final isSelected = controller.selectedPostCategory.value == category;
                          return _CategoryTab(
                            title: category.title,
                            isSelected: isSelected,
                            onTap: () => controller.onChangeCategory(category),
                          );
                        })),
                    _CategoryTab(
                      title: LKey.livestreams.tr,
                      onTap: () => Get.to(() => const LiveStreamSearchScreen()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                _TopActionButton(
                  icon: AssetRes.icNotification,
                  count: SessionManager.instance.notifyCount,
                  onTap: () {
                    Get.to(() => const NotificationScreen());
                  },
                ),
                const SizedBox(width: 10),
                _TopActionButton(
                  icon: AssetRes.icChat,
                  count: Get.find<DashboardScreenController>().unReadCount,
                  onTap: () => Get.to(() => const MessageScreen()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTab({required this.title, required this.onTap, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? themeAccentSolid(context) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title.toUpperCase(),
          style: TextStyleCustom.unboundedBold700(
            color: isSelected ? textDarkGrey(context) : textLightGrey(context),
            fontSize: 12,
          ),
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
                Theme.of(context).brightness == Brightness.dark ? Colors.white : textDarkGrey(context),
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
