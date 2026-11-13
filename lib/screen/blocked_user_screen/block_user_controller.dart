import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/controller/follow_controller.dart';
import 'package:nimiro/common/enum/chat_enum.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/api/user_service.dart';
import 'package:nimiro/common/widget/confirmation_dialog.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/general/status_model.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/utilities/firebase_const.dart';

class BlockUserController extends BaseController {
  void blockUser(User? user, Function() completion) {
    Get.bottomSheet(
        ConfirmationSheet(
          title: LKey.blockUser.trParams({'username': user?.fullname ?? ''}),
          description: LKey.blockUserConfirmation.tr,
          positiveText: LKey.block.tr,
          onTap: () async {
            try {
              if (user?.isFollowing == true) {
                FollowController followController;
                if (Get.isRegistered<FollowController>(
                    tag: user?.id.toString())) {
                  followController =
                      Get.find<FollowController>(tag: user?.id.toString());
                  followController.updateUser(user);
                } else {
                  followController = Get.put(FollowController(user.obs),
                      tag: user?.id.toString());
                }
                await followController.followUnFollowUser();
              }
              StatusModel response =
                  await UserService.instance.blockUser(userId: user?.id ?? -1);
              if (response.status == true) {
                await _updateStatus(user?.id ?? -1, true);
              }
              completion.call();
            } catch (e, st) {
              // v1.1.40: network/Firestore failures must not crash the app.
              // The REST call above is the source of truth; anything that
              // fails here is surfaced to the user and logged.
              Loggers.error('blockUser failed: $e\n$st');
              showSnackBar(LKey.somethingWentWrong.tr);
            }
          },
        ),
        isScrollControlled: true);
  }

  Future<void> unblockUser(User? user, Function() completion) async {
    await Get.bottomSheet(
        ConfirmationSheet(
          title: LKey.unblockUser.trParams({'username': user?.fullname ?? ''}),
          description: LKey.unblockUserConfirmation.tr,
          positiveText: LKey.unBlock.tr,
          onTap: () async {
            try {
              StatusModel response = await UserService.instance
                  .unBlockUser(userId: user?.id ?? -1);
              if (response.status == true) {
                completion.call();
                await _updateStatus(user?.id ?? -1, false);
              }
            } catch (e, st) {
              Loggers.error('unblockUser failed: $e\n$st');
              showSnackBar(LKey.somethingWentWrong.tr);
            }
          },
        ),
        isScrollControlled: true);
  }

  Future<void> _updateStatus(int userId, bool isBlocked) async {
    // v1.1.40: this is a best-effort mirror of the block state for the chat
    // layer. The block/unblock itself already succeeded through the REST API.
    // When the device is offline Firestore throws
    // [cloud_firestore/unavailable]; previously that exception escaped an
    // un-awaited bottom-sheet callback and crashed the whole app. Log it and
    // keep the app running.
    try {
      FirebaseFirestore db = FirebaseFirestore.instance;
      User? myUser = SessionManager.instance.getUser();
      DocumentReference documentSender = db
          .collection(FirebaseConst.users)
          .doc(myUser?.id.toString())
          .collection(FirebaseConst.usersList)
          .doc(userId.toString());

      DocumentReference documentReceiver = db
          .collection(FirebaseConst.users)
          .doc(userId.toString())
          .collection(FirebaseConst.usersList)
          .doc(myUser?.id.toString());

      if ((await documentSender.get()).exists) {
        await documentSender.update({
          FirebaseConst.iBlocked: isBlocked,
          FirebaseConst.requestType: UserRequestAction.block.title,
        });
      }

      if ((await documentReceiver.get()).exists) {
        await documentReceiver.update({
          FirebaseConst.iAmBlocked: isBlocked,
          FirebaseConst.requestType: UserRequestAction.block.title,
        });
      }
    } catch (e, st) {
      Loggers.error('Block status Firestore sync failed: $e\n$st');
    }
  }
}
