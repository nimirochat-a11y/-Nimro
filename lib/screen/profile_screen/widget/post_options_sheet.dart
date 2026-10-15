import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/widget/custom_divider.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/camera_screen/camera_screen.dart';
import 'package:nimiro/screen/create_feed_screen/create_feed_screen.dart';
import 'package:nimiro/screen/profile_screen/profile_screen_controller.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class PostOptionsSheet extends StatelessWidget {
  final ProfileScreenController? controller;
  final Function(PublishType type)? onChanged;

  const PostOptionsSheet({super.key, this.controller, this.onChanged});

  @override
  Widget build(BuildContext context) {
    List<PublishType> postOptions =
        PublishType.values.where((e) => e != PublishType.goLive).toList();
    return Wrap(
      children: [
        Container(
          decoration: ShapeDecoration(
              color: Theme.of(context).bottomSheetTheme.backgroundColor ??
                  scaffoldBackgroundColor(context),
              shape: const SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius.vertical(
                    top: SmoothRadius(cornerRadius: 30, cornerSmoothing: 1)),
              )),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const CustomDivider(
                    margin: EdgeInsets.symmetric(vertical: 10), width: 120),
                Column(
                  children: List.generate(
                    postOptions.length,
                    (index) {
                      PublishType data = postOptions[index];
                      return PostOptionIconWithText(
                          onTap: () {
                                Get.back();
                                onChanged?.call(data);
                            switch (data) {
                              case PublishType.feed:
                                Get.to(() => CreateFeedScreen(
                                    createType: CreateFeedType.feed,
                                    onAddPost: controller?.onAddPost));
                              case PublishType.story:
                                Get.to(() => const CameraScreen(cameraType: CameraScreenType.story));
                              case PublishType.reels:
                                Get.to(() => const CameraScreen(
                                    cameraType: CameraScreenType.post));
                              case PublishType.goLive:
                                break;
                            }
                          },
                          image: data.image,
                          text: data.title);
                    },
                  ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
}

class PostOptionIconWithText extends StatelessWidget {
  final String image;
  final String text;
  final VoidCallback onTap;

  const PostOptionIconWithText(
      {super.key,
      required this.image,
      required this.text,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10),
              child: Row(
                children: [
                  Image.asset(image,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : textDarkGrey(context),
                      height: 35,
                      width: 35),
                  const SizedBox(width: 20),
                  Expanded(
                      child: Text(
                    text,
                    style: TextStyleCustom.unboundedRegular400(
                        fontSize: 15,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : textDarkGrey(context)),
                  ))
                ],
              ),
            ),
          ),
          const CustomDivider()
        ],
      ),
    );
  }
}

enum PublishType {
  feed,
  story,
  reels,
  goLive;

  static const Map<PublishType, String> images = {
    PublishType.feed: AssetRes.icPost,
    PublishType.story: AssetRes.icStory,
    PublishType.reels: AssetRes.icReel,
    PublishType.goLive: AssetRes.icLive_1,
  };

  static Map<PublishType, String> titles = {
    PublishType.feed: LKey.feed.tr,
    PublishType.story: LKey.story.tr,
    PublishType.reels: LKey.reels.tr,
    PublishType.goLive: LKey.goLive.tr,
  };

  String get image => images[this]!;

  String get title => titles[this]!;
}
