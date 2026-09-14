import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/screen/home_screen/home_screen_controller.dart';
import 'package:nimiro/screen/reels_screen/reels_screen.dart';
import 'package:nimiro/utilities/app_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeScreenController());
    return Scaffold(
      backgroundColor: blackPure(context),
      body: ReelsScreen(
        isHomePage: true,
        reels: controller.reels,
        position: 0,
        isLoading: controller.isLoading,
        onFetchMoreData: () => controller.onRefreshPage(reset: false),
        widget: HomeTopCenterWidget(controller: controller),
        onRefresh: controller.onRefreshPage,
      ),
    );
  }
}

class HomeTopCenterWidget extends StatelessWidget {
  final HomeScreenController controller;

  const HomeTopCenterWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      width: 250,
      child: Obx(
        () => ListView.separated(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: TabType.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final tabType = TabType.values[index];
            final isSelected = controller.selectedReelCategory.value == tabType;
            return InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => controller.onTabTypeChanged(tabType),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? whitePure(context).withValues(alpha: .22) : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: whitePure(context).withValues(alpha: isSelected ? .65 : .28),
                  ),
                ),
                child: Text(
                  tabType.title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyleCustom.unboundedBold700(
                    fontSize: 11,
                    color: whitePure(context),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
