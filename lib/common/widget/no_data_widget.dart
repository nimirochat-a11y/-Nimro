import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class NoDataView extends StatelessWidget {
  const NoDataView({
    super.key,
    this.title,
    this.description,
    this.child,
    this.showShow = true,
    this.bgColor,
    this.safeAreaTop = false,
    this.titleColor,
    this.descriptionColor,
  });

  final String? title;
  final String? description;
  final Widget? child;
  final bool showShow;
  final Color? bgColor;
  final bool safeAreaTop;

  /// Optional overrides so specific screens (e.g. the reels screen) can render
  /// a dark empty state without changing the default everywhere else.
  final Color? titleColor;
  final Color? descriptionColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor ?? scaffoldBackgroundColor(context),
      child: Stack(
        children: [
          if (showShow)
            SafeArea(
              top: safeAreaTop,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 3,
                  children: [
                    Center(
                      child: Text(
                        (title ?? LKey.noData).tr,
                        style: TextStyleCustom.unboundedSemiBold600(
                          color: titleColor ?? textDarkGrey(context),
                          fontSize: 17,
                        ).copyWith(decoration: TextDecoration.none),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Text(
                      (description ?? LKey.noContentMessage).tr,
                      style: TextStyleCustom.outFitLight300(
                        color: descriptionColor ??
                            (Theme.of(context).brightness == Brightness.dark
                                ? textLightGrey(context)
                                : ColorRes.textDarkGrey),
                      ).copyWith(decoration: TextDecoration.none),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class NoDataWidgetWithScroll extends StatelessWidget {
  final String title;
  final String description;
  final Color? bgColor;
  final Color? titleColor;
  final Color? descriptionColor;

  const NoDataWidgetWithScroll({
    super.key,
    required this.title,
    required this.description,
    this.bgColor,
    this.titleColor,
    this.descriptionColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NoDataView(
          safeAreaTop: true,
          title: title,
          description: description,
          bgColor: bgColor,
          titleColor: titleColor,
          descriptionColor: descriptionColor,
        ),
        SingleChildScrollView(
          child: SizedBox(width: double.infinity, height: Get.height),
        ),
      ],
    );
  }
}
