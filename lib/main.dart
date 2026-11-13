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
import 'package:nimiro/common/widget/restart_widget.dart';
import 'package:nimiro/languages/dynamic_translations.dart';
import 'package:nimiro/screen/splash_screen/splash_screen.dart';
import 'package:nimiro/utilities/theme_res.dart';

import 'common/service/network_helper/network_helper.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  Loggers.success("Handling a background message: ${message.data}");
  await Firebase.initializeApp();
  // The background handler runs in its own isolate, so local storage must be
  // (re)initialized here before it can read/write the persisted unread count.
  await GetStorage.init('nimiro');
  if (message.data['type'] != NotificationType.chat.type) {
    SessionManager.instance.setNotifyCount(1);
  }
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
      // Local belt-and-braces log, readable from Settings -> Share crash log
      // for the case where the device network cannot reach Sentry.
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

/// The original startup sequence, unchanged and in the same order - it only
/// moved from main() into Sentry's appRunner (see comment above).
Future<void> _runStartupSequence() async {
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

  await GetStorage.init('nimiro');

  // Initialize notification listeners after local storage is ready and
  // before the first screen is shown.
  FirebaseNotificationManager.instance;

  // Init RevenueCat (handle errors gracefully)
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

  runApp(SentryWidget(child: const RestartWidget(child: MyApp())));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: ScrollConfiguration(behavior: MyBehavior(), child: child!)),
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
