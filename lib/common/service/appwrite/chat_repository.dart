import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:nimiro/common/service/appwrite/appwrite_service.dart';

/// Appwrite-backed replacement for the Firestore chat structure.
///
/// Conversation documents are stored one per direction, keyed as
/// "{ownerUserId}_{otherUserId}", mirroring the old
/// users/{id}/users_list/{otherId} Firestore path.
///
/// Message documents live in a single flat collection and are filtered by
/// `conversation_id`.
class ChatRepository {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  static const String conversationsCollectionId = 'conversations';
  static const String messagesCollectionId = 'messages';

  Databases get _db {
    if (!AppwriteService.instance.isInitialized) {
      AppwriteService.instance.initialize();
    }
    return AppwriteService.instance.databases;
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
      final doc = await _db.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: conversationsCollectionId,
        documentId: conversationDocId(ownerUserId, otherUserId),
      );
      return doc.data;
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
      await _db.updateDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: conversationsCollectionId,
        documentId: docId,
        data: payload,
      );
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        await _db.createDocument(
          databaseId: AppwriteService.databaseId,
          collectionId: conversationsCollectionId,
          documentId: docId,
          data: payload,
        );
      } else {
        rethrow;
      }
    }
  }

  /// Subscribes to realtime changes for a single conversation document.
  RealtimeSubscription subscribeToConversation({
    required int ownerUserId,
    required int otherUserId,
    required void Function(Map<String, dynamic> data) onUpdate,
    required void Function() onDelete,
  }) {
    final docId = conversationDocId(ownerUserId, otherUserId);
    final channel =
        'databases.${AppwriteService.databaseId}.collections.$conversationsCollectionId.documents.$docId';
    final subscription = _realtime.subscribe([channel]);
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
    await _db.createDocument(
      databaseId: AppwriteService.databaseId,
      collectionId: messagesCollectionId,
      documentId: messageId,
      data: data,
    );
  }

  Future<Map<String, dynamic>?> getMessage(String messageId) async {
    try {
      final doc = await _db.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: messagesCollectionId,
        documentId: messageId,
      );
      return doc.data;
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      rethrow;
    }
  }

  Future<void> updateMessage(
      String messageId, Map<String, dynamic> data) async {
    await _db.updateDocument(
      databaseId: AppwriteService.databaseId,
      collectionId: messagesCollectionId,
      documentId: messageId,
      data: data,
    );
  }

  Future<void> deleteMessage(String messageId) async {
    await _db.deleteDocument(
      databaseId: AppwriteService.databaseId,
      collectionId: messagesCollectionId,
      documentId: messageId,
    );
  }

  Future<models.DocumentList> listMessages({
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
    return _db.listDocuments(
      databaseId: AppwriteService.databaseId,
      collectionId: messagesCollectionId,
      queries: queries,
    );
  }

  /// Subscribes to realtime create/update/delete events for messages
  /// belonging to [conversationId]. The caller is responsible for filtering
  /// events by conversation_id since Appwrite realtime channels are
  /// collection-wide, not query-scoped.
  RealtimeSubscription subscribeToMessages({
    required void Function(String event, Map<String, dynamic> payload) onEvent,
  }) {
    final channel =
        'databases.${AppwriteService.databaseId}.collections.$messagesCollectionId.documents';
    final subscription = _realtime.subscribe([channel]);
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
