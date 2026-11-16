import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/navigation/navigate_with_controller.dart';
import 'package:nimiro/common/widget/custom_back_button.dart';
import 'package:nimiro/common/widget/custom_divider.dart';
import 'package:nimiro/common/widget/custom_image.dart';
import 'package:nimiro/common/widget/full_name_with_blue_tick.dart';
import 'package:nimiro/common/widget/load_more_widget.dart';
import 'package:nimiro/common/widget/loader_widget.dart';
import 'package:nimiro/common/widget/no_data_widget.dart';
import 'package:nimiro/common/widget/text_button_custom.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/follow_following_screen/follow_following_screen_controller.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

enum FollowFollowingType { follower, following }

class FollowFollowingScreen extends StatelessWidget {
  final FollowFollowingType type;
  final User? user;

  const FollowFollowingScreen({super.key, required this.type, this.user});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
        FollowFollowingScreenController(type, user, context),
        tag: '${user?.id}');
    return Scaffold(
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(color: bgLightGrey(context)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SafeArea(
              bottom: false,
              minimum: EdgeInsets.only(top: AppBar().preferredSize.height),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CustomBackButton(
                          width: 35,
                          height: 18,
                          alignment: AlignmentDirectional.centerStart),
                      CustomImage(
                        size: const Size(48, 48),
                        fullName: user?.fullname,
                        image: user?.profilePhoto?.addBaseURL(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FullNameWithBlueTick(
                                username: user?.fullname ?? '', fontSize: 13),
                            Text(user?.fullname ?? '',
                                style: TextStyleCustom.outFitLight300(
                                    color: textLightGrey(context),
                                    fontSize: 15))
                          ],
                        ),
                      )
                    ],
                  ),
                  Obx(
                    () => Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 12),
                      child: Text(
                        type == FollowFollowingType.follower
                            ? '${controller.followerCount.value} ${LKey.followers.tr}'
                            : '${controller.followingCount.value} ${LKey.following.tr}',
                        style: TextStyleCustom.outFitRegular400(
                            color: textDarkGrey(context), fontSize: 16),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final isFollowers = type == FollowFollowingType.follower;
              final users =
                  isFollowers ? controller.followers : controller.followings;
              final isLoading = isFollowers
                  ? controller.isFollowers.value
                  : controller.isFollowings.value;
              final isEmpty = users.isEmpty;

              return _buildUserList(
                showLoader: isLoading && isEmpty,
                showNoData: !isLoading && isEmpty,
                noDataTitle: !isFollowers && user?.showMyFollowing == 1
                    ? LKey.nothingToShowHere.tr
                    : null,
                noDataDescription: !isFollowers && user?.showMyFollowing == 1
                    ? LKey.userHidFollowings.tr
                    : null,
                users: users,
                userExtractor: isFollowers
                    ? (item) => item.fromUser
                    : (item) => item.toUser,
                onItemTap: controller.onFollowUnFollow,
                loadMore: isFollowers
                    ? controller.fetchFollowers
                    : controller.fetchFollowings,
                controller: isFollowers
                    ? controller.followerController
                    : controller.followingController,
              );
            }),
          )
        ],
      ),
    );
  }

  // Helper Widget
  Widget _buildUserList({
    required bool showLoader,
    required bool showNoData,
    required String? noDataTitle,
    required String? noDataDescription,
    required List<dynamic> users,
    required User? Function(dynamic) userExtractor,
    required Future Function(dynamic) onItemTap,
    required Future Function()? loadMore,
    required ScrollController controller,
  }) {
    if (showLoader) return const LoaderWidget();

    return NoDataView(
      showShow: showNoData,
      title: noDataTitle,
      description: noDataDescription,
      child: ListView.builder(
        controller: controller,
        itemCount: users.length,
        padding: const EdgeInsets.only(top: 10),
        itemBuilder: (context, index) {
          final item = users[index];
          final user = userExtractor(item);
          final isFollow =
              user?.isFollowing == null ? true : user?.isFollowing ?? false;

          // TikTok-style "Follow back": shown whenever the person follows the
          // current user but the current user does not follow them back.
          // On my own followers list everyone follows me, so any unfollowed
          // person is a follow-back candidate even if follow_status is absent.
          final isMyFollowerList = type == FollowFollowingType.follower &&
              this.user?.id?.toInt() == SessionManager.instance.getUserID();
          final showFollowBack =
              !isFollow && (isMyFollowerList || user?.isFollowBack == true);

          return UserProfileTile(
            actionName: ActionName.follow,
            onTap: () => onItemTap(item),
            isFollowOrIsBlock: isFollow,
            showFollowBack: showFollowBack,
            user: user,
            loadMore: index == users.length - 1 ? loadMore : null,
          );
        },
      ),
    );
  }
}

