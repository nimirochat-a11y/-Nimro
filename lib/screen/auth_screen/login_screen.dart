import 'dart:io';

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/widget/custom_divider.dart';
import 'package:nimiro/common/widget/privacy_policy_text.dart';
import 'package:nimiro/common/widget/theme_blur_bg.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/auth_screen/auth_screen_controller.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AuthScreenController());
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        height: Get.height,
        decoration: const ShapeDecoration(
            shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(cornerRadius: 0, cornerSmoothing: 1)),
        )),
        child: Stack(
          children: [
            const ThemeBlurBg(),
            SingleChildScrollView(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 20, right: 20, top: 30),
                      child: Column(
                        children: [
                          Image.asset(
                            AssetRes.nimiroMark,
                            height: 150,
                            width: 150,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.only(top: 30.0),
                            child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  text: LKey.signIn.tr.toUpperCase(),
                                  style: TextStyleCustom.unboundedBlack900(
                                    fontSize: 25,
                                    color: whitePure(context),
                                  ).copyWith(letterSpacing: -.2),
                                  children: [
                                    TextSpan(
                                        text: '\n${LKey.toContinue.tr}'
                                            .toUpperCase(),
                                        style:
                                            TextStyleCustom.unboundedBlack900(
                                                fontSize: 25,
                                                color: whitePure(context)
                                                    .withValues(alpha: .5),
                                                opacity: .5))
                                  ],
                                )),
                          ),
                          const SizedBox(height: 50 * 1.5),
                          const SizedBox(height: 18),
                          Text(
                            Platform.isIOS
                                ? 'Continue with Apple'
                                : 'Continue with Google',
                            style: TextStyleCustom.outFitRegular400(
                              fontSize: 16,
                              color: whitePure(context).withValues(alpha: .8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomDivider(
                          color: whitePure(context),
                          height: .5,
                          width: 100,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15.0),
                          child: Text(
                            LKey.continueWith.tr,
                            style: TextStyleCustom.outFitRegular400(
                                fontSize: 16, color: whitePure(context)),
                          ),
                        ),
                        CustomDivider(
                          color: whitePure(context),
                          height: .5,
                          width: 100,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 25.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SocialBtn(
                            onTap: Platform.isIOS
                                ? controller.onAppleTap
                                : controller.onGoogleTap,
                            icon: Platform.isIOS
                                ? AssetRes.icApple
                                : AssetRes.icGoogle,
                          ),
                        ],
                      ),
                    ),
                    PrivacyPolicyText(
                      boldTextColor: whitePure(context),
                      regularTextColor:
                          whitePure(context).withValues(alpha: .8),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginSheetTextField extends StatefulWidget {
  final bool isPasswordField;
  final String hintText;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const LoginSheetTextField(
      {super.key,
      this.isPasswordField = false,
      required this.hintText,
      required this.controller,
      this.keyboardType});

  @override
  State<LoginSheetTextField> createState() => _LoginSheetTextFieldState();
}

class _LoginSheetTextFieldState extends State<LoginSheetTextField> {
  bool isHide = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
          shape: SmoothRectangleBorder(
            borderRadius:
                SmoothBorderRadius(cornerRadius: 10, cornerSmoothing: 1),
            side: BorderSide(color: whitePure(context).withValues(alpha: .4)),
            borderAlign: BorderAlign.inside,
          ),
          color: whitePure(context).withValues(alpha: .1)),
      child: TextField(
        controller: widget.controller,
        style: TextStyleCustom.outFitRegular400(
            color: whitePure(context), fontSize: 16),
        onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
        obscureText: widget.isPasswordField && isHide,
        keyboardType: widget.keyboardType ?? TextInputType.text,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: widget.hintText,
          hintStyle: TextStyleCustom.outFitRegular400(
              color: whitePure(context), fontSize: 16),
          contentPadding: EdgeInsets.only(
              left: 10, right: 10, top: widget.isPasswordField ? 2 : 0),
          suffixIconConstraints: const BoxConstraints(),
          suffixIcon: widget.isPasswordField
              ? InkWell(
                  onTap: () {
                    isHide = !isHide;
                    setState(() {});
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Image.asset(
                        isHide ? AssetRes.icEye : AssetRes.icHideEye,
                        height: 24,
                        width: 35,
                        color: whitePure(context),
                        key: UniqueKey()),
                  ),
                )
              : null,
        ),
        cursorColor: whitePure(context),
      ),
    );
  }
}

class SocialBtn extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;

  const SocialBtn({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 57,
        width: 57,
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: whitePure(context)),
        alignment: Alignment.center,
        child: Image.asset(icon, height: 32, width: 32),
      ),
    );
  }
}
