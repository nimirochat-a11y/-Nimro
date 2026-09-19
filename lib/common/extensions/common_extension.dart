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

String _arabicCompactFormat(num n) {
  double absN = n.abs().toDouble();
  String sign = n < 0 ? '-' : '';
  double value;
  String suffix;
  if (absN >= 1000000000) {
    value = absN / 1000000000;
    suffix = ' مليار';
  } else if (absN >= 1000000) {
    value = absN / 1000000;
    suffix = ' مليون';
  } else if (absN >= 1000) {
    value = absN / 1000;
    suffix = ' ألف';
  } else {
    return '$sign${_toArabicDigits(absN.toInt().toString())}';
  }
  String valueStr = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  valueStr = valueStr.replaceAll('.', ',');
  return '$sign${_toArabicDigits(valueStr)}$suffix';
}

extension Number on num {
  String get numberFormat {
    if (SessionManager.instance.getLang() == 'ar') {
      return _arabicCompactFormat(this);
    }
    return NumberFormat.compact().format(this);
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
