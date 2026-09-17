import 'package:flutter/material.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/font_res.dart';

/// Nimiro's original palette is a LIGHT theme.
///
/// FIX(v13): in the original design (`a5d6a8c`) `titleLarge` was WHITE, because
/// it is the token that [whitePure] reads for text spoken ON TOP of media. The
/// later "dashboard/theme redesign" flipped that token to the dark text colour
/// and bolted on a dark mode. Since 323 call sites resolve their colour through
/// [whitePure], that single token change is what made bars, sheets and media
/// surfaces render dark-on-dark. The dark theme is gone and the light theme is
/// back to its original shape.
class ThemeRes {
  /// Theme light mode

  static ThemeData lightTheme(BuildContext context) {
    return ThemeData(
      scaffoldBackgroundColor: ColorRes.whitePure,
      colorScheme: const ColorScheme.light(
        primary: ColorRes.themeAccentSolid,
        surface: ColorRes.whitePure,
        onSurface: ColorRes.textDarkGrey,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: ColorRes.whitePure,
          selectedItemColor: ColorRes.themeAccentSolid,
          unselectedItemColor: ColorRes.textLightGrey),
      appBarTheme: const AppBarTheme(
          backgroundColor: ColorRes.bgLightGrey,
          foregroundColor: ColorRes.textDarkGrey,
          iconTheme: IconThemeData(color: ColorRes.textDarkGrey)),
      fontFamily: FontRes.outFitRegular400,
      bottomSheetTheme:
          const BottomSheetThemeData(backgroundColor: ColorRes.whitePure),
      sliderTheme: const SliderThemeData(
          trackHeight: 2.5,
          trackShape: RectangularSliderTrackShape(),
          overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
          overlayColor: Colors.transparent),
      textTheme: const TextTheme(
        // titleLarge is the ON-MEDIA white token. See the class doc before
        // changing it: 323 call sites depend on this being white.
        titleLarge: TextStyle(color: ColorRes.whitePure),
        titleMedium: TextStyle(color: ColorRes.textDarkGrey),
        titleSmall: TextStyle(color: ColorRes.textLightGrey),
        bodyLarge: TextStyle(color: ColorRes.textDarkGrey),
        bodyMedium: TextStyle(color: ColorRes.textDarkGrey),
        bodySmall: TextStyle(color: ColorRes.textLightGrey),
        labelSmall: TextStyle(color: ColorRes.themeAccentSolid),
        labelLarge: TextStyle(color: ColorRes.disabledGrey),
        labelMedium: TextStyle(color: ColorRes.textDarkGrey),
      ),
      textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.black,
          selectionColor: ColorRes.disabledGrey,
          selectionHandleColor: Colors.black),
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
      primaryColorDark: ColorRes.blackPure,
      canvasColor: ColorRes.whitePure,
      useMaterial3: false,
    );
  }
}

/// ON-MEDIA token: white in every theme.
///
/// Text and icons drawn over video, live streams, stories and reels must never
/// follow the theme, or they vanish against the dark media surface.
Color whitePure(BuildContext context) {
  return Theme.of(context).textTheme.titleLarge?.color ?? ColorRes.whitePure;
}

Color textDarkGrey(BuildContext context) {
  return Theme.of(context).textTheme.titleMedium?.color ?? ColorRes.textDarkGrey;
}

Color textLightGrey(BuildContext context) {
  return Theme.of(context).textTheme.titleSmall?.color ?? ColorRes.textLightGrey;
}

Color bgGrey(BuildContext context) {
  return Theme.of(context).dividerColor;
}

Color themeAccentSolid(BuildContext context) {
  return Theme.of(context).textTheme.labelSmall?.color ?? ColorRes.themeAccentSolid;
}

Color disableGrey(BuildContext context) {
  return Theme.of(context).textTheme.labelLarge?.color ?? ColorRes.disabledGrey;
}

Color scaffoldBackgroundColor(BuildContext context) {
  return Theme.of(context).scaffoldBackgroundColor;
}

Color blueFollow(BuildContext context) {
  return ColorRes.blueFollow;
}

Color bgMediumGrey(BuildContext context) {
  return Theme.of(context).cardColor;
}

/// Opaque dark used for scrims and media backdrops. NOT a plain text colour.
Color blackPure(BuildContext context) {
  return ColorRes.blackPure;
}

Color bgLightGrey(BuildContext context) {
  return ColorRes.bgLightGrey;
}

/// Surface used by cards, dialogs and bottom sheets.
Color surfaceColor(BuildContext context) {
  return Theme.of(context).cardColor;
}

/// Text/icon colour for content drawn ON TOP of a dark media surface.
Color onMediaText(BuildContext context) => ColorRes.whitePure;

/// Secondary variant of [onMediaText] for captions and meta rows.
Color onMediaTextMuted(BuildContext context) =>
    ColorRes.whitePure.withValues(alpha: .75);

/// Scrim used for gradients over media. Always dark, on purpose.
Color mediaScrim(BuildContext context) => ColorRes.blackPure;

/// Fill used by editable text fields.
Color inputFillColor(BuildContext context) =>
    Theme.of(context).scaffoldBackgroundColor;

Color themeColor(BuildContext context) {
  return Theme.of(context).canvasColor;
}
