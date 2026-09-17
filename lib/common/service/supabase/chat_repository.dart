import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimiro/common/service/supabase/supabase_service.dart';

/// Small wrapper types mirroring the previous Appwrite row/document shape,
/// so the calling code (chat_screen_controller.dart) stays unchanged.
class MessageDoc {
  final String $id;
  final Map<String, dynamic> data;
  MessageDoc(this.$id, this.data);
}

class MessageDocList {
  final List<MessageDoc> rows;
  MessageDocList(this.rows);
}

/// Supabase-backed replacement for the Firestore/Appwrite chat structure.
///
/// Conversation rows are stored one per direction, keyed as
/// "{ownerUserId}_{otherUserId}".
/// Message rows live in a single flat table and are filtered by
/// `conversation_id`.
class ChatRepository {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  SupabaseClient get _db => SupabaseService.instance.client;

  String conversationDocId(int ownerUserId, int otherUserId) =>
      '${ownerUserId}_$otherUserId';

  // ---- Conversations ----

  Future<Map<String, dynamic>?> getConversation(
      int ownerUserId, int otherUserId) async {
    final docId = conversationDocId(ownerUserId, otherUserId);
    return await _db
        .from('conversations')
        .select()
        .eq('doc_id', docId)
        .maybeSingle();
  }

  Future<void> upsertConversation({
    required int ownerUserId,
    required int otherUserId,
    required Map<String, dynamic> data,
  }) async {
    final docId = conversationDocId(ownerUserId, otherUserId);
    final payload = <String, dynamic>{
      'doc_id': docId,
      'user_id': ownerUserId,
      'other_user_id': otherUserId,
      ...data,
    };
    await _db.from('conversations').upsert(payload, onConflict: 'doc_id');
  }

  RealtimeChannel subscribeToConversation({
    required int ownerUserId,
    required int otherUserId,
    required void Function(Map<String, dynamic> data) onUpdate,
    required void Function() onDelete,
  }) {
    final docId = conversationDocId(ownerUserId, otherUserId);
    final channel = _db.channel('conversation_$docId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'doc_id',
              value: docId),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) {
              onDelete();
            } else {
              onUpdate(payload.newRecord);
            }
          },
        )
        .subscribe();
    return channel;
  }

  // ---- Messages ----

  Future<void> createMessage({
    required String messageId,
    required Map<String, dynamic> data,
  }) async {
    final payload = <String, dynamic>{'doc_id': messageId, ...data};
    await _db.from('messages').insert(payload);
  }

  Future<Map<String, dynamic>?> getMessage(String messageId) async {
    return await _db
        .from('messages')
        .select()
        .eq('doc_id', messageId)
        .maybeSingle();
  }

  Future<void> updateMessage(
      String messageId, Map<String, dynamic> data) async {
    await _db.from('messages').update(data).eq('doc_id', messageId);
  }

  Future<void> deleteMessage(String messageId) async {
    await _db.from('messages').delete().eq('doc_id', messageId);
  }

  Future<MessageDocList> listMessages({
    required String conversationId,
    required int limit,
    String? cursorAfterDocumentId,
  }) async {
    var query =
        _db.from('messages').select().eq('conversation_id', conversationId);
    if (cursorAfterDocumentId != null) {
      final cursorId = int.tryParse(cursorAfterDocumentId);
      if (cursorId != null) {
        query = query.lt('id', cursorId);
      }
    }
    final result = await query.order('id', ascending: false).limit(limit);
    final rows = List<Map<String, dynamic>>.from(result)
        .map((row) => MessageDoc(row['doc_id'].toString(), row))
        .toList();
    return MessageDocList(rows);
  }

  RealtimeChannel subscribeToMessages({
    required void Function(String event, Map<String, dynamic> payload)
        onEvent,
  }) {
    final channel = _db.channel('messages_all');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            String type;
            switch (payload.eventType) {
              case PostgresChangeEvent.insert:
                type = 'create';
                break;
              case PostgresChangeEvent.update:
                type = 'update';
                break;
              case PostgresChangeEvent.delete:
                type = 'delete';
                break;
              default:
                type = 'unknown';
            }
            final data = payload.eventType == PostgresChangeEvent.delete
                ? payload.oldRecord
                : payload.newRecord;
            onEvent(type, data);
          },
        )
        .subscribe();
    return channel;
  }

  // ---- Conversation list (inbox) ----

  Future<List<Map<String, dynamic>>> listConversationsForUser(
      int userId) async {
    final result = await _db
        .from('conversations')
        .select()
        .eq('user_id', userId)
        .eq('is_deleted', false)
        .order('id', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  RealtimeChannel subscribeToUserConversations({
    required int userId,
    required void Function(
            String event, Map<String, dynamic> data)
        onChange,
  }) {
    final channel = _db.channel('user_conversations_$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId),
          callback: (payload) {
            String type;
            switch (payload.eventType) {
              case PostgresChangeEvent.insert:
                type = 'create';
                break;
              case PostgresChangeEvent.update:
                type = 'update';
                break;
              case PostgresChangeEvent.delete:
                type = 'delete';
                break;
              default:
                type = 'unknown';
            }
            final data = payload.eventType == PostgresChangeEvent.delete
                ? payload.oldRecord
                : payload.newRecord;
            onChange(type, data);
          },
        )
        .subscribe();
    return channel;
  }

  void unsubscribe(RealtimeChannel channel) {
    _db.removeChannel(channel);
  }
}
