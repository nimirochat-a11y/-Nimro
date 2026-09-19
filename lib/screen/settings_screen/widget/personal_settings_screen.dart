import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/widget/custom_app_bar.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/blocked_user_screen/blocked_user_screen.dart';
import 'package:nimiro/screen/coin_wallet_screen/coin_wallet_screen.dart';
import 'package:nimiro/screen/saved_post_screen/saved_post_screen.dart';
import 'package:nimiro/screen/select_language_screen/select_language_screen.dart';
import 'package:nimiro/screen/settings_screen/widget/setting_icon_text_with_arrow.dart';
import 'package:nimiro/utilities/asset_res.dart';

class PersonalSettingsScreen extends StatelessWidget {
  final Function(User? user)? onUpdateUser;
  const PersonalSettingsScreen({super.key, this.onUpdateUser});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
      children: [
        CustomAppBar(title: LKey.personal.tr),
        Expanded(
            child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: AppBar().preferredSize.height),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
SettingIconTextWithArrow(
                icon: AssetRes.icPostBookmark,
                title: LKey.savedPosts,
                onTap: () {
                  Get.to(() => const SavedPostScreen());
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
              SettingIconTextWithArrow(
                icon: AssetRes.icBlock,
                title: LKey.blockedUsers,
                onTap: () {
                  Get.to(() => const BlockedUserScreen());
                },
              ),
SettingIconTextWithArrow(
                icon: AssetRes.icWallet,
                title: LKey.coinWallet,
                onTap: () {
                  Get.to(() => const CoinWalletScreen());
                },
              ),
            ],
          ),
        ))
      ],
    ));
  }
}
