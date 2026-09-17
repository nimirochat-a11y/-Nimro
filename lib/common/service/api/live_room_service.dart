import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/utilities/const_res.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/utils/params.dart';

/// Live-room registry access.
///
/// Replaces the Firestore "livestreams" collection that went dark when the
/// Firestore API was disabled. It carries room metadata, participant state and
/// comments ONLY — the actual live audio/video is ZEGO and is completely
/// untouched.
class LiveRoomService {
  LiveRoomService._();
  static final LiveRoomService instance = LiveRoomService._();

  String get _base => '${apiURL}live/';

  Map<String, String> get _headers => {
        Params.apikey: apiKey,
        Params.authToken: SessionManager.instance.getAuthToken(),
      };

  Future<dynamic> _call(String endpoint, Map<String, dynamic> body) async {
    final response = await http
        .post(Uri.parse('$_base$endpoint'), headers: _headers, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw Exception('Unauthorized Access');
    }
    if (response.statusCode == 404) {
      throw Exception('Room not found');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Live room request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected live room response');
    }
    return decoded['data'];
  }

  static Map<String, dynamic> _asMap(dynamic value) =>
      Map<String, dynamic>.from(value as Map);

  static List<Map<String, dynamic>> _asRows(dynamic value) {
    final rows = <Map<String, dynamic>>[];
    for (final row in (value as List? ?? [])) {
      rows.add(_asMap(row));
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> fetchRooms() async =>
      _asRows(await _call('fetchRooms', const {}));

  Future<Map<String, dynamic>?> createRoom({
    required String roomId,
    String? title,
    String? description,
    String? roomType,
    String? thumbnail,
    bool restrictToJoin = false,
  }) async {
    try {
      final data = await _call('createRoom', {
        'room_id': roomId,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (roomType != null) 'room_type': roomType,
        if (thumbnail != null) 'thumbnail': thumbnail,
        'restrict_to_join': restrictToJoin,
      });
      return data == null ? null : _asMap(data);
    } catch (e) {
      Loggers.error('createRoom($roomId) failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> joinRoom(String roomId) async {
    try {
      final data = await _call('joinRoom', {'room_id': roomId});
      return data == null ? null : _asMap(data);
    } catch (e) {
      Loggers.error('joinRoom($roomId) failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> leaveRoom(String roomId) async {
    try {
      final data = await _call('leaveRoom', {'room_id': roomId});
      return data == null ? null : _asMap(data);
    } catch (e) {
      Loggers.error('leaveRoom($roomId) failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> endRoom(String roomId) async {
    try {
      final data = await _call('endRoom', {'room_id': roomId});
      return data == null ? null : _asMap(data);
    } catch (e) {
      Loggers.error('endRoom($roomId) failed: $e');
      return null;
    }
  }

  /// Room-level metadata update.
  ///
  /// [watchingDelta] is applied server-side as an increment, mirroring the
  /// former `FieldValue.increment` semantics. [removeCoHostId] detaches a
  /// co-host, mirroring `FieldValue.arrayRemove`.
  Future<Map<String, dynamic>?> updateRoom(
    String roomId, {
    int? likeCount,
    int? likeDelta,
    String? battleType,
    int? battleDuration,
    int? battleCreatedAt,
    String? livestreamType,
    int? watchingDelta,
    int? addCoHostId,
    int? removeCoHostId,
    String? title,
  }) async {
    try {
      final data = await _call('updateRoom', {
        'room_id': roomId,
        if (likeCount != null) 'like_count': likeCount,
        if (likeDelta != null) 'like_delta': likeDelta,
        if (battleType != null) 'battle_type': battleType,
        if (battleDuration != null) 'battle_duration': battleDuration,
        if (battleCreatedAt != null) 'battle_created_at': battleCreatedAt,
        if (livestreamType != null) 'type': livestreamType,
        if (watchingDelta != null) 'watching_delta': watchingDelta,
        if (addCoHostId != null) 'add_co_host_id': addCoHostId,
        if (removeCoHostId != null) 'remove_co_host_id': removeCoHostId,
        if (title != null) 'title': title,
      });
      return data == null ? null : _asMap(data);
    } catch (e) {
      Loggers.error('updateRoom($roomId) failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchRoom(String roomId) async {
    try {
      final data = await _call('fetchRoom', {'room_id': roomId});
      return data == null ? null : _asMap(data);
    } catch (e) {
      Loggers.error('fetchRoom($roomId) failed: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchParticipants(String roomId) async {
    try {
      return _asRows(await _call('fetchParticipants', {'room_id': roomId}));
    } catch (e) {
      Loggers.error('fetchParticipants($roomId) failed: $e');
      return const [];
    }
  }

  /// Participant state write.
  ///
  /// [payload] carries the engagement fields the client model round-trips
  /// (type, audio/video status, coin and battle counters, join time, follows).
  Future<bool> updateParticipantState(
    String roomId, {
    int? userState,
    int? isMuted,
    String? role,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await _call('updateParticipantState', {
        'room_id': roomId,
        if (userState != null) 'user_state': userState,
        if (isMuted != null) 'is_muted': isMuted,
        if (role != null) 'role': role,
        if (payload != null && payload.isNotEmpty) 'payload': payload,
      });
      return true;
    } catch (e) {
      Loggers.error('updateParticipantState($roomId) failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchComments(String roomId,
      {int since = 0}) async {
    try {
      return _asRows(await _call('fetchComments', {
        'room_id': roomId,
        if (since > 0) 'since': since,
      }));
    } catch (e) {
      Loggers.error('fetchComments($roomId) failed: $e');
      return const [];
    }
  }

  Future<Map<String, dynamic>?> sendComment(
    String roomId, {
    String? comment,
    String commentType = 'TEXT',
    int? receiverId,
    int? giftId,
  }) async {
    try {
      final data = await _call('sendComment', {
        'room_id': roomId,
        'comment': comment ?? '',
        'comment_type': commentType,
        if (receiverId != null) 'receiver_id': receiverId,
        if (giftId != null) 'gift_id': giftId,
      });
      return data == null ? null : _asMap(data);
    } catch (e) {
      Loggers.error('sendComment($roomId) failed: $e');
      return null;
    }
  }

  Future<bool> deleteComment(String roomId, int commentId) async {
    try {
      await _call('deleteComment', {
        'room_id': roomId,
        'comment_id': commentId,
      });
      return true;
    } catch (e) {
      Loggers.error('deleteComment($commentId) failed: $e');
      return false;
    }
  }
}

/// Cache for the host cards returned inline with the room list.
///
/// The registry returns each room's `host_user` inline, so host data no longer
/// needs a second lookup. Keeping it here lets the existing host-resolution
/// logic work without touching Firestore.
class LivestreamHosts {
  LivestreamHosts._();

  static final Map<int, Map<String, dynamic>> _hosts = {};

  static void remember(int hostId, dynamic hostUser) {
    if (hostUser is Map) {
      _hosts[hostId] = Map<String, dynamic>.from(hostUser);
    }
  }

  static Map<String, dynamic>? of(int hostId) => _hosts[hostId];

  static void clear() => _hosts.clear();
}
