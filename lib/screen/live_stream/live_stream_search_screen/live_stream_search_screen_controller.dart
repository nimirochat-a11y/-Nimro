import 'dart:async';

import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/extensions/list_extension.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/api/live_room_service.dart';
import 'package:nimiro/common/controller/firebase_firestore_controller.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/model/livestream/app_user.dart';
import 'package:nimiro/model/livestream/livestream.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/live_stream/create_live_stream_screen/create_live_stream_screen.dart';
import 'package:nimiro/screen/live_stream/livestream_screen/audience/live_stream_audience_screen.dart';
import 'package:nimiro/screen/live_stream/livestream_screen/host/livestream_host_screen.dart';

/// Discovery feed for live rooms.
///
/// The room registry used to be a Firestore collection, which went dark when
/// the Firestore API was disabled. Rooms now come from the Laravel room
/// registry via [LiveRoomService].
///
/// Only room METADATA moved. The live audio and video are ZEGO
/// (zego_express_engine) and are completely untouched — joining, publishing and
/// playback still happen through the ZEGO screens exactly as before.
class LiveStreamSearchScreenController extends BaseController {
  /// Chat-profile mirror backing host cards in the discovery grid.
  ///
  /// Kept as `firebaseFirestoreController` because the grid widget and several
  /// sheets read it under that name; it now resolves through the Laravel chat
  /// proxy rather than Firebase.
  final firebaseFirestoreController = Get.find<FirebaseFirestoreController>();
  RxList<Livestream> livestreamList = <Livestream>[].obs;
  RxList<Livestream> livestreamFilterList = <Livestream>[].obs;

  /// Surfaced by the empty state when the room-registry read fails.
  RxString liveStreamError = ''.obs;

  /// Keeps the feed fresh. The registry read replaces the former live listener.
  Timer? livestreamRefresh;

  Setting? get setting => SessionManager.instance.getSettings();

  RxList<DummyLive> get dummyLives => (setting?.dummyLives ?? []).obs;

  @override
  void onReady() {
    super.onReady();
    // FIX(v13): the dummy-live showcase must be REGISTERED as real rooms, not
    // merely rendered. The dashboard switch (`live_dummy_show`) and the
    // `dummy_live_videos` rows used to build one registry room per dummy host;
    // when the registry moved to Laravel that step was dropped and replaced
    // with a no-op, so enabling "dummy live" in the dashboard lit up nothing.
    fetchLiveStreams();
    _syncDummyLiveRooms();
  }

  @override
  void onClose() {
    super.onClose();
    livestreamRefresh?.cancel();
  }

