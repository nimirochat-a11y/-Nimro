import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

/// New-design settings row (v17 mockup): a title with
/// a short subtitle under
/// it, a colored circular icon badge, and a left-pointing chevron. Used only
/// by [SettingsScreen] - kept separate from the legacy
/// `SettingIconTextWithArrow`
/// so nothing else in the app (e.g. the notifications
/// page) is affected.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isDestructive;
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent =
        isDestructive ? ColorRes.likeRed : themeAccentSolid(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: .12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title.tr,
                      style: TextStyleCustom.unboundedMedium500(
                          fontSize: 14,
                          color: isDestructive
                              ? ColorRes.likeRed
                              : textDarkGrey(context))),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!.tr,
                        style: TextStyleCustom.outFitLight300(
                            fontSize: 12, color: textLightGrey(context))),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(Icons.chevron_left,
                    size: 22, color: textLightGrey(context)),
          ],
        ),
      ),
    );
  }
}

/// A rounded card that groups related settings rows with hairline dividers
/// between them, matching the mockup's sectioned layout.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final Color? backgroundColor;
  const SettingsGroup(
      {super.key, required this.children, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? bgLightGrey(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                indent: 66,
                endIndent: 16,
                color: textLightGrey(context).withValues(alpha: .12),
              ),
          ],
        ],
      ),
    );
  }
}
