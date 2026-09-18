import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/common_extension.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/manager/share_manager.dart';
import 'package:nimiro/common/widget/custom_image.dart';
import 'package:nimiro/common/widget/custom_popup_menu_button.dart';
import 'package:nimiro/common/widget/full_name_with_blue_tick.dart';
import 'package:nimiro/common/widget/gradient_border.dart';
import 'package:nimiro/common/widget/text_button_custom.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/edit_profile_screen/edit_profile_screen.dart';
import 'package:nimiro/screen/follow_following_screen/follow_following_screen.dart';
import 'package:nimiro/screen/level_screen/level_screen.dart';
import 'package:nimiro/screen/profile_screen/profile_screen_controller.dart';
import 'package:nimiro/screen/profile_screen/widget/profile_cover.dart';
import 'package:nimiro/screen/profile_screen/widget/profile_preview_interactive_screen.dart';
import 'package:nimiro/screen/profile_screen/widget/user_link_sheet.dart';
import 'package:nimiro/screen/settings_screen/settings_screen.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/style_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

/// Vertical rhythm for the whole profile header.
///
/// One scale, used everywhere, so the spacing stops being arbitrary numbers
/// chosen per widget. Nothing here is a magic value.
class _Sp {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;

  /// Corner radius for every card / button on this screen.
  static const double radius = 14;
}

/// The profile header: cover, avatar, identity, stats, link, bio, actions.
///
/// Rendered top-to-bottom in the order the design calls for. All content
/// colours come from `theme_res.dart`, so the light theme stays readable and a
/// future theme change needs no edit here.
class ProfileUserHeader extends StatelessWidget {
  final ProfileScreenController controller;

  /// When false no back control is painted over the cover (e.g. when the
  /// profile is a tab rather than a pushed route).
  final bool isTopBarVisible;

  const ProfileUserHeader({
    super.key,
    required this.controller,
    this.isTopBarVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final User? user = controller.userData.value;
        final bool isUserNotFound = controller.isUserNotFound.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileCover(
              user: user,
              overlayActions: [
                if (isTopBarVisible)
                  CoverOverlayButton(
                    icon: AssetRes.icBackArrow,
                    onTap: () => controller.adsController
                        .showInterstitialAdIfAvailable(),
                  ),
              ],
              // No camera affordance: `tbl_users` has no cover column and there
              // is no cover upload endpoint, so offering one would promise an
              // edit that cannot happen. The widget supports it — flip this to
              // `isMe && !isUserNotFound` the day cover uploads exist.
              showEditHint: false,
              onTapEditCover: () => Get.to(
                () => EditProfileScreen(onUpdateUser: controller.onUpdateUser),
              ),
              avatar: isUserNotFound
                  ? Image.asset(
                      AssetRes.icUserPlaceholder,
                      width: ProfileCover.avatarDiameter,
                      height: ProfileCover.avatarDiameter,
                      fit: BoxFit.cover,
                    )
                  : ProfileAvatarView(user: user, controller: controller),
            ),
            if (!isUserNotFound)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    _Sp.s20, _Sp.s12, _Sp.s20, 0),
                child: UserNameView(user: user),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  _Sp.s20, _Sp.s16, _Sp.s20, 0),
              child: ProfileStatsRow(
                stats: [
                  StatItem(
                      value: user?.totalPostLikesCount ?? 0,
                      label: LKey.likes.tr),
                  StatItem(
                      value: user?.followerCount ?? 0,
                      label: LKey.followers.tr),
                  StatItem(
                      value: user?.followingCount ?? 0,
                      label: LKey.following.tr),
                ],
                onTap: (value) {
                  if (isUserNotFound) {
                    return;
                  }
                  switch (value) {
                    case 0:
                      break;
                    case 1:
                      user?.checkIsBlocked(() {
                        Get.to(() => FollowFollowingScreen(
                            type: FollowFollowingType.follower, user: user));
                      });
                      break;
                    case 2:
                      user?.checkIsBlocked(() {
                        Get.to(() => FollowFollowingScreen(
                            type: FollowFollowingType.following, user: user));
                      });
                      break;
                  }
                },
              ),
            ),
            if (!isUserNotFound)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    _Sp.s20, _Sp.s12, _Sp.s20, 0),
                child: UserLinkView(user: user),
              ),
            if (!isUserNotFound)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    _Sp.s20, _Sp.s8, _Sp.s20, 0),
                child: UserBioView(user: user),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  _Sp.s20, _Sp.s16, _Sp.s20, _Sp.s20),
              child: isUserNotFound
                  ? const NoUserFoundButton()
                  : UserButtonView(user: user, controller: controller),
            ),
          ],
        );
      },
    );
  }
}

