import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/extensions/user_extension.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/service/supabase/supabase_service.dart';
import 'package:nimiro/model/livestream/app_user.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FirebaseFirestoreController extends BaseController {
  RxList<AppUser> users = <AppUser>[].obs;
  static final instance = FirebaseFirestoreController();

  SupabaseClient get _db {
    if (!SupabaseService.instance.isInitialized) {
      SupabaseService.instance.initialize();
    }
    return SupabaseService.instance.client;
  }

  void fetchUserIfNeeded(int userId) {
    Loggers.info('[LOAD_USER] Checking if user $userId already exists in list');
    final exists = users.any((element) => element.userId == userId);
    if (exists) {
      Loggers.info('[LOAD_USER] User $userId already loaded, skipping fetch');
      return;
    }
    Loggers.info('[LOAD_USER] Fetching user $userId from Supabase');
    _db
        .from('app_users')
        .select()
        .eq('doc_id', '$userId')
        .maybeSingle()
        .then((row) {
          if (row == null) return;
          final fetchedUser = AppUser.fromJson(row);
          users.add(fetchedUser);
          Loggers.info('[LOAD_USER] User ${fetchedUser.userId} added to list');
        })
        .catchError((error) {
          Loggers.error('[LOAD_USER] Failed to fetch user $userId — $error');
        });
  }

  void updateUser(User? user) async {
    if (user == null) return;
    AppUser chatUser = user.appUser;
    try {
      await _db
          .from('app_users')
          .update(chatUser.toJson())
          .eq('doc_id', '${user.id}');
    } catch (e) {
      Loggers.error('[UPDATE_USER] Failed to update user ${user.id} — $e');
    }
  }

  void addUser(User? user) async {
    if (user == null) return;
    AppUser chatUser = user.appUser;
    try {
      final payload = <String, dynamic>{
        'doc_id': '${user.id}',
        ...chatUser.toJson(),
      };
      await _db.from('app_users').upsert(payload, onConflict: 'doc_id');
    } catch (e) {
      Loggers.error('[ADD_USER] Failed to add user ${user.id} — $e');
    }
  }

  Future<void> deleteUser(int? userId) async {
    if (userId == null) return;
    try {
      await _db.from('app_users').delete().eq('doc_id', '$userId');
    } catch (e) {
      Loggers.error('[DELETE_USER] Failed to delete user $userId — $e');
    }
  }
}