enum ActionName { follow, block }

class UserProfileTile extends StatefulWidget {
  final ActionName actionName;
  final bool isFollowOrIsBlock;
  final bool showFollowBack;
  final Future Function() onTap;
  final User? user;
  final Future<void> Function()? loadMore;

  const UserProfileTile(
      {super.key,
      required this.actionName,
      required this.isFollowOrIsBlock,
      required this.onTap,
      this.showFollowBack = false,
      this.user,
      this.loadMore});

  @override
  State<UserProfileTile> createState() => _UserProfileTileState();
}

class _UserProfileTileState extends State<UserProfileTile> {
  RxBool isLoading = false.obs;

  @override
  Widget build(BuildContext context) {
    return LoadMoreWidget(
      loadMore: widget.loadMore ?? () async {},
      child: Padding(
        padding: const EdgeInsets.only(left: 10.0, right: 10.0, bottom: 10.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      NavigationService.shared.openProfileScreen(widget.user);
                    },
                    child: Row(
                      children: [
                        CustomImage(
                            size: const Size(40, 40),
                            fullName: widget.user?.fullname,
                            image: widget.user?.profilePhoto?.addBaseURL()),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FullNameWithBlueTick(
                                username: widget.user?.fullname ?? '',
                                isVerify: widget.user?.isVerify,
                                fontSize: 13,
                                iconSize: 14,
                              ),
                              Text(
                                widget.user?.fullname ?? '',
                                style: TextStyleCustom.outFitLight300(
                                    color: textLightGrey(context)),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.user?.id != SessionManager.instance.getUserID())
                  Obx(() {
                    Color textColor = widget.isFollowOrIsBlock
                        ? textLightGrey(context)
                        : whitePure(context);
                    return TextButtonCustom(
                      onTap: () async {
                        if (isLoading.value) return;
                        isLoading.value = true;
                        await widget.onTap();
                        isLoading.value = false;
                      },
                      title: widget.actionName == ActionName.follow
                          ? (widget.isFollowOrIsBlock
                              ? LKey.unFollow.tr
                              : widget.showFollowBack
                                  ? LKey.followBack.tr
                                  : LKey.follow.tr)
                          : (widget.isFollowOrIsBlock
                              ? LKey.unBlock.tr
                              : LKey.block.tr),
                      btnWidth: 100,
                      fontSize: 15,
                      horizontalMargin: 0,
                      btnHeight: 30,
                      titleColor: textColor,
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      radius: 8,
                      backgroundColor: widget.isFollowOrIsBlock
                          ? whitePure(context)
                          : blueFollow(context),
                      borderSide: widget.isFollowOrIsBlock
                          ? BorderSide(color: bgGrey(context))
                          : BorderSide.none,
                      child: isLoading.value
                          ? CupertinoActivityIndicator(
                              radius: 8, color: textColor)
                          : null,
                    );
                  })
              ],
            ),
            const SizedBox(height: 10),
            const CustomDivider()
          ],
        ),
      ),
    );
  }
}
