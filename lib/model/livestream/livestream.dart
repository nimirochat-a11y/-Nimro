import 'package:get/get.dart';
import 'package:nimiro/common/controller/firebase_firestore_controller.dart';
import 'package:nimiro/model/livestream/app_user.dart';
import 'package:nimiro/utilities/app_res.dart';

class Livestream {
  int? watchingCount;
  String? description;
  LivestreamType? type;
  BattleType? battleType;
  int battleDuration = AppRes.battleDurationInMinutes;
  int? isRestrictToJoin;
  int? hostViewID;
  String? roomID;
  int? likeCount;
  int? hostId;
  List<int>? coHostIds;
  AppUser? hostUser;
  List<AppUser>? coHostUsers;
  int? createdAt;
  int? battleCreatedAt;
  int? isDummyLive;
  String? dummyUserLink;

  Livestream(
      {this.watchingCount,
      this.description,
      this.type,
      this.battleType,
      this.isRestrictToJoin,
      this.hostViewID,
      this.roomID,
      this.likeCount,
      this.hostId,
      this.coHostIds,
      this.createdAt,
      this.battleCreatedAt,
      this.isDummyLive,
      this.dummyUserLink,
      this.battleDuration = AppRes.battleDurationInMinutes});

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static List<int>? _toIntList(dynamic value) {
    if (value is! List) return const <int>[];
    return value.map(_toInt).whereType<int>().toList();
  }

  Livestream.fromJson(Map<String, dynamic> json) {
    // FIX(v13): every key below was read under a name the Laravel room registry
    // does not send. `type`, `battle_type` and `co-host_ids` threw outright, so
    // a single registry row aborted the whole refresh and the live list stayed
    // empty. Host and timestamps were also dropped. Both spellings are accepted
    // so previously cached payloads keep parsing.
    type = LivestreamType.fromString(
        (json['type'] ?? json['room_type'] ?? json['livestream_type'])
            ?.toString());
    battleType = BattleType.fromString(json['battle_type']?.toString());
    watchingCount = _toInt(json['watching_count']);
    description = json['description'] ?? json['title'];
    isRestrictToJoin =
        _toInt(json['is_restrict_to_join'] ?? json['restrict_to_join']);
    hostViewID = _toInt(json['host_view_id']);
    roomID = json['room_id']?.toString();
    likeCount = _toInt(json['like_count']);
    hostId = _toInt(json['host_id']);
    coHostIds = _toIntList(json['co-host_ids'] ?? json['co_host_ids']);
    createdAt = _toInt(json['created_at']);
    battleCreatedAt = _toInt(json['battle_created_at']);
    isDummyLive = _toInt(json['is_dummy_live']) ??
        (type == LivestreamType.dummy ? 1 : 0);
    dummyUserLink = json['dummy_user_link'] ?? json['link'];
    battleDuration =
        _toInt(json['battle_duration']) ?? AppRes.battleDurationInMinutes;

    final host = json['host_user'];
    if (host is Map) {
      hostUser = AppUser.fromJson(Map<String, dynamic>.from(host));
    }
    final coHosts = json['co_host_users'];
    if (coHosts is List) {
      coHostUsers = coHosts
          .whereType<Map>()
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['watching_count'] = watchingCount;
    data['description'] = description;
    data['type'] = type?.value;
    data['battle_type'] = battleType?.value;
    data['is_restrict_to_join'] = isRestrictToJoin;
    data['host_view_id'] = hostViewID;
    data['room_id'] = roomID;
    data['like_count'] = likeCount;
    data['host_id'] = hostId;
    data['co-host_ids'] = coHostIds;
    data['created_at'] = createdAt;
    data['battle_created_at'] = battleCreatedAt;
    data['is_dummy_live'] = isDummyLive;
    data['dummy_user_link'] = dummyUserLink;
    data['battle_duration'] = battleDuration;
    return data;
  }

  List<AppUser> getAllUsers(List<AppUser> users) {
    AppUser? hostUser =
        users.firstWhereOrNull((element) => element.userId == hostId);
    final coHostUsers = coHostIds
            ?.map((id) => users.firstWhereOrNull((user) => user.userId == id))
            .whereType<AppUser>()
            .toList() ??
        [];

    final allUsers = [if (hostUser != null) hostUser, ...coHostUsers];
    return allUsers;
  }

  AppUser? getHostUser(List<AppUser> users) {
    final controller = Get.find<FirebaseFirestoreController>();
    AppUser? hostUser = controller.users
        .firstWhereOrNull((element) => element.userId == hostId);
    return hostUser;
  }

  List<AppUser> getCoHostUsers(List<AppUser> users) {
    final coHostUsers = coHostIds
            ?.map((id) => users.firstWhereOrNull((user) => user.userId == id))
            .whereType<AppUser>()
            .toList() ??
        [];
    return coHostUsers;
  }
}

enum LivestreamType {
  livestream('LIVESTREAM'),
  battle('BATTLE'),
  dummy('DUMMY');

  final String value;

  const LivestreamType(this.value);

  static LivestreamType fromString(String? value) {
    return LivestreamType.values.firstWhereOrNull((e) => e.value == value) ??
        LivestreamType.livestream;
  }
}

enum BattleType {
  initiate('INITIATE'),
  waiting('WAITING'),
  running('RUNNING'),
  end('END');

  final String value;

  const BattleType(this.value);

  static BattleType fromString(String? value) {
    return BattleType.values.firstWhereOrNull((e) => e.value == value) ??
        BattleType.initiate;
  }
}
