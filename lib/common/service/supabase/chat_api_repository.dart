import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/utils/params.dart';
import 'package:nimiro/utilities/const_res.dart';

/// Row wrapper kept identical to the Supabase-backed implementation so the
/// calling screens do not have to change.
class MessageDoc {
  final String $id;
  final Map<String, dynamic> data;
  MessageDoc(this.$id, this.data);
}

class MessageDocList {
  final List<MessageDoc> rows;
  MessageDocList(this.rows);
}

/// Handle returned by the polling "subscriptions" below.
///
/// It replaces Supabase's RealtimeChannel: once RLS is on and the publishable
/// key is gone, the app can no longer receive Postgres change events directly,
/// so changes are polled through the backend instead.
class ChatSubscription {
  final String id;
  Timer? _timer;

  ChatSubscription(this.id);

  void attach(Timer timer) => _timer = timer;

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Chat data access through the Nimiro backend instead of a direct Supabase
/// connection.
///
/// WHY
/// ---
/// The old implementation opened PostgREST from the phone with the publishable
/// key that ships inside the APK. Because the tables had no Row Level Security,
/// anyone holding that key could read every message and every user row. Moving
/// the traffic behind the API lets Supabase keep a real secret (service_role,
/// server-side only) and lets us switch RLS on without breaking the chat.
///
/// SAFETY
/// ------
/// [ChatRepository] is left untouched and still works, so switching back is a
/// one-line change: set [useApi] to false.
class ChatApiRepository {
  ChatApiRepository._();
  static final ChatApiRepository instance = ChatApiRepository._();

  /// Flip to false to fall back to the direct-Supabase implementation.
  static bool useApi = true;

  Map<String, String> get _headers => {
        Params.apikey: apiKey,
        Params.authToken: SessionManager.instance.getAuthToken(),
      };

  String conversationDocId(int ownerUserId, int otherUserId) =>
      '${ownerUserId}_$otherUserId';

  /// POSTs to `<base>/api/chat/<path>` and returns the decoded envelope, or
  /// null when the call failed (the reason is logged, never thrown at the UI).
  Future<Map<String, dynamic>?> _post(
    String path, [
    Map<String, dynamic> body = const {},
  ]) async {
    final uri = Uri.parse('${apiURL}chat$path');
    final params = body.map((k, v) => MapEntry(k, '$v'));

    try {
      final response = await http
          .post(uri, headers: _headers, body: params)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) {
        Loggers.error('ChatApiRepository: unauthorized ($path)');
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['status'] != true) {
        Loggers.error('ChatApiRepository: ${decoded['message']} ($path)');
        return null;
      }

      return decoded;
    } catch (e) {
      Loggers.error('ChatApiRepository: $path failed — $e');
      return null;
    }
  }

  // ---- Conversations ----

  Future<Map<String, dynamic>?> getConversation(
      int ownerUserId, int otherUserId) async {
    final decoded = await _post('/fetchConversation', {
      'doc_id': conversationDocId(ownerUserId, otherUserId),
      'other_user_id': '$otherUserId',
    });

    final data = decoded?['data'];

    return data is Map<String, dynamic> ? data : null;
  }

  Future<void> upsertConversation({
    required int ownerUserId,
    required int otherUserId,
    required Map<String, dynamic> data,
  }) async {
    await _post('/upsertConversation', {
      'doc_id': conversationDocId(ownerUserId, otherUserId),
      'other_user_id': '$otherUserId',
      ...data,
    });
  }

  Future<List<Map<String, dynamic>>> listConversationsForUser(
      int userId) async {
    final decoded = await _post('/fetchMyConversations');
    final data = decoded?['data'];

    if (data is! List) return <Map<String, dynamic>>[];

    return data.whereType<Map<String, dynamic>>().toList();
  }

  // ---- Messages ----

  Future<void> createMessage({
    required String messageId,
    required Map<String, dynamic> data,
  }) async {
    await _post('/sendMessage', {
      'doc_id': messageId,
      ...data,
    });
  }

  Future<Map<String, dynamic>?> getMessage(String messageId) async {
    final decoded = await _post('/fetchMessage', {'doc_id': messageId});
    final data = decoded?['data'];

    return data is Map<String, dynamic> ? data : null;
  }

