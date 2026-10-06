import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart' as getx;
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/utilities/const_res.dart';

/// Upload queue that keeps running after the app is closed.
///
/// On Android the queue is owned by a foreground service (WorkManager-free,
/// no execution time cap) which shows a progress notification, so uploads of
/// stories, posts and chat media survive the user closing the app.
///
/// On iOS the queue is processed inline while the app runs (iOS does not
/// permit long-running background services; closing the app there still
/// cancels - platform limitation).
///
/// A job is a list of steps:
///   {'kind': 'multipart', 'url': ..., 'fields': {...}, 'files': [{'field': 'file', 'path': '/abs/path'}]}
///   {'kind': 'api',      'url': ..., 'fields': {...}}
///
/// Field values may reference earlier results with '@s<index>' followed by a
/// json path, e.g. '@s2.data' or '@s1.data.id' (s1 = result of step 1,
/// zero-based). The multipart results come from `uploadFileGivePath` which
/// returns `{status, message, data: <server path>}`.
class UploadQueueService {
  UploadQueueService._();

  static final UploadQueueService instance = UploadQueueService._();

  static const String boxName = 'nimiro';
  static const String queueKey = 'upload_queue_v1';

  GetStorage get _box => GetStorage(boxName);

  List<Map<String, dynamic>> _queue() {
    final raw = _box.read(queueKey);
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> _saveQueue(List<Map<String, dynamic>> q) =>
      _box.write(queueKey, q);

  static bool _svcListening = false;
  static void _listenServiceEvents(FlutterBackgroundService service) {
    if (_svcListening) return;
    _svcListening = true;
    service.on('svc_event').listen((e) {
      final m = e?['msg'];
      if (m != null) _debug('service: $m');
    });
  }

  static void _debug(String message) {
    Loggers.error('UploadDebug: $message');
    try {
      getx.Get.snackbar('UPLOAD DEBUG', message,
          duration: const Duration(seconds: 8));
    } catch (_) {}
  }

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
    _listenServiceEvents(service);
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

  /// Enqueue [steps] and wait for the chain result (works even when the app
  /// is backgrounded; if the app was killed the job still completes and the
  /// result is read back on the next open).
  Future<Map<String, dynamic>?> submit(
    List<Map<String, dynamic>> steps, {
    void Function(double progress)? onProgress,
  }) async {
    _debug('submit entered, steps=${steps.length}');
    try {
      await ensureConfigured();
    } catch (e) {
      _debug('ensureConfigured failed: $e');
      return {'__error': 'Upload setup failed: $e'};
    }

    // Drop stale finished jobs before enqueueing the new one.
    final now = DateTime.now().millisecondsSinceEpoch;
    final pruned = _queue().where((j) {
      return !(j['status'] == 'done' && now - (j['finishedAt'] as int? ?? 0) > 600000);
    }).toList();
    await _saveQueue(pruned);

    final tag = 'u$now${Random().nextInt(999)}';
    final job = <String, dynamic>{
      'tag': tag,
      'status': 'queued',
      'progress': 0.0,
      'step': 0,
      'steps': steps,
      'results': <Map<String, dynamic>>[],
      'response': null,
      'error': null,
      'createdAt': now,
    };
    pruned.add(job);
    await _saveQueue(pruned);

    if (Platform.isAndroid) {
      final service = FlutterBackgroundService();
      try {
        if (!await service.isRunning()) {
          final started = await service.startService();
          _debug('startService returned: $started');
        }
        service.invoke('kick');
      } catch (e) {
        _debug('starting the upload service failed: $e');
        return {'__error': 'Upload service failed to start: $e'};
      }
      for (final secs in [6, 20]) {
        Timer(Duration(seconds: secs), () async {
          try {
            final running = await service.isRunning();
            final q = _queue();
            final i = q.indexWhere((e) => e['tag'] == tag);
            final st = i < 0 ? 'missing' : '${q[i]['status']}';
            if (st == 'done') return;
            _debug('after ${secs}s: service running=$running, job=$st');
          } catch (e) {
            _debug('status check failed: $e');
          }
        });
      }
    } else {
      unawaited(processQueue());
    }

    final completer = Completer<Map<String, dynamic>?>();
    Timer? poller;
    Timer? giveUpTimer;
    void finish(Map<String, dynamic>? result) {
      if (completer.isCompleted) return;
      poller?.cancel();
      giveUpTimer?.cancel();
      completer.complete(result);
    }
    void check() {
      final q = _queue();
      final i = q.indexWhere((e) => e['tag'] == tag);
      if (i < 0) return;
      final j = q[i];
      if (onProgress != null) {
        onProgress((j['progress'] as num?)?.toDouble() ?? 0.0);
      }
      final status = j['status'];
      if (status == 'done') {
        finish(Map<String, dynamic>.from(j['response'] as Map? ?? {}));
      } else if (status == 'failed') {
        finish({'__error': j['error']});
      }
    }

    poller = Timer.periodic(const Duration(milliseconds: 400), (_) => check());
    // Safety net: if the job never reaches 'done' or 'failed' (e.g. the
    // background service failed to start), the caller must not be left
    // waiting on a spinner forever.
    giveUpTimer = Timer(const Duration(minutes: 5), () {
      finish({'__error': 'Upload timed out. Please try again.'});
    });
    check();
    return completer.future;
  }

  // ---------------------------------------------------------------- service

  @pragma('vm:entry-point')
  static Future<bool> onServiceStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();
    try {
      service.invoke('svc_event', {'msg': 'service isolate started'});
      await GetStorage.init(boxName);
      final pending = GetStorage(boxName).read(queueKey);
      service.invoke('svc_event', {
        'msg': 'storage ready, queue=${pending is List ? pending.length : -1}'
      });
      _requeueStaleRunningJobs();
      service.on('kick').listen((_) => unawaited(processQueue(service)));
      await processQueue(service);
    } catch (e) {
      service.invoke('svc_event', {'msg': 'service crashed: $e'});
    }
    return true;
  }

