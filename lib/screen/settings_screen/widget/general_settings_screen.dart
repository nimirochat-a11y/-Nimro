import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/widget/custom_app_bar.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/settings_screen/settings_screen_controller.dart';
import 'package:nimiro/screen/settings_screen/widget/setting_icon_text_with_arrow.dart';
import 'package:nimiro/screen/term_and_privacy_screen/term_and_privacy_screen.dart';
import 'package:nimiro/utilities/asset_res.dart';

class GeneralSettingsScreen extends StatelessWidget {
  const GeneralSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsScreenController>();
    return Scaffold(
        body: Column(
      children: [
        CustomAppBar(title: LKey.general.tr),
        Expanded(
            child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: AppBar().preferredSize.height),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
