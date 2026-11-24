import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:nimiro/common/service/supabase/supabase_service.dart';
import 'package:nimiro/common/manager/crash_log_service.dart';
import 'package:nimiro/common/manager/firebase_notification_manager.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/subscription/subscription_manager.dart';
import 'package:nimiro/common/service/upload/upload_queue_service.dart';
import 'package:nimiro/common/widget/restart_widget.dart';
import 'package:nimiro/languages/dynamic_translations.dart';
import 'package:nimiro/screen/gift_sheet/gift_animation_overlay.dart';
import 'package:nimiro/screen/splash_screen/splash_screen.dart';
import 'package:nimiro/utilities/theme_res.dart';

import 'common/service/network_helper/network_helper.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  Loggers.success("Handling a background message: ${message.data}");
  await Firebase.initializeApp();
  // Do NOT open the app's get_storage file from this isolate. This callback
  // runs in a separate isolate with its own in-memory copy; writing the same
  // file while the UI isolate has it open can lose data and contributed to
  // "Bad state: No element" crash loops at startup. The unread count is
  // recalculated when the app opens.
  if (Platform.isIOS) {
    FirebaseNotificationManager.instance.showNotification(message);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // v1.1.38: Sentry is initialised FIRST, before any other SDK. Previously it
  // was the last step of startup, so every crash that happened earlier
  // (Supabase/Firebase/Ads/...) went unreported - exactly the repeated
  // startup crashes reported on the user's Samsung device. The whole startup
  // sequence now runs inside appRunner, so any error there is captured and
  // reported to Sentry instead of vanishing.
  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://e57768e45209ac08dd8703e373689aa3@o4512265705553920.ingest.de.sentry.io/4512266288431184';
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 0.1;
    },
    appRunner: () async {
      // Local belt-and-braces log: every fatal error is queued and uploaded
      // automatically to the admin panel (v1.1.41), even if Sentry is blocked.
      CrashLogService.instance.install();
      try {
        await _runStartupSequence();
      } catch (e, st) {
        Loggers.error('Fatal crash during app startup $e\n$st');
        await CrashLogService.instance.write('startup', e, st);
        await Sentry.captureException(e, stackTrace: st);
        rethrow;
      }
    },
  );
}

/// Opens the local key-value store before anything reads or listens to it.
///
/// Startup used to await `GetStorage.init('nimiro')` after several SDKs had
/// already been initialised. On some devices that ordering crashed the app
/// with `Bad state: No element` and users saw repeated errors instead of the
/// feed. Storage is now the first thing initialised and a failure is logged
/// without aborting the launch: the app still opens and can log in again.
Future<void> _initLocalStorage() async {
  try {
    await GetStorage.init('nimiro').timeout(const Duration(seconds: 8));
  } catch (e, st) {
    Loggers.error('Local storage init failed (continuing): $e\n$st');
  }
}

/// The original startup sequence, unchanged and in the same order - it only
/// moved from main() into Sentry's appRunner (see comment above).
Future<void> _runStartupSequence() async {
  // Local storage must exist before SessionManager listeners are registered.
  await _initLocalStorage();

  // Initialize Supabase's client layer for the migration phase. Firebase
  // remains active until authentication, realtime, and messaging are
  // migrated and verified feature-by-feature.
  await SupabaseService.instance.initialize();
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 20));
  } catch (e, st) {
    Loggers.error('Firebase init failed (continuing): $e\n$st');
  }

  // OneSignal (added alongside Firebase during migration)
  try {
    OneSignal.initialize('f2231f10-416c-4fd4-bc9e-f054574281a5');
    // Notification permission is NOT requested at startup: it is asked
    // the first time the user opens the notifications screen — the one
    // moment they're actively telling us they want notifications.
  } catch (e) {
    Loggers.error('OneSignal init failed: $e');
  }
  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // v1.1.41: retry any crash reports that could not be uploaded on a previous
  // run (offline / server down). Runs in the background - never blocks startup.
  unawaited(CrashLogService.instance.flush());

  // Initialize notification listeners after local storage is ready and
  // before the first screen is shown.
  FirebaseNotificationManager.instance;

  // Init RevenueCat (automatically skipped when no real API key is set)
  try {
    await SubscriptionManager.shared.initPlatformState();
  } catch (e, st) {
    Loggers.error('SubscriptionManager init error: $e\n$st');
  }
  (await AudioSession.instance)
      .configure(const AudioSessionConfiguration.speech());

  // Init Ads (ignore async wait if needed)
  MobileAds.instance.initialize();

  NetworkHelper().initialize();

  // Load Translations
  Get.put(DynamicTranslations());

  // v1.1.53: finish any upload that was still queued when the app was last
  // closed or killed. Never blocks startup; on Android this only starts the
  // foreground service, which owns the actual upload.
  unawaited(UploadQueueService.instance.resumePending());

  runApp(SentryWidget(child: const RestartWidget(child: MyApp())));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // GiftAnimationHost owns the gift animation queue via a stream, so
    // animations never depend on the navigator overlay being available (e.g.
    // right after Get.back() closes the gift sheet) and work on every screen.
    // It is mounted from GetMaterialApp.builder so it sits above the
    // navigator but still inherits Theme/Directionality/MediaQuery.
    return GetMaterialApp(
      // The root key is only used by GetX routing now; gift animations do
      // not touch it any more.
      navigatorKey: Get.key,
      builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: ScrollConfiguration(
              behavior: MyBehavior(),
              child: GiftAnimationHost(
                child: child ?? const SizedBox.shrink(),
              ))),
      translations: Get.find<DynamicTranslations>(),
      locale: Locale(SessionManager.instance.getLang()),
      fallbackLocale: Locale(SessionManager.instance.getFallbackLang()),
      // FIX(v13): the app's original and only design is the LIGHT theme. The
      // dark theme added by the "theme redesign" has been removed from
      // ThemeRes entirely, so the app renders light regardless of the device
      // setting and regardless of any dark_mode value left in local storage.
      themeMode: ThemeMode.light,
      theme: ThemeRes.lightTheme(context),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

class MyBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
