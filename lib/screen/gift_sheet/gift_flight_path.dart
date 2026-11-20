import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The path a TikTok-style gift flies along: from the bottom of the screen,
/// swooping in an S-curve to the centre, then settling there.
///
/// `t` is normalised progress (0 = launch, 1 = centre).
Offset giftFlightOffset(double t, Size screen) {
  // Ease out: fast launch, graceful arrival.
  final e = 1 - math.pow(1 - t, 3);

  // Vertical: start below the screen (1.15 * half-height) up to centre (0).
  final dy = (1 - e) * screen.height * 0.62;

  // Horizontal S-swing that decays as the gift approaches the centre.
  final swing = math.sin(e * math.pi * 1.6) * (1 - e) * screen.width * 0.22;

  return Offset(swing, dy);
}

/// Rotation while flying: a couple of lively spins that settle at centre.
double giftFlightRotation(double t) {
  return (1 - t) * math.pi * 1.4 * (t < .5 ? 1 : -1);
}

/// Scale: small at launch, a little overshoot at arrival, then normal.
double giftFlightScale(double t) {
  if (t < .85) {
    return 0.55 + 0.65 * (t / .85);
  }
  final k = (t - .85) / .15;
  return 1.2 - 0.2 * (1 - math.pow(1 - k, 2));
}
