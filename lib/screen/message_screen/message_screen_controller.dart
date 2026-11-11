import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/controller/firebase_firestore_controller.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/supabase/chat_api_repository.dart';
import 'package:nimiro/common/widget/confirmation_dialog.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/chat/chat_thread.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/dashboard_screen/dashboard_screen_controller.dart';

class MessageScreenController extends BaseController {
  List<String> chatCategories = [LKey.chats.tr, LKey.requests.tr];
  RxInt selectedChatCategory = 0.obs;
  PageController pageController = PageController();
  User? myUser = SessionManager.instance.getUser();
  RxList<ChatThread> chatsUsers = <ChatThread>[].obs;
  RxList<ChatThread> requestsUsers = <ChatThread>[].obs;
  final dashboardController = Get.find<DashboardScreenController>();
  final firebaseFirestoreController = Get.find<FirebaseFirestoreController>();
  final ChatApiRepository _repo = ChatApiRepository.instance;
  ChatSubscription? _subscription;

  /// Chats the user deleted on this device. Until a genuinely newer message
  /// arrives, an in-flight poll must not put the chat back on screen.
  final Map<int, int> _deletedAt = <int, int>{};

  @override
  void onInit() {
    super.onInit();
    pageController = PageController(initialPage: selectedChatCategory.value);
    _listenToUserChatsAndRequests();
  }

  @override
  void onClose() {
    super.onClose();
    if (_subscription != null) _repo.unsubscribe(_subscription!);
  }

  void onPageChanged(int index) {
    selectedChatCategory.value = index;
  }

  Future<void> _listenToUserChatsAndRequests() async {
    if (myUser?.id == null) return;
    isLoading.value = true;
    try {
      final rows = await _repo
          .listConversationsForUser(myUser!.id!)
          .timeout(const Duration(seconds: 15));
      _replaceRows(rows);
    } catch (error) {
      Loggers.error('Failed to load conversations: $error');
    } finally {
      isLoading.value = false;
    }

    _subscription = _repo.subscribeToUserConversations(
      userId: myUser!.id!,
      onChange: (event, data) {
        final rows = data['rows'];
        if (rows is List) {
          _replaceRows(rows.whereType<Map<String, dynamic>>().toList());
          return;
        }
        final isDeletedFlag = event == 'delete' || data['is_deleted'] == true;
        _applyRow(data, isDelete: isDeletedFlag);
      },
    );
  }

  void _applyRow(Map<String, dynamic> row, {required bool isDelete}) {
    final userIdHint = int.tryParse('${row['user_id']}');
    final previous = userIdHint == null ? null : _threadFor(userIdHint);
    previous?.disposeChatUserBinding();

    final chatUser = ChatThread.fromJson(row, chatUser: previous?.chatUser);
    final userId = chatUser.userId;
    chatsUsers.removeWhere((user) => user.userId == userId);
    requestsUsers.removeWhere((user) => user.userId == userId);
    if (isDelete || chatUser.isDeleted == true) return;
    if (userId != null && userId > 0) {
      firebaseFirestoreController.fetchUserIfNeeded(userId);
      if (chatUser.chatUser == null) chatUser.bindChatUser();
    }
    if (chatUser.chatType == ChatType.approved) {
      chatsUsers.add(chatUser);
    } else {
      requestsUsers.add(chatUser);
    }
    _sortLists();
  }

  ChatThread? _threadFor(int userId) =>
      chatsUsers.firstWhereOrNull((thread) => thread.userId == userId) ??
      requestsUsers.firstWhereOrNull((thread) => thread.userId == userId);

  bool _isLocallyDeleted(ChatThread thread) {
    final userId = thread.userId;
    if (userId == null) return false;
    final deletedAt = _deletedAt[userId];
    if (deletedAt == null) return false;

    // A message newer than the deletion re-opens the chat on the server, so
    // let it through instead of hiding it forever.
    final lastActivity = int.tryParse(thread.id ?? '') ?? 0;
    if (lastActivity > deletedAt) {
      _deletedAt.remove(userId);
      return false;
    }
    return true;
  }

  /// Mirror the server list exactly.
  ///
  /// Applying only the rows that still exist was not enough: when the other
  /// account was deleted, the next poll simply contained fewer rows and the
  /// stale conversation stayed in the local list. Replacing both lists makes
  /// a deleted account disappear on the very next refresh.
  void _replaceRows(List<Map<String, dynamic>> rows) {
    final existing = <int, ChatThread>{};
    for (final thread in [...chatsUsers, ...requestsUsers]) {
      final userId = thread.userId;
      if (userId != null) existing[userId] = thread;
    }
    for (final thread in existing.values) {
      thread.disposeChatUserBinding();
    }

    final chats = <ChatThread>[];
    final requests = <ChatThread>[];
    final seen = <int>{};

    for (final row in rows) {
      final userIdHint = int.tryParse('${row['user_id']}');
      final previous = userIdHint == null ? null : existing[userIdHint];
      final chatUser = ChatThread.fromJson(row, chatUser: previous?.chatUser);
      final userId = chatUser.userId;
      if (userId == null || userId <= 0) continue;
      if (chatUser.isDeleted == true) continue;
      if (_isLocallyDeleted(chatUser)) continue;
      if (!seen.add(userId)) continue;
      firebaseFirestoreController.fetchUserIfNeeded(userId);
      if (chatUser.chatUser == null) chatUser.bindChatUser();
      if (chatUser.chatType == ChatType.approved) {
        chats.add(chatUser);
      } else {
        requests.add(chatUser);
      }
    }

    chatsUsers.assignAll(chats);
    requestsUsers.assignAll(requests);
    _sortLists();
  }

  void _sortLists() {
    chatsUsers.sort((a, b) => (b.id ?? '0').compareTo(a.id ?? '0'));
    requestsUsers.sort((a, b) => (b.id ?? '0').compareTo(a.id ?? '0'));
  }

  void onLongPress(ChatThread chatConversation) {
    Get.bottomSheet(ConfirmationSheet(
      title: LKey.deleteChatUserTitle
          .trParams({'user_name': chatConversation.chatUser?.username ?? ''}),
      description: LKey.deleteChatUserDescription.tr,
      onTap: () async {
        final otherUserId = chatConversation.userId;
        if (myUser?.id == null || otherUserId == null) return;

        final time = DateTime.now().millisecondsSinceEpoch;
        showLoader();
        bool deleted = false;
        try {
          deleted = await _repo.upsertConversation(
            ownerUserId: myUser!.id!,
            otherUserId: otherUserId,
            data: {
              'deleted_id': time,
              'is_deleted': true,
            },
          );
        } catch (error) {
          Loggers.error('USER NOT DELETE : $error');
        } finally {
          stopLoader();
        }

        if (!deleted) {
          showSnackBar(LKey.somethingWentWrong.tr);
          return;
        }

        // The backend is authoritative, but removing the row immediately makes
        // the delete feel instant and prevents a stale in-flight poll from
        // bringing the chat back.
        _deletedAt[otherUserId] = time;
        chatConversation.disposeChatUserBinding();
        chatsUsers.removeWhere((thread) => thread.userId == otherUserId);
        requestsUsers.removeWhere((thread) => thread.userId == otherUserId);
      },
    ));
  }
}
