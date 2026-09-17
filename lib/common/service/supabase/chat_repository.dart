import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/utilities/const_res.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/supabase/supabase_service.dart';
import 'package:nimiro/common/service/utils/params.dart';

/// Small wrapper types mirroring the previous row/document shape, so the
/// calling code (chat_screen_controller.dart) stays unchanged.
class MessageDoc {
  final String $id;
  final Map<String, dynamic> data;
  MessageDoc(this.$id, this.data);
}

class MessageDocList {
  final List<MessageDoc> rows;
  MessageDocList(this.rows);
}

/// Chat data access.
///
/// Every read and write goes through the Laravel chat proxy (ChatController),
/// which is the only component holding the Supabase service key. The app never
/// queries the chat tables directly, which is what lets those tables keep
/// row-level security enabled without breaking chat — a direct client
/// connection is exactly what the lock exists to stop.
///
/// Conversation rows are stored one per direction, keyed as
/// "{ownerUserId}_{otherUserId}". Message rows live in a single flat table and
/// are filtered by `conversation_id`.
///
/// Change notification is a short poll. The previous implementation used
/// Postgres-changes subscriptions that required a direct database connection;
/// the public method signatures are unchanged, so no screen code had to move.
/// The returned channel is an inert handle used purely as the unsubscribe key.
class ChatRepository {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  String get _chatBase => '${apiURL}chat/';
  static const Duration _pollInterval = Duration(seconds: 4);

  /// Live polls, keyed by the channel handle handed back to the caller.
  final Map<RealtimeChannel, Timer> _polls = {};

  /// Live polls started under a plain name rather than a handle.
  final Map<String, Timer> _namedPolls = {};

  SupabaseClient get _db => SupabaseService.instance.client;

  Map<String, String> get _headers => {
        Params.apikey: apiKey,
        Params.authToken: SessionManager.instance.getAuthToken() ?? '',
      };

  String conversationDocId(int ownerUserId, int otherUserId) =>
      '${ownerUserId}_$otherUserId';

