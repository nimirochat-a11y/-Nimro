import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/model/post_story/comment/fetch_comment_model.dart';
import 'package:nimiro/model/post_story/post_model.dart';
import 'package:nimiro/screen/comment_sheet/helper/comment_helper.dart';
import 'package:nimiro/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:nimiro/screen/profile_screen/profile_screen_controller.dart';
import 'package:nimiro/screen/profile_screen/widget/post_options_sheet.dart';
import 'package:nimiro/screen/reels_screen/reel/reel_page_controller.dart';
import 'package:nimiro/screen/report_sheet/report_sheet.dart';

class ReelsScreenController extends BaseController {
  static const String tag = "REEL";
  PageController pageController = PageController();

  final RxList<Post> reels;
  final RxInt currentIndex;
  final Future<void> Function()? onFetchMoreData;
  final bool isHomePage;

  final RxBool isRefreshing = false.obs;
  CommentHelper commentHelper = CommentHelper();

  ReelsScreenController({required this.reels,
    required this.currentIndex,
    this.onFetchMoreData,
    this.isHomePage = false});

  @override
  void onInit() {
    super.onInit();
    pageController = PageController(initialPage: currentIndex.value);
  }

  @override
  void onReady() {
    super.onReady();
    initFirstPlayers();
  }

  /// Initialize first two players
  Future<void> initFirstPlayers() async {
    isLoading.value = true;
    if (reels.length <= 1) {
      await onFetchMoreData?.call();
    }

    if (reels.length - 1 == currentIndex.value) {
      await onFetchMoreData?.call();
    }
    isLoading.value = false;
  }

  /// Handle page change
  Future<void> onPageChanged(int index) async {
    currentIndex.value = index;
    // Fetch more data if near end
    if (index >= reels.length - 3) {
      onFetchMoreData?.call();
    }
  }

  bool isCurrentPageVisible = true;

  /// Handle refresh logic
  Future<void> handleRefresh(Future<void> Function()? onRefresh) async {
    if (isRefreshing.value) return;
    isRefreshing.value = true;

    await Future.delayed(const Duration(milliseconds: 100));
    await onRefresh?.call();
    await Future.delayed(const Duration(milliseconds: 200));

    if (reels.isNotEmpty) {
      currentIndex.value = 0;
      pageController.jumpToPage(0);
    }

    isRefreshing.value = false;
    update();
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }

  void onReportTap() {
    Get.bottomSheet(
        ReportSheet(reportType: ReportType.post, id: reels[currentIndex.value].id?.toInt()),
        isScrollControlled: true);
  }

  void onUpdateComment(Comment comment, bool isReplyComment) {
    final post = reels.firstWhereOrNull((e) => e.id == comment.postId);
    if (post == null) {
      return Loggers.error('Post not found');
    }
    final controllerTag = post.id.toString();
    if (Get.isRegistered<ReelController>(tag: controllerTag)) {
      Get.find<ReelController>(tag: controllerTag)
          .reelData
          .update((val) => val?.updateCommentCount(1));
    }
  }

  void openPostOptionsSheet() {
    const tag = ProfileScreenController.tag;

    final controller = Get.isRegistered<ProfileScreenController>(tag: tag)
        ? Get.find<ProfileScreenController>(tag: tag)
        : Get.put(ProfileScreenController(SessionManager.instance.getUser().obs, (user) {}),
            tag: tag);

    Get.bottomSheet(
        PostOptionsSheet(
          controller: controller,
          onChanged: (type) {
            if (type == PublishType.goLive) {
              Future.delayed(
                const Duration(seconds: 1),
                () {
                  final controller = Get.find<DashboardScreenController>();
                  controller.onChanged(2);
                },
              );
            }
          },
        ),
        isScrollControlled: true);
  }

  onUpdateReelData(Post reel) {
    final index = reels.indexWhere((element) => element.id == reel.id);
    if (index != -1) {
      reels[index] = reel;
      update();
    }
  }
}
