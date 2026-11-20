import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Per-gift motion style, inspired by the way TikTok gives every gift its own
/// entrance (roses bloom, rockets blast off, crowns descend, coins rain...).
///
/// Each style controls three things:
///   * the entrance path from the launch point to the centre,
///   * the rotation/scale while arriving,
///   * the ambient loop once the gift has settled.
enum GiftMotion {
  bloom, // rose / bouquet: spin while blossoming outward
  pulse, // heart: heartbeat scale
  tumble, // teddy: soft rolling tumble
  sparkle, // diamond / gem / ring: glint flashes + tiny jitter
  descend, // crown / trophy / castle: slow royal descent from the top
  soar, // falcon / rocket / balloon / star: swoop up with a trail
  roar, // lion: bold shake + lunge
  play, // game: bouncy arc
  orbit, // planet: slow orbital drift + ring spin
  unwrap, // gift box / chocolate / cake: excited pop + wobble
}

/// Pick the motion style for a gift id (DB ids 5–28).
GiftMotion motionFor(int id) {
  switch (id) {
    case 5: // rose
    case 18: // crystal rose
    case 24: // bouquet
      return GiftMotion.bloom;
    case 6: // heart
      return GiftMotion.pulse;
    case 7: // teddy
    case 20: // velvet teddy
      return GiftMotion.tumble;
    case 8: // diamond
    case 22: // diamond ring
    case 25: // rare gemstone
      return GiftMotion.sparkle;
    case 9: // crown
    case 16: // trophy
    case 26: // royal crown
    case 28: // champion trophy
    case 14: // castle
      return GiftMotion.descend;
    case 10: // falcon
    case 13: // rocket
    case 19: // golden balloon
    case 27: // shining star
      return GiftMotion.soar;
    case 11: // lion
      return GiftMotion.roar;
    case 12: // game
      return GiftMotion.play;
    case 15: // planet
      return GiftMotion.orbit;
    case 17: // chocolate
    case 21: // cake
    case 23: // gift box
      return GiftMotion.unwrap;
    default:
      return GiftMotion.soar;
  }
}

/// Where the gift starts its journey. Most fly up from the bottom, but the
/// "royal" gifts descend from above and the playful ones come from the side.
Offset motionLaunchOffset(GiftMotion motion, Size screen) {
  switch (motion) {
    case GiftMotion.descend:
      return const Offset(0, -1); // from above the screen
    case GiftMotion.play:
      return const Offset(-1, .3); // bounce in from the left
    case GiftMotion.roar:
      return const Offset(1, .2); // lunge in from the right
    case GiftMotion.soar:
      return const Offset(.15, 1); // rocket-like from bottom, slightly right
    default:
      return const Offset(0, 1); // from the bottom centre
  }
}

/// Entrance position. `t` is 0 at launch and 1 at the centre.
/// `e` is the eased progress supplied by the caller.
Offset motionEntranceOffset(
  GiftMotion motion,
  double t,
  double e,
  Size screen,
) {
  final launch = motionLaunchOffset(motion, screen);
  final startX = launch.dx * screen.width * .5;
  final startY = launch.dy * screen.height * .62;

  switch (motion) {
    case GiftMotion.bloom:
      // Gentle spiral as the petals open.
      final angle = e * math.pi * 1.2;
      return Offset(
        startX * (1 - e) + math.sin(angle) * 40 * (1 - e),
        startY * (1 - e),
      );
    case GiftMotion.pulse:
      // Two little hops before settling.
      final hop = math.sin(e * math.pi * 3) * 26 * (1 - e);
      return Offset(startX * (1 - e), startY * (1 - e) + hop);
    case GiftMotion.tumble:
      return Offset(
        startX * (1 - e) + math.sin(e * math.pi * 2) * 50 * (1 - e),
        startY * (1 - e) + math.sin(e * math.pi) * 18,
      );
    case GiftMotion.sparkle:
      // Quick zig-zag glint path.
      return Offset(
        startX * (1 - e) + math.sin(e * math.pi * 5) * 18 * (1 - e),
        startY * (1 - e),
      );
    case GiftMotion.descend:
      // Slow royal drop with a tiny sideways sway.
      return Offset(
        startX * (1 - e) + math.sin(e * math.pi) * 24,
        startY * (1 - e),
      );
    case GiftMotion.soar:
      // Fast curved swoop upward.
      return Offset(
        startX * (1 - e) + math.sin(e * math.pi * 1.5) * 70 * (1 - e),
        startY * (1 - e),
      );
    case GiftMotion.roar:
      // Aggressive lunge with an overshoot past the centre.
      final over = math.sin(e * math.pi) * 36;
      return Offset(startX * (1 - e) - over, startY * (1 - e));
    case GiftMotion.play:
      // Bouncy parabolic arc.
      return Offset(
        startX * (1 - e),
        startY * (1 - e) - math.sin(e * math.pi) * 90,
      );
    case GiftMotion.orbit:
      // Wide orbital entry.
      final angle = e * math.pi * 2;
      return Offset(
        startX * (1 - e) + math.cos(angle) * 60 * (1 - e),
        startY * (1 - e) + math.sin(angle) * 24 * (1 - e),
      );
    case GiftMotion.unwrap:
      // Excited springy entry.
      return Offset(
        startX * (1 - e) + math.sin(e * math.pi * 4) * 14 * (1 - e),
        startY * (1 - e),
      );
  }
}

