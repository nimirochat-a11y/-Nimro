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
    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            ...TabType.values.map((tabType) => Obx(() {
                  final isSelected = controller.selectedReelCategory.value == tabType;
                  return _buildTab(
                    context,
                    title: tabType.title,
                    isSelected: isSelected,
                    onTap: () => controller.onTabTypeChanged(tabType),
                  );
                })),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context,
      {required String title, required VoidCallback onTap, bool isSelected = false}) {
    final foreground = isSelected ? whitePure(context) : whitePure(context).withValues(alpha: .72);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
            style: TextStyleCustom.unboundedBold700(fontSize: 12, color: foreground),
          ),
        ),
      ),
    );
  }
}
