import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/service/api/api_service.dart';
import 'package:nimiro/common/service/utils/web_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Lightweight activity tracker: session heartbeats + content watch-time
/// events. Everything is batched (flush every 30s or 25 events) so battery
/// and data usage stay minimal. Sessions are sent as a heartbeat every 60s
/// and closed when the app goes to the background.
class ActivityTracker with WidgetsBindingObserver {
  ActivityTracker._();

  static final instance = ActivityTracker._();

  final List<Map<String, dynamic>> _events = [];
  Timer? _heartbeat;
  Timer? _flushTimer;
  DateTime? _lastFlushAt;
  DateTime? _sessionStart;
  String _sessionKey = '';
  bool _bound = false;
  DateTime? _backgroundedAt;
  String? _appVersion;

  /// When the app was last sent to the background. Attention timers use it
  /// so time spent away from the app is never counted as watch time.
  DateTime? get backgroundedAt => _backgroundedAt;

  /// Called once from the dashboard controller after a successful login.
  void start() {
    if (!_bound) {
      _bound = true;
      WidgetsBinding.instance.addObserver(this);
    }
    _loadAppVersion();
    _beginSession();
  }

  /// Reads the installed app version once so every session carries it.
  Future<void> _loadAppVersion() async {
    if (_appVersion != null) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (e) {
      Loggers.error('App version read failed: $e');
    }
  }

  void _beginSession() {
    if (_sessionStart != null) return;
    _sessionStart = DateTime.now();
    _sessionKey = '${_sessionStart!.millisecondsSinceEpoch}';
    _sendSession();

    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(
        const Duration(seconds: 60), (_) => _sendSession());
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => flushEvents());
  }

  void _endSession() {
    if (_sessionStart == null) return;
    _sendSession(end: true);
    _sessionStart = null;
    _heartbeat?.cancel();
    flushEvents();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _backgroundedAt = null;
      _beginSession();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _backgroundedAt = DateTime.now();
      _endSession();
    }
  }

  /// Reels / feed players report what was watched and for how long.
  /// `durationSeconds` lets the server rank by watch *percentage*; it is
  /// omitted when the player has not reported a duration yet.
  void addContentEvent(
      {required int postId,
      required String eventType,
      int watchSeconds = 0,
      int durationSeconds = 0}) {
    if (postId <= 0) return;
    _events.add({
      'post_id': postId,
      'event_type': eventType,
      'watch_seconds': watchSeconds,
      if (durationSeconds > 0) 'duration_seconds': durationSeconds,
      'occurred_at': DateTime.now().millisecondsSinceEpoch,
    });
    if (_events.length >= 25) flushEvents();
  }

  Future<void> flushEvents({bool force = false}) async {
    if (_events.isEmpty) return;
    final now = DateTime.now();
    // Page swipes ask for a flush too; keep that from becoming one request
    // per swipe while still delivering signals within ~10 seconds.
    if (!force &&
        _lastFlushAt != null &&
        now.difference(_lastFlushAt!).inSeconds < 10) {
      return;
    }
    _lastFlushAt = now;
    final batch = List<Map<String, dynamic>>.of(_events);
    _events.clear();
    try {
      await ApiService.instance.call(
        url: WebService.activity.trackEvents,
        param: {
          'events': jsonEncode(batch),
          if (_sessionKey.isNotEmpty) 'session_key': _sessionKey,
        },
      );
    } catch (e) {
      // Keep the signals for the next attempt (bounded so a persistent
      // failure cannot grow memory forever).
      if (_events.length < 200) _events.insertAll(0, batch);
      Loggers.error('ActivityTracker flush failed: $e');
    }
  }

  Future<void> _sendSession({bool end = false}) async {
    if (_sessionStart == null) return;
    try {
      await ApiService.instance.call(
        url: WebService.activity.trackSession,
        param: {
          'session_key': _sessionKey,
          'started_at': _sessionStart!.millisecondsSinceEpoch,
          if (end) 'ended_at': DateTime.now().millisecondsSinceEpoch,
          'platform': Platform.isIOS ? 'ios' : 'android',
          if (_appVersion != null) 'app_version': _appVersion,
        },
      );
    } catch (e) {
      Loggers.error('ActivityTracker session failed: $e');
    }
  }
}