/// Avatar straddling the cover's lower edge, with the story ring and the
/// long-press preview that already existed. The Hero tag is unchanged
/// (`profile-<id>`) so it still pairs with ProfilePreviewInteractiveScreen.
class ProfileAvatarView extends StatelessWidget {
  final User? user;
  final ProfileScreenController controller;

  const ProfileAvatarView({
    super.key,
    required this.user,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    const double size = ProfileCover.avatarDiameter;
    final bool isStoryAvailable = (user?.stories ?? []).isNotEmpty;
    final bool isWatch = isStoryAvailable &&
        (user?.stories ?? []).every((element) => element.isWatchedByMe());
    final RxBool isHeroEnable = false.obs;
    final GlobalKey previewKey = GlobalKey();

    return GestureDetector(
      onTap: () => controller.onStoryTap(isStoryAvailable),
      onLongPressStart: (details) {
        isHeroEnable.value = true;
      },
      onLongPressEnd: (details) {
        isHeroEnable.value = false;
      },
      onLongPress: () {
        user?.checkIsBlocked(() {
          Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              barrierColor: Colors.transparent,
              transitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (_, __, ___) =>
                  ProfilePreviewInteractiveScreen(user: user),
            ),
          );
        });
      },
      child: Container(
        key: previewKey,
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(cornerRadius: 90),
          ),
          gradient: isStoryAvailable
              ? (isWatch
                  ? StyleRes.disabledGreyGradient(opacity: .5)
                  : StyleRes.themeGradient)
              : null,
        ),
        child: Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: whitePure(context),
          ),
          child: Obx(
            () => HeroMode(
              enabled: isHeroEnable.value,
              child: Hero(
                tag: 'profile-${user?.id}',
                // if user is blocked then don't show the image
                child: CustomImage(
                  size: !isStoryAvailable
                      ? const Size(size, size)
                      : const Size(size - 10, size - 10),
                  image:
                      user?.isBlock == true ? '' : user?.profilePhoto?.addBaseURL(),
                  fullName: user?.fullname,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The three counters as three EQUAL columns, separated by hairline dividers.
class ProfileStatsRow extends StatelessWidget {
  final List<StatItem> stats;
  final Function(int value) onTap;

  const ProfileStatsRow({
    super.key,
    required this.stats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(stats.length, (index) {
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  borderRadius: BorderRadius.circular(_Sp.radius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: _Sp.s8),
                    child: StatColumn(
                      value: stats[index].value,
                      label: stats[index].label,
                    ),
                  ),
                ),
              ),
              if (index != stats.length - 1)
                Container(
                  height: 30,
                  width: .5,
                  color: textLightGrey(context).withValues(alpha: .45),
                ),
            ],
          ),
        );
      }),
    );
  }
}

/// Individual stat column: value on top, label underneath. Also used by the
/// live-stream audience sheet, which overrides both text styles for its own
/// always-dark surface — hence the optional style parameters.
class StatColumn extends StatelessWidget {
  final num value;
  final String label;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const StatColumn({
    super.key,
    required this.value,
    required this.label,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toInt().numberFormat,
          style: valueStyle ??
              TextStyleCustom.unboundedMedium500(
                color: textDarkGrey(context),
                fontSize: 16,
              ),
        ),
        const SizedBox(height: _Sp.s4),
        Text(
          label.capitalize ?? '',
          style: labelStyle ??
              TextStyleCustom.outFitLight300(
                color: textLightGrey(context),
                fontSize: 13,
              ),
        ),
      ],
    );
  }
}

/// Name + handle.
///
/// FIX(v15): the name used to be rendered TWICE — once inside
/// `FullNameWithBlueTick` and again immediately below it. That second line is
/// now the handle, which is what the design calls for and removes the
/// duplicate.
class UserNameView extends StatelessWidget {
  final User? user;

