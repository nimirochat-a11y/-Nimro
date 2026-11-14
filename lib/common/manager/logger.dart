import 'dart:developer' as developer;

class Loggers {
  /// Optional hook used by CrashLogService so every handled error is queued
  /// for the admin panel. Wrapped so logging can never throw.
  static void Function(Object? message)? onError;

  static void info(Object? msg) {
    developer.log('$msg', name: 'INFO');
  }

  static void success(Object? msg) {
    developer.log('✅✅✅: $msg', name: 'SUCCESS');
  }

  static void warning(Object? msg) {
    developer.log('⚠️⚠️⚠️: $msg', name: 'WARNING');
  }

  static void error(Object? msg) {
    developer.log('🔴🔴🔴: $msg', name: 'ERROR');
    try {
      onError?.call(msg);
    } catch (_) {}
  }
}
