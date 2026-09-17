import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart' show SessionManager;
import 'package:nimiro/common/service/api/notification_service.dart';
import 'package:nimiro/common/service/api/post_service.dart';
import 'package:nimiro/common/service/api/user_service.dart';
import 'package:nimiro/common/service/navigation/navigate_with_controller.dart';
import 'package:nimiro/languages/dynamic_translations.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/chat/chat_thread.dart';
import 'package:nimiro/model/livestream/livestream.dart';
import 'package:nimiro/model/post_story/post_model.dart';
import 'package:nimiro/screen/chat_screen/chat_screen.dart';
import 'package:nimiro/screen/chat_screen/chat_screen_controller.dart';
import 'package:nimiro/screen/dashboard_screen/dashboard_screen_controller.dart';
import 'package:nimiro/screen/live_stream/livestream_screen/audience/live_stream_audience_screen.dart';
import 'package:nimiro/screen/live_stream/livestream_screen/host/livestream_host_screen.dart';
import 'package:nimiro/screen/post_screen/single_post_screen.dart';
import 'package:nimiro/screen/reels_screen/reels_screen.dart';
import 'package:nimiro/utilities/const_res.dart';
import 'package:nimiro/utilities/firebase_const.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Navigation must happen on the main isolate. The payload is recovered by
  // getNotificationAppLaunchDetails/onDidReceiveNotificationResponse.
  Loggers.info('Notification tapped in background isolate');
}

class FirebaseNotificationManager {
  FirebaseNotificationManager._() {
    init();
  }

  static final instance = FirebaseNotificationManager._();

  FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  RxString notificationPayload = ''.obs;
  AndroidNotificationChannel channel = const AndroidNotificationChannel(
      'nimiro', // id
      'Nimiro', // title
      playSound: true,
      enableLights: true,
      enableVibration: true,
      showBadge: true,
      importance: Importance.max);

  final Set<String> _handledMessageIds = <String>{};
  final Set<String> _handledPayloads = <String>{};