  const UserNameView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FullNameWithBlueTick(
          username: user?.fullname,
          style: TextStyleCustom.unboundedSemiBold600(
              color: textDarkGrey(context), fontSize: 18),
          isVerify: user?.isVerify,
          iconSize: 22,
          child: user?.getLevel.id == null
              ? const SizedBox()
              : GradientBorder(
                  onPressed: () {
                    Get.to(() => LevelScreen(userLevels: user?.getLevel));
                  },
                  strokeWidth: 1.5,
                  radius: 30,
                  gradient: StyleRes.themeGradient,
                  child: Container(
                    height: 27,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      borderRadius: SmoothBorderRadius(cornerRadius: 30),
                      color: themeAccentSolid(context).withValues(alpha: .1),
                    ),
                    alignment: Alignment.center,
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => StyleRes
                          .themeGradient
                          .createShader(Rect.fromLTWH(
                              0, 0, bounds.width, bounds.height)),
                      child: RichText(
                        text: TextSpan(
                          text: LKey.lvl.tr,
                          style: TextStyleCustom.outFitLight300(fontSize: 15),
                          children: [
                            TextSpan(
                              text: ' ${user?.getLevel.level ?? 0}',
                              style: TextStyleCustom.outFitBold700(fontSize: 15),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        if ((user?.username ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: _Sp.s4),
            child: Text(
              '@${user?.username}',
              style: TextStyleCustom.outFitRegular400(
                  color: textLightGrey(context), fontSize: 14),
            ),
          ),
      ],
    );
  }
}

class UserLinkView extends StatelessWidget {
  final User? user;

  const UserLinkView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    List<Link> links = user?.links ?? [];
    if (links.isEmpty) {
      return const SizedBox();
    }
    return InkWell(
      onTap: () {
        user?.checkIsBlocked(() {
          if (links.length > 1) {
            Get.bottomSheet(
              UserLinkSheet(links: links),
              isScrollControlled: true,
              barrierColor: blackPure(context).withValues(alpha: .7),
            );
          } else {
            (links.first.url ?? '').lunchUrlWithHttps;
          }
        });
      },
      borderRadius: BorderRadius.circular(_Sp.radius),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AssetRes.icLink,
              height: 18, width: 18, color: themeAccentSolid(context)),
          const SizedBox(width: _Sp.s4),
          Expanded(
            child: Text(
              shortUrl,
              style: TextStyleCustom.outFitRegular400(
                  fontSize: 15, color: themeAccentSolid(context)),
            ),
          ),
        ],
      ),
    );
  }

  String get shortUrl {
    List<Link> links = user?.links ?? [];
    String firstLink = links.first.url ?? '';
    String andMore = '';
    if (firstLink.length >= 40) {
      int endCount = links.length > 1 ? 25 : 35;
      firstLink = '${firstLink.substring(0, endCount)}...';
    }
    if (links.length > 1) {
      andMore = ' & ${links.length - 1} ${LKey.more.tr.toLowerCase()}';
    }
    return '$firstLink$andMore';
  }
}

class UserBioView extends StatelessWidget {
  final User? user;

  const UserBioView({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if ((user?.bio ?? '').isEmpty) {
      return const SizedBox();
    }
    return Text(
      user?.bio ?? '',
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyleCustom.outFitLight300(
          color: textLightGrey(context), fontSize: 15),
    );
  }
}

class UserButtonView extends StatelessWidget {
  final User? user;
  final ProfileScreenController controller;

