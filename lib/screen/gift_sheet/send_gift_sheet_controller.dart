import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/functions/debounce_action.dart';
import 'package:nimiro/common/manager/firebase_notification_manager.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/api/common_service.dart';
import 'package:nimiro/common/service/api/gift_wallet_service.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/model/general/status_model.dart';
import 'package:nimiro/model/user_model/app_user.dart';
import 'package:nimiro/model/post_story/post_model.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/gift_sheet/gift_animation_overlay.dart';
import 'package:nimiro/screen/gift_sheet/send_gift_sheet.dart';
import 'package:nimiro/screen/live_stream/livestream_screen/livestream_screen_controller.dart';

class SendGiftSheetController extends BaseController {
  Rx<Setting?> settings = Rx<Setting?>(null);
  Rx<User?> myUser = Rx<User?>(null);
  int? userId;
  List<AppUser> liveUsers;
  GiftType? giftType;
  LivestreamScreenController? livestreamController;

  /// Guards against double-taps / concurrent sends producing duplicate
  /// transactions or duplicate `Get.back()` calls.
  bool _sending = false;

  SendGiftSheetController(this.giftType, this.userId, this.liveUsers);

  @override
  void onInit() {
    super.onInit();
    _initData();

    if (liveUsers.isNotEmpty &&
        (giftType == GiftType.livestream || giftType == GiftType.battle) &&
        Get.isRegistered<LivestreamScreenController>()) {
      livestreamController = Get.find<LivestreamScreenController>();
      if (livestreamController!.selectedGiftUser.value == null) {
        livestreamController!.selectedGiftUser = liveUsers.first.obs;
      } else {
        DebounceAction.shared.call(() {
          final selected = livestreamController!.selectedGiftUser.value;
          livestreamController!.selectedGiftUser.value = liveUsers.firstWhere(
              (element) => element.userId == selected?.userId,
              orElse: () => liveUsers.first);
        });
      }
    }
  }

  _initData() {
    // Always read the freshest persisted user, not a stale copy.
    myUser.value = SessionManager.instance.getUser();

    // The gift catalogue is cached at splash time. On older installs that
    // cache can be empty, so refresh it in the background every time the sheet
    // opens. The Obx in the sheet rebuilds as soon as the list is replaced.
    unawaited(_refreshGifts());
  }

  Future<void> _refreshGifts() async {
    final fresh = await CommonService.instance.refreshGifts();
    if (fresh == null || fresh.isEmpty) return;
    final current = SessionManager.instance.getSettings();
    if (current == null) return;
    // Assign a new object so GetX detects the change and rebuilds the grid.
    settings.value = Setting.fromJson(current.toJson());
  }

  /// Current wallet balance, never negative.
  int get _balance {
    final raw = myUser.value?.coinWallet;
    if (raw == null) return 0;
    final value = raw.toInt();
    return value < 0 ? 0 : value;
  }

  bool _hasEnoughBalance(int price) => _balance >= price;

  void onGiftTap(Gift gift, BuildContext context) {
    if (_sending) return;
    final giftId = gift.id;
    if (giftId == null) {
      return showSnackBar(LKey.giftNotFound.tr);
    }
    final coinPrice = gift.coinPrice ?? 0;
    if (coinPrice <= 0) {
      return Loggers.error('Invalid coin price: $coinPrice');
    }
    // Allow sending when the balance is exactly equal to the price.
    if (!_hasEnoughBalance(coinPrice)) {
      return showSnackBar(LKey.insufficientFunds.tr);
    }
    sendGift(gift, context);
  }

  Future<void> sendGift(Gift gift, BuildContext context) async {
    if (_sending) return;
    _sending = true;

    final giftId = gift.id?.toInt() ?? -1;
    final coinPrice = gift.coinPrice ?? 0;

    if ((giftType == GiftType.livestream || giftType == GiftType.battle) &&
        userId == null) {
      userId = livestreamController?.selectedGiftUser.value?.userId;
    }

    if (giftId == -1 || userId == null || userId == -1) {
      _sending = false;
      return Loggers.error('Invalid Gift: $giftId or User: $userId');
    }
    if (coinPrice <= 0) {
      _sending = false;
      return Loggers.error('Invalid coin price: $coinPrice, skipping gift.');
    }
    if (!_hasEnoughBalance(coinPrice)) {
      _sending = false;
      return showSnackBar(LKey.insufficientFunds.tr);
    }

    showLoader();
    StatusModel response;
    try {
      response = await GiftWalletService.instance
          .sendGift(giftId: giftId, userId: userId);
    } catch (e, s) {
      Loggers.error('SendGift failed: $e $s');
      stopLoader();
      _sending = false;
      return showSnackBar(LKey.somethingWentWrong.tr);
    }
    stopLoader();

    if (response.status == true) {
      // Deduct coins from a fresh copy and clamp at zero, never negative.
      myUser.update((val) {
        if (val == null) return;
        final next = (val.coinWallet ?? 0).toInt() - coinPrice;
        val.coinWallet = next < 0 ? 0 : next;
      });
      final fresh = myUser.value;
      if (fresh != null) SessionManager.instance.setUser(fresh);

      _sending = false;
      if (giftType == GiftType.none) {
        Get.back(result: GiftManager(gift));
      } else {
        Get.back(
            result: GiftManager(gift,
                streamUser: livestreamController?.selectedGiftUser.value));
      }
    } else {
      _sending = false;
      showSnackBar(response.message);
    }
  }
}

class GiftManager {
  Gift gift;
  AppUser? streamUser;

  GiftManager(this.gift, {this.streamUser});

  static Future<void> openGiftSheet(
      {int? userId,
      Post? post,
      GiftType giftType = GiftType.none,
      BattleView battleViewType = BattleView.red,
      List<AppUser> streamUsers = const [],
      required Function(GiftManager giftManager) onCompletion}) async {
    await Get.bottomSheet<GiftManager>(
      SendGiftSheet(
        userId: userId,
        giftType: giftType,
        battleViewType: battleViewType,
        streamUsers: streamUsers,
      ),
      isScrollControlled: true,
    ).then((gift) {
      if (gift != null) {
        onCompletion(gift);
      }
    });
  }

  /// Plays the animated gift overlay. Safe from any screen and at any time —
  /// the app-level host handles it independently of navigation state.
  static void showAnimationDialog(Gift gift) {
    GiftAnimationOverlay.shared.enqueue(gift);
  }

  static void sendNotification(Post? post) {
    final user = post?.user;
    if (user == null || user.id == SessionManager.instance.getUserID()) return;

    if (user.notifyGiftReceived == 1) {
      FirebaseNotificationManager.instance.sendLocalisationNotification(
        LKey.activitySentGift,
        type: NotificationType.post,
        deviceType: user.device,
        toUserId: user.id?.toString(),
        languageCode: user.appLanguage,
        body: NotificationInfo(id: post?.id),
      );
    }
  }
}
