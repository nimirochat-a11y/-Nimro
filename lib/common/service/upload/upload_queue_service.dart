import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/utilities/const_res.dart';

class UploadQueueService {
  UploadQueueService._();
  static final UploadQueueService instance = UploadQueueService._();

  static const String boxName = 'nimiro';
  static const String queueKey = 'upload_queue_v1';
  static const String _eventName = 'upload_event';

  static final StreamController<Map<String, dynamic>> _localEvents =
      StreamController<Map<String, dynamic>>.broadcast();
  static final List<Map<String, dynamic>> _jobs = [];
  static final Set<String> _cancelled = {};
  static bool _processing = false;

  Future<void> ensureConfigured() async {
    if (!Platform.isAndroid) return;
    try {
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            'nimiro_upload',
            'Uploads',
            description: 'Shows media upload progress',
            importance: Importance.low,
          ));
    } catch (e) {
      Loggers.error('Upload channel creation failed: $e');
    }
    final service = FlutterBackgroundService();
    if (await service.isRunning()) return;
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onServiceStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'nimiro_upload',
        initialNotificationTitle: 'Nimiro',
        initialNotificationContent: 'Preparing media upload...',
        foregroundServiceNotificationId: 8901,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onServiceStart,
        onBackground: onIosBackground,
      ),
    );
  }

  Future<Map<String, dynamic>?> submit(
    List<Map<String, dynamic>> steps, {
    void Function(double progress)? onProgress,
  }) async {
    await ensureConfigured();
    final now = DateTime.now().millisecondsSinceEpoch;
    final tag = 'u$now${Random().nextInt(999)}';
    final job = <String, dynamic>{
      'tag': tag,
      'steps': steps,
      'authToken': _authToken(GetStorage(boxName)),
    };
    final completer = Completer<Map<String, dynamic>?>();
    StreamSubscription? sub;
    Timer? resend;
    Timer? aliveWatchdog;
    Timer? ackWatchdog;
    Timer? giveUp;
    bool alive = false;
    bool acked = false;

    void finish(Map<String, dynamic>? result) {
      if (completer.isCompleted) return;
      sub?.cancel();
      resend?.cancel();
      aliveWatchdog?.cancel();
      ackWatchdog?.cancel();
      giveUp?.cancel();
      completer.complete(result);
    }

    void onEvent(Map<String, dynamic>? e) {
      if (e == null) return;
      alive = true;
      final type = e['type'];
      if (type == 'service_error') {
        finish({'__error': e['error'] ?? 'Upload service failed'});
        return;
      }
      if (e['tag'] != tag) return;
      acked = true;
      if (onProgress != null && e['progress'] is num) {
        onProgress((e['progress'] as num).toDouble());
      }
      if (type == 'done') {
        Map<String, dynamic> response = {};
        final raw = e['response'];
        try {
          if (raw is String && raw.isNotEmpty) {
            response = Map<String, dynamic>.from(jsonDecode(raw) as Map);
          } else if (raw is Map) {
            response = Map<String, dynamic>.from(raw);
          }
        } catch (_) {}
        finish(response);
      } else if (type == 'failed') {
        finish({'__error': e['error'] ?? 'Upload failed'});
      }
    }

    void startInline() {
      if (completer.isCompleted) return;
      resend?.cancel();
      sub?.cancel();
      try {
        FlutterBackgroundService().invoke('cancel', {'tag': tag});
      } catch (_) {}
      Loggers.error('Upload service silent, uploading inside the app');
      sub = _localEvents.stream.listen(onEvent);
      _enqueue(Map<String, dynamic>.from(job), null);
    }

    if (Platform.isAndroid) {
      final service = FlutterBackgroundService();
      sub = service.on(_eventName).listen(onEvent);
      Future<void> send() async {
        if (acked || completer.isCompleted) return;
        try {
          if (!await service.isRunning()) await service.startService();
          service.invoke('enqueue', {'job': jsonEncode(job)});
        } catch (e) {
          Loggers.error('Upload enqueue failed: $e');
        }
      }

      unawaited(send());
      resend = Timer.periodic(
          const Duration(milliseconds: 1500), (_) => unawaited(send()));
      aliveWatchdog = Timer(const Duration(seconds: 10), () {
        if (!alive) startInline();
      });
      ackWatchdog = Timer(const Duration(seconds: 30), () {
        if (!acked) {
          finish({'__error': 'Upload service did not respond'});
        }
      });
    } else {
      sub = _localEvents.stream.listen(onEvent);
      _enqueue(Map<String, dynamic>.from(job), null);
    }
    giveUp = Timer(const Duration(minutes: 30), () {
      finish({'__error': 'Upload timed out. Please try again.'});
    });
    return completer.future;
  }

