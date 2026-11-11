import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/service/location/location_service.dart';
import 'package:nimiro/languages/languages_keys.dart';
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
      body: Obx(() {
        final isNearby =
            controller.selectedReelCategory.value == TabType.nearby;
        return ReelsScreen(
          isHomePage: true,
          reels: controller.reels,
          position: 0,
          isLoading: controller.isLoading,
          onFetchMoreData: () => controller.onRefreshPage(reset: false),
          widget: HomeTopCenterWidget(controller: controller),
          onRefresh: controller.onRefreshPage,
          emptyTitle: isNearby ? LKey.noNearbyReelsTitle.tr : null,
          emptyDescription: isNearby ? _nearbyDescription(controller) : null,
        );
      }),
    );
  }

  String _nearbyDescription(HomeScreenController controller) {
    switch (controller.nearbyFailure.value) {
      case LocationFailureReason.permissionDenied:
        return LKey.nearbyPermissionDeniedDescription.tr;
      case LocationFailureReason.permissionDeniedForever:
        return LKey.nearbyPermissionForeverDescription.tr;
      case LocationFailureReason.serviceDisabled:
        return LKey.nearbyServiceDisabledDescription.tr;
      case LocationFailureReason.timeout:
        return LKey.nearbyTimeoutDescription.tr;
      case LocationFailureReason.unavailable:
        return LKey.nearbyUnavailableDescription.tr;
      case null:
        return LKey.noNearbyReelsDescription.tr;
    }
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
                  final isSelected =
                      controller.selectedReelCategory.value == tabType;
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
      {required String title,
      required VoidCallback onTap,
      bool isSelected = false}) {
    final foreground = isSelected
        ? whitePure(context)
        : whitePure(context).withValues(alpha: .72);
    // Same treatment as the feed tabs (v1.1.32): a short rounded pill that
    // sits right under the label. The reels screen has a black background, so
    // the hard accent blue (#237BFF) is replaced by a softer light blue.
    const indicatorColor = Color(0xFF5FA0FF);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 42,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyleCustom.unboundedBold700(
                    fontSize: 12, color: foreground),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 3,
                width: isSelected ? 20 : 0,
                decoration: BoxDecoration(
                  color: isSelected ? indicatorColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
