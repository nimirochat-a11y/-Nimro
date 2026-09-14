import 'package:flutter/material.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/font_res.dart';

class ThemeRes {
  /// Theme light mode

  static ThemeData lightTheme(BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: ColorRes.whitePure,
      colorScheme: ColorScheme.light(
        primary: ColorRes.themeAccentSolid,
        surface: ColorRes.whitePure,
        onSurface: ColorRes.textDarkGrey,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: ColorRes.whitePure,
        selectedItemColor: ColorRes.themeAccentSolid,
        unselectedItemColor: ColorRes.textLightGrey,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ColorRes.whitePure,
        foregroundColor: ColorRes.textDarkGrey,
        iconTheme: IconThemeData(color: ColorRes.textDarkGrey),
      ),
      fontFamily: FontRes.outFitRegular400,
      bottomSheetTheme:
          const BottomSheetThemeData(backgroundColor: ColorRes.whitePure),
      sliderTheme: const SliderThemeData(
          trackHeight: 2.5,
          trackShape: RectangularSliderTrackShape(),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
          overlayColor: Colors.transparent),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: ColorRes.textDarkGrey),
        titleMedium: TextStyle(color: ColorRes.textDarkGrey),
        titleSmall: TextStyle(color: ColorRes.textLightGrey),
        bodyLarge: TextStyle(color: ColorRes.textDarkGrey),
        bodyMedium: TextStyle(color: ColorRes.textDarkGrey),
        bodySmall: TextStyle(color: ColorRes.textLightGrey),
        labelSmall: TextStyle(color: ColorRes.themeAccentSolid),
        labelLarge: TextStyle(color: ColorRes.disabledGrey),
        labelMedium: TextStyle(color: ColorRes.textDarkGrey),
      ),
      textSelectionTheme:
          const TextSelectionThemeData(
            cursorColor: Colors.black,
            selectionColor: ColorRes.disabledGrey,
            selectionHandleColor: Colors.black,
          ),
      cardTheme: const CardThemeData(color: ColorRes.whitePure),
      dialogTheme: const DialogThemeData(backgroundColor: ColorRes.whitePure),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: ColorRes.textLightGrey),
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      primaryColor: ColorRes.themeAccentSolid,
      dividerColor: ColorRes.bgGrey,
      cardColor: ColorRes.bgMediumGrey,
      primaryColorDark: Colors.black,
      canvasColor: ColorRes.whitePure,
      useMaterial3: false,
    );
  }

  /// Theme dark mode

  static ThemeData darkTheme(BuildContext context) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: ColorRes.themeAccentSolid,
        surface: Color(0xFF151515),
        onSurface: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
        selectedItemColor: ColorRes.themeAccentSolid,
        unselectedItemColor: Color(0xFF8B98A8),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      fontFamily: FontRes.outFitRegular400,
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xFF101010)),
      cardTheme: const CardThemeData(color: Color(0xFF151515)),
      dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF151515)),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Color(0xFF8B98A8)),
      ),
      primaryColor: ColorRes.themeAccentSolid,
      primaryColorDark: Colors.black,
      cardColor: const Color(0xFF151515),
      canvasColor: Colors.black,
      dividerColor: const Color(0xFF303030),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Color(0xFFB8C1CC)),
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Color(0xFFB8C1CC)),
        labelSmall: TextStyle(color: ColorRes.themeAccentSolid),
        labelLarge: TextStyle(color: Color(0xFF8B98A8)),
        labelMedium: TextStyle(color: Colors.white),
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
  return ColorRes.whitePure;
}

Color textDarkGrey(BuildContext context) {
  return Theme.of(context).textTheme.titleMedium?.color ??
      (Theme.of(context).brightness == Brightness.dark
          ? ColorRes.whitePure
          : ColorRes.textDarkGrey);
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
      ColorRes.themeAccentSolid;
}

Color disableGrey(BuildContext context) {
  return Theme.of(context).textTheme.labelLarge?.color ?? ColorRes.disabledGrey;
}

Color scaffoldBackgroundColor(BuildContext context) {
  return Theme.of(context).scaffoldBackgroundColor;
}

Color blueFollow(BuildContext context) {
  return Theme.of(context).cardTheme.color ?? ColorRes.blueFollow;
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
      : ColorRes.whitePure;
}

Color themeColor(BuildContext context) {
  return Theme.of(context).canvasColor;
}
