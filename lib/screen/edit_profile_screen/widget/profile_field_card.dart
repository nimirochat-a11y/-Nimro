import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

/// A modern, card-styled text field used only on the Edit Profile screen.
/// Each field is a standalone rounded card with a small leading icon.
class ProfileFieldCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final TextEditingController controller;
  final String? hintText;
  final Function(String value)? onChanged;
  final bool isError;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  const ProfileFieldCard({
    super.key,
    required this.icon,
    required this.title,
    required this.controller,
    this.hintText,
    this.onChanged,
    this.isError = false,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMultiline = maxLines > 1;
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgLightGrey(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError ? ColorRes.likeRed : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            margin: EdgeInsets.only(top: isMultiline ? 2 : 0),
            decoration: BoxDecoration(
              color: themeAccentSolid(context).withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: themeAccentSolid(context), size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyleCustom.outFitRegular400(
                      fontSize: 12, color: textLightGrey(context)),
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: controller,
                  onChanged: onChanged,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  maxLines: isMultiline ? maxLines : 1,
                  minLines: 1,
                  scrollPadding: const EdgeInsets.only(bottom: 120),
                  onTapOutside: (event) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  style: TextStyleCustom.outFitRegular400(
                      color: textDarkGrey(context), fontSize: 16),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: TextStyleCustom.outFitLight300(
                        color: textLightGrey(context), fontSize: 16),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
