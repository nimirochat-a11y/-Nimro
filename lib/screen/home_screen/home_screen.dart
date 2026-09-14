import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/home_screen/home_screen_controller.dart';
import 'package:nimiro/screen/live_stream/live_stream_search_screen/live_stream_search_screen.dart';
import 'package:nimiro/screen/reels_screen/reels_screen.dart';
import 'package:nimiro/utilities/app_res.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeScreenController());
    return Scaffold(
      backgroundColor: blackPure(context),
      body: Stack(
        children: [
          ReelsScreen(
            isHomePage: true,
            reels: controller.reels,
            position: 0,
            isLoading: controller.isLoading,
            onFetchMoreData: () => controller.onRefreshPage(reset: false),
            widget: HomeTopCenterWidget(controller: controller),
            onRefresh: controller.onRefreshPage,
          ),
          HomeTopCenterWidget(controller: controller),
        ],
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
            _buildTab(
              context,
              title: LKey.livestreams.tr,
              icon: AssetRes.icLive,
              onTap: () => Get.to(() => const LiveStreamSearchScreen()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context,
      {required String title, required VoidCallback onTap, bool isSelected = false, String? icon}) {
    final foreground = isSelected ? whitePure(context) : whitePure(context).withValues(alpha: .72);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: ShapeDecoration(
            color: isSelected ? themeAccentSolid(context) : Colors.white.withValues(alpha: .12),
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(cornerRadius: 22, cornerSmoothing: 1),
              side: BorderSide(color: Colors.white.withValues(alpha: isSelected ? .35 : .18)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Image.asset(icon, color: foreground, height: 18, width: 18),
                const SizedBox(width: 6),
              ],
              Text(title.toUpperCase(),
                  style: TextStyleCustom.unboundedBold700(fontSize: 11, color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color strokeColor;
  final PaintingStyle paintingStyle;
  final double strokeWidth;

  TrianglePainter({this.strokeColor = Colors.black, this.strokeWidth = 3, this.paintingStyle = PaintingStyle.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = paintingStyle;

    canvas.drawPath(getTrianglePath(size.width, size.height), paint);
  }

  Path getTrianglePath(double x, double y) {
    return Path()
      ..moveTo(0, y)
      ..lineTo(x / 2, 0)
      ..lineTo(x, y)
      ..lineTo(0, y);
  }

  @override
  bool shouldRepaint(TrianglePainter oldDelegate) {
    return oldDelegate.strokeColor != strokeColor ||
        oldDelegate.paintingStyle != paintingStyle ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
