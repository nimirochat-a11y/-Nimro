import 'package:detectable_text_field/detectable_text_field.dart';
import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/widget/custom_image.dart';
import 'package:nimiro/model/misc/admin_notification_model.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class SystemNotificationPage extends StatelessWidget {
  final AdminNotificationData data;

  const SystemNotificationPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // FIX(v14): the hard-coded 0xFF151515 branch is dead in a light-only app
      // and was the source of the dark block behind the text when the device was
      // in dark mode. The palette is now theme-derived only.
      color: bgLightGrey(context),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.image != null)
            ClipSmoothRect(
              radius: SmoothBorderRadius(cornerRadius: 5, cornerSmoothing: 1),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: CustomImage(
                  image: data.image?.addBaseURL(),
                  size: const Size(double.infinity, 200),
                  fit: BoxFit.cover,
                  radius: 5,
                  cornerSmoothing: 1,
                  isShowPlaceHolder: true,
                ),
              ),
            ),
          Text(data.title ?? '',
              style: TextStyleCustom.outFitMedium500(
                  fontSize: 16, color: ColorRes.textDarkGrey)),
          // FIX(v14): `detectedStyle` carried no decoration override, so the
          // package fell back to its Material default (a black underline) and
          // the links rendered as unreadable black-on-dark text with a heavy
          // underline. Any underline now inherits the accent colour, and the
          // base text is the explicit dark grey rather than a theme lookup.
          DetectableText(
            text: data.description ?? '',
            basicStyle: TextStyleCustom.outFitLight300(
                fontSize: 15, color: ColorRes.textLightGrey, opacity: .95),
            detectionRegExp:
                detectionRegExp(atSign: false, hashtag: false, url: true)!,
            detectedStyle: TextStyleCustom.outFitMedium500(
                    color: themeAccentSolid(context))
                .copyWith(
              decoration: TextDecoration.underline,
              decorationColor: themeAccentSolid(context).withValues(alpha: .55),
              decorationThickness: 1.2,
            ),
            onTap: (p0) {
              p0.lunchUrlWithHttps;
            },
          ),
          const SizedBox(height: 10),
          Text(
            (data.createdAt ?? '').formatDate,
            style: TextStyleCustom.outFitLight300(
                fontSize: 12, color: textLightGrey(context)),
          ),
        ],
      ),
    );
  }
}
