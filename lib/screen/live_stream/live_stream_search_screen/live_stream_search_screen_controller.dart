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
    fetchLiveStreams();
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

  Map<int, AppUser> _userMapFromList(List<AppUser> list) {
    return {
      for (var user in list)
        if (user.userId != null) user.userId!: user,
    };
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

  /// Retained for source compatibility.
  ///
  /// The dummy-live showcase already ships to the client inside the settings
  /// payload and is rendered locally, so there is no registry left to reconcile
  /// against and nothing to write.
  Future<void> addDummyUsers() async {
    await Future.delayed(const Duration(milliseconds: 500));
    Loggers.info('Dummy lives are served from settings; nothing to sync.');
  }

  Future<void> createLiveStream(DummyLive? dummyLive) async {
    Loggers.info('Dummy lives are served from settings; no room to register.');
  }

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
