import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nimiro/common/widget/verification_info_sheet.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class FullNameWithBlueTick extends StatelessWidget {
  final Widget? child;
  final double? iconSize;
  final double? fontSize;
  final Color? fontColor;
  final String? icon;
  final String? username;
  final MainAxisAlignment? mainAxisAlignment;
  final CrossAxisAlignment? crossAxisAlignment;
  final TextStyle? style;
  final int? isVerify;
  final VoidCallback? onTap;
  final double opacity;

  const FullNameWithBlueTick(
      {super.key,
      required this.username,
      this.child,
      this.iconSize,
      this.fontSize,
      this.fontColor,
      this.mainAxisAlignment,
      this.crossAxisAlignment,
      this.icon,
      this.style,
      this.isVerify = 0,
      this.onTap,
      this.opacity = 1});

  @override
  Widget build(BuildContext context) {
    final verificationFlags = isVerify ?? 0;
    final resolvedIconSize = math.max(iconSize ?? 18, 18).toDouble() * 1.1;
    final badgeIcons = <String>[
      if ((verificationFlags & 1) != 0) AssetRes.icBlueTick,
      if ((verificationFlags & 2) != 0) AssetRes.icGreenTick,
      if ((verificationFlags & 4) != 0) AssetRes.icNimiroVerified,
    ];
    return Row(
        mainAxisAlignment: mainAxisAlignment ?? MainAxisAlignment.start,
        crossAxisAlignment: crossAxisAlignment ?? CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: InkWell(
              onTap: onTap,
              child: Text(
                username ?? '',
                style: style ??
                    TextStyleCustom.unboundedMedium500(
                        color: fontColor ?? textDarkGrey(context),
                        fontSize: fontSize ?? 11,
                      opacity: opacity,
                    ).copyWith(height: 2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (badgeIcons.isNotEmpty) const SizedBox(width: 3),
          ...badgeIcons.map(
            (badgeIcon) {
              final isNimiroBadge = badgeIcon == AssetRes.icNimiroVerified;
              final badgeSize =
                  isNimiroBadge ? resolvedIconSize + 2 : resolvedIconSize;
              final verificationFlag = badgeIcon == AssetRes.icBlueTick
                  ? 1
                  : badgeIcon == AssetRes.icGreenTick
                      ? 2
                      : 4;
              final badgeGlowColor = verificationFlag == 1
                  ? const Color(0xFF2E8BFF)
                  : verificationFlag == 2
                      ? const Color(0xFF27C978)
                      : const Color(0xFF28A9FF);
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 2),
                child: InkWell(
                  onTap: () => showVerificationInfoSheet(
                      context, verificationFlag),
                  borderRadius: BorderRadius.circular(badgeSize),
                  child: Container(
                    padding: isNimiroBadge ? const EdgeInsets.all(1) : null,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: badgeGlowColor.withValues(
                              alpha: isNimiroBadge ? .72 : .42),
                          blurRadius: isNimiroBadge ? 7 : 4,
                          spreadRadius: isNimiroBadge ? .8 : .2,
                        ),
                      ],
                    ),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        1.15, -0.11, -0.02, 0, 4,
                        -0.04, 1.10, -0.01, 0, 4,
                        -0.01, -0.08, 1.16, 0, 4,
                        0, 0, 0, 1, 0,
                      ]),
                      child: Image.asset(
                        icon ?? badgeIcon,
                        height: badgeSize,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          if (child != null) child!
        ],
      );
  }
}
