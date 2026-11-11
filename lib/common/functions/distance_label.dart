import 'package:get/get.dart';
import 'package:nimiro/languages/languages_keys.dart';

/// Formats the distance shown in the Nearby feed.
///
/// The API returns metres (`distance_m`) plus a flag telling whether the
/// source coordinates were exact. Old posts whose coordinates were rounded to
/// one decimal are prefixed with "≈" instead of pretending to be precise.
String nearbyDistanceLabel({
  double? distanceKm,
  int? distanceM,
  bool approximate = false,
}) {
  final meters =
      distanceM ?? (distanceKm == null ? null : (distanceKm * 1000).round());
  if (meters == null) return '';

  if (meters < 1000) {
    final key = approximate ? LKey.approxMeterFromYou : LKey.meterFromYou;
    return key.tr.replaceFirst('{m}', '$meters');
  }

  final km = (meters / 1000).toStringAsFixed(1);
  final key = approximate ? LKey.approxKmFromYou : LKey.kmFromYou;
  return key.tr.replaceFirst('{km}', km);
}