  /// If the OS killed the service mid-job, the job is stuck in 'running'
  /// forever. A freshly started service is the only processor, so any
  /// 'running' job it finds must be stale -> requeue it.
  static void _requeueStaleRunningJobs() {
    final box = GetStorage(boxName);
    final raw = box.read(queueKey);
    if (raw is! List) return;
    final q = raw.whereType<Map<String, dynamic>>().toList();
    var changed = false;
    for (final j in q) {
      if (j['status'] == 'running') {
        j['status'] = 'queued';
        changed = true;
      }
    }
    if (changed) box.write(queueKey, q);
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    await GetStorage.init(boxName);
    return true;
  }

  static bool _processing = false;

  static Future<void> processQueue([ServiceInstance? service]) async {
    // A 'kick' can arrive while a job is already running; process one queue
    // at a time so queue writes from concurrent loops never clobber each
    // other.
    if (_processing) return;
    _processing = true;
    final box = GetStorage(boxName);
    try {
      while (true) {
        final raw = box.read(queueKey);
        if (raw is! List || raw.isEmpty) {
          if (service != null && Platform.isAndroid) service.stopSelf();
          return;
        }
        final queue = raw.whereType<Map<String, dynamic>>().toList();
        final index = queue.indexWhere((j) => j['status'] == 'queued');
        if (index < 0) {
          if (service != null && Platform.isAndroid) service.stopSelf();
          return;
        }
        final job = queue[index];
        job['status'] = 'running';
        queue[index] = job;
        await box.write(queueKey, queue);
        try {
          service?.invoke('svc_event', {'msg': 'picked job ${job['tag']}'});
          await _runJob(job, service);
        } catch (e) {
          job['status'] = 'failed';
          job['error'] = '$e';
          queue[index] = job;
          await box.write(queueKey, queue);
          Loggers.error('UploadQueue job failed: $e');
          // Keep the loop going: other queued jobs still deserve a try.
        }
      }
    } finally {
      _processing = false;
    }
  }

