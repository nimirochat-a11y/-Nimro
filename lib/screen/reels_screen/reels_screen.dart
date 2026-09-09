import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/widget/my_refresh_indicator.dart';
import 'package:nimiro/common/widget/no_data_widget.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/post_story/post_by_id.dart';
import 'package:nimiro/model/post_story/post_model.dart';
import 'package:nimiro/screen/comment_sheet/widget/hashtag_and_mention_view.dart';
import 'package:nimiro/screen/reels_screen/reel/reel_page.dart';
import 'package:nimiro/screen/reels_screen/reels_screen_controller.dart';
import 'package:nimiro/screen/reels_screen/widget/reels_text_field.dart';
import 'package:nimiro/screen/reels_screen/widget/reels_top_bar.dart';
import 'package:nimiro/utilities/theme_res.dart';

// ---------------------------------------------------------------
// REELS SCREEN (PAGEVIEW)
// ---------------------------------------------------------------
class ReelsScreen extends StatefulWidget {
  final RxList<Post> reels;
  final int position;
  final Widget? widget;
  final Future<void> Function()? onFetchMoreData;
  final Future<void> Function()? onRefresh;
  final RxBool? isLoading;
  final PostByIdData? postByIdData;
  final bool isHomePage;
  final bool isFromChat;

  const ReelsScreen({
    super.key,
    required this.reels,
    required this.position,
    this.widget,
    this.onFetchMoreData,
    this.onRefresh,
    this.isLoading,
    this.postByIdData,
    this.isHomePage = false,
    this.isFromChat = false,
  });

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late final ReelsScreenController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
        ReelsScreenController(
          reels: widget.reels,
          currentIndex: widget.position.obs,
          onFetchMoreData: widget.onFetchMoreData,
          isHomePage: widget.isHomePage,
        ),
        tag: widget.isHomePage ? ReelsScreenController.tag : '${DateTime.now().millisecondsSinceEpoch}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackPure(context),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Expanded(
                child: MyRefreshIndicator(
                  onRefresh: () async {
                    await controller.handleRefresh(widget.onRefresh);
                  },
                  shouldRefresh: widget.onRefresh != null,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Obx(() {
                        final reels = widget.reels;
                        if (widget.isLoading?.value == true && reels.isEmpty) {
                          return Center(child: CupertinoActivityIndicator(color: textLightGrey(context)));
                        }
                        if (widget.isLoading?.value == false && reels.isEmpty) {
                          return NoDataWidgetWithScroll(
                              title: LKey.reelsEmptyTitle.tr, description: LKey.reelsEmptyDescription.tr);
                        }
                        return PageView.builder(
                          controller: controller.pageController,
                          physics: const CustomPageViewScrollPhysics(),
                          scrollDirection: Axis.vertical,
                          itemCount: reels.length,
                          onPageChanged: controller.onPageChanged,
                          itemBuilder: (context, index) {
                            return Obx(
                              () {
                                bool isLoading = controller.isLoading.value;
                                return isLoading
                                    ? Center(child: CupertinoActivityIndicator(color: textLightGrey(context)))
                                    : ReelPage(
                                        reelData: reels[index],
                                        autoPlay: index == controller.currentIndex.value,
                                        likeKey: GlobalKey(),
                                        reelsScreenController: controller,
                                        onUpdateReelData: controller.onUpdateReelData,
                                        isHomePage: widget.isHomePage);
                              },
                            );
                          },
                        );
                      }),
                      HashTagAndMentionUserView(helper: controller.commentHelper),
                    ],
                  ),
                ),
              ),
              ReelsTextField(controller: controller),
            ],
          ),
          ReelsTopBar(controller: controller, widget: widget.widget),
        ],
      ),
    );
  }
}

class CustomPageViewScrollPhysics extends ScrollPhysics {
  const CustomPageViewScrollPhysics({super.parent});

  @override
  CustomPageViewScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CustomPageViewScrollPhysics(parent: buildParent(ancestor)!);
  }

  @override
  SpringDescription get spring => const SpringDescription(mass: 1, stiffness: 1000, damping: 60);
}
