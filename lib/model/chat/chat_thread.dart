import 'package:get/get.dart';
import 'package:nimiro/common/controller/firebase_firestore_controller.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/service/api/user_service.dart';
import 'package:nimiro/model/user_model/app_user.dart';

class ChatThread {
  int? userId;
  String? id;
  int? msgCount;
  ChatType? chatType;
  String? requestType;
  String? lastMsg;
  String? conversationId;
  int? deletedId;
  bool? isDeleted;
  bool? iAmBlocked;
  bool? iBlocked;

  ChatThread({
    this.userId,
    this.id,
    this.msgCount,
    this.chatType,
    this.requestType,
    this.lastMsg,
    this.conversationId,
    this.deletedId,
    this.isDeleted,
    this.iAmBlocked,
    this.iBlocked,
  });

  ChatThread.fromJson(Map<String, dynamic> json, {AppUser? chatUser}) {
    updateFromJson(json);
    if (chatUser != null) _chatUser.value = chatUser;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final text = value.trim().toLowerCase();
      if (text == 'true' || text == '1' || text == 't') return true;
      if (text == 'false' || text == '0' || text == 'f') return false;
    }
    return null;
  }

  /// Merge a server row into this thread without touching [chatUser].
  ///
  /// The polling endpoints return a fresh row every few seconds. Replacing the
  /// whole object used to drop the cached avatar until the next user lookup,
  /// which is why the peer's photo kept blinking while chatting.
  void updateFromJson(Map<String, dynamic> json) {
    if (json.containsKey('user_id')) {
      userId = _toInt(json['user_id']) ?? userId;
    }
    if (json.containsKey('id')) {
      id = json['id']?.toString() ?? id;
    }
    if (json.containsKey('msg_count')) {
      msgCount = _toInt(json['msg_count']) ?? msgCount;
    }
    if (json.containsKey('chat_type')) {
      chatType = ChatType.fromString(json['chat_type']?.toString());
    }
    if (json.containsKey('request_type')) {
      requestType = json['request_type']?.toString();
    }
    if (json.containsKey('last_msg')) {
      lastMsg = json['last_msg']?.toString();
    }
    if (json.containsKey('conversation_id')) {
      conversationId = json['conversation_id']?.toString() ?? conversationId;
    }
    if (json.containsKey('deleted_id')) {
      deletedId = _toInt(json['deleted_id']);
    }
    if (json.containsKey('is_deleted')) {
      isDeleted = _toBool(json['is_deleted']);
    }
    if (json.containsKey('i_am_blocked')) {
      iAmBlocked = _toBool(json['i_am_blocked']);
    }
    if (json.containsKey('i_blocked')) {
      iBlocked = _toBool(json['i_blocked']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    data['user_id'] = userId;
    data['id'] = id;
    data['msg_count'] = msgCount;
    data['chat_type'] = chatType?.value;
    data['request_type'] = requestType;
    data['last_msg'] = lastMsg;
    data['conversation_id'] = conversationId;
    data['deleted_id'] = deletedId;
    data['is_deleted'] = isDeleted;
    data['i_am_blocked'] = iAmBlocked;
    data['i_blocked'] = iBlocked;
    return data;
  }

  // Reactive variable for chat user
  final Rx<AppUser?> _chatUser = Rx<AppUser?>(null);
  Worker? _userWorker;
  bool _isFetchingUser = false;

  /// Plain getter and setter (same type = AppUser?)
  AppUser? get chatUser => _chatUser.value;

  set chatUser(AppUser? user) {
    if (user == null) return;
    final clean = AppUser(
      userId: user.userId,
      username: AppUser.cleanText(user.username),
      fullname: AppUser.cleanText(user.fullname),
      profile: AppUser.cleanText(user.profile),
      isVerify: user.isVerify,
      identity: AppUser.cleanText(user.identity),
      country: AppUser.cleanText(user.country),
    );
    _chatUser.value = clean; // update reactive value

    if (Get.isRegistered<FirebaseFirestoreController>()) {
      Get.find<FirebaseFirestoreController>().cacheUser(clean);
    }
  }

  /// Expose Rx version for reactive UI (`Obx`)
  Rx<AppUser?> get chatUserRx => _chatUser;

  /// Keep [chatUser] in sync with the shared user cache.
  ///
  /// This method is called from widgets, so it must be idempotent: registering
  /// a new `ever` worker on every rebuild leaked listeners and could reset the
  /// avatar to null while a lookup was in flight.
  void bindChatUser() {
    final controller = Get.find<FirebaseFirestoreController>();
    _userWorker ??= ever(controller.users, (_) => _syncChatUser(controller));
    _syncChatUser(controller);
  }

  void _syncChatUser(FirebaseFirestoreController controller) {
    final id = userId;
    if (id == null || id <= 0) return;

    final appUser =
        controller.users.firstWhereOrNull((element) => element.userId == id);
    if (appUser != null) {
      _chatUser.value = appUser;
      return;
    }

    // Keep whatever photo we already have while the lookup is running. A
    // failed lookup is NOT a reason to delete the user's profile row.
    if (_isFetchingUser) return;
    _isFetchingUser = true;
    _loadChatUser(controller, id);
  }

  Future<void> _loadChatUser(
      FirebaseFirestoreController controller, int id) async {
    try {
      final value = await UserService.instance.fetchUserDetails(userId: id);
      if (value != null) controller.addUser(value);
    } catch (error) {
      Loggers.error('[CHAT_USER] Could not fetch $id — $error');
    } finally {
      _isFetchingUser = false;
    }
  }

  /// Stop listening to the shared user cache (called when the inbox rebuilds).
  void disposeChatUserBinding() {
    _userWorker?.dispose();
    _userWorker = null;
  }
}

enum ChatType {
  request('request'),
  approved('approved');

  final String value;

  const ChatType(this.value);

  static ChatType fromString(String? value) {
    final normalized = value?.trim().toLowerCase();
    return ChatType.values.firstWhereOrNull((e) => e.value == normalized) ??
        ChatType.approved;
  }
}
