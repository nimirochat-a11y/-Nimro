import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/utilities/const_res.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Automatic crash reporting for the Nimiro admin panel (v1.1.41).
///
/// Every fatal error (Flutter framework errors, uncaught platform errors and
/// startup failures) is written to a local queue and uploaded to
/// `POST /api/misc/reportCrash`. Reports that cannot be uploaded (offline,
/// server down) stay in the queue and are retried on the next app start.
///
/// Behaviour is unchanged: errors still propagate exactly as before — this
/// service only mirrors them to the panel. Uploading is best-effort and can
/// never crash or block the app.
class CrashLogService {
  CrashLogService._();

  static final CrashLogService instance = CrashLogService._();

  static const int _maxQueuedReports = 50;
  static const int _maxLogBytes = 200 * 1024;
  static const int _trimLogBytes = 100 * 1024;

  bool _installed = false;
  bool _flushing = false;
  bool _reportingMessage = false;
  final Map<String, DateTime> _recentMessages = {};

  /// Hook Flutter framework errors, uncaught platform errors and handled
  /// errors logged through [Loggers.error].
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
      // Handled errors (API failures, caught Firestore exceptions...) are
      // logged through Loggers.error; mirror them to the panel as well.
      Loggers.onError = reportMessage;
      try {
        WidgetsBinding.instance.addObserver(_CrashLifecycleObserver());
      } catch (_) {}
    } catch (e) {
      Loggers.error('CrashLogService install failed: $e');
    }
  }

  Future<File> logFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/nimiro_last_crash.txt');
  }

  Future<File> _queueFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/nimiro_crash_queue.jsonl');
  }

  /// Records one fatal error locally and queues it for the admin panel.
  /// Never throws into the caller.
  Future<void> write(String source, Object? error, StackTrace? stack) async {
    try {
      await _appendLocalLog(source, error, stack);
      await _enqueue(source, error, stack);
    } catch (e) {
      Loggers.error('CrashLogService write failed: $e');
    }
  }

  /// Called for every handled error logged through [Loggers.error].
  ///
  /// Identical messages are deduplicated for 5 minutes so a failing endpoint
  /// or an offline device cannot flood the admin panel. Never throws.
  void reportMessage(Object? message) {
    if (_reportingMessage) return;
    _reportingMessage = true;
    try {
      final text = (message ?? 'Unknown error').toString();
      if (text.trim().isEmpty) return;
      // Guard against feedback loops from this service's own log calls.
      if (text.contains('CrashLogService')) return;

      final key = _limit(text, 200);
      final now = DateTime.now();
      final last = _recentMessages[key];
      if (last != null && now.difference(last) < const Duration(minutes: 5)) {
        return;
      }
      _recentMessages[key] = now;
      if (_recentMessages.length > 100) {
        final cutoff = now.subtract(const Duration(minutes: 5));
        _recentMessages.removeWhere((_, time) => time.isBefore(cutoff));
        if (_recentMessages.length > 100) {
          _recentMessages.remove(_recentMessages.keys.first);
        }
      }

      unawaited(_enqueue('app:error', text, StackTrace.current));
    } catch (_) {
    } finally {
      _reportingMessage = false;
    }
  }

  Future<void> _enqueue(String source, Object? error, StackTrace? stack) async {
    try {
      final report = await _buildReport(source, error, stack);
      final queue = await _queueFile();
      await queue.writeAsString(
        '${jsonEncode(report)}\n',
        mode: FileMode.append,
        flush: true,
      );
      await _trimQueue(queue);

      // Fire-and-forget: uploading must never delay error propagation.
      unawaited(flush());
    } catch (e) {
      Loggers.error('CrashLogService enqueue failed: $e');
    }
  }

  /// Human-readable local log (kept for on-device debugging).
  Future<void> _appendLocalLog(
      String source, Object? error, StackTrace? stack) async {
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
    if (length > _maxLogBytes) {
      final bytes = await file.readAsBytes();
      final trimmed = bytes.sublist(bytes.length - _trimLogBytes);
      await file.writeAsBytes(trimmed, mode: FileMode.write);
    }
  }

  Future<Map<String, String>> _buildReport(
      String source, Object? error, StackTrace? stack) async {
    var appVersion = '';
    var buildNumber = '';
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = info.version;
      buildNumber = info.buildNumber;
    } catch (_) {}

    var deviceModel = '';
    var osVersion = '';
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        deviceModel = '${android.manufacturer} ${android.model}'.trim();
        osVersion = 'Android ${android.version.release} '
            '(SDK ${android.version.sdkInt})';
      } else if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        deviceModel = ios.utsname.machine;
        osVersion = 'iOS ${ios.systemVersion}';
      } else {
        osVersion = Platform.operatingSystemVersion;
      }
    } catch (_) {
      osVersion = Platform.operatingSystemVersion;
    }

    int? userId;
    try {
      final id = SessionManager.instance.getUserID();
      if (id > 0) userId = id;
    } catch (_) {}

    final report = <String, String>{
      'error_type': _limit(_errorType(source, error), 64),
      'error_message': _limit(error?.toString() ?? 'Unknown error', 4000),
      'stack_trace': _limit(stack?.toString() ?? '', 60000),
      'app_version': _limit(appVersion, 32),
      'build_number': _limit(buildNumber, 32),
      'platform': Platform.isAndroid
          ? 'android'
          : (Platform.isIOS ? 'ios' : Platform.operatingSystem),
      'device_model': _limit(deviceModel, 120),
      'os_version': _limit(osVersion, 160),
    };
    if (userId != null) {
      report['user_id'] = '$userId';
    }
    return report;
  }

  String _errorType(String source, Object? error) {
    final name = error?.runtimeType.toString() ?? 'Error';
    return '$source:$name';
  }

  String _limit(String value, int max) {
    if (value.length <= max) return value;
    return value.substring(0, max);
  }

  /// Uploads every queued report, oldest first. Stops at the first failure so
  /// the remaining reports are retried later; successfully sent ones are
  /// removed from the queue.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final file = await _queueFile();
      if (!await file.exists()) return;
      final lines = await file.readAsLines();
      if (lines.isEmpty) return;

      final remaining = <String>[];
      var failed = false;
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        if (failed) {
          remaining.add(line);
          continue;
        }
        Map<String, dynamic> report;
        try {
          report = jsonDecode(line) as Map<String, dynamic>;
        } catch (_) {
          // Corrupt line: drop it instead of retrying forever.
          continue;
        }
        final sent = await _send(report);
        if (!sent) {
          failed = true;
          remaining.add(line);
        }
      }

      await file.writeAsString(
        remaining.isEmpty ? '' : '${remaining.join('\n')}\n',
        flush: true,
      );
    } catch (e) {
      Loggers.error('CrashLogService flush failed: $e');
    } finally {
      _flushing = false;
    }
  }

  Future<bool> _send(Map<String, dynamic> report) async {
    try {
      final body = <String, String>{};
      report.forEach((key, value) {
        if (value != null) body[key] = value.toString();
      });

      var language = 'ar';
      try {
        language = SessionManager.instance.getLang();
      } catch (_) {}

      final response = await http
          .post(
            Uri.parse('${apiURL}misc/reportCrash'),
            headers: {
              'apikey': apiKey,
              'lang': language,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        return decoded is Map && decoded['status'] == true;
      }
      return false;
    } catch (e) {
      Loggers.error('CrashLogService send failed: $e');
      return false;
    }
  }

  /// Keeps the queue bounded so a permanently offline device cannot grow the
  /// file without limit. Oldest reports are dropped first.
  Future<void> _trimQueue(File queue) async {
    try {
      final lines = await queue.readAsLines();
      final valid = lines.where((line) => line.trim().isNotEmpty).toList();
      if (valid.length <= _maxQueuedReports) return;
      final kept = valid.sublist(valid.length - _maxQueuedReports);
      await queue.writeAsString('${kept.join('\n')}\n', flush: true);
    } catch (e) {
      Loggers.error('CrashLogService trim failed: $e');
    }
  }
}

/// Retries queued crash reports whenever the app comes back to the foreground
/// (e.g. after the network was restored while the app was in background).
class _CrashLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(CrashLogService.instance.flush());
    }
  }
}
