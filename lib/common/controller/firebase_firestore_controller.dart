import 'package:nimiro/common/service/supabase/chat_api_repository.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/extensions/user_extension.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/service/supabase/supabase_service.dart';
import 'package:nimiro/model/user_model/app_user.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class FirebaseFirestoreController extends BaseController {
  RxList<AppUser> users = <AppUser>[].obs;
  static final instance = FirebaseFirestoreController();
  final Set<int> _fetchingUserIds = <int>{};

  SupabaseClient get _db {
    if (!SupabaseService.instance.isInitialized) {
      SupabaseService.instance.initialize();
    }
    return SupabaseService.instance.client;
  }

  /// Add or merge a user into the local cache without hitting the network.
  ///
  /// Existing values are kept when the incoming object only carries a partial
  /// profile. This is what keeps an avatar visible when a poll or a notification
  /// delivers a row without a photo.
  void cacheUser(AppUser user) {
    final id = user.userId;
    if (id == null || id <= 0) return;

    final incoming = AppUser(
      userId: id,
      username: AppUser.cleanText(user.username),
      fullname: AppUser.cleanText(user.fullname),
      profile: AppUser.cleanText(user.profile),
      isVerify: user.isVerify,
      identity: AppUser.cleanText(user.identity),
      country: AppUser.cleanText(user.country),
    );

    final index = users.indexWhere((element) => element.userId == id);
    if (index == -1) {
      users.add(incoming);
      return;
    }

    final old = users[index];
    users[index] = AppUser(
      userId: id,
      username: incoming.username ?? old.username,
      fullname: incoming.fullname ?? old.fullname,
      profile: incoming.profile ?? old.profile,
      isVerify: incoming.isVerify ?? old.isVerify,
      identity: incoming.identity ?? old.identity,
      country: incoming.country ?? old.country,
    );
  }

  void fetchUserIfNeeded(int userId) {
    if (userId <= 0) return;
    if (users.any((element) => element.userId == userId)) {
      Loggers.info('[LOAD_USER] User $userId already loaded, skipping fetch');
      return;
    }
    // Several inbox rows and the open chat can request the same profile at the
    // same time; one request is enough.
    if (!_fetchingUserIds.add(userId)) return;

    Loggers.info('[LOAD_USER] Fetching user $userId from the chat API');
    ChatApiRepository.instance.fetchAppUser(userId).then((row) {
      if (row == null) return;
      final fetchedUser = AppUser.fromJson(row);
      cacheUser(fetchedUser);
      Loggers.info('[LOAD_USER] User ${fetchedUser.userId} cached');
    }).catchError((error) {
      Loggers.error('[LOAD_USER] Failed to fetch user $userId — $error');
    }).whenComplete(() {
      _fetchingUserIds.remove(userId);
    });
  }

  void updateUser(User? user) async {
    if (user == null || user.id == null) return;
    final merged = _mergeWithCached(user.appUser);
    cacheUser(merged);
    await _upsertUser(merged);
  }

  void addUser(User? user) {
    if (user == null || user.id == null) return;
    final merged = _mergeWithCached(user.appUser);
    // Update the local cache first: the avatar must be available even when the
    // network upsert is slow or fails.
    cacheUser(merged);
    _upsertUser(merged);
  }

  AppUser _mergeWithCached(AppUser incoming) {
    final id = incoming.userId;
    if (id == null) return incoming;
    final old = users.firstWhereOrNull((element) => element.userId == id);
    return AppUser(
      userId: id,
      username: AppUser.cleanText(incoming.username) ?? old?.username,
      fullname: AppUser.cleanText(incoming.fullname) ?? old?.fullname,
      profile: AppUser.cleanText(incoming.profile) ?? old?.profile,
      isVerify: incoming.isVerify ?? old?.isVerify,
      identity: AppUser.cleanText(incoming.identity) ?? old?.identity,
      country: AppUser.cleanText(incoming.country) ?? old?.country,
    );
  }

  Future<void> _upsertUser(AppUser chatUser) async {
    try {
      await ChatApiRepository.instance.upsertAppUser(chatUser.toJson());
    } catch (e) {
      Loggers.error('[ADD_USER] Failed to add user ${chatUser.userId} — $e');
    }
  }

  Future<void> deleteUser(int? userId) async {
    if (userId == null) return;
    // Remove locally as well; otherwise `fetchUserIfNeeded` keeps finding the
    // deleted row and never asks the server for a fresh profile.
    users.removeWhere((element) => element.userId == userId);
    try {
      await _db.from('app_users').delete().eq('doc_id', '$userId');
    } catch (e) {
      Loggers.error('[DELETE_USER] Failed to delete user $userId — $e');
    }
  }
}
