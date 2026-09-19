import 'dart:ui';

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/common_extension.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/widget/custom_image.dart';
import 'package:nimiro/common/widget/custom_search_text_field.dart';
import 'package:nimiro/common/widget/full_name_with_blue_tick.dart';
import 'package:nimiro/common/widget/loader_widget.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/livestream/app_user.dart';
import 'package:nimiro/model/livestream/livestream.dart';
import 'package:nimiro/screen/live_stream/live_stream_search_screen/live_stream_search_screen_controller.dart';
import 'package:nimiro/screen/live_stream/livestream_screen/widget/live_stream_background_blur_image.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class LiveStreamSearchScreen extends StatelessWidget {
  const LiveStreamSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LiveStreamSearchScreenController());
    return Stack(
      children: [
        const LiveStreamBlurBackgroundImage(),
        Column(
          children: [
            SafeArea(
              bottom: false,
              child: CustomSearchTextField(
                onChanged: controller.onSearchChange,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: .12)
                    : ColorRes.bgLightGrey,
                borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: .22)
                        : ColorRes.bgGrey),
              ),
            ),
            LiveStreamListView(controller: controller),
          ],
        ),
      ],
    );
  }
}

class LiveStreamListView extends StatelessWidget {
  final LiveStreamSearchScreenController controller;

