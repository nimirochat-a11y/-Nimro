import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/utilities/const_res.dart';

/// Durable upload queue.
///
/// Every upload is written to a small JSON job file *before* any byte is sent.
/// On Android the actual work runs inside the foreground service isolate, so
/// leaving the app (or Android reclaiming the UI) does not cancel it. If the
/// service is killed anyway, the watchdog restarts it and [processQueue]
/// resumes every job that is still `pending` or `running`. The same files are
/// replayed on the next app launch.
///
/// The UI isolate only appends a job, starts the service and polls that job's
/// file for progress/result. All network and file work happens in one place
/// (the service isolate), which keeps the queue free of cross-isolate races.
class UploadQueueService {
  UploadQueueService._();
  static final UploadQueueService instance = UploadQueueService._();

  static const String queueDirName = 'nimiro_upload_queue';
  static const String _channelId = 'nimiro_upload';
  static const String _doneChannelId = 'nimiro_upload_done';

  static bool _configured = false;
  static bool _notificationsReady = false;
  static bool _isServiceIsolate = false;
  static bool _processing = false;
  static bool _wake = false;
  static Directory? _dirCache;

  /// Serialises writes per job so an older progress snapshot can never
  /// overwrite a newer status (done/failed) on disk.
  static final Map<String, Future<void>> _writeChains = {};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Creates the notification channels and configures the foreground service.
  /// Safe to call repeatedly; only the first call in an isolate does work.
  Future<void> ensureConfigured() async {
    if (!Platform.isAndroid || _configured) return;

    try {
      await _ensureNotifications();
    } catch (e) {
      // A notification problem must never disable background uploading.
      Loggers.error('upload notification setup failed: $e');
    }

    try {
      await FlutterBackgroundService().configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onServiceStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: _channelId,
          initialNotificationTitle: 'Nimiro',
          initialNotificationContent: 'Preparing upload...',
          foregroundServiceNotificationId: 8901,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onServiceStart,
          onBackground: onIosBackground,
        ),
      );
      _configured = true;
    } catch (e, st) {
      Loggers.error('upload service configure failed: $e\n$st');
    }
  }

  /// Called once at app startup. Re-arms the service for jobs that were still
  /// queued when the app was last closed/killed. On iOS it processes them in
  /// the UI isolate because the platform does not allow a permanent service.
  Future<void> resumePending() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return;
      await _cleanupOldJobs();

      final currentUserId = _currentUserId();
      if (currentUserId == 0) return;

      // Never upload one account's queued media with another account's token.
      for (final job in await _readJobs()) {
        final owner = (job['userId'] as num?)?.toInt() ?? 0;
        if (owner != 0 && owner != currentUserId) {
          await _deleteJob(job['tag'] as String);
        }
      }

      final pending = (await _readJobs()).where(_isResumable).toList();
      if (pending.isEmpty) return;

      await _saveAuthToken();

      if (Platform.isAndroid) {
        final started = await _startService();
        if (!started) {
          // Extremely rare (service disabled by the OS). At least finish the
          // queue while this app process is alive.
          unawaited(processQueue());
        }
      } else {
        unawaited(processQueue());
      }
    } catch (e, st) {
      Loggers.error('resumePending failed: $e\n$st');
    }
  }

  /// Queues [steps] durably and returns the final API response (or
  /// `{'__error': reason}`). The contract is identical to the old inline
  /// implementation, so every existing caller keeps working unchanged.
  Future<Map<String, dynamic>?> submit(
    List<Map<String, dynamic>> steps, {
    void Function(double progress)? onProgress,
  }) async {
    final tag =
        'u${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(9999)}';
    final now = DateTime.now().millisecondsSinceEpoch;
    final job = <String, dynamic>{
      'tag': tag,
      'steps': steps,
      'status': 'pending',
      'createdAt': now,
      'updatedAt': now,
      'attempts': 0,
      'progress': 0.0,
      'lang': _currentLang(),
      'userId': _currentUserId(),
    };

    // The token must exist before the service can pick the job up.
    await _saveAuthToken();
    await _writeJob(job);

    if (Platform.isAndroid) {
      final started = await _startService();
      if (started) {
        final result = await _waitForJob(tag, onProgress);
        if (result != null) return result;

        // The service reported that it is not running and never picked the
        // job up. Remove the persisted copy before running inline so the two
        // paths can never upload the same job twice.
        Loggers.error('upload $tag was not picked up by the service');
        await _deleteJob(tag);
      } else {
        // Inline fallback below owns the upload; never leave a duplicate job
        // behind for the next app launch.
        await _deleteJob(tag);
      }
    }

    // iOS (no permanent service) or Android fallback. iOS keeps the job file
    // so a future launch can finish it even if the app is killed mid-upload.
    try {
      if (Platform.isIOS) {
        // The durable queue is the single owner of the upload. If a resumed
        // job is already running, this only wakes the loop instead of
        // starting a second upload of the same job.
        unawaited(processQueue());
        return await _waitForJob(tag, onProgress, watchService: false);
      }
      return await _runJob(job, (p) => onProgress?.call(p));
    } catch (e) {
      Loggers.error('Upload failed: $e');
      return {'__error': '$e'};
    }
  }

  // ---------------------------------------------------------------------------
  // Queue processing (service isolate on Android, UI isolate on iOS)
  // ---------------------------------------------------------------------------

  static Future<void> processQueue([ServiceInstance? service]) async {
    if (_processing) {
      _wake = true;
      return;
    }
    _processing = true;

    try {
      await _cleanupOldJobs();

      while (true) {
        _wake = false;
        final pending = (await _readJobs()).where(_isResumable).toList();
        for (final job in pending) {
          await _processJob(job, service);
        }

        // Give a job that was just submitted time to appear on disk before
        // deciding that the queue is empty and stopping the service.
        await Future<void>.delayed(const Duration(seconds: 3));

        final remaining = (await _readJobs()).where(_isResumable).toList();
        if (remaining.isEmpty && !_wake) break;
      }
    } catch (e, st) {
      Loggers.error('processQueue failed: $e\n$st');
    } finally {
      _processing = false;
      if (service != null) {
        try {
          final remaining = (await _readJobs()).where(_isResumable).toList();
          if (remaining.isEmpty) {
            // A job can be written at the exact moment the queue looks empty.
            await Future<void>.delayed(const Duration(seconds: 1));
            if ((await _readJobs()).where(_isResumable).isEmpty) {
              await service.stopSelf();
            }
          }
        } catch (_) {
          try {
            await service.stopSelf();
          } catch (_) {}
        }
      }
    }
  }

  static Future<void> _processJob(
    Map<String, dynamic> job,
    ServiceInstance? service, {
    void Function(double)? onProgress,
  }) async {
    final tag = job['tag'] as String;
    final lang = (job['lang'] ?? 'ar').toString();
    final attempts = ((job['attempts'] as num?)?.toInt() ?? 0) + 1;

    job['attempts'] = attempts;
    job['status'] = 'running';
    job['progress'] = 0.0;
    job['error'] = null;
    await _writeJob(job);

    if (service != null) {
      unawaited(_setForegroundInfo(service, _uploadingText(lang, 0)));
    }

    var lastWrite = 0;
    var lastNotify = 0;

    void report(double p) {
      final progress = p.clamp(0.0, 1.0).toDouble();
      job['progress'] = progress;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - lastWrite >= 900 || progress >= 1) {
        lastWrite = now;
        unawaited(_writeJob(job));
      }
      if (service != null && (now - lastNotify >= 1000 || progress >= 1)) {
        lastNotify = now;
        unawaited(_setForegroundInfo(service, _uploadingText(lang, progress)));
      }
      onProgress?.call(progress);
    }

    Map<String, dynamic> result;
    try {
      result = await _runJob(job, report);
    } catch (e, st) {
      Loggers.error('upload $tag crashed: $e\n$st');
      result = {
        '__error': '$e'.replaceFirst('Exception: ', ''),
        '__retryable': false,
        '__multipart': false,
      };
    }

    if (result['__error'] == null) {
      job['status'] = 'done';
      job['progress'] = 1.0;
      job['result'] = result;
      job['error'] = null;
      final done = _writeJob(job);
      await done;
      _writeChains.remove(tag);
      onProgress?.call(1);
      await _showCompletionNotification(job, true)
          .timeout(const Duration(seconds: 10), onTimeout: () {});
      return;
    }

    final error = '${result['__error']}';
    final retryable = result['__retryable'] == true;
    final isMultipart = result['__multipart'] == true;
    final maxAttempts = isMultipart ? 2 : 3;

    if (retryable && attempts < maxAttempts) {
      job['status'] = 'pending';
      job['error'] = error;
      await _writeJob(job);
      Loggers.info(
          'upload $tag failed (attempt $attempts/$maxAttempts), retrying: $error');
      await Future<void>.delayed(const Duration(seconds: 8));
      return;
    }

    job['status'] = 'failed';
    job['error'] = error;
    await _writeJob(job);
    _writeChains.remove(tag);
    await _showCompletionNotification(job, false)
        .timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  static Future<Map<String, dynamic>> _runJob(
    Map<String, dynamic> job,
    void Function(double) onProgress,
  ) async {
    final steps = (job['steps'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final token = await _readAuthToken();
    final results = <Map<String, dynamic>>[];

    onProgress(0.0);

    for (int i = 0; i < steps.length; i++) {
      final step = _resolvePlaceholders(steps[i], results);
      Map<String, dynamic>? res;
      String? failure;

      try {
        if (step['kind'] == 'api') {
          res =
              await _postApi(step, token).timeout(const Duration(seconds: 90));
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
        final reason = failure ??
            (res?['message'] ?? 'Upload failed at step ${i + 1}').toString();
        return {
          '__error': reason,
          '__retryable': failure != null
              ? _isRetryable(failure)
              : res?['__retryable'] == true,
          '__multipart': step['kind'] != 'api',
          '__step': i,
        };
      }

      results.add(res);
      onProgress((i + 1) / steps.length);
    }

    return results.isEmpty ? <String, dynamic>{} : results.last;
  }

  // ---------------------------------------------------------------------------
  // Foreground service entry points
  // ---------------------------------------------------------------------------

  @pragma('vm:entry-point')
  static Future<bool> onServiceStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();
    _isServiceIsolate = true;

    service.on('stop').listen((_) async {
      // Never stop in the middle of a queued upload.
      try {
        final pending = (await _readJobs()).where(_isResumable).toList();
        if (pending.isEmpty) await service.stopSelf();
      } catch (_) {
        await service.stopSelf();
      }
    });
    service.on('processQueue').listen((_) => processQueue(service));
    service.on('cancelAll').listen((_) => service.stopSelf());

    unawaited(processQueue(service));
    return true;
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Service helpers (UI isolate)
  // ---------------------------------------------------------------------------

  static Future<bool> _startService() async {
    try {
      await instance.ensureConfigured();
      final service = FlutterBackgroundService();
      if (!await service.isRunning()) {
        final ok = await service.startService();
        if (!ok) return false;
      }
      // The service also processes on start; this wakes an already-running,
      // idle service. If the listener is not ready yet the start callback has
      // already covered the job.
      service.invoke('processQueue');
      return true;
    } catch (e, st) {
      Loggers.error('start upload service failed: $e\n$st');
      return false;
    }
  }

  /// Pumps this job's persisted state until it finishes. Returns `null` only
  /// when the service is not running and the job was never picked up, which
  /// lets [submit] fall back to an inline upload.
  Future<Map<String, dynamic>?> _waitForJob(
    String tag,
    void Function(double progress)? onProgress, {
    bool watchService = true,
  }) async {
    final startedAt = DateTime.now();
    final deadline = startedAt.add(const Duration(hours: 3));
    var lastProgress = -1.0;
    var lastProgressAt = startedAt;
    var lastServiceCheck = startedAt;

    while (DateTime.now().isBefore(deadline)) {
      final job = await _readJob(tag);
      if (job == null) return {'__error': 'Upload job disappeared'};

      final progress =
          ((job['progress'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
      if (progress != lastProgress) {
        lastProgress = progress.toDouble();
        lastProgressAt = DateTime.now();
        onProgress?.call(lastProgress);
      }

      final status = job['status'];
      if (status == 'done') {
        onProgress?.call(1);
        return Map<String, dynamic>.from(job['result'] as Map? ?? {});
      }
      if (status == 'failed') {
        return {'__error': job['error'] ?? 'Upload failed'};
      }

      // If the service died (or was never started) and nothing has moved for
      // a minute, let submit() take over inline instead of waiting for hours.
      final now = DateTime.now();
      if (watchService && now.difference(lastServiceCheck).inSeconds >= 30) {
        lastServiceCheck = now;
        var running = false;
        try {
          running = await FlutterBackgroundService().isRunning();
        } catch (_) {}
        if (!running && now.difference(lastProgressAt).inSeconds >= 60) {
          return null;
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    return {'__error': 'Upload timed out'};
  }

  // ---------------------------------------------------------------------------
  // Durable storage
  // ---------------------------------------------------------------------------

  static Future<Directory> _queueDir() async {
    final cached = _dirCache;
    if (cached != null) return cached;

    Directory base;
    try {
      base = await getApplicationSupportDirectory();
    } catch (e) {
      // The background isolate may not have path_provider registered on some
      // devices. Android's files dir lives next to the cache dir, so this
      // resolves to the same place the UI isolate uses.
      base = Directory('${Directory.systemTemp.parent.path}/files');
      Loggers.error('queue dir fallback: $e -> ${base.path}');
    }

    final dir = Directory('${base.path}/$queueDirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dirCache = dir;
    return dir;
  }

  static Future<void> _writeFileAtomic(File target, String content) async {
    final tmp =
        File('${target.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(target.path);
  }

  static Future<void> _writeJob(Map<String, dynamic> job) {
    final tag = job['tag'] as String;
    job['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    final data = jsonEncode(job);

    final previous = _writeChains[tag] ?? Future<void>.value();
    final next = () async {
      try {
        await previous;
      } catch (_) {}
      try {
        final dir = await _queueDir();
        await _writeFileAtomic(File('${dir.path}/job_$tag.json'), data);
      } catch (e, st) {
        Loggers.error('write job $tag failed: $e\n$st');
      }
    }();
    _writeChains[tag] = next;
    return next;
  }

  static Future<Map<String, dynamic>?> _readJob(String tag) async {
    try {
      final dir = await _queueDir();
      final file = File('${dir.path}/job_$tag.json');
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _readJobs() async {
    try {
      final dir = await _queueDir();
      final jobs = <Map<String, dynamic>>[];
      await for (final entry in dir.list()) {
        if (entry is! File || !entry.path.endsWith('.json')) continue;
        try {
          final decoded = jsonDecode(await entry.readAsString());
          if (decoded is Map) {
            jobs.add(decoded.cast<String, dynamic>());
          }
        } catch (_) {
          // A truncated file can only be a leftover temp file; skip it.
        }
      }
      jobs.sort((a, b) => ((a['createdAt'] as num?) ?? 0)
          .compareTo((b['createdAt'] as num?) ?? 0));
      return jobs;
    } catch (e) {
      Loggers.error('read upload jobs failed: $e');
      return [];
    }
  }

  static Future<void> _deleteJob(String tag) async {
    try {
      final dir = await _queueDir();
      final file = File('${dir.path}/job_$tag.json');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<void> _cleanupOldJobs() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const maxAge = 3 * 24 * 60 * 60 * 1000;
    for (final job in await _readJobs()) {
      final status = job['status'];
      final updated = (job['updatedAt'] as num?)?.toInt() ?? 0;
      if ((status == 'done' || status == 'failed') && now - updated > maxAge) {
        await _deleteJob(job['tag'] as String);
      }
    }
  }

  static bool _isResumable(Map<String, dynamic> job) {
    final status = job['status'];
    return status == 'pending' || status == 'running';
  }

  // ---------------------------------------------------------------------------
  // Auth token + language
  // ---------------------------------------------------------------------------

  /// The token already lives in GetStorage (plain, app-private). A second
  /// app-private file is used so the service isolate never has to open the
  /// same Hive box as the UI isolate, which is not safe across isolates.
  static Future<void> _saveAuthToken() async {
    try {
      final dir = await _queueDir();
      final token = SessionManager.instance.getAuthToken().trim();
      if (token.isEmpty || token == 'AUTH TOKEN EMPTY') {
        final stale = File('${dir.path}/auth_token');
        if (await stale.exists()) await stale.delete();
        return;
      }
      await _writeFileAtomic(File('${dir.path}/auth_token'), token);
    } catch (e) {
      Loggers.error('save upload auth token failed: $e');
    }
  }

  static Future<String?> _readAuthToken() async {
    try {
      final dir = await _queueDir();
      final file = File('${dir.path}/auth_token');
      if (!await file.exists()) return null;
      final token = (await file.readAsString()).trim();
      return token.isEmpty ? null : token;
    } catch (_) {
      return null;
    }
  }

  static String _currentLang() {
    try {
      return SessionManager.instance.getLang();
    } catch (_) {
      return 'ar';
    }
  }

  static int _currentUserId() {
    try {
      return SessionManager.instance.getUserID();
    } catch (_) {
      return 0;
    }
  }

  /// Cancels and removes every queued upload. Called on logout/account
  /// deletion so one account's pending media can never be sent with another
  /// account's token.
  Future<void> clearQueue() async {
    try {
      if (Platform.isAndroid) {
        try {
          FlutterBackgroundService().invoke('cancelAll');
        } catch (_) {}
        // Give the service engine time to stop before its files disappear;
        // otherwise an in-flight write could recreate a job file.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      final dir = await _queueDir();
      await for (final entry in dir.list()) {
        if (entry is File) {
          try {
            await entry.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      Loggers.error('clear upload queue failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  static Future<void> _ensureNotifications() async {
    if (_notificationsReady) return;
    final plugin = FlutterLocalNotificationsPlugin();

    // In the UI isolate FirebaseNotificationManager already initialised the
    // singleton with its tap callbacks. Calling initialize() again without
    // those callbacks would silently break taps on push notifications. The
    // service isolate has a fresh engine, so it must initialise its own copy.
    if (_isServiceIsolate) {
      await plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ));
    }

    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      'Uploads',
      description: 'Shows media upload progress',
      importance: Importance.low,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _doneChannelId,
      'Upload results',
      description: 'Notifies when a media upload finishes',
      importance: Importance.defaultImportance,
    ));
    _notificationsReady = true;
  }

  static Future<void> _setForegroundInfo(
      ServiceInstance service, String content) async {
    try {
      await (service as dynamic)
          .setForegroundNotificationInfo(title: 'Nimiro', content: content);
    } catch (_) {
      // Older plugin versions used a different method name.
      try {
        await (service as dynamic)
            .setNotificationInfo(title: 'Nimiro', content: content);
      } catch (_) {}
    }
  }

  static String _uploadingText(String lang, double progress) {
    final pct = (progress * 100).clamp(0, 100).round();
    return lang == 'ar'
        ? 'جاري رفع الوسائط... $pct%'
        : 'Uploading media... $pct%';
  }

  static Future<void> _showCompletionNotification(
      Map<String, dynamic> job, bool success) async {
    try {
      await _ensureNotifications();
      final lang = (job['lang'] ?? 'ar').toString();
      final title = success
          ? (lang == 'ar' ? 'تم الرفع' : 'Upload complete')
          : (lang == 'ar' ? 'فشل الرفع' : 'Upload failed');
      final body = success
          ? (lang == 'ar'
              ? 'تم رفع الوسائط بنجاح.'
              : 'Your media was uploaded successfully.')
          : (lang == 'ar'
              ? 'تعذر رفع الوسائط. افتح التطبيق لإعادة المحاولة.'
              : 'The upload could not be completed. Open the app to retry.');

      final tag = '${job['tag']}';
      final id = 20000 + (tag.hashCode & 0x7fffffff) % 100000;
      await FlutterLocalNotificationsPlugin().show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _doneChannelId,
            'Upload results',
            channelDescription: 'Notifies when a media upload finishes',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentSound: false,
          ),
        ),
      );
    } catch (e) {
      Loggers.error('completion notification failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Networking (pure dart:io so it works in the service isolate)
  // ---------------------------------------------------------------------------

  static bool _isRetryable(String message) {
    final m = message.toLowerCase();
    return m.contains('socket') ||
        m.contains('connection') ||
        m.contains('network') ||
        m.contains('timed out') ||
        m.contains('timeout') ||
        m.contains('host lookup') ||
        m.contains('broken pipe');
  }

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
          {
            'status': false,
            'message': 'Server error (HTTP ${resp.statusCode})',
            '__retryable': resp.statusCode >= 500,
          };
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
          {
            'status': false,
            'message': 'Server error (HTTP ${resp.statusCode})',
            '__retryable': resp.statusCode >= 500,
          };
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
