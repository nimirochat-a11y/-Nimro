import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/widget/custom_app_bar.dart';
import 'package:nimiro/common/widget/custom_drop_down.dart';
import 'package:nimiro/common/widget/custom_toggle.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/blocked_user_screen/blocked_user_screen.dart';
import 'package:nimiro/screen/coin_wallet_screen/coin_wallet_screen.dart';
import 'package:nimiro/screen/saved_post_screen/saved_post_screen.dart';
import 'package:nimiro/screen/select_language_screen/select_language_screen.dart';
import 'package:nimiro/screen/settings_screen/settings_screen_controller.dart';
import 'package:nimiro/screen/settings_screen/widget/notifications_page.dart';
import 'package:nimiro/screen/settings_screen/widget/settings_tile.dart';
import 'package:nimiro/screen/term_and_privacy_screen/term_and_privacy_screen.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

/// REDESIGN(v17): sectioned card layout with subtitles, colored icon badges
/// and a hero wallet card - matches the new settings mockup.
class SettingsScreen extends StatelessWidget {
  final Function(User? user)? onUpdateUser;
  const SettingsScreen({super.key, this.onUpdateUser});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsScreenController());
    return Scaffold(
        body: Column(
      children: [
        CustomAppBar(title: LKey.settings.tr),
        Expanded(
            child: SingleChildScrollView(
          padding: EdgeInsets.only(
              top: 8, bottom: AppBar().preferredSize.height),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero wallet card.
              SettingsGroup(
                backgroundColor:
                    themeAccentSolid(context).withValues(alpha: .08),
                children: [
                  SettingsTile(
                    icon: Icons.account_balance_wallet_rounded,
                    title: LKey.coinWallet,
                    subtitle: 'Manage your balance and purchases',
                    onTap: () {
                      Get.to(() => const CoinWalletScreen());
                    },
                  ),
                ],
              ),

              // Personal.
              SettingsGroup(
                children: [
                  SettingsTile(
                    icon: Icons.bookmark_rounded,
                    title: LKey.savedPosts,
                    subtitle: 'View posts you have saved',
                    onTap: () {
                      Get.to(() => const SavedPostScreen());
                    },
                  ),
                  SettingsTile(
                    icon: Icons.block_rounded,
                    title: LKey.blockedUsers,
                    subtitle: 'Manage your blocked users list',
                    onTap: () {
                      Get.to(() => const BlockedUserScreen());
                    },
                  ),
                  SettingsTile(
                    icon: Icons.translate_rounded,
                    title: LKey.languages,
                    subtitle: 'Choose your preferred language',
                    onTap: () {
                      Get.to(() => const SelectLanguageScreen(
                          languageNavigationType:
                              LanguageNavigationType.fromSetting));
                    },
                  ),
                ],
              ),

              // Privacy.
              SettingsGroup(
                children: [
                  Obx(
                    () => SettingsTile(
                      icon: Icons.groups_rounded,
                      title: LKey.whoCanSeePosts,
                      subtitle: 'Control who can see your posts',
                      trailing: CustomDropDownBtn<WhoCanSeePost>(
                        items: WhoCanSeePost.values,
                        onChanged: controller.isUpdateApiCalled.value
                            ? null
                            : controller.onChangedWhoCanSeePost,
                        selectedValue: controller.selectedWhoCanSeePost.value,
                        style: TextStyleCustom.outFitRegular400(
                            fontSize: 13, color: textLightGrey(context)),
                        getTitle: (value) => value.title,
                      ),
                    ),
                  ),
                  Obx(
                    () => SettingsTile(
                      icon: Icons.person_rounded,
                      title: LKey.showMyFollowings,
                      subtitle: 'Allow others to see who you follow',
                      trailing: CustomToggle(
                        isOn: (controller.myUser.value?.showMyFollowing == 1)
                            .obs,
                        onChanged: (value) {
                          controller.onChangedToggle(
                              value, SettingToggle.showMyFollowings);
                        },
                      ),
                    ),
                  ),
                  Obx(
                    () => SettingsTile(
                      icon: Icons.chat_bubble_rounded,
                      title: LKey.showChatBtn,
                      subtitle: 'Show the chat button on your profile',
                      trailing: CustomToggle(
                        isOn:
                            (controller.myUser.value?.receiveMessage == 1)
                                .obs,
                        onChanged: (value) async {
                          controller.onChangedToggle(
                              value, SettingToggle.receiveMessage);
                        },
                      ),
                    ),
                  ),
                ],
              ),

              // Notifications.
              SettingsGroup(
                children: [
                  SettingsTile(
                    icon: Icons.notifications_rounded,
                    title: LKey.notifications,
                    subtitle: 'Manage your alerts and preferences',
                    onTap: () {
                      Get.to(() => const NotificationsPage());
                    },
                  ),
                ],
              ),

              // General.
              SettingsGroup(
                children: [
                  SettingsTile(
                    icon: Icons.description_rounded,
                    title: LKey.termsOfUse,
                    subtitle: "Read the app's terms of use",
                    onTap: () {
                      Get.to(() => const TermAndPrivacyScreen(
                          type: TermAndPrivacyType.termAndCondition));
                    },
                  ),
                  SettingsTile(
                    icon: Icons.shield_rounded,
                    title: LKey.privacyPolicy,
                    subtitle: 'Learn how your data is protected',
                    onTap: () {
                      Get.to(() => const TermAndPrivacyScreen(
                          type: TermAndPrivacyType.privacyPolicy));
                    },
                  ),
                ],
              ),

              // Account actions - destructive, last.
              SettingsGroup(
                backgroundColor: ColorRes.likeRed.withValues(alpha: .06),
                children: [
                  SettingsTile(
                    icon: Icons.logout_rounded,
                    title: LKey.logOut,
                    subtitle: 'Sign out of your current account',
                    onTap: controller.onLogout,
                    isDestructive: true,
                    trailing: const SizedBox(),
                  ),
                  SettingsTile(
                    icon: Icons.delete_rounded,
                    title: LKey.deleteAccount,
                    subtitle: 'All your data will be permanently deleted',
                    onTap: controller.onDeleteAccount,
                    isDestructive: true,
                    trailing: const SizedBox(),
                  ),
                ],
              ),
            ],
          ),
        ))
      ],
    ));
  }
}