  const LiveStreamListView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    Widget _buildBlurredBackground(AppUser? hostUser) {
      return Stack(
        children: [
          CustomImage(
            size: Size(Get.width, Get.height),
            radius: 0,
            image: hostUser?.profile?.addBaseURL(),
            fullName: hostUser?.fullname,
          ),
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: blackPure(context).withValues(alpha: .5)),
            ),
          )
        ],
      );
    }

    Widget _buildImageContain({List<AppUser> allUsers = const [], int userCount = 0, bool isBattleOn = false}) {
      if (allUsers.isEmpty) return const SizedBox();

      // FIX(v13): `userCount` is derived from the room's participant rows while
      // `allUsers` is built from the host + co-host ids. When those disagree -
      // a co-host id with no matching user, a stale participant row, a room
      // whose co-host list never resolved - the branches below indexed past the
      // end of the list. That threw a RangeError which took down the entire live
      // grid, so live rooms appeared not to work at all. Never index past the
      // list: render the branch that matches what we actually have.
      final safeUserCount = userCount > allUsers.length ? allUsers.length : userCount;

      return Container(
          height: 310 / 2.4,
          alignment: Alignment.center,
          child: switch (safeUserCount) {
            2 => SizedBox(
                width: double.infinity,
                child: LayoutBuilder(builder: (context, constraints) {
                  double imageSize = constraints.maxWidth / 2;
                  return Stack(
                    children: [
                      Positioned(
                        left: 10,
                        top: 0,
                        bottom: 0,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: CustomImage(
                              size: Size(imageSize, imageSize),
                              image: allUsers.first.profile?.addBaseURL(),
                              fullName: allUsers.first.fullname,
                              strokeWidth: 2,
                              strokeColor: whitePure(context).withValues(alpha: .55)),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 0,
                        bottom: 0,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: CustomImage(
                            size: Size(imageSize, imageSize),
                            image: allUsers[1].profile?.addBaseURL(),
                            fullName: allUsers[1].fullname,
                            strokeWidth: 2,
                            strokeColor: whitePure(context).withValues(alpha: .55),
                          ),
                        ),
                      ),
                      if (isBattleOn)
                        Align(
                          alignment: Alignment.center,
                          child: Image.asset(AssetRes.icBattleVs, height: 60, width: 60),
                        )
                    ],
                  );
                }),
              ),
            3 => SizedBox(
                width: double.infinity,
                child: LayoutBuilder(builder: (context, constraints) {
                  double maxWidth = constraints.maxWidth;
                  double imageSize = maxWidth / 1.7;
                  double smallImageSize = maxWidth / 2.7;
                  return Stack(
                    children: [
                      Align(
                        alignment: AlignmentDirectional.topCenter,
                        child: CustomImage(
                          size: Size(imageSize, imageSize),
                          image: allUsers.first.profile?.addBaseURL(),
                          fullName: allUsers.first.fullname,
                          strokeWidth: 2,
                          strokeColor: whitePure(context).withValues(alpha: .55),
                        ),
                      ),
                      Positioned(
                        left: 30,
                        top: 0,
                        bottom: 0,
                        child: Align(
                          alignment: AlignmentDirectional.bottomStart,
                          child: CustomImage(
                            size: Size(smallImageSize, smallImageSize),
                            image: allUsers[1].profile?.addBaseURL(),
                            fullName: allUsers[1].fullname,
                            strokeWidth: 2,
                            strokeColor: whitePure(context).withValues(alpha: .55),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 30,
                        top: 0,
                        bottom: 0,
                        child: Align(
                          alignment: AlignmentDirectional.bottomEnd,
                          child: CustomImage(
                            size: Size(smallImageSize, smallImageSize),
                            image: allUsers[2].profile?.addBaseURL(),
                            fullName: allUsers[2].fullname,
                            strokeWidth: 2,
                            strokeColor: whitePure(context).withValues(alpha: .55),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            4 => SizedBox(
                width: double.infinity,
                child: LayoutBuilder(builder: (context, constraints) {
                  double maxWidth = constraints.maxWidth;
                  double imageSize = maxWidth / 1.7;
                  double smallImageSize = maxWidth / 2.7;
                  return Stack(
                    children: [
                      Align(
                        alignment: AlignmentDirectional.topCenter,
                        child: CustomImage(
                          size: Size(imageSize, imageSize),
                          image: allUsers.first.profile?.addBaseURL(),
                          fullName: allUsers.first.fullname,
                          strokeWidth: 2,
                          strokeColor: whitePure(context).withValues(alpha: .55),
                        ),
                      ),
                      Positioned(
                        left: 5,
                        top: 0,
                        bottom: 0,
                        child: Align(
                          alignment: AlignmentDirectional.bottomStart,
                          child: CustomImage(
                            size: Size(smallImageSize, smallImageSize),
                            image: allUsers[1].profile?.addBaseURL(),
                            fullName: allUsers[1].fullname,
                            strokeWidth: 2,
                            strokeColor: whitePure(context).withValues(alpha: .55),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Align(
                          alignment: AlignmentDirectional.bottomCenter,
                          child: CustomImage(
                            size: Size(smallImageSize, smallImageSize),
                            image: allUsers[2].profile?.addBaseURL(),
                            fullName: allUsers[2].fullname,
                            strokeWidth: 2,
                            strokeColor: whitePure(context).withValues(alpha: .55),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 5,
                        top: 0,
                        bottom: 0,
                        child: Align(
                          alignment: AlignmentDirectional.bottomEnd,
                          child: CustomImage(
                            size: Size(smallImageSize, smallImageSize),
                            image: allUsers[3].profile?.addBaseURL(),
                            fullName: allUsers[3].fullname,
                            strokeWidth: 2,
                            strokeColor: whitePure(context).withValues(alpha: .55),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            1 => CustomImage(
                size: Size(Get.width / 3, Get.width / 3),
                image: allUsers.first.profile?.addBaseURL(),
                fullName: allUsers.first.fullname,
                strokeWidth: 2,
                strokeColor: whitePure(context).withValues(alpha: .55),
              ),
            _ => const SizedBox()
          });
    }

    Widget _buildUserInfo(AppUser? hostUser, int watchingCount) {
      return Column(
        spacing: 5,
        children: [
          if (hostUser != null)
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                  color: whitePure(context).withValues(alpha: .15),
                  borderRadius: SmoothBorderRadius(cornerRadius: 30),
                  border: Border.all(color: whitePure(context).withValues(alpha: .15))),
              child: FullNameWithBlueTick(
                  username: hostUser.fullname,
                  isVerify: hostUser.isVerify,
                  iconSize: 16,
                  icon: AssetRes.icVerifiedWhite,
                  style: TextStyleCustom.outFitMedium500(color: whitePure(context), fontSize: 15)),
            ),
          Text(
            '${watchingCount.numberFormat} ${LKey.viewers.tr}',
            style: TextStyleCustom.outFitLight300(color: whitePure(context)),
          ),
        ],
      );
    }

    Widget _buildDescription(Livestream stream) {
      return Flexible(
          child: Text(stream.description ?? '',
              style: TextStyleCustom.outFitSemiBold600(color: whitePure(context), fontSize: 19),
              maxLines: 3,
              overflow: TextOverflow.ellipsis));
    }

    Widget _buildGridItem(Livestream stream) {
      return Obx(() {
        AppUser? hostUser = stream.getHostUser(controller.firebaseFirestoreController.users);

        List<AppUser> allUsers = stream.getAllUsers(controller.firebaseFirestoreController.users);
        bool isBattleOn = stream.type == LivestreamType.battle;
        int userCount = allUsers.length;
        int count = stream.watchingCount ?? 0;
        int watchingCount = count >= 0 ? count : 0;

        return Stack(
          children: [
            _buildBlurredBackground(hostUser),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildImageContain(allUsers: allUsers, isBattleOn: isBattleOn, userCount: userCount),
                  _buildUserInfo(hostUser, watchingCount),
                  _buildDescription(stream),
                ],
              ),
            ),
          ],
        );
      });
    }

    return Expanded(
      child: Obx(
        () {
          return controller.isLoading.value && controller.livestreamFilterList.isEmpty
              ? const LoaderWidget()
              : Stack(
                  children: [
                    if (!controller.isLoading.value &&
                        controller.livestreamFilterList.isEmpty)
                      LiveStreamEmptyState(
                        error: controller.liveStreamError.value,
                        onRetry: controller.fetchLiveStreams,
                      ),
                    GridView.builder(
                    itemCount: controller.livestreamFilterList.length,
                    padding: EdgeInsets.only(bottom: AppBar().preferredSize.height),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, crossAxisSpacing: 1, mainAxisSpacing: 1, mainAxisExtent: 310),
                    itemBuilder: (context, index) {
                      Livestream stream = controller.livestreamFilterList[index];
                      return InkWell(onTap: () => controller.onLiveUserTap(stream), child: _buildGridItem(stream));
                    },
                    ),
                  ],
                );
        },
      ),
    );
  }
}

class LiveStreamEmptyState extends StatelessWidget {
  final String error;
  final Future<void> Function() onRetry;

  const LiveStreamEmptyState({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = error.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(hasError ? Icons.wifi_off_rounded : Icons.videocam_off_rounded,
                size: 46,
                color: isDark ? Colors.white70 : ColorRes.textDarkGrey),
            const SizedBox(height: 14),
            Text(
              hasError ? 'Live streams unavailable' : LKey.noLivestreamsTitle.tr,
              style: TextStyleCustom.unboundedSemiBold600(
                color: isDark ? Colors.white : ColorRes.textDarkGrey,
                fontSize: 17,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 7),
            Text(
              hasError ? error : LKey.noLivestreamsDescription.tr,
              style: TextStyleCustom.outFitRegular400(
                color: isDark ? Colors.white70 : ColorRes.textLightGrey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasError) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: () => onRetry(), child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