  Future<dynamic> _call(String endpoint, Map<String, dynamic> body) async {
    final response = await http
        .post(Uri.parse('$_chatBase$endpoint'),
            headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw Exception('Unauthorized Access');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Chat request failed: ${response.statusCode}');
    }
    if (response.body.isEmpty) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected chat response');
    }
    return decoded['data'];
  }

  // ---- Conversations ----

  Future<Map<String, dynamic>?> getConversation(
      int ownerUserId, int otherUserId) async {
    final data = await _call('fetchConversation', {
      'other_user_id': otherUserId,
      'doc_id': conversationDocId(ownerUserId, otherUserId),
    });
    return data == null ? null : Map<String, dynamic>.from(data as Map);
  }

  Future<void> upsertConversation({
    required int ownerUserId,
    required int otherUserId,
    required Map<String, dynamic> data,
  }) async {
    await _call('upsertConversation', {
      'other_user_id': otherUserId,
      'doc_id': conversationDocId(ownerUserId, otherUserId),
      ...data,
    });
  }

  /// Watches one conversation row and reports changes.
  ///
  /// Returns an inert channel used only as the handle the caller passes back to
  /// [unsubscribe]; no realtime socket is opened.
  RealtimeChannel subscribeToConversation({
    required int ownerUserId,
    required int otherUserId,
    required void Function(Map<String, dynamic> data) onUpdate,
    required void Function() onDelete,
  }) {
    final channel =
        _inertChannel('poll_conversation_${ownerUserId}_$otherUserId');
    String? lastSeen;

    _startPoll(channel, () async {
      final data = await getConversation(ownerUserId, otherUserId);

      if (data == null) {
        if (lastSeen != null) {
          lastSeen = null;
          onDelete();
        }
        return;
      }

      final fingerprint = jsonEncode(data);
      if (fingerprint != lastSeen) {
        lastSeen = fingerprint;
        onUpdate(data);
      }
    });

    return channel;
  }

  // ---- Messages ----

  Future<void> createMessage({
    required String messageId,
    required Map<String, dynamic> data,
  }) async {
    await _call('sendMessage', {'doc_id': messageId, ...data});
  }

  Future<Map<String, dynamic>?> getMessage(String messageId) async {
    final data = await _call('fetchMessage', {'doc_id': messageId});
    return data == null ? null : Map<String, dynamic>.from(data as Map);
  }

  Future<void> updateMessage(String messageId, Map<String, dynamic> data) async {
    await _call('updateMessage', {'doc_id': messageId, 'data': data});
  }

  Future<void> deleteMessage(String messageId) async {
    await _call('deleteMessage', {'doc_id': messageId});
  }

  Future<MessageDocList> listMessages({
    required String conversationId,
    required int limit,
    String? cursorAfterDocumentId,
  }) async {
    final data = await _call('fetchMessages', {
      'conversation_id': conversationId,
      'limit': limit,
      if (cursorAfterDocumentId != null)
        'cursor_after_document_id': cursorAfterDocumentId,
    });

    final rows = <MessageDoc>[];
    for (final row in (data as List? ?? [])) {
      final map = Map<String, dynamic>.from(row as Map);
      rows.add(MessageDoc(map['doc_id'].toString(), map));
    }
    return MessageDocList(rows);
  }

  /// Watches a conversation's messages and reports each change.
  ///
  /// The caller filters by conversation, exactly as it did with the previous
  /// stream, so the signature stays as it was.
  RealtimeChannel subscribeToMessages({
    required void Function(String event, Map<String, dynamic> payload) onEvent,
    String? conversationId,
  }) {
    final channel = _inertChannel(
        conversationId == null ? 'poll_messages' : 'poll_messages_$conversationId');
    Map<String, String> known = {};

    _startPoll(channel, () async {
      final data = await _call('fetchMessages', {
        if (conversationId != null) 'conversation_id': conversationId,
        'limit': 50,
      });

      final current = <String, String>{};
      for (final row in (data as List? ?? [])) {
        final map = Map<String, dynamic>.from(row as Map);
        current[map['doc_id'].toString()] = jsonEncode(map);
      }

      for (final entry in current.entries) {
        final previous = known[entry.key];
        if (previous == null) {
          onEvent('create', jsonDecode(entry.value) as Map<String, dynamic>);
        } else if (previous != entry.value) {
          onEvent('update', jsonDecode(entry.value) as Map<String, dynamic>);
        }
      }

      for (final gone in known.keys.toSet().difference(current.keys.toSet())) {
        onEvent('delete', {'doc_id': gone});
      }

      known = current;
    });

    return channel;
  }

  // ---- Conversation list (inbox) ----

  Future<List<Map<String, dynamic>>> listConversationsForUser(
      int userId) async {
    final data = await _call('fetchMyConversations', const {});
    final rows = <Map<String, dynamic>>[];
    for (final row in (data as List? ?? [])) {
      rows.add(Map<String, dynamic>.from(row as Map));
    }
    return rows;
  }

  // ---- App users (chat profile mirror) ----

  /// Reads chat-profile rows for the given ids, or a page of them when empty.
  Future<List<Map<String, dynamic>>> fetchAppUsers(
      {List<int> userIds = const []}) async {
    final data = await _call('fetchAppUsers', {
      if (userIds.isNotEmpty) 'user_ids': userIds,
    });
    final rows = <Map<String, dynamic>>[];
    for (final row in (data as List? ?? [])) {
      rows.add(Map<String, dynamic>.from(row as Map));
    }
    return rows;
  }

  /// Creates or updates the caller's own chat-profile row.
  Future<void> upsertAppUser(Map<String, dynamic> data) async {
    await _call('upsertAppUser', data);
  }

  /// Removes the caller's own chat-profile row.
  Future<void> deleteAppUser() async {
    await _call('deleteAppUser', const {});
  }

  /// Watches the user's inbox and reports each change.
  RealtimeChannel subscribeToUserConversations({
    required int userId,
    required void Function(String event, Map<String, dynamic> data) onChange,
  }) {
    final channel = _inertChannel('poll_user_conversations_$userId');
    Map<String, String> known = {};

    _startPoll(channel, () async {
      final rows = await listConversationsForUser(userId);

      final current = <String, String>{};
      for (final row in rows) {
        final key = (row['doc_id'] ?? row['conversation_id'] ?? '').toString();
        if (key.isEmpty) continue;
        current[key] = jsonEncode(row);
      }

      for (final entry in current.entries) {
        final previous = known[entry.key];
        if (previous == null) {
          onChange('create', jsonDecode(entry.value) as Map<String, dynamic>);
        } else if (previous != entry.value) {
          onChange('update', jsonDecode(entry.value) as Map<String, dynamic>);
        }
      }

      for (final gone in known.keys.toSet().difference(current.keys.toSet())) {
        onChange('delete', {'doc_id': gone});
      }

      known = current;
    });

    return channel;
  }

  /// Stops the poll behind a channel handle. The argument is the value returned
  /// by one of the subscribe methods above.
  void unsubscribe(RealtimeChannel channel) {
    _polls.remove(channel)?.cancel();
    try {
      _db.removeChannel(channel);
    } catch (_) {
      // The channel was never actually joined; nothing to release.
    }
  }

  /// Stops a poll that was started under a plain name instead of a handle.
  ///
  /// Kept for call sites that only ever tear down, never subscribe. The name is
  /// recorded in a side map so no internal channel field is touched.
  void unsubscribeByName(String name) {
    _namedPolls.remove(name)?.cancel();
  }

  void disposeAll() {
    for (final timer in _polls.values) {
      timer.cancel();
    }
    _polls.clear();
  }

  // ---- poll plumbing ----

  /// A never-joined channel, used purely as the unsubscribe handle so the
  /// existing call sites keep working unchanged.
  RealtimeChannel _inertChannel(String name) => _db.channel(name);

  void _startPoll(RealtimeChannel channel, Future<void> Function() tick) {
    _polls.remove(channel)?.cancel();
    _polls[channel] = Timer.periodic(_pollInterval, (_) async {
      try {
        await tick();
      } catch (e) {
        Loggers.error('Chat poll error: $e');
      }
    });
  }
}
