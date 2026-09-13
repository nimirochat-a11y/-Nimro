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
      appBarTheme: const AppBarTheme(backgroundColor: ColorRes.bgLightGrey),
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
          const TextSelectionThemeData(selectionColor: ColorRes.disabledGrey),
      cardTheme: const CardThemeData(color: ColorRes.blueFollow),
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
      scaffoldBackgroundColor: const Color(0xFF050B1A),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF071326),
      ),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF071326)),
      fontFamily: FontRes.outFitRegular400,
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xFF0B1D3A)),
      cardTheme: const CardThemeData(color: Color(0xFF10264A)),
      primaryColor: ColorRes.themeAccentSolid,
      primaryColorDark: Colors.white,
      cardColor: const Color(0xFF10264A),
      canvasColor: const Color(0xFF050B1A),
      dividerColor: const Color(0xFF243858),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Color(0xFFE4EBF7)),
        titleSmall: TextStyle(color: Color(0xFF9CAAC2)),
        labelSmall: TextStyle(color: ColorRes.themeAccentSolid),
        labelLarge: TextStyle(color: Color(0xFF7586A3)),
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
  return Theme.of(context).appBarTheme.backgroundColor ?? ColorRes.bgLightGrey;
}

Color themeColor(BuildContext context) {
  return Theme.of(context).canvasColor;
}