/// Rotation during the entrance (radians). Settles to 0 at the centre.
double motionEntranceRotation(GiftMotion motion, double t) {
  final left = 1 - t;
  switch (motion) {
    case GiftMotion.bloom:
      return left * math.pi * 1.6;
    case GiftMotion.pulse:
      return math.sin(t * math.pi * 4) * .12 * left;
    case GiftMotion.tumble:
      return left * math.pi * 3;
    case GiftMotion.sparkle:
      return math.sin(t * math.pi * 6) * .18 * left;
    case GiftMotion.descend:
      return math.sin(t * math.pi * 2) * .12 * left;
    case GiftMotion.soar:
      return left * math.pi * 2;
    case GiftMotion.roar:
      return math.sin(t * math.pi * 5) * .2 * left;
    case GiftMotion.play:
      return left * math.pi;
    case GiftMotion.orbit:
      return left * math.pi * 2.5;
    case GiftMotion.unwrap:
      return math.sin(t * math.pi * 4) * .16 * left;
  }
}

/// Scale during the entrance.
double motionEntranceScale(GiftMotion motion, double t) {
  if (t < .82) {
    final base = 0.5 + (t / .82) * 0.7;
    if (motion == GiftMotion.descend) {
      return base + math.sin(t * math.pi) * .12; // grand, slightly larger
    }
    return base;
  }
  final k = (t - .82) / .18;
  // Overshoot peaks differ per style.
  final peak = switch (motion) {
    GiftMotion.pulse => 1.35,
    GiftMotion.roar => 1.30,
    GiftMotion.unwrap => 1.28,
    GiftMotion.descend => 1.22,
    _ => 1.18,
  };
  return peak - (peak - 1) * (1 - math.pow(1 - k, 2));
}

/// Ambient motion once the gift has reached the centre. `v` loops 0..1.
Offset motionAmbientOffset(GiftMotion motion, double v) {
  final s = math.sin(v * math.pi * 2);
  final c = math.cos(v * math.pi * 2);
  final beat = math.pow(math.max(0, math.sin(v * math.pi * 4)), 8).toDouble();
  switch (motion) {
    case GiftMotion.pulse:
      // Strong double heartbeat.
      return Offset(0, -beat * 12);
    case GiftMotion.tumble:
      return Offset(s * 10, s.abs() * -8);
    case GiftMotion.sparkle:
      return Offset(s * 3, c * 3);
    case GiftMotion.orbit:
      return Offset(c * 14, s * 6);
    case GiftMotion.roar:
      return Offset(s * 5, 0);
    case GiftMotion.play:
      return Offset(0, -s.abs() * 14);
    case GiftMotion.bloom:
      return Offset(s * 6, c.abs() * -6);
    case GiftMotion.unwrap:
      return Offset(s * 5, -s.abs() * 8);
    case GiftMotion.soar:
      return Offset(s * 7, -c.abs() * 10);
    case GiftMotion.descend:
      return Offset(0, s * 6);
  }
}

/// Ambient scale once settled (`v` loops 0..1).
double motionAmbientScale(GiftMotion motion, double v) {
  final s = math.sin(v * math.pi * 2);
  final beat = math.pow(math.max(0, math.sin(v * math.pi * 4)), 8).toDouble();
  switch (motion) {
    case GiftMotion.pulse:
      return 1 + beat * .10;
    case GiftMotion.sparkle:
      return 1 + math.max(0, s) * .05;
    case GiftMotion.roar:
      return 1 + math.max(0, s) * .06;
    case GiftMotion.bloom:
      return 1 + (1 - math.cos(v * math.pi * 2)) * .03;
    case GiftMotion.tumble:
      return 1 + s * .03;
    default:
      return 1 + s * .015;
  }
}