  static Future<void> _runJob(
      Map<String, dynamic> job, ServiceInstance? service) async {
    final box = GetStorage(boxName);
    final steps = (job['steps'] as List).cast<Map<String, dynamic>>();
    final results = <Map<String, dynamic>>[];

    for (int i = 0; i < steps.length; i++) {
      final step = _resolvePlaceholders(steps[i], results);
      Map<String, dynamic>? res;
      try {
        if (step['kind'] == 'api') {
          res = await _postApi(step);
        } else {
          res = await _postMultipart(step, onProgress: (p) {
            job['progress'] = (i + p) / steps.length;
            job['finishedAt'] = DateTime.now().millisecondsSinceEpoch;
            _persistAsync(box, job);
            _updateNotification(service, job);
          });
        }
      } catch (e) {
        res = null;
        Loggers.error('UploadQueue step $i error: $e');
      }

      if (res == null || res['status'] != true) {
        job['status'] = 'failed';
        job['error'] = res?['message'] ?? 'upload failed at step $i';
        service?.invoke('svc_event', {'msg': 'step $i failed: ${job['error']}'});
        await _persistAsync(box, job);
        _updateNotification(service, job);
        return;
      }

      results.add(res);
      job['step'] = i + 1;
      job['progress'] = (i + 1) / steps.length;
      job['finishedAt'] = DateTime.now().millisecondsSinceEpoch;
      await _persistAsync(box, job);
      _updateNotification(service, job);
    }

    job['status'] = 'done';
    job['progress'] = 1.0;
    job['response'] = results.isEmpty ? <String, dynamic>{} : results.last;
    job['finishedAt'] = DateTime.now().millisecondsSinceEpoch;
    await _persistAsync(box, job);
    _updateNotification(service, job);
  }

  static Future<void> _persistAsync(
      GetStorage box, Map<String, dynamic> job) async {
    final raw = box.read(queueKey);
    if (raw is! List) return;
    final q = raw.whereType<Map<String, dynamic>>().toList();
    final i = q.indexWhere((e) => e['tag'] == job['tag']);
    if (i >= 0) {
      q[i] = job;
      box.write(queueKey, q);
    }
  }

  static void _updateNotification(ServiceInstance? service, job) {
    if (service == null || !Platform.isAndroid) return;
    try {
      final p = ((job['progress'] as num?)?.toDouble() ?? 0.0) * 100;
      // setNotificationInfo exists on the Android implementation of
      // ServiceInstance; the base interface does not declare it.
      (service as dynamic).setNotificationInfo(
        title: 'Nimiro',
        content: p >= 100
            ? 'Upload finished'
            : 'Uploading media... ${p.round()}%',
      );
    } catch (e) {
      // notification updates are best-effort
    }
  }

  /// Replace '@s<i>[.json.path]' references in field values with the
  /// corresponding step results.
  static Map<String, dynamic> _resolvePlaceholders(
      Map<String, dynamic> step, List<Map<String, dynamic>> results) {
    final fields = <String, dynamic>{};
    final srcFields = step['fields'];
    if (srcFields is Map) {
      srcFields.forEach((key, value) {
        fields['$key'] = _resolveValue(value, results);
      });
    }
    return {
      ...step,
      'fields': fields,
    };
  }

  static dynamic _resolveValue(
      dynamic value, List<Map<String, dynamic>> results) {
    if (value is! String || !value.startsWith('@s')) return value;
    final parts = value.substring(1).split('.');
    final idx = int.tryParse(parts.first.substring(1));
    if (idx == null || idx >= results.length) return value;
    dynamic current = results[idx];
    for (int i = 1; i < parts.length && current is Map; i++) {
      current = current[parts[i]];
    }
    return current is String || current is num || current is bool
        ? current
        : value;
  }

