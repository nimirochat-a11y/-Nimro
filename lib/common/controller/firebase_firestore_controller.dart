import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/extensions/user_extension.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/service/supabase/chat_repository.dart';
import 'package:nimiro/model/livestream/app_user.dart';
import 'package:nimiro/model/user_model/user_model.dart';

/// Chat-profile mirror.
///
/// Historically this talked to Firestore, then briefly to Supabase directly.
/// Both are gone: the chat tables now sit behind row-level security, so a
/// direct client connection is exactly what is blocked. Every read and write
/// goes through the Laravel chat proxy instead, which is the only component
/// holding the service key.
///
/// Kept under its original class name so the rest of the app — services,
/// controllers and `Get.put` call sites — needs no change.
class FirebaseFirestoreController extends BaseController {
  RxList<AppUser> users = <AppUser>[].obs;
  static final instance = FirebaseFirestoreController();

  void fetchUserIfNeeded(int userId) {
    Loggers.info('[LOAD_USER] Checking if user $userId already exists in list');
    final exists = users.any((element) => element.userId == userId);
    if (exists) {
      Loggers.info('[LOAD_USER] User $userId already loaded, skipping fetch');
      return;
    }
    Loggers.info('[LOAD_USER] Fetching user $userId through the chat proxy');
    ChatRepository.instance.fetchAppUsers(userIds: [userId]).then((rows) {
      if (rows.isEmpty) return;
      for (final row in rows) {
        final fetchedUser = AppUser.fromJson(row);
        if (fetchedUser.userId == null) continue;
        if (users.any((element) => element.userId == fetchedUser.userId)) {
          continue;
        }
        users.add(fetchedUser);
        Loggers.info('[LOAD_USER] User ${fetchedUser.userId} added to list');
      }
    }).catchError((error) {
      Loggers.error('[LOAD_USER] Failed to fetch user $userId — $error');
    });
  }

  Future<void> updateUser(User? user) async {
    if (user == null) return;
    try {
      await ChatRepository.instance.upsertAppUser(user.appUser.toJson());
    } catch (e) {
      Loggers.error('[UPDATE_USER] Failed to update user ${user.id} — $e');
    }
  }

  void addUser(User? user) async {
    if (user == null) return;
    try {
      await ChatRepository.instance.upsertAppUser(user.appUser.toJson());
    } catch (e) {
      Loggers.error('[ADD_USER] Failed to add user ${user.id} — $e');
    }
  }

  /// Removes the caller's own chat-profile row.
  ///
  /// The proxy derives the target from the authenticated token, so the former
  /// `userId` argument is accepted for source compatibility and not sent.
  Future<void> deleteUser(int? userId) async {
    try {
      await ChatRepository.instance.deleteAppUser();
    } catch (e) {
      Loggers.error('[DELETE_USER] Failed to delete user $userId — $e');
    }
  }
}
