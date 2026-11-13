import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// v1.1.38: local belt-and-braces crash log.
///
/// Sentry is the primary crash reporter, but it cannot report anything that
/// happens before its SDK is initialised, or if the device network blocks the
/// ingest endpoint. This service keeps the last fatal errors in a small local
/// file that can be shared from Settings -> "Share crash log".
class CrashLogService {
  CrashLogService._();

  static final CrashLogService instance = CrashLogService._();

  bool _installed = false;

  /// Hook Flutter framework errors and uncaught platform errors. Behaviour is
  /// unchanged: errors still propagate exactly as before, we only mirror them
  /// into the local file.
  void install() {
    if (_installed) return;
    _installed = true;
    try {
      final originalFlutterError = FlutterError.onError;
      FlutterError.onError = (details) {
        write('flutterError', details.exception, details.stack);
        originalFlutterError?.call(details);
      };
      final originalOnError = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (error, stack) {
        write('platformError', error, stack);
        return originalOnError?.call(error, stack) ?? false;
      };
    } catch (e) {
      Loggers.error('CrashLogService install failed: $e');
    }
  }

  Future<File> logFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/nimiro_last_crash.txt');
  }

  /// Appends one entry. Never throws into the caller.
  Future<void> write(String source, Object? error, StackTrace? stack) async {
    try {
      final file = await logFile();
      final ts = DateTime.now().toUtc().toIso8601String();
      final entry = '\n===== crash $ts (source: $source) =====\n'
          'error: $error\n'
          'stack:\n${stack ?? StackTrace.empty}\n';
      RandomAccessFile? raf;
      try {
        raf = await file.open(mode: FileMode.append);
        await raf.writeString(entry);
      } finally {
        await raf?.close();
      }
      // Keep the file small: drop the oldest content beyond 200 KB.
      final length = await file.length();
      if (length > 200 * 1024) {
        final bytes = await file.readAsBytes();
        final trimmed = bytes.sublist(bytes.length - 100 * 1024);
        await file.writeAsBytes(trimmed, mode: FileMode.write);
      }
    } catch (e) {
      Loggers.error('CrashLogService write failed: $e');
    }
  }

  /// Settings action: share the local crash file, or tell the user there is
  /// nothing to share yet.
  Future<void> shareLatest() async {
    try {
      final file = await logFile();
      if (!await file.exists()) {
        Get.snackbar(LKey.noCrashLog.tr, LKey.noCrashLogDesc.tr);
        return;
      }
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Nimiro crash log'),
      );
    } catch (e) {
      Loggers.error('CrashLogService share failed: $e');
    }
  }
}