  Future<void> fetchLiveStreams() async {
    isLoading.value = true;
    await Future.delayed(const Duration(milliseconds: 500));

    await _refreshLiveStreams();
    isLoading.value = false;

    livestreamRefresh?.cancel();
    livestreamRefresh = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshLiveStreams(),
    );
  }

  /// One read of the registry, folded into the same list shape the screen
  /// already renders.
  Future<void> _refreshLiveStreams() async {
    try {
      final rows = await LiveRoomService.instance.fetchRooms();

      final livestreamMap = <String, Livestream>{};
      for (final row in rows) {
        final livestream = Livestream.fromJson(row);
        final roomId = livestream.roomID ?? '';
        if (roomId.isEmpty) continue;

        livestreamMap[roomId] = livestream;

        // The registry sends each room's host card inline, so it is cached
        // here instead of being fetched one document at a time.
        final hostId = livestream.hostId;
        if (hostId != null && hostId != -1) {
          LivestreamHosts.remember(hostId, row['host_user']);
        }
      }

      livestreamList.value = List.from(livestreamMap.values);
      livestreamFilterList.value = List.from(livestreamMap.values);
      livestreamFilterList
          .sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));

      liveStreamError.value = '';
      removeDummyLive();
      _assignHostUsersToStreams();
    } catch (e) {
      Loggers.error('Live stream refresh error: $e');
      liveStreamError.value =
          'Unable to load live streams. Please try again.';
    }
  }

  void _assignHostUsersToStreams() {
    for (var stream in livestreamList) {
      final hostId = stream.hostId;
      if (hostId == null) continue;
      final cached = LivestreamHosts.of(hostId);
      if (cached != null) {
        stream.hostUser = AppUser.fromJson(cached);
      }
    }
  }

  void onLiveUserTap(Livestream stream) async {
    User? myUser = SessionManager.instance.getUser();
    if (stream.hostId == myUser?.id) {
      Get.to(() => LivestreamHostScreen(isHost: true, livestream: stream));
    } else {
      Get.to(() => LiveStreamAudienceScreen(isHost: false, livestream: stream));
    }
  }

  onSearchChange(String value) {
    livestreamFilterList.value = livestreamList.search(value, (p0) {
      return p0.hostUser?.username ?? '';
    }, (p1) => p1.description ?? '');
  }

  /// Materialise the dummy-live showcase as ordinary registry rooms.
  ///
  /// FIX(v13): this replaces the two no-ops that were left behind when the room
  /// registry moved off Firestore. The dashboard toggle and `dummy_live_videos`
  /// still arrive inside the settings payload as [dummyLives]; each active row
  /// whose host has no room yet is registered through [LiveRoomService], and a
  /// row that was switched off has its room closed again. This is exactly what
  /// the Firestore version did, expressed against the Laravel registry.
  Future<void> _syncDummyLiveRooms() async {
    final rows = dummyLives;
    if (rows.isEmpty) return;

    try {
      final existing = await LiveRoomService.instance.fetchRooms();
      final liveRoomIds = existing
          .map((row) => row['room_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      for (final dummy in rows) {
        final dummyId = dummy.userId;
        if (dummyId == null || dummyId == -1) continue;

        final roomId = '$dummyId';
        final alreadyLive = liveRoomIds.contains(roomId);

        if (!alreadyLive && dummy.status == 1) {
          await LiveRoomService.instance.createRoom(
            roomId: roomId,
            title: dummy.title,
            roomType: LivestreamType.dummy.value,
            thumbnail: dummy.link,
          );
          Loggers.success('Registered dummy live room $roomId in the registry.');
        } else if (alreadyLive && dummy.status == 0) {
          await LiveRoomService.instance.endRoom(roomId);
          Loggers.success('Closed dummy live room $roomId in the registry.');
        }
      }
    } catch (e) {
      Loggers.error('Dummy live sync failed: $e');
    }
  }

  /// Retained for source compatibility with the old Firestore flow.
  Future<void> addDummyUsers() async => _syncDummyLiveRooms();

  /// Close a room and drop its participants.
  ///
  /// Replaces the former Firestore teardown. The live media itself is ZEGO and
  /// is ended by its own SDK on the host screen — this only retires the room row
  /// in the registry.
  Future<void> deleteStreamOnFirebase(int? dummyUserId) async {
    if (dummyUserId == null) return;
    try {
      await LiveRoomService.instance.leaveRoom('$dummyUserId');
      Loggers.success('Closed live room $dummyUserId in the registry.');
    } catch (e) {
      Loggers.error('Failed to close live room: $e');
    }
  }

  /// Hide dummy showcase rooms the settings no longer want shown.
  ///
  /// Purely local: those rooms are not real registry entries, so they are
  /// filtered out of the visible list rather than deleted anywhere.
  void removeDummyLive() {
    final dummyStream =
        livestreamFilterList.where((e) => e.isDummyLive == 1).toList();
    if (dummyStream.isEmpty) return;

    bool shouldHide(DummyLiveHolder element) {
      if (setting?.liveDummyShow == 0) return true;
      return dummyLives.isEmpty ||
          !dummyLives.any((e) => e.userId == element.hostId);
    }

    final visible = livestreamFilterList.where((element) {
      if (element.isDummyLive != 1) return true;
      return !shouldHide(element);
    }).toList();
    livestreamFilterList.value = visible;
  }

  Future<void> onGoLive() async {
    User? myUser = SessionManager.instance.getUser();
    bool isExist = livestreamList.any((element) => element.hostId == myUser?.id);
    if (myUser?.isDummy == 1 && isExist) {
      return showSnackBar(LKey.yourProfileIsAlreadyInUseForDummyEtc.tr);
    }

    if (myUser?.isDummy == 0 && isExist) {
      showLoader();
      await deleteStreamOnFirebase(myUser?.id);
      stopLoader();
    }

    Get.to(() => const CreateLiveStreamScreen());
  }
}

/// Minimal shape used by [LiveStreamSearchScreenController.removeDummyLive] so
/// that helper does not need to depend on the concrete model.
typedef DummyLiveHolder = Livestream;
