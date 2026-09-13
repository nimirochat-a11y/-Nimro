import 'package:flutter/material.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/font_res.dart';

class ThemeRes {
  /// Theme light mode

  static ThemeData lightTheme(BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: ColorRes.whitePure,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: ColorRes.whitePure),
      appBarTheme: const AppBarTheme(backgroundColor: ColorRes.whitePure),
      fontFamily: FontRes.outFitRegular400,
      bottomSheetTheme:
          const BottomSheetThemeData(backgroundColor: ColorRes.whitePure),
      sliderTheme: const SliderThemeData(
          trackHeight: 2.5,
          trackShape: RectangularSliderTrackShape(),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
          overlayColor: Colors.transparent),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: ColorRes.whitePure),
        titleMedium: TextStyle(color: ColorRes.textDarkGrey),
        titleSmall: TextStyle(color: ColorRes.textLightGrey),
        labelSmall: TextStyle(color: ColorRes.themeAccentSolid),
        labelLarge: TextStyle(color: ColorRes.disabledGrey),
      ),
      textSelectionTheme:
          const TextSelectionThemeData(
            cursorColor: Colors.black,
            selectionColor: ColorRes.disabledGrey,
            selectionHandleColor: Colors.black,
          ),
      cardTheme: const CardThemeData(color: ColorRes.whitePure),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      primaryColor: ColorRes.themeAccentSolid,
      dividerColor: ColorRes.bgGrey,
      cardColor: ColorRes.bgMediumGrey,
      primaryColorDark: ColorRes.blackPure,
      canvasColor: ColorRes.themeColor,
      useMaterial3: false,
    );
  }

  /// Theme dark mode

  static ThemeData darkTheme(BuildContext context) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
      fontFamily: FontRes.outFitRegular400,
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xFF101010)),
      cardTheme: const CardThemeData(color: Color(0xFF151515)),
      primaryColor: ColorRes.themeAccentSolid,
      primaryColorDark: Colors.black,
      cardColor: const Color(0xFF151515),
      canvasColor: Colors.black,
      dividerColor: const Color(0xFF303030),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
        labelSmall: TextStyle(color: ColorRes.themeAccentSolid),
        labelLarge: TextStyle(color: Colors.white),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.white,
        selectionColor: Color(0xFF505050),
        selectionHandleColor: Colors.white,
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      useMaterial3: false,
    );
  }
}

Color whitePure(BuildContext context) {
  return Theme.of(context).textTheme.titleLarge?.color ?? ColorRes.whitePure;
}

Color textDarkGrey(BuildContext context) {
  return Theme.of(context).textTheme.titleMedium?.color ??
      textDarkGrey(context);
}

Color textLightGrey(BuildContext context) {
  return Theme.of(context).textTheme.titleSmall?.color ??
      ColorRes.textLightGrey;
}

Color bgGrey(BuildContext context) {
  return Theme.of(context).dividerColor;
}

Color themeAccentSolid(BuildContext context) {
  return Theme.of(context).textTheme.labelSmall?.color ??
      themeAccentSolid(context);
}

Color disableGrey(BuildContext context) {
  return Theme.of(context).textTheme.labelLarge?.color ?? ColorRes.disabledGrey;
}

Color scaffoldBackgroundColor(BuildContext context) {
  return Theme.of(context).scaffoldBackgroundColor;
}

Color blueFollow(BuildContext context) {
  return Theme.of(context).cardTheme.color ?? blueFollow(context);
}

Color bgMediumGrey(BuildContext context) {
  return Theme.of(context).cardColor;
}

Color blackPure(BuildContext context) {
  return Theme.of(context).primaryColorDark;
}

Color bgLightGrey(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF101010)
      : (Theme.of(context).appBarTheme.backgroundColor ?? ColorRes.whitePure);
}

Color themeColor(BuildContext context) {
  return Theme.of(context).canvasColor;
}
