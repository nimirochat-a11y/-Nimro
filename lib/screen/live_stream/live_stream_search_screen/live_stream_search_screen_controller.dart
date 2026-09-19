import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/controller/firebase_firestore_controller.dart';
import 'package:nimiro/common/extensions/list_extension.dart';
import 'package:nimiro/common/extensions/user_extension.dart';
import 'package:nimiro/common/service/api/live_room_service.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/model/livestream/app_user.dart';
import 'package:nimiro/model/livestream/livestream.dart';
import 'package:nimiro/model/livestream/livestream_user_state.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/live_stream/create_live_stream_screen/create_live_stream_screen.dart';
import 'package:nimiro/screen/live_stream/livestream_screen/audience/live_stream_audience_screen.dart';
import 'package:nimiro/screen/live_stream/livestream_screen/host/livestream_host_screen.dart';
import 'package:nimiro/utilities/firebase_const.dart';

class LiveStreamSearchScreenController extends BaseController {
  FirebaseFirestore db = FirebaseFirestore.instance;
  RxList<Livestream> livestreamList = <Livestream>[].obs;
  RxList<Livestream> livestreamFilterList = <Livestream>[].obs;
  RxString liveStreamError = ''.obs;
  StreamSubscription<QuerySnapshot<Livestream>>? livestreamListListener;

  final firebaseFirestoreController = Get.find<FirebaseFirestoreController>();

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
    livestreamListListener?.cancel();
  }

  Future<void> fetchLiveStreams() async {
    await livestreamListListener?.cancel();
    isLoading.value = true;
    liveStreamError.value = '';
    await Future.delayed(const Duration(milliseconds: 500));

    // Using a map for faster access and modification
    final Map<String, Livestream> livestreamMap = {};

    livestreamListListener = db
        .collection(FirebaseConst.liveStreams)
        .withConverter(
          fromFirestore: (snapshot, options) => Livestream.fromJson(snapshot.data()!),
          toFirestore: (Livestream livestream, options) => livestream.toJson(),
        )
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final Livestream? livestream = change.doc.data();
        String roomId = livestream?.roomID ?? '';
        if (livestream == null || roomId.isEmpty) continue;

        // Add, modify, or remove based on document change type
        switch (change.type) {
          case DocumentChangeType.added:
            livestreamMap[roomId] = livestream;
            if (livestream.hostId != null && livestream.hostId != -1) {
              firebaseFirestoreController.fetchUserIfNeeded(livestream.hostId ?? -1);
            }
            break;

          case DocumentChangeType.modified:
            // Update only if the livestream has changed
            livestreamMap[roomId] = livestream;
            for (var coHostId in (livestream.coHostIds ?? [])) {
              firebaseFirestoreController.fetchUserIfNeeded(coHostId);
            }
            break;

          case DocumentChangeType.removed:
            livestreamMap.remove(roomId);
            break;
        }
      }

      // Convert map back to lists
      livestreamList.value = List.from(livestreamMap.values);
      livestreamFilterList.value = List.from(livestreamMap.values);
      livestreamFilterList.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
      // Perform any additional cleanup or transformations
      removeDummyLive();

      _assignHostUsersToStreams();
      isLoading.value = false; // Hide loader after initial fetch
    }, onError: (Object error) {
      Loggers.error('Error loading livestreams: $error');
      liveStreamError.value = 'Unable to load live streams. Please try again.';
      isLoading.value = false;
    });
  }

  Map<int, AppUser> _userMapFromList(List<AppUser> users) {
    return {
      for (var u in users)
        if (u.userId != null) u.userId!: u
    };
  }

  void _assignHostUsersToStreams() {
    final userMap = _userMapFromList(firebaseFirestoreController.users);
    for (var stream in livestreamList) {
      stream.hostUser = userMap[stream.hostId];
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

  Future<void> deleteStreamOnFirebase(int? dummyUserId) async {
    if (dummyUserId == null) return;

    final String roomId = dummyUserId.toString();

    final DocumentReference livestreamRef = db.collection(FirebaseConst.liveStreams).doc(roomId);

    final CollectionReference usersStateRef = livestreamRef.collection(FirebaseConst.userState);

    final CollectionReference commentsRef = livestreamRef.collection(FirebaseConst.comments);

    try {
      // Fetch both collections in parallel
      final results = await Future.wait([
        usersStateRef.get(),
        commentsRef.get(),
      ]);

      final QuerySnapshot usersSnapshot = results[0];
      final QuerySnapshot commentsSnapshot = results[1];

      final WriteBatch batch = db.batch();

      // Queue deletions for user states
      for (final doc in usersSnapshot.docs) {
        batch.delete(doc.reference);
      }
      Loggers.info('Queued ${usersSnapshot.size} user state deletions.');

      // Queue deletions for comments
      for (final doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      Loggers.info('Queued ${commentsSnapshot.size} comment deletions.');

      // Delete the livestream document
      batch.delete(livestreamRef);

      // Commit all deletions in one batch
      await batch.commit();
      Loggers.success('Deleted live stream, user states, and comments from Firestore.');
      Loggers.error('Live Stream Search Delete The Data');
    } catch (e, stackTrace) {
      Loggers.error('Failed to delete live stream: $e');
      Loggers.error('StackTrace: $stackTrace');
    }
  }

  void removeDummyLive() {
    final dummyStream = livestreamFilterList.where((e) => e.isDummyLive == 1).toList();
    if (dummyStream.isEmpty) return;
    if (setting?.liveDummyShow == 0) {
      for (var element in dummyStream) {
        deleteStreamOnFirebase(element.hostId);
      }
    } else {
      for (var element in dummyStream) {
        final shouldDelete = dummyLives.isEmpty || !dummyLives.any((e) => e.userId == element.hostId);
        if (shouldDelete) {
          deleteStreamOnFirebase(element.hostId);
        }
      }
    }
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