  const UserButtonView({
    super.key,
    required this.user,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    User? user = controller.profileController.user;

    bool isMe = user?.id?.toInt() == SessionManager.instance.getUserID();
    bool isBlock =
        (user?.isBlock == true && user?.id != SessionManager.instance.getUserID());
    return Row(
      children: [
        Expanded(
          child: isBlock
              ? UnblockButton(onTap: () => controller.toggleBlockUnblock(true))
              : RowButton(controller: controller, isMe: isMe, user: user),
        ),
        const SizedBox(width: _Sp.s8),
        // Owner: share. Anyone else: the block / report / freeze menu.
        if (isMe)
          InkWell(
            onTap: () {
              ShareManager.shared
                  .showCustomShareSheet(user: user, keys: ShareKeys.user);
            },
            borderRadius: BorderRadius.circular(_Sp.radius),
            child: Container(
              height: 48,
              width: 48,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius(
                      cornerRadius: _Sp.radius, cornerSmoothing: 1),
                ),
                color: bgGrey(context),
              ),
              child: Image.asset(AssetRes.icShare1, height: 20, width: 20),
            ),
          )
        else
          Obx(
            () => CustomPopupMenuButton(
              items: [
                MenuItem(user?.isBlock == true ? LKey.unBlock.tr : LKey.block.tr,
                    () {
                  controller.toggleBlockUnblock(user?.isBlock ?? false);
                }),
                MenuItem(LKey.report.tr, () => controller.reportUser(user)),
                if (SessionManager.instance.isModerator.value == 1)
                  MenuItem(
                      user?.isFreez == 1 ? LKey.unFreeze.tr : LKey.freeze.tr,
                      () => controller.freezeUnfreezeUser(user?.isFreez == 1))
              ],
              child: Container(
                height: 48,
                width: 48,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  shape: SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius(
                        cornerRadius: _Sp.radius, cornerSmoothing: 1),
                  ),
                  color: bgGrey(context),
                ),
                child: Image.asset(AssetRes.icMore, height: 20, width: 20),
              ),
            ),
          ),
      ],
    );
  }
}

class NoUserFoundButton extends StatelessWidget {
  const NoUserFoundButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButtonCustom(
      onTap: () {},
      title: LKey.userNotFound.tr,
      btnHeight: 48,
      backgroundColor: bgMediumGrey(context),
      fontSize: 15,
      radius: _Sp.radius,
      titleColor: textLightGrey(context),
      horizontalMargin: 0,
    );
  }
}

class UnblockButton extends StatelessWidget {
  final VoidCallback onTap;

  const UnblockButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButtonCustom(
      onTap: onTap,
      title: LKey.unBlock.tr,
      fontSize: 16,
      backgroundColor: blueFollow(context),
      titleColor: whitePure(context),
      horizontalMargin: 0,
      btnHeight: 48,
      radius: _Sp.radius,
    );
  }
}

class RowButton extends StatelessWidget {
  final bool isMe;
  final ProfileScreenController controller;
  final User? user;

  const RowButton({
    super.key,
    required this.isMe,
    required this.controller,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Obx(
            () {
              bool isFollowProgress = controller.isFollowUnFollowInProcess.value;
              Color textColor = user?.isFollowing == true
                  ? textLightGrey(context)
                  : whitePure(context);
              return TextButtonCustom(
                onTap: () async {
                  if (isMe) {
                    Get.to(() => SettingsScreen(
                        onUpdateUser: controller.onUpdateUser));
                  } else {
                    if (!isFollowProgress) {
                      controller.followUnFollowUser();
                    }
                  }
                },
                title: isMe
                    ? LKey.settings.tr
                    : (user?.isFollowing == true
                        ? LKey.unFollow.tr
                        : LKey.follow.tr),
                fontSize: 16,
                backgroundColor: isMe
                    ? bgGrey(context)
                    : (user?.isFollowing == true
                        ? bgGrey(context)
                        : blueFollow(context)),
                titleColor: isMe ? textLightGrey(context) : textColor,
                horizontalMargin: 0,
                btnHeight: 48,
                radius: _Sp.radius,
                child: isMe
                    ? null
                    : isFollowProgress
                        ? CupertinoActivityIndicator(radius: 10, color: textColor)
                        : null,
              );
            },
          ),
        ),
        const SizedBox(width: _Sp.s8),
        if (isMe || user?.receiveMessage == 1)
          Expanded(
            child: TextButtonCustom(
              onTap: () => controller.handlePublishOrMessageBtn(isMe),
              title: isMe ? LKey.publish.tr : LKey.message.tr,
              fontSize: 16,
              backgroundColor: bgGrey(context),
              titleColor: textLightGrey(context),
              horizontalMargin: 0,
              btnHeight: 48,
              radius: _Sp.radius,
            ),
          ),
      ],
    );
  }
}

/// Stat Item Model
class StatItem {
  final num value;
  final String label;

  StatItem({required this.value, required this.label});
}