  Future<void> updateMessage(
      String messageId, Map<String, dynamic> data) async {
    await _post('/updateMessage', {
      'doc_id': messageId,
      'data': jsonEncode(data),
    });
  }

  Future<void> deleteMessage(String messageId) async {
    await _post('/deleteMessage', {'doc_id': messageId});
  }

  Future<MessageDocList> listMessages({
    required String conversationId,
    required int limit,
    String? cursorAfterDocumentId,
  }) async {
    final decoded = await _post('/fetchMessages', {
      'conversation_id': conversationId,
      'limit': '$limit',
      if (cursorAfterDocumentId != null)
        'cursor_after_document_id': cursorAfterDocumentId,
    });

    final data = decoded?['data'];
    if (data is! List) return MessageDocList([]);

    final rows = data
        .whereType<Map<String, dynamic>>()
        .map((row) => MessageDoc('${row['doc_id']}', row))
        .toList();

    return MessageDocList(rows);
  }

  // ---- App users (chat profile mirror) ----

  Future<Map<String, dynamic>?> fetchAppUser(int userId) async {
    final decoded = await _post('/fetchAppUsers', {'user_ids': '$userId'});
    final data = decoded?['data'];

    if (data is! List || data.isEmpty) return null;

    return data.first as Map<String, dynamic>;
  }

  Future<void> upsertAppUser(Map<String, dynamic> data) async {
    await _post('/upsertAppUser', data);
  }

  Future<void> deleteAppUser() async {
    await _post('/deleteAppUser');
  }

  // ---- Polling subscriptions --------------------------------------------
  //
  // Polling deliberately replaces the Postgres change feed: it needs no new
  // server component, it survives RLS, and it can be swapped for websockets
  // later without touching the callers below.

  ChatSubscription subscribeToConversation({
    required int ownerUserId,
    required int otherUserId,
    required void Function(Map<String, dynamic> data) onUpdate,
    required void Function() onDelete,
    Duration interval = const Duration(seconds: 5),
  }) {
    final docId = conversationDocId(ownerUserId, otherUserId);
    final sub = ChatSubscription('conversation_$docId');
    String? last;

    sub.attach(Timer.periodic(interval, (_) async {
      final row = await getConversation(ownerUserId, otherUserId);
      if (row == null) {
        if (last != null) onDelete();
        last = null;
        return;
      }
      final snapshot = jsonEncode(row);
      if (snapshot != last) {
        last = snapshot;
        onUpdate(row);
      }
    }));

    return sub;
  }

  ChatSubscription subscribeToMessages({
    required void Function(String event, Map<String, dynamic> payload) onEvent,
    required String conversationId,
    Duration interval = const Duration(seconds: 2),
  }) {
    final sub = ChatSubscription('messages_$conversationId');
    int? lastSeenId;

    sub.attach(Timer.periodic(interval, (_) async {
      final decoded = await _post('/fetchMessages', {
        'conversation_id': conversationId,
        'limit': '20',
      });

      final data = decoded?['data'];
      if (data is! List) return;

      final rows = data.whereType<Map<String, dynamic>>().toList();
      if (rows.isEmpty) return;

      final newestId = int.tryParse('${rows.first['id']}');

      // Emit everything newer than the last id we surfaced.
      // `lastSeenId` is a captured local, so Dart will not promote it to a
      // non-nullable int inside this closure; copy it out first.
      final seenId = lastSeenId;
      for (final row in rows.reversed) {
        final id = int.tryParse('${row['id']}');
        if (id != null && (seenId == null || id > seenId)) onEvent('create', row);
      }

      if (newestId != null) lastSeenId = newestId;
    }));

    return sub;
  }

  ChatSubscription subscribeToUserConversations({
    required int userId,
    required void Function(String event, Map<String, dynamic> data) onChange,
    Duration interval = const Duration(seconds: 5),
  }) {
    final sub = ChatSubscription('user_conversations_$userId');
    String? lastSnapshot;

    sub.attach(Timer.periodic(interval, (_) async {
      final rows = await listConversationsForUser(userId);
      final snapshot = jsonEncode(rows);
      if (lastSnapshot != null && snapshot != lastSnapshot) {
        onChange('update', {'rows': rows});
      }
      lastSnapshot = snapshot;
    }));

    return sub;
  }

  void unsubscribe(ChatSubscription? sub) => sub?.cancel();
}
