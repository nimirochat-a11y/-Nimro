import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:nimiro/common/service/appwrite/appwrite_service.dart';

/// Appwrite-backed replacement for the Firestore chat structure.
///
/// Conversation rows are stored one per direction, keyed as
/// "{ownerUserId}_{otherUserId}", mirroring the old
/// users/{id}/users_list/{otherId} Firestore path.
///
/// Message rows live in a single flat table and are filtered by
/// `conversation_id`.
class ChatRepository {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  static const String conversationsCollectionId = 'conversations';
  static const String messagesCollectionId = 'messages';

  TablesDB get _db {
    if (!AppwriteService.instance.isInitialized) {
      AppwriteService.instance.initialize();
    }
    return AppwriteService.instance.tablesDB;
  }

  Realtime get _realtime {
    if (!AppwriteService.instance.isInitialized) {
      AppwriteService.instance.initialize();
    }
    return AppwriteService.instance.realtime;
  }

  String conversationDocId(int ownerUserId, int otherUserId) =>
      '${ownerUserId}_$otherUserId';

  // ---- Conversations ----

  Future<Map<String, dynamic>?> getConversation(
      int ownerUserId, int otherUserId) async {
    try {
      final row = await _db.getRow(
        databaseId: AppwriteService.databaseId,
        tableId: conversationsCollectionId,
        rowId: conversationDocId(ownerUserId, otherUserId),
      );
      return row.data;
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      rethrow;
    }
  }

  Future<void> upsertConversation({
    required int ownerUserId,
    required int otherUserId,
    required Map<String, dynamic> data,
  }) async {
    final docId = conversationDocId(ownerUserId, otherUserId);
    final payload = {
      'user_id': ownerUserId,
      'other_user_id': otherUserId,
      ...data,
    };
    try {
      await _db.updateRow(
        databaseId: AppwriteService.databaseId,
        tableId: conversationsCollectionId,
        rowId: docId,
        data: payload,
      );
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        await _db.createRow(
          databaseId: AppwriteService.databaseId,
          tableId: conversationsCollectionId,
          rowId: docId,
          data: payload,
        );
      } else {
        rethrow;
      }
    }
  }

  /// Subscribes to realtime changes for a single conversation row.
  RealtimeSubscription subscribeToConversation({
    required int ownerUserId,
    required int otherUserId,
    required void Function(Map<String, dynamic> data) onUpdate,
    required void Function() onDelete,
  }) {
    final docId = conversationDocId(ownerUserId, otherUserId);
    final channel = Channel.tablesdb(AppwriteService.databaseId)
        .table(conversationsCollectionId)
        .row(docId);
    final subscription = _realtime.subscribe([channel.toString()]);
    subscription.stream.listen((event) {
      final isDelete = event.events.any((e) => e.endsWith('.delete'));
      if (isDelete) {
        onDelete();
      } else {
        onUpdate(event.payload);
      }
    });
    return subscription;
  }

  // ---- Messages ----

  Future<void> createMessage({
    required String messageId,
    required Map<String, dynamic> data,
  }) async {
    await _db.createRow(
      databaseId: AppwriteService.databaseId,
      tableId: messagesCollectionId,
      rowId: messageId,
      data: data,
    );
  }

  Future<Map<String, dynamic>?> getMessage(String messageId) async {
    try {
      final row = await _db.getRow(
        databaseId: AppwriteService.databaseId,
        tableId: messagesCollectionId,
        rowId: messageId,
      );
      return row.data;
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      rethrow;
    }
  }

  Future<void> updateMessage(
      String messageId, Map<String, dynamic> data) async {
    await _db.updateRow(
      databaseId: AppwriteService.databaseId,
      tableId: messagesCollectionId,
      rowId: messageId,
      data: data,
    );
  }

  Future<void> deleteMessage(String messageId) async {
    await _db.deleteRow(
      databaseId: AppwriteService.databaseId,
      tableId: messagesCollectionId,
      rowId: messageId,
    );
  }

  Future<models.RowList> listMessages({
    required String conversationId,
    required int limit,
    String? cursorAfterDocumentId,
  }) {
    final queries = <String>[
      Query.equal('conversation_id', conversationId),
      Query.orderDesc('\$createdAt'),
      Query.limit(limit),
    ];
    if (cursorAfterDocumentId != null) {
      queries.add(Query.cursorAfter(cursorAfterDocumentId));
    }
    return _db.listRows(
      databaseId: AppwriteService.databaseId,
      tableId: messagesCollectionId,
      queries: queries,
    );
  }

  /// Subscribes to realtime create/update/delete events for all messages.
  /// The caller filters events by conversation_id since Appwrite realtime
  /// channels are table-wide, not query-scoped.
  RealtimeSubscription subscribeToMessages({
    required void Function(String event, Map<String, dynamic> payload) onEvent,
  }) {
    final channel =
        Channel.tablesdb(AppwriteService.databaseId).table(messagesCollectionId).row();
    final subscription = _realtime.subscribe([channel.toString()]);
    subscription.stream.listen((event) {
      final type = event.events.any((e) => e.endsWith('.create'))
          ? 'create'
          : event.events.any((e) => e.endsWith('.update'))
              ? 'update'
              : event.events.any((e) => e.endsWith('.delete'))
                  ? 'delete'
                  : 'unknown';
      onEvent(type, event.payload);
    });
    return subscription;
  }
}
