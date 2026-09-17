import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/widget/bottom_sheet_top_view.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

void showVerificationInfoSheet(BuildContext context, int verificationFlag) {
  Get.bottomSheet(
    VerificationInfoSheet(verificationFlag: verificationFlag),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

class VerificationInfoSheet extends StatelessWidget {
  final int verificationFlag;

  const VerificationInfoSheet({super.key, required this.verificationFlag});

  VerificationBadgeInfo? _infoForFlag(int flag) {
    switch (flag) {
      case 1:
        return VerificationBadgeInfo(
          icon: AssetRes.icBlueTick,
          title: LKey.blueVerificationTitle.tr,
          description: LKey.blueVerificationDescription.tr,
        );
      case 2:
        return VerificationBadgeInfo(
          icon: AssetRes.icGreenTick,
          title: LKey.greenVerificationTitle.tr,
          description: LKey.greenVerificationDescription.tr,
        );
      case 4:
        return VerificationBadgeInfo(
          icon: AssetRes.icNimiroVerified,
          title: LKey.nimiroVerificationTitle.tr,
          description: LKey.nimiroVerificationDescription.tr,
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _infoForFlag(verificationFlag);
    if (info == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.only(bottom: 25),
      decoration: ShapeDecoration(
        color: scaffoldBackgroundColor(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetTopView(title: LKey.verificationBadgeTitle.tr),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: bgLightGrey(context),
                borderRadius: BorderRadius.circular(22),
                boxShadow: verificationFlag == 4
                    ? [
                        BoxShadow(
                          color: const Color(0xFF18D6F5).withValues(alpha: .18),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: whitePure(context),
                      shape: BoxShape.circle,
                      boxShadow: verificationFlag == 4
                          ? [
                              BoxShadow(
                                color: const Color(0xFF18D6F5).withValues(alpha: .35),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: Image.asset(info.icon, filterQuality: FilterQuality.high),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.title,
                          style: TextStyleCustom.unboundedSemiBold600(
                            color: textDarkGrey(context),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          info.description,
                          style: TextStyleCustom.outFitRegular400(
                            color: textLightGrey(context),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VerificationBadgeInfo {
  final String icon;
  final String title;
  final String description;

  const VerificationBadgeInfo({
    required this.icon,
    required this.title,
    required this.description,
  });
}
