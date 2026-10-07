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

  static bool _configured = false;
  static int _activeUploads = 0;
  static int _lastNotify = 0;

  Future<void> ensureConfigured() async {
    if (!Platform.isAndroid || _configured) return;
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'nimiro_upload',
          'Uploads',
          description: 'Shows media upload progress',
          importance: Importance.low,
        ));
    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onServiceStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'nimiro_upload',
        initialNotificationTitle: 'Nimiro',
        initialNotificationContent: 'Uploading media...',
        foregroundServiceNotificationId: 8901,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onServiceStart,
        onBackground: onIosBackground,
      ),
    );
    _configured = true;
  }

  static Future<void> _keepAliveStart() async {
    _activeUploads++;
    if (!Platform.isAndroid) return;
    try {
      await instance.ensureConfigured();
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        await service.startService();
      }
    } catch (e) {
      Loggers.error('Keep-alive service failed to start: $e');
    }
  }

  static void _keepAliveStop() {
    if (_activeUploads > 0) _activeUploads--;
    if (_activeUploads > 0 || !Platform.isAndroid) return;
    try {
      FlutterBackgroundService().invoke('stop');
    } catch (_) {}
  }

  static void _keepAliveProgress(double progress) {
    if (!Platform.isAndroid) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNotify < 1000 && progress < 1) return;
    _lastNotify = now;
    try {
      FlutterBackgroundService().invoke('progress', {'p': progress});
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> submit(
    List<Map<String, dynamic>> steps, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      await _keepAliveStart().timeout(const Duration(seconds: 8));
    } catch (e) {
      Loggers.error('Keep-alive setup skipped: $e');
    }
    final job = <String, dynamic>{
      'tag': 'u${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(999)}',
      'steps': steps,
    };
    try {
      return await _runJob(job, (p) {
        if (onProgress != null) onProgress(p);
        _keepAliveProgress(p);
      });
    } catch (e) {
      Loggers.error('Upload failed: $e');
      return {'__error': '$e'};
    } finally {
      _keepAliveStop();
    }
  }

  static Future<Map<String, dynamic>> _runJob(
      Map<String, dynamic> job, void Function(double) onProgress) async {
    final steps = (job['steps'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final token = _authToken(GetStorage(boxName));
    final results = <Map<String, dynamic>>[];
    onProgress(0.0);
    for (int i = 0; i < steps.length; i++) {
      final step = _resolvePlaceholders(steps[i], results);
      Map<String, dynamic>? res;
      String? failure;
      try {
        if (step['kind'] == 'api') {
          res = await _postApi(step, token)
              .timeout(const Duration(seconds: 90));
        } else {
          res = await _postMultipart(step, token, onProgress: (p) {
            onProgress((i + p) / steps.length);
          }).timeout(const Duration(minutes: 30));
        }
      } catch (e) {
        failure = e is TimeoutException
            ? 'Upload timed out. Please try again.'
            : '$e'.replaceFirst('Exception: ', '');
      }
      if (res == null || res['status'] != true) {
        final String reason = failure ??
            (res?['message'] ?? 'Upload failed at step ${i + 1}').toString();
        return {'__error': reason};
      }
      results.add(res);
      onProgress((i + 1) / steps.length);
    }
    return results.isEmpty ? <String, dynamic>{} : results.last;
  }

  @pragma('vm:entry-point')
  static Future<bool> onServiceStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();
    service.on('stop').listen((_) => service.stopSelf());
    service.on('progress').listen((e) {
      try {
        final p = ((e?['p'] as num?)?.toDouble() ?? 0.0) * 100;
        (service as dynamic).setNotificationInfo(
          title: 'Nimiro',
          content: p >= 100
              ? 'Upload finished'
              : 'Uploading media... ${p.round()}%',
        );
      } catch (_) {}
    });
    Timer(const Duration(minutes: 40), () => service.stopSelf());
    return true;
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    return true;
  }

  static Future<void> processQueue([ServiceInstance? service]) async {}

  static Map<String, dynamic> _resolvePlaceholders(
      Map<String, dynamic> step, List<Map<String, dynamic>> results) {
    final fields = <String, dynamic>{};
    final srcFields = step['fields'];
    if (srcFields is Map) {
      srcFields.forEach((key, value) {
        fields['$key'] = _resolveValue(value, results);
      });
    }
    return {...step, 'fields': fields};
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
      if (raw is Map) return raw['auth_token'] as String?;
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>> _postApi(
      Map<String, dynamic> step, String? token) async {
    final uri = Uri.parse(step['url'] as String);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final req = await client.postUrl(uri);
      req.headers.set('apikey', apiKey);
      req.headers.set('Accept', 'application/json');
      req.headers.set('Content-Type', 'application/json');
      if (token != null && token.isNotEmpty && token != 'AUTH TOKEN EMPTY') {
        req.headers.set('AUTHTOKEN', token);
      }
      req.add(utf8.encode(jsonEncode(step['fields'] ?? {})));
      final resp = await req.close();
      final text = await utf8.decodeStream(resp);
      return _decode(text) ??
          {'status': false, 'message': 'Server error (HTTP ${resp.statusCode})'};
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> _postMultipart(
    Map<String, dynamic> step,
    String? token, {
    void Function(double progress)? onProgress,
  }) async {
    final uri = Uri.parse(step['url'] as String);
    final boundary = '----nimiro${DateTime.now().microsecondsSinceEpoch}';
    final fields = step['fields'] as Map? ?? {};
    final sb = StringBuffer();
    fields.forEach((key, value) {
      sb.write('--$boundary\r\n');
      sb.write('Content-Disposition: form-data; name="$key"\r\n\r\n');
      sb.write('$value\r\n');
    });
    final preamble = utf8.encode(sb.toString());
    final closing = utf8.encode('--$boundary--\r\n');
    final files = <File>[];
    final heads = <List<int>>[];
    int fileBytes = 0;
    int total = preamble.length + closing.length;
    for (final f in (step['files'] as List? ?? []).whereType<Map>()) {
      final path = f['path'];
      if (path is! String || path.isEmpty) continue;
      final file = File(path);
      if (!await file.exists()) {
        throw Exception(
            'The selected file is no longer available, please try again');
      }
      final field = (f['field'] as String?) ?? 'file';
      final head = utf8.encode(
          '--$boundary\r\nContent-Disposition: form-data; name="$field"; '
          'filename="${Uri.encodeComponent(file.uri.pathSegments.last)}"\r\n'
          'Content-Type: application/octet-stream\r\n\r\n');
      final len = await file.length();
      files.add(file);
      heads.add(head);
      fileBytes += len;
      total += head.length + len + 2;
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader,
          'multipart/form-data; boundary=$boundary');
      req.headers.set('apikey', apiKey);
      req.headers.set('Accept', 'application/json');
      if (token != null && token.isNotEmpty && token != 'AUTH TOKEN EMPTY') {
        req.headers.set('AUTHTOKEN', token);
      }
      req.contentLength = total;
      req.add(preamble);
      int sent = 0;
      for (int i = 0; i < files.length; i++) {
        req.add(heads[i]);
        await req.addStream(files[i].openRead().map((chunk) {
          sent += chunk.length;
          if (onProgress != null && fileBytes > 0) {
            onProgress((sent / fileBytes).clamp(0.0, 1.0).toDouble());
          }
          return chunk;
        }));
        req.add(const [13, 10]);
      }
      req.add(closing);
      final resp = await req.close();
      final text = await utf8.decodeStream(resp);
      return _decode(text) ??
          {'status': false, 'message': 'Server error (HTTP ${resp.statusCode})'};
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
