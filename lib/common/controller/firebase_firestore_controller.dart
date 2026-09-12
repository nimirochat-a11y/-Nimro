import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/extensions/user_extension.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/service/appwrite/appwrite_service.dart';
import 'package:nimiro/model/livestream/app_user.dart';
import 'package:nimiro/model/user_model/user_model.dart';

class FirebaseFirestoreController extends BaseController {
  RxList<AppUser> users = <AppUser>[].obs;
  static final instance = FirebaseFirestoreController();

  TablesDB get _db {
    if (!AppwriteService.instance.isInitialized) {
      AppwriteService.instance.initialize();
    }
    return AppwriteService.instance.tablesDB;
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
        .getRow(
          databaseId: AppwriteService.databaseId,
          tableId: AppwriteService.appUsersCollectionId,
          rowId: '$userId',
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
      await _db.updateRow(
        databaseId: AppwriteService.databaseId,
        tableId: AppwriteService.appUsersCollectionId,
        rowId: '${user.id}',
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
      await _db.getRow(
        databaseId: AppwriteService.databaseId,
        tableId: AppwriteService.appUsersCollectionId,
        rowId: '${user.id}',
      );
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        try {
          await _db.createRow(
            databaseId: AppwriteService.databaseId,
            tableId: AppwriteService.appUsersCollectionId,
            rowId: '${user.id}',
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
      await _db.deleteRow(
        databaseId: AppwriteService.databaseId,
        tableId: AppwriteService.appUsersCollectionId,
        rowId: '$userId',
      );
    } on AppwriteException catch (e) {
      Loggers.error('[DELETE_USER] Failed to delete user $userId — ${e.message}');
    }
  }
}
