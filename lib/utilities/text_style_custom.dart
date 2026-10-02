import 'package:flutter/cupertino.dart';
import 'package:nimiro/utilities/font_res.dart';
import 'package:get/get.dart';

class TextStyleCustom {
  static double _scale(double size) {
    final lang = Get.locale?.languageCode ?? 'ar';
    return lang == 'ar' ? size : size * 0.86;
  }

  static TextStyle outFitBlack900(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.outFitBlack900);

  static TextStyle outFitExtraBold800(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.outFitExtraBold800);

  static TextStyle outFitBold700(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.outFitBold700);

  static TextStyle outFitSemiBold600(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.outFitSemiBold600);

  static TextStyle outFitMedium500(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.outFitMedium500);

  static TextStyle outFitRegular400(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.outFitRegular400);

  static TextStyle outFitLight300(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.outFitLight300);

  static TextStyle outFitExtraLight200(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.outFitExtraLight200);

  static TextStyle outFitThin100(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.outFitThin100);

  static TextStyle unboundedBlack900(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.unboundedBlack900);

  static TextStyle unboundedBold700(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.unboundedBold700);

  static TextStyle unboundedExtraBold800(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.unboundedExtraBold800);

  static TextStyle unboundedExtraLight100(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.unboundedExtraLight100);

  static TextStyle unboundedLight200(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.unboundedLight200);

  static TextStyle unboundedMedium500(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.unboundedMedium500);

  static TextStyle unboundedRegular400(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.unboundedRegular400);

  static TextStyle unboundedSemiBold600(
          {Color? color, double? opacity,
    double fontSize = 14}) =>
      TextStyle(
          color: color?.withValues(alpha: opacity ?? 1),
          fontSize: _scale(fontSize),
          fontFamily: FontRes.unboundedSemiBold600);
}