  void init() async {
    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true);
      await firebaseMessaging.requestPermission(alert: true, badge: false, sound: true);
    }

    subscribeToTopic();

    var initializationSettingsAndroid = const AndroidInitializationSettings('@mipmap/ic_launcher');

    var initializationSettingsIOS = const DarwinInitializationSettings(
        defaultPresentAlert: true, defaultPresentSound: true, defaultPresentBadge: true);

    var initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

    // Handling notification taps
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
      final payload = response.payload;
      if (payload == null || payload.isEmpty) return;
      notificationPayload.value = payload;
      Future<void>.delayed(const Duration(milliseconds: 300),
          () => handleNotification(payload));
    }, onDidReceiveBackgroundNotificationResponse: notificationTapBackground);

    final launchDetails = await flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      notificationPayload.value = launchPayload;
      Future<void>.delayed(const Duration(milliseconds: 800),
          () => handleNotification(launchPayload));
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final messageKey = _messageKey(message);
      if (!_handledMessageIds.add(messageKey)) return;
      if (_handledMessageIds.length > 100) {
        _handledMessageIds.remove(_handledMessageIds.first);
      }

      String data = message.data['notification_data'] ?? '';

      if (message.data['type'] == NotificationType.chat.type) {
        ChatThread conversationUser = ChatThread.fromJson(jsonDecode(data));
        if (conversationUser.conversationId == ChatScreenController.chatId) {
          return;
        }
      } else {
        SessionManager.instance.setNotifyCount(1);
      }
      showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      Loggers.info('User tapped the notification: ${message.data}');
      print('FirebaseMessaging.onMessageOpenedApp');
      if (message.data.isNotEmpty) {
        handleNotification(jsonEncode(message.toMap()));
      }
    });

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    firebaseMessaging.onTokenRefresh.listen((token) async {
      final user = SessionManager.instance.getUser();
      if (user?.id == null || token.isEmpty) return;
      try {
        await UserService.instance.updateUserDetails(deviceToken: token);
        Loggers.info('FCM token updated after refresh');
      } catch (e) {
        Loggers.error('Failed to update refreshed FCM token: $e');
      }
    });
  }

  String _messageKey(RemoteMessage message) {
    final id = message.messageId;
    if (id != null && id.isNotEmpty) return id;
    return '${message.data['type']}|${message.data['notification_data']}|'
        '${message.notification?.title}|${message.notification?.body}';
  }

  void unsubscribeToTopic({String? topic}) async {
    Loggers.success(
        '🔔 Topic UnSubscribe : ${topic ?? notificationTopic}_${Platform.isAndroid ? 'android' : 'ios'}');
    await firebaseMessaging.unsubscribeFromTopic(
        '${topic ?? notificationTopic}_${Platform.isAndroid ? 'android' : 'ios'}');
    if (kDebugMode) {
      await firebaseMessaging.unsubscribeFromTopic(
          'test_${topic ?? notificationTopic}_${Platform.isAndroid ? 'android' : 'ios'}');
    }
  }

  Future<void> subscribeToTopic({String? topic}) async {
    Loggers.success(
        '🔔 Topic Subscribe : ${topic ?? notificationTopic}_${Platform.isAndroid ? 'android' : 'ios'}');
    await firebaseMessaging.subscribeToTopic(
        '${topic ?? notificationTopic}_${Platform.isAndroid ? 'android' : 'ios'}');

    if (kDebugMode) {
      await firebaseMessaging.subscribeToTopic(
          'test_${topic ?? notificationTopic}_${Platform.isAndroid ? 'android' : 'ios'}');
    }
  }

  void showNotification(RemoteMessage message) {
    print('SHOW MESSAGE : ${message.toMap()}');
    int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    flutterLocalNotificationsPlugin.show(
        notificationId,
        (message.data['title']) ?? message.notification?.title,
        (message.data['body'] as String?) ?? message.notification?.body,
        NotificationDetails(
            iOS: const DarwinNotificationDetails(
                presentSound: true, presentAlert: true, presentBadge: true),
            android: AndroidNotificationDetails(channel.id, channel.name)),
        payload: jsonEncode(message.toMap()));
  }

  Future<void> handleNotification(String payload) async {
    if (!_handledPayloads.add(payload)) return;
    if (_handledPayloads.length > 50) {
      _handledPayloads.remove(_handledPayloads.first);
    }
    final RemoteMessage message = RemoteMessage.fromMap(jsonDecode(payload));
    final dataType = message.data['type'];
    final dataString = message.data['notification_data'];
    print('DATA TYPE : $dataType');
    print('DATA STRING : $dataString');
    if (dataType == null || dataString == null || dataString.isEmpty) return;
    final controller = Get.put(DashboardScreenController());
    switch (dataType) {
      case 'chat':
        Future.delayed(const Duration(milliseconds: 500), () async {
          controller.selectedPageIndex.value = 4;
          await _handleChatNotification(dataString);
        });

        break;
      case 'post':
        await _handlePostNotification(dataString, controller);
        break;
      case 'user':
        controller.selectedPageIndex.value = 5;
        await _handleUserNotification(dataString);
        break;
      case 'live_stream':
        controller.selectedPageIndex.value = 2;
        await _handleLivestreamNotification(dataString);
        break;
      default:
        Loggers.warning('Unknown notification type: $dataType');
    }
  }

  Future<void> _handleChatNotification(String data) async {
    try {
      final conversationUser = ChatThread.fromJson(jsonDecode(data));
      Loggers.info('Navigating to chat: ${conversationUser.toJson()}');
      await Get.to(() => ChatScreen(conversationUser: conversationUser));
    } catch (e) {
      Loggers.error('Failed to handle chat notification: $e');
    }
  }

  Future<void> _handlePostNotification(String data, DashboardScreenController controller) async {
    try {
      NotificationInfo notificationInfo = NotificationInfo.fromJson(jsonDecode(data));
      final int postId = notificationInfo.id ?? -1;
      final int? commentId = notificationInfo.commentId;
      final int? replyId = notificationInfo.replyCommentId;
      final result = await PostService.instance
          .fetchPostById(postId: postId, commentId: commentId, replyId: replyId);

      if (result.status == true && result.data != null) {
        final Post? post = result.data?.post;
        if (post == null) return;

        if (post.postType == PostType.reel) {
          controller.selectedPageIndex.value = 5;
          Get.to(() => ReelsScreen(reels: [post].obs, position: 0, postByIdData: result.data));
        } else if ([PostType.text, PostType.image, PostType.video].contains(post.postType)) {
          controller.selectedPageIndex.value = 1;
          await Get.to(() =>
              SinglePostScreen(post: post, postByIdData: result.data, isFromNotification: true));
        }
      }
    } catch (e) {
      Loggers.error('Failed to handle post notification: $e');
    }
  }

  Future<void> _handleUserNotification(String data) async {
    try {
      final map = jsonDecode(data);
      final int id = map['id'];
      final user = await UserService.instance.fetchUserDetails(userId: id);

      if (user != null) {
        Loggers.success('Navigating to user: ${user.id}');
        NavigationService.shared.openProfileScreen(user);
      }
    } catch (e) {
      Loggers.error('Failed to handle user notification: $e');
    }
  }

  Future<String?> getNotificationToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      Loggers.info('DeviceToken $token');
      return token;
    } catch (e) {
      Loggers.error('DeviceToken Exception $e');
      return null;
    }
  }

  Future<void> sendLocalisationNotification(
    String key, {
    Map<String, String> keyParams = const {},
    String? deviceToken = '',
    int? deviceType = 0,
    String? languageCode = 'en',
    required NotificationInfo body,
    required NotificationType type,
  }) async {
    // Early return if no device token provided
    if ((deviceToken ?? '').isEmpty) {
      Loggers.error('Device Token Empty - Notification not sent for key: $key');
      return;
    }

    // Get user data once
    final user = SessionManager.instance.getUser();
    final title = user?.fullname ?? '';

    // Get translations efficiently
    final translations = Get.find<DynamicTranslations>();
    final languageData = translations.keys[languageCode] ?? {};

    // Get description with fallback
    var description = languageData[key] ?? key;

    keyParams.forEach((key, value) {
      description = description.replaceAll('@$key', value);
    });

    // Log relevant information
    Loggers.info('''
      [Notification Details]
      Language: $languageCode
      Key: $key
      Description: $description
      Recipient: ${user?.id ?? 'Unknown'}
      Device Type: $deviceType
      Device Token: $deviceToken
    ''');

    // Send notification
    await NotificationService.instance.pushNotification(
        title: title,
        body: description,
        data: body.toJson(),
        deviceType: deviceType,
        token: deviceToken,
        type: type);
  }

  Future<void> _handleLivestreamNotification(String dataString) async {
    final incomingStream = Livestream.fromJson(jsonDecode(dataString));

    // If controller not registered, fetch from Firestore
    final snapshot = await FirebaseFirestore.instance
        .collection(FirebaseConst.liveStreams)
        .withConverter<Livestream>(
          fromFirestore: (snapshot, _) => Livestream.fromJson(snapshot.data()!),
          toFirestore: (livestream, _) => livestream.toJson(),
        )
        .get();

    final matchedDoc =
        snapshot.docs.firstWhereOrNull((doc) => doc.data().roomID == incomingStream.roomID);

    if (matchedDoc == null) {
      BaseController.share.showSnackBar(LKey.livestreamHasEnded.tr);
      return;
    }

    final stream = matchedDoc.data();
    final myUser = SessionManager.instance.getUser();

    if (stream.hostId == myUser?.id) {
      Get.to(() => LivestreamHostScreen(isHost: true, livestream: stream));
    } else {
      Get.to(() => LiveStreamAudienceScreen(isHost: false, livestream: stream));
    }
  }
}

enum NotificationType {
  chat('chat'),
  post('post'),
  user('user'),
  liveStream('live_stream'),
  other('other');

  final String type;

  const NotificationType(this.type);
}

class NotificationInfo {
  int? id;
  int? commentId;
  int? replyCommentId;

  NotificationInfo({
    this.id,
    this.commentId,
    this.replyCommentId,
  });

  factory NotificationInfo.fromJson(Map<String, dynamic> json) => NotificationInfo(
        id: json["id"],
        commentId: json["comment_id"],
        replyCommentId: json["reply_comment_id"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "comment_id": commentId,
        "reply_comment_id": replyCommentId,
      };
}
