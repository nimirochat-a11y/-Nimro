import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/manager/haptic_manager.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/widget/dominant_color.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/general/status_model.dart';
import 'package:url_launcher/url_launcher.dart';

extension StringExtention on String {
  String addBaseURL() {
    return (SessionManager.instance.getSettings()?.itemBaseUrl ?? '') + this;
  }

  Future<StatusModel> get lunchUrlWithHttps async {
    String url = this;
    if (!startsWith('http')) {
      url = 'https://$this';
    }

    try {
      bool result =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return StatusModel(status: result, message: 'Success');
    } on PlatformException catch (e) {
      Loggers.error(e);
      return StatusModel(status: false, message: e.code);
    }
  }

  Future<StatusModel> get lunchUrl async {
    String url = this;

    try {
      bool result =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return StatusModel(status: result, message: 'Success');
    } on PlatformException catch (e) {
      Loggers.error(e);
      return StatusModel(status: false, message: e.code);
    }
  }

  Future get copyText async {
    try {
      HapticManager.shared.light();
      await Clipboard.setData(ClipboardData(text: this));
      BaseController.share.showSnackBar(LKey.copiedToClipboard.tr);
    } catch (e) {
      BaseController.share.showSnackBar('Failed to copy to clipboard');
    }
  }

  Future<String> get getFileSize async {
    var file = File(this);
    int bytes = await file.length();
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  String get timeAgo {
    DateTime time = DateTime.parse(this);
    DateTime now = DateTime.now();

    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime messageDate = DateTime(time.year, time.month, time.day);

    Duration diff = now.difference(time);
    int dayDiff = today.difference(messageDate).inDays;

    final bool isArabic = SessionManager.instance.getLang() == 'ar';

    if (dayDiff == 0) {
      if (diff.inHours > 0) {
        if (isArabic) {
          final int h = diff.inHours;
          return 'منذ ${h == 1 ? 'ساعة واحدة' : '${_toArabicDigits(h.toString())} ساعات'}';
        }
        return "${diff.inHours} ${diff.inHours == 1 ? "hour" : "hours"} ago";
      }
      if (diff.inMinutes > 0) {
        if (isArabic) {
          final int m = diff.inMinutes;
          return 'منذ ${m == 1 ? 'دقيقة واحدة' : '${_toArabicDigits(m.toString())} دقائق'}';
        }
        return "${diff.inMinutes} ${diff.inMinutes == 1 ? "min" : "mins"} ago";
      }
      return isArabic ? "الآن" : "Now";
    } else if (dayDiff == 1) {
      return isArabic ? "أمس" : "Yesterday";
    } else {
      return isArabic
          ? formatArabicDate(time)
          : DateFormat('dd MMM yyyy').format(time);
    }
  }

  String get chatTimeFormat {
    DateTime time = DateTime.fromMillisecondsSinceEpoch(int.parse(this));
    DateTime now = DateTime.now();

    // Remove time part for accurate day comparison
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime messageDate = DateTime(time.year, time.month, time.day);

    Duration dateDiff = today.difference(messageDate);

    final bool isArabic = SessionManager.instance.getLang() == 'ar';

    if (dateDiff.inDays == 0) {
      return isArabic
          ? "اليوم، ${formatArabicTime(time)}"
          : "Today, ${DateFormat('hh:mm a').format(time)}";
    } else if (dateDiff.inDays == 1) {
      return isArabic
          ? "أمس، ${formatArabicTime(time)}"
          : "Yesterday, ${DateFormat('hh:mm a').format(time)}";
    } else {
      return isArabic
          ? "${formatArabicDate(time)}، ${formatArabicTime(time)}"
          : DateFormat('dd MMM, yyyy hh:mm a').format(time);
    }
  }

  String get formatDate {
    final time = DateTime.parse(this);
    if (SessionManager.instance.getLang() == 'ar') {
      return formatArabicDate(time);
    }
    return DateFormat('dd MMM, yyyy').format(time);
  }

  String get formatDate1 {
    final time = DateTime.parse(this);
    if (SessionManager.instance.getLang() == 'ar') {
      return formatArabicDate(time);
    }
    return DateFormat('dd MMMM yyyy').format(time);
  }

  String get addHash {
    return '#${replaceAll('#', '')}';
  }

  String get removeHash {
    return replaceAll('#', '');
  }

  Future<LinearGradient> get getGradientFromImage async {
    List<Color> colors = [];
    Uint8List imageBytes = await File(this).readAsBytes();
    print(imageBytes);
    try {
      DominantColors extractor =
          DominantColors(bytes: imageBytes, dominantColorsCount: 5);

      List<Color> dominantColors = extractor.extractDominantColors();
      colors = dominantColors;
    } catch (e) {
      colors.clear();
      print(e);
    }

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const [0.1, 1],
      colors: [colors.first, colors.last],
    );
  }
}

/// Converts western digits (0-9) to Eastern Arabic digits (٠-٩).
String _toArabicDigits(String input) {
  const List<String> western = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9'
  ];
  const List<String> eastern = [
    '٠',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩'
  ];
  String out = input;
  for (int i = 0; i < western.length; i++) {
    out = out.replaceAll(western[i], eastern[i]);
  }
  return out;
}

/// Formats a date in Arabic, e.g. "٢٤ سبتمبر ٢٠٢٦".
String formatArabicDate(DateTime time) {
  const List<String> months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر'
  ];
  return '${_toArabicDigits(time.day.toString())} ${months[time.month - 1]} ${_toArabicDigits(time.year.toString())}';
}

/// Formats a 12-hour time in Arabic, e.g. "٠٥:٣٠ م".
String formatArabicTime(DateTime time) {
  final int hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final String period = time.hour < 12 ? 'ص' : 'م';
  final String minutes = time.minute.toString().padLeft(2, '0');
  return '${_toArabicDigits(hour12.toString())}:${_toArabicDigits(minutes)} $period';
}
