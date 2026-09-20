import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/widget/custom_app_bar.dart';
import 'package:nimiro/common/widget/custom_image.dart';
import 'package:nimiro/common/widget/text_button_custom.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/edit_profile_screen/edit_profile_screen_controller.dart';
import 'package:nimiro/screen/edit_profile_screen/widget/build_link_view.dart';
import 'package:nimiro/screen/edit_profile_screen/widget/profile_field_card.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class EditProfileScreen extends StatelessWidget {
  final Function(User? user)? onUpdateUser;
  const EditProfileScreen({super.key, this.onUpdateUser});
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditProfileScreenController(onUpdateUser));
    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(title: LKey.editProfile.tr),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: bgLightGrey(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${LKey.userId.tr} : ${controller.userData.value?.id}',
                      style: TextStyleCustom.outFitLight300(
                          fontSize: 15, color: textLightGrey(context)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                    child: Text(LKey.profileImage.tr,
                        style: TextStyleCustom.outFitRegular400(
                            fontSize: 15, color: textLightGrey(context))),
                  ),
                  Container(
                    height: 100,
                    margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: bgLightGrey(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: AlignmentDirectional.centerStart,
                    child: InkWell(
                      onTap: controller.onChangeProfileImage,
                      child: Stack(
                        children: [
                          Obx(
                            () => controller.fileProfileImage.value != null
                                ? ClipOval(
                                    child: Image.file(
                                        File(controller
                                                .fileProfileImage.value?.path ??
                                            ''),
                                        height: 78,
                                        width: 78,
                                        fit: BoxFit.cover))
                                : CustomImage(
                                    size: const Size(78, 78),
                                    image: controller
                                        .userData.value?.profilePhoto
                                        ?.addBaseURL(),
                                    fullName:
                                        controller.userData.value?.fullname,
                                  ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: 26,
                              width: 26,
                              decoration: BoxDecoration(
                                  color: textDarkGrey(context),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: bgLightGrey(context), width: 2)),
                              child: Center(
                                child: Image.asset(AssetRes.icEdit_1,
                                    width: 20,
                                    height: 20,
                                    color: whitePure(context)),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                    child: Text(LKey.coverImage.tr,
                        style: TextStyleCustom.outFitRegular400(
                            fontSize: 15, color: textLightGrey(context))),
                  ),
                  Container(
                    height: 100,
                    margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: bgLightGrey(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: AlignmentDirectional.centerStart,
                    child: InkWell(
                      onTap: controller.onChangeCoverImage,
                      child: Stack(
                        children: [
                          Obx(
                            () => controller.fileCoverImage.value != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                        File(controller
                                            .fileCoverImage.value?.path ??
                                            ''),
                                        height: 78,
                                        width: 140,
                                        fit: BoxFit.cover))
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CustomImage(
                                      size: const Size(140, 78),
                                      radius: 10,
                                      fit: BoxFit.cover,
                                      image: controller
                                          .userData.value?.coverPhoto
                                          ?.addBaseURL(),
                                      fullName:
                                          controller.userData.value?.fullname,
                                    ),
                                  ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: 26,
                              width: 26,
                              decoration: BoxDecoration(
                                  color: textDarkGrey(context),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: bgLightGrey(context), width: 2)),
                              child: Center(
                                child: Image.asset(AssetRes.icEdit_1,
                                    width: 20,
                                    height: 20,
                                    color: whitePure(context)),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ProfileFieldCard(
                    icon: Icons.person_outline,
                    controller: controller.fullNameController,
                    title: LKey.fullName.tr,
                  ),
                  Obx(() {
                    return ProfileFieldCard(
                      icon: Icons.alternate_email,
                      controller: controller.usernameController,
                      title: LKey.username.tr,
                      onChanged: controller.checkUsernameAvailability,
                      isError: !controller.isValidUserName.value,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
                      ],
                    );
                  }),
                  ProfileFieldCard(
                    icon: Icons.info_outline,
                    controller: controller.bioController,
                    title: LKey.bio.tr,
                    maxLines: 4,
                  ),
                  BuildLinkView(controller: controller)
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.symmetric(vertical: 20),
            child: TextButtonCustom(
              onTap: controller.onSaveTap,
              title: LKey.save.tr,
              backgroundColor: textDarkGrey(context),
              titleColor: whitePure(context),
            ),
          ),
        ],
      ),
    );
  }
}
