import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/extensions/user_extension.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/service/appwrite/appwrite_service.dart';
import 'package:nimiro/model/livestream/app_user.dart';
import 'package:nimiro/model/user_model/user_model.dart';

/// Replaces the previous Firestore-backed controller. Keeps the same public
/// method names/signatures so existing call sites do not need to change.
/// Backed by Appwrite Databases (collection: app_users).
class FirebaseFirestoreController extends BaseController {
  RxList<AppUser> users = <AppUser>[].obs;
  static final instance = FirebaseFirestoreController();

  Databases get _db {
    if (!AppwriteService.instance.isInitialized) {
      AppwriteService.instance.initialize();
    }
    return AppwriteService.instance.databases;
  }

  void fetchUserIfNeeded(int userId) {
    Loggers.info('[LOAD_USER] Checking if user $userId already exists in list');
    final exists = users.any((element) => element.userId == userId);
    if (exists) {
      Loggers.info('[LOAD_USER] User $userId already loaded, skipping fetch');
      return;
    }
    Loggers.info('[LOAD_USER] Fetching user $userId from Appwrite');
    _db
        .getDocument(
          databaseId: AppwriteService.databaseId,
          collectionId: AppwriteService.appUsersCollectionId,
          documentId: '$userId',
        )
        .then((doc) {
          final fetchedUser = AppUser.fromJson(doc.data);
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
      await _db.updateDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.appUsersCollectionId,
        documentId: '${user.id}',
        data: chatUser.toJson(),
      );
    } on AppwriteException catch (e) {
      Loggers.error('[UPDATE_USER] Failed to update user ${user.id} — ${e.message}');
    }
  }

  void addUser(User? user) async {
    if (user == null) return;
    AppUser chatUser = user.appUser;
    try {
      await _db.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.appUsersCollectionId,
        documentId: '${user.id}',
      );
      // Document already exists — nothing to do.
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        try {
          await _db.createDocument(
            databaseId: AppwriteService.databaseId,
            collectionId: AppwriteService.appUsersCollectionId,
            documentId: '${user.id}',
            data: chatUser.toJson(),
          );
        } on AppwriteException catch (createError) {
          Loggers.error('[ADD_USER] Failed to create user ${user.id} — ${createError.message}');
        }
      } else {
        Loggers.error('[ADD_USER] Failed to check user ${user.id} — ${e.message}');
      }
    }
  }

  Future<void> deleteUser(int? userId) async {
    if (userId == null) return;
    try {
      await _db.deleteDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.appUsersCollectionId,
        documentId: '$userId',
      );
    } on AppwriteException catch (e) {
      Loggers.error('[DELETE_USER] Failed to delete user $userId — ${e.message}');
    }
  }
}
