import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

/// Browsing stays fully open for restricted accounts (isFreez == 1): feed,
/// reels, explore, chats, profiles. Only WRITES are refused — like, comment,
/// follow, gift, messages, posting, stories, live, save, repost.
///
/// Every interaction gate funnels through this guard so the localized
/// notice is consistent, and it is checked BEFORE any optimistic UI update
/// so the UI never lies about a server-rejected action.
class RestrictionGuard {
  static bool get isRestricted =>
      (SessionManager.instance.getUser()?.isFreez ?? 0) == 1;

  /// Shows the localized restriction notice (mirrors
  /// [BaseController.showSnackBar] styling) and returns true when the caller
  /// belongs to a restricted account and must abort the write action.
  static bool blockIfRestricted() {
    if (!isRestricted) {
      return false;
    }
    if (!Get.isSnackbarOpen) {
      Get.rawSnackbar(
        backgroundColor: blackPure(Get.context!),
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.all(15),
        borderRadius: 10,
        isDismissible: true,
        duration: const Duration(seconds: 2),
        snackPosition: SnackPosition.TOP,
        messageText: Text(LKey.accountRestricted.tr,
            style: TextStyleCustom.outFitRegular400(
                color: whitePure(Get.context!), fontSize: 17)),
      );
    }

    return true;
  }
}
