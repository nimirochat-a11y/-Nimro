import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/extensions/user_extension.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/service/supabase/chat_api_repository.dart';
import 'package:nimiro/model/livestream/app_user.dart';
import 'package:nimiro/model/user_model/user_model.dart';

/// Chat-profile mirror for the people a user sees in chat and live rooms.
///
/// NOTE ON THE NAME: despite the historical `Firebase` prefix, this controller
/// never touched Firestore in this build — it read and wrote the `app_users`
/// table directly on Supabase using the publishable key that ships inside the
/// app. That is exactly the path being closed (RLS + anon grant revocation), so
/// the calls now go through the backend proxy, which holds the service_role key
/// on the server and derives the acting user from the auth token.
///
/// The public API is unchanged on purpose, so no calling screen needs edits.
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

    Loggers.info('[LOAD_USER] Fetching user $userId from the chat backend');
    ChatApiRepository.instance.fetchAppUser(userId).then((row) {
      if (row == null) return;
      final fetchedUser = AppUser.fromJson(row);
      users.add(fetchedUser);
      Loggers.info('[LOAD_USER] User ${fetchedUser.userId} added to list');
    }).catchError((error) {
      Loggers.error('[LOAD_USER] Failed to fetch user $userId — $error');
    });
  }

  void updateUser(User? user) async {
    if (user == null) return;
    final AppUser chatUser = user.appUser;
    try {
      // The backend always writes the row of the authenticated user, so this
      // can only ever update the caller's own profile.
      await ChatApiRepository.instance.upsertAppUser({
        'doc_id': '${user.id}',
        ...chatUser.toJson(),
      });
    } catch (e) {
      Loggers.error('[UPDATE_USER] Failed to update user ${user.id} — $e');
    }
  }

  void addUser(User? user) async {
    if (user == null) return;
    final AppUser chatUser = user.appUser;
    try {
      await ChatApiRepository.instance.upsertAppUser({
        'doc_id': '${user.id}',
        ...chatUser.toJson(),
      });
    } catch (e) {
      Loggers.error('[ADD_USER] Failed to add user ${user.id} — $e');
    }
  }

  Future<void> deleteUser(int? userId) async {
    if (userId == null) return;
    try {
      // Removes the authenticated user's own chat profile.
      await ChatApiRepository.instance.deleteAppUser();
    } catch (e) {
      Loggers.error('[DELETE_USER] Failed to delete user $userId — $e');
    }
  }
}
