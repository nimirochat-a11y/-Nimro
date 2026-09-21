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
import 'package:nimiro/screen/settings_screen/widget/setting_icon_text_with_arrow.dart';
import 'package:nimiro/screen/term_and_privacy_screen/term_and_privacy_screen.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

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
          padding: EdgeInsets.only(bottom: AppBar().preferredSize.height),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Personal
              SettingIconTextWithArrow(
                icon: AssetRes.icWallet,
                title: LKey.coinWallet,
                onTap: () {
                  Get.to(() => const CoinWalletScreen());
                },
              ),
              SettingIconTextWithArrow(
                icon: AssetRes.icPostBookmark,
                title: LKey.savedPosts,
                onTap: () {
                  Get.to(() => const SavedPostScreen());
                },
              ),
              SettingIconTextWithArrow(
                icon: AssetRes.icBlock,
                title: LKey.blockedUsers,
                onTap: () {
                  Get.to(() => const BlockedUserScreen());
                },
              ),
              SettingIconTextWithArrow(
                icon: AssetRes.icLanguage_1,
                title: LKey.languages,
                onTap: () {
                  Get.to(() => const SelectLanguageScreen(
                      languageNavigationType:
                          LanguageNavigationType.fromSetting));
                },
              ),
              // Privacy
              Obx(
                () => SettingIconTextWithArrow(
                  icon: AssetRes.icEye_1,
                  title: LKey.whoCanSeePosts,
                  widget: CustomDropDownBtn<WhoCanSeePost>(
                    items: WhoCanSeePost.values,
                    onChanged: controller.isUpdateApiCalled.value
                        ? null
                        : controller.onChangedWhoCanSeePost,
                    selectedValue: controller.selectedWhoCanSeePost.value,
                    style: TextStyleCustom.outFitRegular400(
                        fontSize: 15, color: textLightGrey(context)),
                    getTitle: (value) => value.title,
                  ),
                ),
              ),
              Obx(
                () {
                  return SettingIconTextWithArrow(
                    icon: AssetRes.icEye_1,
                    title: LKey.showMyFollowings,
                    widget: CustomToggle(
                      isOn: (controller.myUser.value?.showMyFollowing == 1).obs,
                      onChanged: (value) {
                        controller.onChangedToggle(
                            value, SettingToggle.showMyFollowings);
                      },
                    ),
                  );
                },
              ),
              Obx(
                () {
                  return SettingIconTextWithArrow(
                    icon: AssetRes.icMessage,
                    title: LKey.showChatBtn,
                    widget: CustomToggle(
                      isOn: (controller.myUser.value?.receiveMessage == 1).obs,
                      onChanged: (value) async {
                        controller.onChangedToggle(
                            value, SettingToggle.receiveMessage);
                      },
                    ),
                  );
                },
              ),
              SettingIconTextWithArrow(
                icon: AssetRes.icNotification_1,
                title: LKey.notifications,
                onTap: () {
                  Get.to(() => const NotificationsPage());
                },
              ),
              // General
              SettingIconTextWithArrow(
                icon: AssetRes.icReport,
                title: LKey.termsOfUse,
                onTap: () {
                  Get.to(() => const TermAndPrivacyScreen(
                      type: TermAndPrivacyType.termAndCondition));
                },
              ),
              SettingIconTextWithArrow(
                icon: AssetRes.icReport,
                title: LKey.privacyPolicy,
                onTap: () {
                  Get.to(() => const TermAndPrivacyScreen(
                      type: TermAndPrivacyType.privacyPolicy));
                },
              ),
              // Account actions - last, and destructive action last of all
              SettingIconTextWithArrow(
                icon: AssetRes.icLogout,
                title: LKey.logOut,
                onTap: controller.onLogout,
                widget: const SizedBox(),
              ),
              SettingIconTextWithArrow(
                icon: AssetRes.icDelete2,
                title: LKey.deleteAccount,
                onTap: controller.onDeleteAccount,
                widget: const SizedBox(),
              ),
            ],
          ),
        ))
      ],
    ));
  }
}
