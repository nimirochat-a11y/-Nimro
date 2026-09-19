import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/widget/custom_app_bar.dart';
import 'package:nimiro/common/widget/custom_drop_down.dart';
import 'package:nimiro/common/widget/custom_toggle.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/settings_screen/settings_screen_controller.dart';
import 'package:nimiro/screen/settings_screen/widget/notifications_page.dart';
import 'package:nimiro/screen/settings_screen/widget/setting_icon_text_with_arrow.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsScreenController>();
    return Scaffold(
        body: Column(
      children: [
        CustomAppBar(title: LKey.privacy.tr),
        Expanded(
            child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: AppBar().preferredSize.height),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
            ],
          ),
        ))
      ],
    ));
  }
}
