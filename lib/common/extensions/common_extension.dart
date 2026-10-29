import 'dart:io';
import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/model/user_model/user_model.dart';

String _toArabicDigits(String input) {
  const List<String> western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const List<String> eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  String out = input;
  for (int i = 0; i < western.length; i++) {
    out = out.replaceAll(western[i], eastern[i]);
  }
  return out;
}

/// Arabic decimal separator (U+066B). A comma is the *thousands* separator in
/// Arabic, so "٣,١ ألف" reads as an ambiguous number; it must be "٣٫١ ألف".
const String _arabicDecimalSeparator = '\u066B';

/// Arabic thousands separator (U+066C).
const String _arabicThousandsSeparator = '\u066C';

String _arabicCompactFormat(num n) {
  final double absN = n.abs().toDouble();
  final String sign = n < 0 ? '-' : '';

  const List<double> units = [1000, 1000000, 1000000000];
  const List<String> suffixes = [' ألف', ' مليون', ' مليار'];

  int unitIndex = -1;
  for (int i = 0; i < units.length; i++) {
    if (absN >= units[i]) unitIndex = i;
  }
  if (unitIndex < 0) {
    return '$sign${_toArabicDigits(absN.toInt().toString())}';
  }

  double value = absN / units[unitIndex];
  int tenths = (value * 10).round();

  // 999,999 must read "١ مليون", not "١٠٠٠٫٠ ألف": if rounding pushes the
  // value to 1000, promote it to the next unit.
  if (tenths >= 10000 && unitIndex < units.length - 1) {
    unitIndex++;
    value = absN / units[unitIndex];
    tenths = (value * 10).round();
  }

  final String valueStr = tenths % 10 == 0
      ? (tenths ~/ 10).toString()
      : '${tenths ~/ 10}$_arabicDecimalSeparator${tenths % 10}';

  return '$sign${_toArabicDigits(valueStr)}${suffixes[unitIndex]}';
}

extension Number on num {
  String get numberFormat {
    if (SessionManager.instance.getLang() == 'ar') {
      return _arabicCompactFormat(this);
    }
    return NumberFormat.compact().format(this);
  }

  /// Full number with grouping and no unit suffix ("٣٬١٠٠" instead of
  /// "٣٫١ ألف"). Used where the whole value must be readable, such as the coin
  /// balance, so a large "ألف" never dominates the number.
  String get numberFormatFull {
    if (SessionManager.instance.getLang() == 'ar') {
      final grouped = NumberFormat.decimalPattern('en').format(this);
      return _toArabicDigits(grouped)
          .replaceAll(',', _arabicThousandsSeparator);
    }
    return NumberFormat.decimalPattern().format(this);
  }

  String get currencyFormat =>
      '${SessionManager.instance.getCurrency()}$numberFormat';

  int get convertInt => toInt();

  UserLevel get getUserLevelByTotalCoins {
    List<UserLevel> userLevels =
        SessionManager.instance.getSettings()?.userLevels ?? [];
    if (userLevels.isEmpty) {
      return UserLevel();
    }
    userLevels.sort((a, b) => (b.coinsCollection).compareTo(a.coinsCollection));
    for (var level in userLevels) {
      if (this >= (level.coinsCollection)) {
        return level;
      }
    }
    return userLevels.last;
  }

  String get elapsedTimeFromEpoch {
    String time = '';
    final joinTime = DateTime.fromMillisecondsSinceEpoch(toInt());
    final currentTime = DateTime.now();

    final duration = currentTime.difference(joinTime);
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60);
    final seconds = (duration.inSeconds % 60);
    print('$hours $minutes $seconds');
    if (hours > 0) {
      time = '${hours}h ';
    }
    if (minutes > 0) {
      time += '${minutes}m ';
    }
    if (seconds > 0) {
      time += '${seconds}s';
    }

    return time;
  }
}

extension FormatLatLng on LatLng {
  String get getDistance {
    User? user = SessionManager.instance.getUser();
    if (user == null) return "0.0"; // Handle null user case

    const double p = 0.017453292519943295; // π / 180
    const double radiusOfEarth = 6371; // Earth's radius in km

    double lat1 = (user.lat ?? 0) * p;
    double lon1 = (user.lon ?? 0) * p;
    double lat2 = latitude * p;
    double lon2 = longitude * p;

    double a = 0.5 -
        cos(lat2 - lat1) / 2 +
        cos(lat1) * cos(lat2) * (1 - cos(lon2 - lon1)) / 2;

    return (radiusOfEarth * 2 * asin(sqrt(a))).toStringAsFixed(2);
  }
}

extension PlatformPathExtension on Platform {
  static Future<String> get localPath async {
    Directory? directory = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    return '${directory?.path ?? ''}/';
  }
}
