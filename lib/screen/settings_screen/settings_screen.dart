import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/widget/custom_app_bar.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/settings_screen/settings_screen_controller.dart';
import 'package:nimiro/screen/settings_screen/widget/general_settings_screen.dart';
import 'package:nimiro/screen/settings_screen/widget/personal_settings_screen.dart';
import 'package:nimiro/screen/settings_screen/widget/privacy_settings_screen.dart';
import 'package:nimiro/screen/settings_screen/widget/setting_icon_text_with_arrow.dart';
import 'package:nimiro/utilities/asset_res.dart';

class SettingsScreen extends StatelessWidget {
  final Function(User? user)? onUpdateUser;
  const SettingsScreen({super.key, this.onUpdateUser});
  @override
  Widget build(BuildContext context) {
    Get.put(SettingsScreenController());
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
              SettingIconTextWithArrow(
                icon: AssetRes.icEdit,
                title: LKey.personal,
                onTap: () {
                  Get.to(() =>
                      PersonalSettingsScreen(onUpdateUser: onUpdateUser));
                },
              ),
              SettingIconTextWithArrow(
                icon: AssetRes.icEye_1,
                title: LKey.privacy,
                onTap: () {
                  Get.to(() => const PrivacySettingsScreen());
                },
              ),
              SettingIconTextWithArrow(
                icon: AssetRes.icReport,
                title: LKey.general,
                onTap: () {
                  Get.to(() => const GeneralSettingsScreen());
                },
              ),
            ],
          ),
        ))
      ],
    ));
  }
}
