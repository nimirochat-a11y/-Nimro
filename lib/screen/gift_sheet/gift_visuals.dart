import 'package:flutter/material.dart';
import 'package:nimiro/model/general/settings_model.dart';

/// Per-gift visual identity shared by the store and the send animation.
///
/// Each realistic gift gets its own accent colour so the glow, particles and
/// name banner feel customised instead of every gift looking the same.
class GiftVisuals {
  GiftVisuals._();

  static Color accentFor(Gift gift) {
    switch (gift.id) {
      case 17:
        return const Color(0xFFFFB74D); // luxury chocolate
      case 18:
        return const Color(0xFFFF4D6D); // crystal rose
      case 19:
        return const Color(0xFFFFD54F); // golden balloon
      case 20:
        return const Color(0xFFFFB74D); // velvet teddy
      case 21:
        return const Color(0xFFFF80AB); // birthday cake
      case 22:
        return const Color(0xFF80DEEA); // diamond ring
      case 23:
        return const Color(0xFFFE2C55); // gift box
      case 24:
        return const Color(0xFFFF4081); // flower bouquet
      case 25:
        return const Color(0xFFB388FF); // rare gemstone
      case 26:
        return const Color(0xFFFFD700); // royal crown
      case 27:
        return const Color(0xFF82B1FF); // shining star
      case 28:
        return const Color(0xFFFFC107); // champion trophy
      default:
        return const Color(0xFFFE2C55);
    }
  }
}
