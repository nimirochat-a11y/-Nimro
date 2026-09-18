import 'dart:io';

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/widget/custom_app_bar.dart';
import 'package:nimiro/common/widget/custom_image.dart';
import 'package:nimiro/common/widget/text_button_custom.dart';
import 'package:nimiro/common/widget/text_field_custom.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/edit_profile_screen/edit_profile_screen_controller.dart';
import 'package:nimiro/screen/edit_profile_screen/widget/build_link_view.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

/// Same rhythm and corner radius as the profile header, so the screen you edit
/// in looks like the screen you edit from.
class _Sp {
  static const double s8 = 8;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double radius = 14;
}

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: _Sp.s8),

                  // Account id — a quiet card rather than a full-bleed strip.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _Sp.s20),
                    child: _Card(
                      child: Row(
                        children: [
                          Text(
                            '${LKey.userId.tr} :',
                            style: TextStyleCustom.outFitLight300(
                                fontSize: 15, color: textLightGrey(context)),
                          ),
                          const SizedBox(width: _Sp.s8),
                          Expanded(
                            child: Text(
                              '${controller.userData.value?.id}',
                              style: TextStyleCustom.outFitMedium500(
                                  fontSize: 15, color: textDarkGrey(context)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: _Sp.s16),

                  // Profile photo.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _Sp.s20),
                    child: Text(
                      LKey.profileImage.tr,
                      style: TextStyleCustom.outFitMedium500(
                          fontSize: 15, color: textDarkGrey(context)),
                    ),
                  ),
                  const SizedBox(height: _Sp.s8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _Sp.s20),
                    child: _Card(
                      child: Row(
                        children: [
                          InkWell(
                            onTap: controller.onChangeProfileImage,
                            borderRadius: BorderRadius.circular(60),
                            child: Stack(
                              children: [
                                Obx(
                                  () => controller.fileProfileImage.value != null
                                      ? ClipOval(
                                          child: Image.file(
                                            File(controller.fileProfileImage
                                                    .value?.path ??
                                                ''),
                                            height: 86,
                                            width: 86,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : CustomImage(
                                          size: const Size(86, 86),
                                          image: controller.userData.value
                                              ?.profilePhoto
                                              ?.addBaseURL(),
                                          fullName: controller
                                              .userData.value?.fullname,
                                        ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    height: 28,
                                    width: 28,
                                    decoration: BoxDecoration(
                                      color: themeAccentSolid(context),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Image.asset(
                                        AssetRes.icEdit_1,
                                        width: 16,
                                        height: 16,
                                        color: whitePure(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: _Sp.s16),
                          Expanded(
                            child: Text(
                              LKey.profileImage.tr,
                              style: TextStyleCustom.outFitLight300(
                                  fontSize: 14, color: textLightGrey(context)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: _Sp.s20),

                  // Fields. TextFieldCustom already renders the label above the
                  // field, so spacing is all that is added here.
                  TextFieldCustom(
                    controller: controller.fullNameController,
                    title: LKey.fullName.tr,
                  ),
                  Obx(() {
                    return TextFieldCustom(
                      controller: controller.usernameController,
                      title: LKey.username.tr,
                      onChanged: controller.checkUsernameAvailability,
                      isError: !controller.isValidUserName.value,
                    );
                  }),
                  TextFieldCustom(
                      controller: controller.bioController,
                      title: LKey.bio.tr,
                      height: 100),
                  TextFieldCustom(
                    controller: controller.emailController,
                    title: LKey.email.tr,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  TextFieldCustom(
                      controller: controller.phoneNumberController,
                      title: LKey.phoneNumber.tr,
                      isPrefixIconShow: true),
                  BuildLinkView(controller: controller),
                  const SizedBox(height: _Sp.s16),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.symmetric(vertical: _Sp.s16),
            child: TextButtonCustom(
              onTap: controller.onSaveTap,
              title: LKey.save.tr,
              backgroundColor: themeAccentSolid(context),
              titleColor: whitePure(context),
              radius: _Sp.radius,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded surface used for every block on this screen.
class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_Sp.s16),
      decoration: ShapeDecoration(
        shape: SmoothRectangleBorder(
          borderRadius:
              SmoothBorderRadius(cornerRadius: _Sp.radius, cornerSmoothing: 1),
        ),
        color: bgLightGrey(context),
      ),
      child: child,
    );
  }
}
