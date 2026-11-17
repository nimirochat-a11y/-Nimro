import 'dart:io';

import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final isArabic = Get.locale?.languageCode == 'ar';
    final brandShadow = Shadow(
      color: const Color(0xFF18D6F5).withValues(alpha: .45),
      blurRadius: 18,
    );
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
                    const SizedBox(height: 155),
                    Text(
                      LKey.appName.tr,
                      textDirection:
                          isArabic ? TextDirection.rtl : TextDirection.ltr,
                      style: isArabic
                          ? GoogleFonts.getFont(
                              'Aref Ruqaa',
                              fontSize: 56,
                              fontWeight: FontWeight.w700,
                              color: whitePure(context),
                              shadows: [brandShadow],
                            )
                          : TextStyleCustom.outFitBold700(
                                  fontSize: 56, color: whitePure(context))
                              .copyWith(shadows: [brandShadow]),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      LKey.appTagline.tr,
                      style: TextStyleCustom.outFitRegular400(
                        fontSize: 16,
                        color: whitePure(context).withValues(alpha: .82),
                      ),
                    ),
                    const SizedBox(height: 260),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 34.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              const SizedBox(height: 71),
                              SocialBtn(
                                onTap: Platform.isIOS
                                    ? controller.onAppleTap
                                    : controller.onGoogleTap,
                                icon: Platform.isIOS
                                    ? AssetRes.icApple
                                    : AssetRes.icGoogle,
                                label: Platform.isIOS
                                    ? LKey.signInWithApple.tr
                                    : LKey.signInWithGoogle.tr,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: PrivacyPolicyText(
                        boldTextColor: whitePure(context),
                        regularTextColor:
                            whitePure(context).withValues(alpha: .8),
                      ),
                    ),
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
  final String label;

  const SocialBtn({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 57,
        width: 255,
        decoration: BoxDecoration(
          color: whitePure(context),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(icon, height: 24, width: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyleCustom.outFitMedium500(
                fontSize: 15,
                color: const Color(0xFF172B4D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