  static String? _authToken(GetStorage box) {
    try {
      final raw = box.read('authToken');
      // BUG FIX: the stored map's field is 'auth_token' (matches Token.toJson()/
      // Token.fromJson(), which use the API's snake_case field names) - reading
      // 'authToken' here always returned null, so every background upload went
      // out with no auth header at all and failed silently.
      if (raw is Map) return raw['auth_token'] as String?;
    } catch (_) {}
    return null;
  }

  // ------------------------------------------------------------------ http

  static Future<Map<String, dynamic>?> _postApi(
      Map<String, dynamic> step) async {
    final box = GetStorage(boxName);
    final uri = Uri.parse(step['url'] as String);
    final headers = <String, String>{
      'apikey': apiKey,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    final token = _authToken(box);
    if (token != null && token.isNotEmpty && token != 'AUTH TOKEN EMPTY') {
      headers['AUTHTOKEN'] = token;
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final req = await client.postUrl(uri);
      headers.forEach(req.headers.set);
      final body = jsonEncode(step['fields'] ?? {});
      req.add(utf8.encode(body));
      final resp = await req.close();
      final text = await utf8.decodeStream(resp);
      return _decode(text);
    } catch (e) {
      Loggers.error('UploadQueue api step failed: $e');
      return null;
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>?> _postMultipart(
    Map<String, dynamic> step, {
    void Function(double progress)? onProgress,
  }) async {
    final box = GetStorage(boxName);
    final uri = Uri.parse(step['url'] as String);
    final boundary = '----nimiro${DateTime.now().microsecondsSinceEpoch}';
    final files = (step['files'] as List? ?? [])
        .whereType<Map>()
        .where((f) => f['path'] is String && (f['path'] as String).isNotEmpty)
        .toList();
    final fields = step['fields'] as Map? ?? {};

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader,
          'multipart/form-data; boundary=$boundary');
      req.headers.set('apikey', apiKey);
      req.headers.set('Accept', 'application/json');
      final token = _authToken(box);
      if (token != null && token.isNotEmpty && token != 'AUTH TOKEN EMPTY') {
        req.headers.set('AUTHTOKEN', token);
      }

      // Precompute total length for progress (approximation: files dominate).
      int total = 0;
      for (final f in files) {
        try {
          total += File(f['path'] as String).lengthSync();
        } catch (_) {}
      }
      final sb = StringBuffer();
      fields.forEach((key, value) {
        sb.write('--$boundary\r\n');
        sb.write('Content-Disposition: form-data; name="$key"\r\n\r\n');
        sb.write('$value\r\n');
      });
      req.add(utf8.encode(sb.toString()));

      int sent = 0;
      for (final f in files) {
        final path = f['path'] as String;
        final field = (f['field'] as String?) ?? 'file';
        final file = File(path);
        final header =
            '--$boundary\r\nContent-Disposition: form-data; name="$field"; '
            'filename="${Uri.encodeComponent(file.uri.pathSegments.last)}"\r\n'
            'Content-Type: application/octet-stream\r\n\r\n';
        req.add(utf8.encode(header));
        await for (final chunk in file.openRead()) {
          sent += chunk.length;
          req.add(chunk);
          if (onProgress != null && total > 0) {
            onProgress((sent / max(total, 1)).clamp(0.0, 1.0));
          }
        }
        req.add(utf8.encode('\r\n'));
      }
      req.add(utf8.encode('--$boundary--\r\n'));

      final resp = await req.close();
      final text = await utf8.decodeStream(resp);
      return _decode(text);
    } catch (e) {
      Loggers.error('UploadQueue multipart step failed: $e');
      return null;
    } finally {
      client.close();
    }
  }

  static Map<String, dynamic>? _decode(String text) {
    if (text.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return null;
  }
}
