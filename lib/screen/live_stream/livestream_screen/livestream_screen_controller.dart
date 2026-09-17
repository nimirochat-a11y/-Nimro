import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nimiro/common/controller/ads_controller.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/controller/firebase_firestore_controller.dart';
import 'package:nimiro/common/service/api/live_room_service.dart';
import 'package:nimiro/common/extensions/user_extension.dart';
import 'package:nimiro/common/manager/firebase_notification_manager.dart';
import 'package:nimiro/common/manager/haptic_manager.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/api/notification_service.dart';
import 'package:nimiro/common/widget/confirmation_dialog.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/model/livestream/app_user.dart';
import 'package:nimiro/model/livestream/livestream.dart';
import 'package:nimiro/model/livestream/livestream_comment.dart';
import 'package:nimiro/model/livestream/livestream_user_state.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/gift_sheet/send_gift_sheet.dart';
import 'package:nimiro/screen/gift_sheet/send_gift_sheet_controller.dart';
import 'package:nimiro/screen/live_stream/live_stream_end_screen/live_stream_end_screen.dart';
import 'package:nimiro/screen/live_stream/live_stream_end_screen/widget/livestream_summary.dart';
import 'package:nimiro/screen/live_stream/livestream_screen/audience/widget/live_stream_join_sheet.dart';
import 'package:nimiro/screen/live_stream/livestream_screen/host/widget/live_stream_host_top_view.dart';
import 'package:nimiro/screen/report_sheet/report_sheet.dart';
import 'package:nimiro/utilities/app_res.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class LivestreamScreenController extends BaseController {
  ZegoExpressEngine zegoEngine = ZegoExpressEngine.instance;
  final liveRoom = LiveRoomService.instance;

  final firestoreController = Get.find<FirebaseFirestoreController>();
  final adsController = Get.find<AdsController>();

  Timer? timer;
  Timer? minViewerTimeoutTimer;
  Function? onLikeTap;

  Setting? get setting => SessionManager.instance.getSettings();

  int get minViewersThreshold => setting?.liveMinViewers ?? 0;

  int get timeoutMinutes => setting?.liveTimeout ?? 0;

  int get myUserId => SessionManager.instance.getUserID();

  RxBool isPlayerMute = false.obs;
  RxBool isMinViewerTimeout = false.obs;
  RxBool isTextEmpty = true.obs;
  bool isJoinSheetOpen = false;
  bool isFrontCamera = true;
  bool isHost;

  /// Registry refresh handles. Replace the three Firestore listeners.
  Timer? roomStatePoll;
  Timer? roomUsersPoll;
  Timer? roomCommentsPoll;

  /// Fingerprints of the last state seen, so a poll only reports changes.
  Map<String, String> _knownStates = {};
  Map<String, String> _knownComments = {};

  TextEditingController textCommentController = TextEditingController();

  String get _roomId => liveData.value.roomID ?? '';

  Future<List<Map<String, dynamic>>> _readStates() =>
      liveRoom.fetchParticipants(_roomId);

  Future<List<Map<String, dynamic>>> _readComments() =>
      liveRoom.fetchComments(_roomId);

  static VideoAudioStatus _statusFrom(dynamic value) =>
      VideoAudioStatus.fromString(value?.toString() ?? '');

  Future<void> _writeUserState(int userId, Map<String, dynamic> data,
      {int? userState, String? role, int? isMuted}) async {
    if (_roomId.isEmpty) return;
    final payload = Map<String, dynamic>.from(data);
    payload.remove('userId');
    payload.remove('user_id');
    await liveRoom.updateParticipantState(_roomId,
        userState: userState, role: role, isMuted: isMuted, payload: payload);
  }

  Widget? hostPreview;

  LivestreamScreenController(this.liveData, this.isHost, {this.hostPreview});

  int totalBattleSecond = 0;

  RxInt remainingBattleSeconds = 0.obs;
  RxBool isViewVisible = true.obs;

  List<LivestreamUserState> memberList = <LivestreamUserState>[];

  List<Gift> get gifts => setting?.gifts ?? [];
  RxList<LivestreamUserState> requestList = <LivestreamUserState>[].obs;
  RxList<LivestreamUserState> audienceList = <LivestreamUserState>[].obs;
  RxList<LivestreamUserState> invitedList = <LivestreamUserState>[].obs;
  RxList<LivestreamUserState> coHostList = <LivestreamUserState>[].obs;
  RxList<LivestreamUserState> audienceMemberList = <LivestreamUserState>[].obs;
  RxList<StreamView> streamViews = <StreamView>[].obs;
  RxList<LivestreamComment> comments = <LivestreamComment>[].obs;
  RxList<LivestreamUserState> liveUsersStates = <LivestreamUserState>[].obs;

  Rx<AppUser?> selectedGiftUser = Rx(null);
  Rx<VideoPlayerController?> videoPlayerController = Rx(null);

  Rx<User?> get myUser => SessionManager.instance.getUser().obs;
  Rx<Livestream> liveData;

  AudioPlayer countdownPlayer = AudioPlayer();
  AudioPlayer battleStartPlayer = AudioPlayer();
  AudioPlayer winAudioPlayer = AudioPlayer();

  List<User> usersList = [];

  @override
  void onInit() {
    super.onInit();

    if (liveData.value.isDummyLive == 1) {
      initVideoPlayer();
    } else {
      totalBattleSecond =
          Duration(minutes: liveData.value.battleDuration).inSeconds;
      remainingBattleSeconds.value = totalBattleSecond;
      zegoEngine.setAudioDeviceMode(ZegoAudioDeviceMode.General);
      loginRoom();
      startListenEvent();
      initAudioPlayer();
    }

    // Common listeners for all users
    listenLiveStreamData();
    listenUserState();
    fetchLiveStreamComments();
    WakelockPlus.enable();
    FirebaseNotificationManager.instance
        .unsubscribeToTopic(topic: myUserId.toString());
  }

  @override
  void onClose() {
    super.onClose();

    WakelockPlus.disable();
    timer?.cancel();
    minViewerTimeoutTimer?.cancel();
    videoPlayerController.value?.dispose();
    roomStatePoll?.cancel();
    roomUsersPoll?.cancel();
    roomCommentsPoll?.cancel();
    countdownPlayer.dispose();
    winAudioPlayer.dispose();
    stopListenEvent();
    logoutRoom();
  }

  Future<void> initVideoPlayer() async {
    final url = liveData.value.dummyUserLink ?? '';
    if (url.isEmpty) return;

    // Dispose old controller if exists to avoid memory leak
    await videoPlayerController.value?.dispose();

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    isPlayerMute.value = false;

    try {
      await controller.initialize();
      controller
        ..setLooping(true)
        ..play();

      videoPlayerController.value = controller;
      videoPlayerController.value?.setLooping(true);
    } on PlatformException catch (e) {
      showSnackBar(e.message);
      Loggers.error(e);
    }
  }

  void initAudioPlayer() {
    countdownPlayer.setAsset(AssetRes.endCountdown);
    battleStartPlayer.setAsset(AssetRes.battleStart);
    winAudioPlayer.setAsset(AssetRes.winSound);
  }

  Future<void> logoutRoom() async {
    if (isHost) {
      deleteStreamOnFirebase();
    }
    stopPreview();
    stopPublish();
    zegoEngine.logoutRoom(liveData.value.roomID ?? '');
  }

  Future<ZegoRoomLoginResult> loginRoom() async {
    final roomID = liveData.value.roomID ?? '';
    final user = ZegoUser('$myUserId', myUser.value?.fullname ?? '');

    final roomConfig = ZegoRoomConfig.defaultConfig()
      ..isUserStatusNotify = true;

    try {
      final result =
          await zegoEngine.loginRoom(roomID, user, config: roomConfig);

      if (result.errorCode != 0) {
        if (result.errorCode == 1001005) {
          showSnackBar(
              'Please check AppSign is correct or not on ZEGO manage console');
        } else {
          showSnackBar('loginRoom failed: ${result.errorCode}');
        }
        Loggers.error('Login Error : ${result.errorCode}');
        return result;
      }

      if (isHost) {
        startHostPublish();
        return result;
      }

      // For Audience — the join is recorded in the room registry.
      final joinResult = await liveRoom.joinRoom(roomID);
      if (joinResult == null) {
        Loggers.error('Could not register the join for room $roomID');
      }

      final states = await _readStates();
      final mine = states.firstWhereOrNull(
          (row) => (row['user_id'] as num?)?.toInt() == myUserId);

      if (mine == null) {
        User? myUser = this.myUser.value;
        if (myUser != null) {
          final initialState = myUser.streamState(time: 0);
          await _writeUserState(myUserId, initialState.toJson());
          _sendCommentToFirestore(type: LivestreamCommentType.joined);
        } else {
          Loggers.error('User not found');
        }
      } else {
        updateUserStateToFirestore(myUserId,
            type: LivestreamUserType.audience,
            audioStatus: _statusFrom(mine['audioStatus']),
            videoStatus: _statusFrom(mine['videoStatus']));
      }
      return result;
    } catch (e) {
      Loggers.error('Error in loginRoom: $e');
      showSnackBar('Something went wrong while joining the room.');
      rethrow;
    }
  }

  void startListenEvent() async {
    // Callback for updates on the status of other users in the room.
    // Users can only receive callbacks when the isUserStatusNotify property of ZegoRoomConfig is set to `true` when logging in to the room (loginRoom).
    ZegoExpressEngine.onRoomUserUpdate =
        (roomID, updateType, List<ZegoUser> userList) {
      // Check if multiple users are in the room
      if (userList.length > 1) {
        // Force audio to speaker
        ZegoExpressEngine.instance.setAudioRouteToSpeaker(true);
      }
      if (isHost) {
        switch (updateType) {
          case ZegoUpdateType.Add:
            for (var _ in userList) {
              updateLiveStreamData(watchingCount: 1);
            }
            break;
          case ZegoUpdateType.Delete:
            Livestream stream = liveData.value;
            for (var element in userList) {
              if ((stream.watchingCount ?? 0) > 0) {
                updateLiveStreamData(
                  watchingCount: -1,
                  removeCoHostId: int.tryParse(element.userID),
                );
              }
              int coHostId = int.parse(element.userID);
              bool isCoHostExist =
                  stream.coHostIds?.contains(coHostId) ?? false;
              if (isCoHostExist) {
                updateUserStateToFirestore(coHostId,
                    type: LivestreamUserType.audience,
                    audioStatus: VideoAudioStatus.on,
                    videoStatus: VideoAudioStatus.on);
                updateLiveStreamData(removeCoHostId: coHostId);
              }
            }
        }
      }
      Loggers.info(
          'onRoomUserUpdate: roomID: $roomID, updateType: ${updateType.name}, userList: ${userList.map((e) => e.userID)}');
    };
    // Callback for updates on the status of the streams in the room.
    ZegoExpressEngine.onRoomStreamUpdate =
        (roomID, updateType, List<ZegoStream> streamList, extendedData) async {
      String priorityId = liveData.value.hostId.toString();

      streamList.sort((a, b) {
        if (a.streamID == priorityId) return -1; // a goes first
        if (b.streamID == priorityId) return 1; // b goes first
        return a.streamID.compareTo(b.streamID); // regular sorting
      });
      Loggers.info(
          'onRoomStreamUpdate: roomID: $roomID, updateType: $updateType, streamList: ${streamList.map((e) => e.streamID)}, extendedData: $extendedData');
      switch (updateType) {
        case ZegoUpdateType.Add:
          for (final stream in streamList) {
            startPlayStream(stream.streamID);
          }
          break;
        case ZegoUpdateType.Delete:
          for (final stream in streamList) {
            if (liveData.value.roomID == stream.streamID) {
              if (Get.isBottomSheetOpen == false) {
                Get.back();
              }
              for (var element in liveUsersStates) {
                if (element.type == LivestreamUserType.coHost) {
                  streamEnded();
                }
              }
              // Empty LiveData
              logoutRoom();
              stopListenEvent();
              liveData.value = Livestream();
            }
            streamViews
                .removeWhere((element) => element.streamId == stream.streamID);
            stopPlayStream(stream.streamID);
          }
          break;
      }
    };
    // Callback for updates on the current user's room connection status.
    ZegoExpressEngine.onRoomStateUpdate =
        (roomID, state, errorCode, extendedData) {
      Loggers.info(
          'onRoomStateUpdate: roomID: $roomID, state: ${state.name}, errorCode: $errorCode, extendedData: $extendedData');
    };

    // Callback for updates on the current user's stream publishing changes.
    ZegoExpressEngine.onPublisherStateUpdate =
        (streamID, state, errorCode, extendedData) {
      switch (state) {
        case ZegoPublisherState.NoPublish:
          streamViews.removeWhere((element) => element.streamId == streamID);
        case ZegoPublisherState.PublishRequesting:
        case ZegoPublisherState.Publishing:
      }
      debugPrint(
          'onPublisherStateUpdate: streamID: $streamID, state: ${state.name}, errorCode: $errorCode, extendedData: $extendedData');
    };
  }

  void stopListenEvent() {
    ZegoExpressEngine.onRoomUserUpdate = null;
    ZegoExpressEngine.onRoomStreamUpdate = null;
    ZegoExpressEngine.onRoomStateUpdate = null;
    ZegoExpressEngine.onPublisherStateUpdate = null;
  }

  Future<void> startHostPublish() async {
    if ((liveData.value.roomID ?? '').isEmpty) {
      return Loggers.error('No ID FOUND');
    }
    String streamID = liveData.value.roomID ?? '';
    if (hostPreview == null) {
      deleteStreamOnFirebase();
      Get.back();
      return;
    }
    streamViews.add(StreamView(
        streamID, liveData.value.hostViewID ?? -1, hostPreview!, false));
    await zegoEngine.enableCamera(true);
    await zegoEngine.mutePublishStreamAudio(false); // Ensure audio is not muted
    startMinViewerTimeoutCheck(); //  Check time to Min. Viewers Required to continue live
    pushNotificationToFollowers(liveData.value);
    return zegoEngine.startPublishingStream(streamID);
  }

  Future<void> stopPublish() async {
    return zegoEngine.stopPublishingStream();
  }

  Future<void> startPlayStream(String streamID) async {
    Loggers.info('Starting to play stream: $streamID');
    int streamViewId = -1;
    try {
      await zegoEngine.createCanvasView((viewID) {
        Loggers.info('Created remote view with ID: $viewID');
        streamViewId = viewID;
        ZegoCanvas canvas =
            ZegoCanvas(viewID, viewMode: ZegoViewMode.AspectFill);
        ZegoPlayerConfig config = ZegoPlayerConfig.defaultConfig();
        config.resourceMode = ZegoStreamResourceMode.OnlyL3; // interactive live streaming

        Loggers.info(
            'StartPlayStream playback: StreamID: $streamID, ViewMode: ${canvas.viewMode}, ResourceMode: ${config.resourceMode}');

        zegoEngine.startPlayingStream(streamID, canvas: canvas, config: config);
      }).then((canvasViewWidget) {
        if (canvasViewWidget != null) {
          streamViews
              .add(StreamView(streamID, streamViewId, canvasViewWidget, false));
        }
        Loggers.success('Stream playback started successfully for: $streamID');
      });
    } catch (e, stackTrace) {
      Loggers.error('Failed to start playing stream: $e');
      Loggers.error('StackTrace: $stackTrace');
    }
  }

  Future<void> stopPlayStream(String streamID) async {
    Loggers.info('Stopping playback for stream: $streamID');

    try {
      zegoEngine.stopPlayingStream(streamID);
      Loggers.success('Stopped playing stream: $streamID');

      StreamView? stream = streamViews
          .firstWhereOrNull((element) => element.streamId == streamID);

      if (stream?.streamViewId != null) {
        Loggers.info('Destroying remote view with ID: ${stream?.streamViewId}');
        await zegoEngine.destroyCanvasView(stream!.streamViewId);
        Loggers.success('Remote view destroyed successfully.');
      }
    } catch (e, stackTrace) {
      Loggers.error('Failed to stop playing stream: $e');
      Loggers.error('StackTrace: $stackTrace');
    }
  }

  Future<void> stopPreview({int? viewId}) async {
    int id = viewId ?? -1;
    zegoEngine.stopPreview();
    if (id != -1) {
      await zegoEngine.destroyCanvasView(id);
    }
  }

  Future<void> updateLiveStreamData({
    BattleType? battleType,
    LivestreamType? type,
    int? battleCreatedAt,
    int? battleDuration,
    int watchingCount = 0,
    int? addCoHostId,
    int? removeCoHostId,
  }) async {
    if (_roomId.isEmpty) return;

    await liveRoom.updateRoom(
      _roomId,
      battleType: battleType?.value,
      livestreamType: type?.value,
      battleCreatedAt: battleCreatedAt,
      battleDuration: battleDuration,
      watchingDelta: watchingCount == 0 ? null : watchingCount,
      addCoHostId: addCoHostId,
      removeCoHostId: removeCoHostId,
    );
  }

  Future<void> handleRequestResponse({
    required AppUser? user,
    required bool isRefused,
    LivestreamComment? comment,
  }) async {
    final userId = user?.userId;
    if (userId == null) return;

    // Update user state based on refusal
    updateUserStateToFirestore(userId,
        type: isRefused
            ? LivestreamUserType.audience
            : LivestreamUserType.coHost);

    // Determine the comment to delete
    final commentToDelete = comment ??
        comments.firstWhereOrNull((element) =>
            element.senderId == userId &&
            element.commentType == LivestreamCommentType.request);

    if (commentToDelete != null && commentToDelete.id != null) {
      await liveRoom.deleteComment(_roomId, commentToDelete.id!.toInt());
    }
  }

  /// Retires the room in the registry.
  ///
  /// Replaces the former Firestore teardown. The live media itself is ZEGO and
  /// is stopped by its own SDK; this only closes the metadata row so the room
  /// disappears from discovery and can no longer be joined.
  Future<void> deleteStreamOnFirebase() async {
    final String roomId = _roomId;

    if (roomId.isEmpty) {
      Loggers.error('Room ID is null. Cannot stop live stream.');
      return;
    }

    Loggers.info('Stopping live stream Room : $roomId');

    try {
      await liveRoom.endRoom(roomId);
      roomStatePoll?.cancel();
      roomCommentsPoll?.cancel();
      Loggers.success('Live room $roomId retired in the registry.');
    } catch (e, stackTrace) {
      Loggers.error('Failed to stop live stream: $e');
      Loggers.error('StackTrace: $stackTrace');
    }
  }

  /// Keeps the room row in step with the registry.
  ///
  /// Replaces the former Firestore document listener with a short poll. The
  /// battle-timer and like-animation reactions are unchanged.
  void listenLiveStreamData() {
    int likeCount = liveData.value.likeCount ?? 0;
    roomStatePoll?.cancel();

    roomStatePoll = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_roomId.isEmpty) return;
      try {
        final row = await liveRoom.fetchRoom(_roomId);
        if (row == null) {
          Loggers.warning('Livestream room not found: $_roomId');
          return;
        }

        final stream = Livestream.fromJson(row);

        if (stream.battleType == BattleType.initiate) {
          timer?.cancel();
          remainingBattleSeconds.value =
              Duration(minutes: stream.battleDuration).inSeconds;
          countdownPlayer.pause();
        }

        if (stream.battleType == BattleType.waiting) {
          totalBattleSecond =
              Duration(minutes: stream.battleDuration).inSeconds;
        }

        liveData.value = stream;

        final newLikeCount = stream.likeCount ?? 0;
        if (likeCount != newLikeCount) {
          onLikeTap?.call();
          likeCount = newLikeCount;
        }
      } catch (error) {
        Loggers.error('Error refreshing livestream row: $error');
      }
    });
  }

  /// Keeps the participant list in step with the registry.
  ///
  /// Replaces the former Firestore collection listener with a short poll.
  void listenUserState() {
    roomUsersPoll?.cancel();
    roomUsersPoll = Timer.periodic(const Duration(seconds: 4), (_) {
      _refreshUserStates();
    });
    _refreshUserStates();
  }

  Future<void> _refreshUserStates() async {
    if (_roomId.isEmpty) return;
    try {
      final rows = await _readStates();
      final current = <String, String>{};
      final parsed = <LivestreamUserState>[];

      for (final row in rows) {
        final state = LivestreamUserState.fromJson(row);
        final uid = state.userId;
        if (uid == null) continue;
        current['$uid'] = jsonEncode(row);
        parsed.add(state);
      }

      for (final entry in current.entries) {
        final previous = _knownStates[entry.key];
        if (previous == entry.value) continue;

        final state = parsed.firstWhere((s) => '${s.userId}' == entry.key);

        if (previous == null) {
          _showJoinStreamSheet(state);
          liveUsersStates.add(state);
        } else {
          final oldState = liveUsersStates
              .firstWhereOrNull((u) => '${u.userId}' == entry.key);
          updateStateAction(oldState, state);
          final index = liveUsersStates
              .indexWhere((u) => '${u.userId}' == entry.key);
          if (index != -1) {
            liveUsersStates[index] = state;
          } else {
            liveUsersStates.add(state);
          }
        }
      }

      final gone = _knownStates.keys.toSet().difference(current.keys.toSet());
      for (final key in gone) {
        liveUsersStates.removeWhere((u) => '${u.userId}' == key);
      }

      _knownStates = current;
      _recomputeUserLists();
    } catch (e) {
      Loggers.error('Live user state refresh error: $e');
    }
  }

  void _recomputeUserLists() {
    requestList.value = liveUsersStates
        .where((element) => element.type == LivestreamUserType.requested)
        .toList();
    audienceList.value = liveUsersStates
        .where((element) =>
            element.type != LivestreamUserType.host &&
            element.type != LivestreamUserType.left)
        .toList();
    invitedList.value = liveUsersStates
        .where((element) => element.type == LivestreamUserType.invited)
        .toList();
    coHostList.value = liveUsersStates
        .where((element) => element.type == LivestreamUserType.coHost)
        .toList();
    audienceMemberList.value = liveUsersStates
        .where((element) =>
            element.type != LivestreamUserType.left &&
            element.userId != myUserId)
        .toList();
  }

  /// Keeps the comment list in step with the registry.
  ///
  /// Replaces the former Firestore collection listener with a short poll. The
  /// request/gift filtering and gift attachment are unchanged.
  void fetchLiveStreamComments() {
    Loggers.info('Fetching live stream comments...');
    roomCommentsPoll?.cancel();
    roomCommentsPoll = Timer.periodic(const Duration(seconds: 4), (_) {
      _refreshComments();
    });
    _refreshComments();
  }

  Future<void> _refreshComments() async {
    if (_roomId.isEmpty) return;
    try {
      final rows = await _readComments();
      final current = <String, String>{};
      final parsed = <LivestreamComment>[];

      for (final row in rows) {
        final comment = LivestreamComment.fromJson(row);
        final key = '${comment.id}';
        current[key] = jsonEncode(row);
        parsed.add(comment);
      }

      for (final entry in current.entries) {
        final previous = _knownComments[entry.key];
        if (previous == entry.value) continue;

        final comment = parsed.firstWhere((c) => '${c.id}' == entry.key);

        if (previous == null) {
          firestoreController.fetchUserIfNeeded(comment.senderId ?? -1);
          if (comment.commentType == LivestreamCommentType.request && !isHost) {
            continue;
          }
          comments.add(comment);
        } else {
          if (comment.commentType == LivestreamCommentType.request && !isHost) {
            continue;
          }
          final index = comments.indexWhere((c) => '${c.id}' == entry.key);
          if (index != -1) {
            comments[index] = comment;
          }
        }
      }

      final gone = _knownComments.keys.toSet().difference(current.keys.toSet());
      for (final key in gone) {
        comments.removeWhere((c) => '${c.id}' == key);
      }

      _knownComments = current;

      for (var comment in comments) {
        comment.gift =
            gifts.firstWhereOrNull((gift) => gift.id == comment.giftId);
      }

      comments.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    } catch (e) {
      Loggers.error('Live comment refresh error: $e');
    }
  }

  void _appendComment(Map<String, dynamic> row) {
    final comment = LivestreamComment.fromJson(row);
    comments.add(comment);
    _knownComments['${comment.id}'] = jsonEncode(row);
    comment.gift = gifts.firstWhereOrNull((gift) => gift.id == comment.giftId);
  }

  void toggleCamera() {
    isFrontCamera = !isFrontCamera;
    zegoEngine.useFrontCamera(isFrontCamera, channel: ZegoPublishChannel.Main);
  }

  void toggleFlipCamera() {
    isFrontCamera = !isFrontCamera;
    zegoEngine.useFrontCamera(isFrontCamera, channel: ZegoPublishChannel.Main);
  }

  void toggleMic(LivestreamUserState? state) async {
    if (state?.audioStatus == VideoAudioStatus.offByHost) {
      return showSnackBar(LKey.theHostHasTurnedOffYourAudio);
    }

    bool isAudioOn = state?.audioStatus == VideoAudioStatus.on;

    if (isAudioOn) {
      updateUserStateToFirestore(myUserId,
          audioStatus: VideoAudioStatus.offByMe);
      zegoEngine.muteMicrophone(true);
    } else {
      updateUserStateToFirestore(myUserId, audioStatus: VideoAudioStatus.on);
      zegoEngine.muteMicrophone(false);
    }
  }

  // RxBool isVideoOn = true.obs;
  void toggleVideo(LivestreamUserState? state) async {
    if (state?.videoStatus == VideoAudioStatus.offByHost) {
      return showSnackBar(LKey.theHostHasTurnedOffYourVideo.tr);
    }
    bool isVideoOn = state?.videoStatus == VideoAudioStatus.on;
    Loggers.error(isVideoOn);
    if (isVideoOn) {
      updateUserStateToFirestore(myUserId,
          videoStatus: VideoAudioStatus.offByMe);
      await zegoEngine.enableCamera(false);
      print('HELLO WOW');
    } else {
      updateUserStateToFirestore(myUserId, videoStatus: VideoAudioStatus.on);
      await zegoEngine.enableCamera(true);
      print('HELLO NOTHING');
    }
  }

  void toggleStreamAudio(int? streamId) {
    StreamView? view = streamViews
        .firstWhereOrNull((element) => int.parse(element.streamId) == streamId);

    zegoEngine.mutePlayStreamAudio(
        '$streamId', (view?.isMuted ?? false) ? false : true);
    view?.isMuted = view.isMuted ? false : true;
    if (view != null) {
      streamViews[streamViews.indexWhere(
          (element) => int.parse(element.streamId) == streamId)] = view;
      streamViews.refresh();
    }
  }

  void onLikeButtonTap() async {
    if (_roomId.isEmpty) return;
    HapticManager.shared.light();
    await liveRoom.updateRoom(_roomId, likeDelta: 1);
  }

  void onTextCommentSend() {
    String comment = textCommentController.text.trim();
    textCommentController.clear();
    isTextEmpty.value = true;
    if (comment.isEmpty) return;
    _sendCommentToFirestore(type: LivestreamCommentType.text, comment: comment);
  }

  void onGiftTap(GiftType type,
      {BattleView battleViewType = BattleView.red,
      List<AppUser> users = const []}) {
    users.removeWhere((element) => element.userId == myUserId);
    if (liveData.value.type == LivestreamType.battle &&
        liveData.value.battleType == BattleType.end) {
      return showSnackBar(LKey.battleEndedGiftNotSent.tr);
    }
    GiftManager.openGiftSheet(
        onCompletion: (giftManager) {
          Gift gift = giftManager.gift;
          AppUser? user = giftManager.streamUser;

          int coinPrice = gift.coinPrice?.toInt() ?? 0;

          _sendCommentToFirestore(
              type: LivestreamCommentType.gift,
              giftId: gift.id,
              receiverId: user?.userId);
          updateUserStateToFirestore(
            user?.userId,
            battleCoin: type == GiftType.battle ? coinPrice : null,
            currentBattleCoin: type == GiftType.battle ? coinPrice : null,
            liveCoin: type == GiftType.livestream ? coinPrice : null,
          );
        },
        giftType: type,
        battleViewType: battleViewType,
        streamUsers: users);
  }

  _sendCommentToFirestore(
      {required LivestreamCommentType type,
      String? comment,
      int? giftId,
      int? receiverId}) async {
    try {
      await _addUsersFirebaseFireStore();
      final row = await liveRoom.sendComment(
        _roomId,
        comment: comment,
        commentType: type.value,
        receiverId: receiverId,
        giftId: giftId,
      );
      if (row != null) {
        _appendComment(row);
      }
    } catch (e) {
      Loggers.error('Message Error : $e');
    }
  }

  /// Mirrors the sender's own chat profile through the proxy.
  ///
  /// The proxy derives the row from the authenticated token, so no id is sent.
  Future<void> _addUsersFirebaseFireStore() async {
    final user = myUser.value;
    if (user == null) return;
    await firestoreController.updateUser(user);
  }

  void onVideoRequestSend(Livestream liveData) {
    LivestreamUserState? state = liveUsersStates
        .firstWhereOrNull((element) => element.userId == myUserId);
    switch (state?.type) {
      case null:
        break;
      case LivestreamUserType.audience:
        updateUserStateToFirestore(myUserId,
            type: LivestreamUserType.requested);
        _sendCommentToFirestore(
            type: LivestreamCommentType.request, receiverId: liveData.hostId);
        showSnackBar(LKey.requestJoinToHost.tr);
        break;
      case LivestreamUserType.requested:
        showSnackBar(LKey.joinRequestSentDescription.tr);
        break;
      case LivestreamUserType.host:
      case LivestreamUserType.coHost:
      case LivestreamUserType.invited:
      case LivestreamUserType.left:
        break;
    }
  }

  Future<void> updateUserStateToFirestore(
    int? userId, {
    LivestreamUserType? type,
    VideoAudioStatus? audioStatus,
    VideoAudioStatus? videoStatus,
    int? battleCoin,
    int? liveCoin,
    bool? isFollow,
    int? joinTime,
    int? currentBattleCoin,
  }) async {
    if (userId == null) {
      Loggers.error('updateUserStateToFirestore: userId is null');
      return;
    }

    if (_roomId.isEmpty) return;

    try {
      // Coin counters arrive as deltas, mirroring the previous
      // FieldValue.increment semantics; everything else is absolute. Enum
      // values are their wire strings, exactly as the model round-trips them.
      final payload = <String, dynamic>{
        if (type != null) 'type': type.value,
        if (audioStatus != null) 'audio_status': audioStatus.value,
        if (videoStatus != null) 'video_status': videoStatus.value,
        if (battleCoin != null) 'battle_coin_delta': battleCoin,
        if (currentBattleCoin != null) 'current_battle_coin': currentBattleCoin,
        if (liveCoin != null) 'live_coin_delta': liveCoin,
        if (isFollow != null) 'followers_gained': isFollow ? 1 : 0,
        if (joinTime != null) 'join_stream_time': joinTime,
      };
      if (battleCoin != null || liveCoin != null) {
        myUser.value?.coinEstimatedValue(
            battleCoin?.toDouble() ?? liveCoin?.toDouble());
        SessionManager.instance.setUser(myUser.value);
      }
      await liveRoom.updateParticipantState(_roomId,
          userState: type == LivestreamUserType.left ? 0 : null,
          role: type == LivestreamUserType.coHost
              ? 'coHost'
              : (type == LivestreamUserType.host ? 'host' : null),
          payload: payload);
      Loggers.success('User state updated for userId: $userId');
    } catch (e, stack) {
      Loggers.error('Failed to update user state: $e\n$stack');
    }
  }

  void onInvite(AppUser? user, {bool isInvited = false}) {
    updateUserStateToFirestore(user?.userId,
        type: isInvited
            ? LivestreamUserType.audience
            : LivestreamUserType.invited);
  }

  void _showJoinStreamSheet(LivestreamUserState state) {
    if (state.userId == myUserId && state.type == LivestreamUserType.invited) {
      AppUser? hostUser = liveData.value.getHostUser(firestoreController.users);
      isJoinSheetOpen = true;
      Get.bottomSheet(
              LiveStreamJoinSheet(
                  hostUser: hostUser,
                  myUser: myUser.value,
                  onJoined: () async {
                    LivestreamUserState? userState =
                        liveUsersStates.firstWhereOrNull(
                            (element) => element.userId == myUserId);
                    if (userState?.type == LivestreamUserType.invited) {
                      updateUserStateToFirestore(myUserId,
                          type: LivestreamUserType.coHost);
                    } else {
                      showSnackBar(LKey.joinCancelledDescription.tr);
                    }
                  },
                  onCancel: () {
                    updateUserStateToFirestore(myUserId,
                        type: LivestreamUserType.audience);
                  }),
              isScrollControlled: true,
              enableDrag: false,
              isDismissible: false)
          .then(
        (value) {
          isJoinSheetOpen = false;
        },
      );
    }
  }

  void publishCoHostStream(int streamId) async {
    bool isPermissionGranted = await requestPermission();
    if (isPermissionGranted) {
      int canvasViewID = -1;

      // ✅ Enable camera and microphone
      await zegoEngine.enableCamera(true);
      await zegoEngine.mutePublishStreamAudio(false);
      zegoEngine.muteMicrophone(false);

      // ✅ Create preview canvas and start preview
      await zegoEngine.createCanvasView((viewID) async {
        canvasViewID = viewID;
        ZegoCanvas previewCanvas =
            ZegoCanvas(canvasViewID, viewMode: ZegoViewMode.AspectFill);
        zegoEngine.startPreview(canvas: previewCanvas);
      }).then((canvasViewWidget) {
        if (canvasViewWidget != null) {
          streamViews.add(
            StreamView('$streamId', canvasViewID, canvasViewWidget, false),
          );
        }
      });

      // ✅ Publish the stream
      await zegoEngine.startPublishingStream('$streamId');

      // ✅ Force audio output to speaker (after stream starts)
      Future.delayed(const Duration(milliseconds: 300), () {
        zegoEngine.setAudioRouteToSpeaker(true);
      });

      updateLiveStreamData(addCoHostId: streamId);
      _sendCommentToFirestore(type: LivestreamCommentType.joinedCoHost);
      updateUserStateToFirestore(myUserId,
          joinTime: DateTime.now().millisecondsSinceEpoch);
    } else {
      Get.bottomSheet(ConfirmationSheet(
        title: LKey.cameraMicrophonePermissionTitle.tr,
        description: LKey.cameraMicrophonePermissionDescription.tr,
        onTap: openAppSettings,
      ));
    }
  }

  Future<void> closeCoHostStream(int? streamId) async {
    StreamView? view = streamViews
        .firstWhereOrNull((element) => element.streamId == '$streamId');
    if (view != null) {
      stopPreview(viewId: view.streamViewId);
      stopPublish();
      updateLiveStreamData(removeCoHostId: streamId);
      LivestreamComment? comment = comments.firstWhereOrNull((element) =>
          element.senderId == myUserId &&
          element.commentType == LivestreamCommentType.joinedCoHost);
      if (comment != null && comment.id != null) {
        await liveRoom.deleteComment(_roomId, comment.id!.toInt());
      }
      updateUserStateToFirestore(streamId,
          type: LivestreamUserType.audience,
          audioStatus: VideoAudioStatus.offByMe,
          videoStatus: VideoAudioStatus.offByMe,
          battleCoin: 0,
          currentBattleCoin: 0);
      streamViews.removeWhere((element) => element.streamId == '$streamId');
      stopPlayStream(streamId.toString());
      streamEnded();
    }
  }

  Future<bool> requestPermission() async {
    Loggers.info("requestPermission...");
    try {
      PermissionStatus microphoneStatus = await Permission.microphone.request();
      if (microphoneStatus != PermissionStatus.granted) {
        Loggers.error('Error: Microphone permission not granted!!!');
        return false;
      }
    } on Exception catch (error) {
      Loggers.error("[ERROR], request microphone permission exception, $error");
    }

    try {
      PermissionStatus cameraStatus = await Permission.camera.request();
      if (cameraStatus != PermissionStatus.granted) {
        Loggers.error('Error: Camera permission not granted!!!');
        return false;
      }
    } on Exception catch (error) {
      Loggers.error("[ERROR], request camera permission exception, $error");
    }

    return true;
  }

  void coHostVideoToggle(LivestreamUserState state) {
    if (state.videoStatus == VideoAudioStatus.offByMe) {
      return showSnackBar(LKey.theCoHostHasTurnedOffTheirVideo);
    }

    updateUserStateToFirestore(state.userId,
        videoStatus: state.videoStatus == VideoAudioStatus.on
            ? VideoAudioStatus.offByHost
            : VideoAudioStatus.on);
  }

  void coHostAudioToggle(LivestreamUserState state) {
    if (state.audioStatus == VideoAudioStatus.offByMe) {
      return showSnackBar(LKey.theCoHostHasTurnedOffTheirAudio);
    }

    updateUserStateToFirestore(state.userId,
        audioStatus: state.audioStatus == VideoAudioStatus.on
            ? VideoAudioStatus.offByHost
            : VideoAudioStatus.on);
  }

  void updateStateAction(
      LivestreamUserState? oldState, LivestreamUserState newState) {
    if (newState.userId == myUserId) {
      Loggers.info('Updating state for userId: ${newState.toJson()}');
      if (newState.type == LivestreamUserType.coHost &&
          oldState?.type != LivestreamUserType.coHost) {
        publishCoHostStream(myUserId);
      }

      if (newState.type == LivestreamUserType.audience &&
          oldState?.type == LivestreamUserType.invited &&
          isJoinSheetOpen) {
        Get.back();
      }

      if (newState.type == LivestreamUserType.invited &&
          oldState?.type == LivestreamUserType.audience) {
        _showJoinStreamSheet(newState);
      }
      if (oldState?.type == LivestreamUserType.coHost &&
          newState.type == LivestreamUserType.audience) {
        closeCoHostStream(newState.userId);
      }
    }
  }

  void coHostDelete(LivestreamUserState state) {
    if (state.type == LivestreamUserType.coHost) {
      updateLiveStreamData(removeCoHostId: state.userId);
      updateUserStateToFirestore(state.userId,
          type: LivestreamUserType.audience);
    }
  }

  void reportUser(int? userId) {
    Get.bottomSheet(ReportSheet(reportType: ReportType.user, id: userId),
        isScrollControlled: true);
  }

  void _timerStart(VoidCallback callBack) {
    timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (t) {
        callBack.call();
        // if (t.tick >= totalBattleSecond) {
        //   timer?.cancel();
        // }
      },
    );
  }

  void onStopButtonTap() {
    bool isBattleOn = liveData.value.type == LivestreamType.battle;
    String title =
        !isBattleOn ? LKey.endStreamTitle.tr : LKey.stopBattleTitle.tr;
    String description =
        !isBattleOn ? LKey.endStreamMessage.tr : LKey.stopBattleDescription.tr;

    Get.bottomSheet(
        StopLiveStreamSheet(
            onTap: () {
              if (isBattleOn) {
                updateLiveStreamData(
                    battleType: BattleType.initiate,
                    type: LivestreamType.livestream);
                startMinViewerTimeoutCheck();
              } else {
                hostEndStream();
              }
            },
            title: title,
            description: description,
            positiveText: LKey.stop.tr),
        isScrollControlled: true);
  }

  void hostEndStream() {
    streamEnded();
    logoutRoom();
  }

  void streamEnded() {
    LivestreamUserState? userState = liveUsersStates
        .firstWhereOrNull((element) => element.userId == myUserId);
    AppUser? user = firestoreController.users
        .firstWhereOrNull((element) => element.userId == myUserId);
    userState?.user = user;
    int viewers = liveUsersStates.length;
    if (isHost) {
      Get.back();
      Get.off(() => LiveStreamEndScreen(
          userState: userState, isHost: isHost, viewers: viewers));
    } else {
      if (userState?.type == LivestreamUserType.coHost) {
        Get.bottomSheet(
                LiveStreamSummary(
                    userState: userState, isHost: isHost, viewers: viewers),
                isScrollControlled: true)
            .then((value) {
          updateUserStateToFirestore(myUserId,
              battleCoin: 0,
              liveCoin: 0,
              currentBattleCoin: 0,
              type: LivestreamUserType.audience);
          if ((liveData.value.roomID ?? '').isEmpty) {
            Get.back();
          }
        });
      }
    }
  }

  togglePlayerAudioToggle() {
    videoPlayerController.value?.setVolume(isPlayerMute.value ? 1 : 0);
    isPlayerMute.value = !isPlayerMute.value;
  }

  void toggleView() {
    isViewVisible.value = !isViewVisible.value;
  }

  void startBattle() {
    updateLiveStreamData(
      battleType: BattleType.waiting,
      battleDuration: AppRes.battleDurationInMinutes,
      battleCreatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void battleRunning() {
    Livestream stream = liveData.value;
    // Battle Start Timer Logic

    final startTime =
        DateTime.fromMillisecondsSinceEpoch(stream.battleCreatedAt ?? 0);
    final endTime = startTime
        .add(Duration(seconds: totalBattleSecond + AppRes.battleStartInSecond));

    Loggers.success('Battle Timer Started');

    _timerStart(() {
      final remaining = endTime.difference(DateTime.now()).inSeconds;
      remainingBattleSeconds.value = remaining.clamp(0, totalBattleSecond);

      if (remainingBattleSeconds.value <= 10) {
        if (!countdownPlayer.playing) {
          countdownPlayer
              .seek(Duration(seconds: 10 - remainingBattleSeconds.value));
          countdownPlayer.play();
        }
      }

      Loggers.info(
          '[BATTLE RUNNING] Battle end in ${remainingBattleSeconds.value} sec.');

      if (remainingBattleSeconds.value <= 0) {
        winAudioPlayer.seek(const Duration(seconds: 0));
        winAudioPlayer.play();
        timer?.cancel();
        updateLiveStreamData(battleType: BattleType.end);
      }
    });
  }

  void startMinViewerTimeoutCheck() {
    if (minViewerTimeoutTimer?.isActive ?? false) return;
    Loggers.info(
        'Check Min. Viewers Required to continue live $timeoutMinutes Minutes');
    minViewerTimeoutTimer =
        Timer.periodic(Duration(minutes: timeoutMinutes), (_) {
      minViewerTimeoutTimer?.cancel();
      if ((liveData.value.watchingCount ?? 0) <= minViewersThreshold) {
        isMinViewerTimeout.value = true;
        Loggers.info('Close Stream Because of Min. Viewers');
      }
    });
  }

  void onCloseAudienceBtn() {
    HapticManager.shared.light();
    Get.bottomSheet(ConfirmationSheet(
        title: LKey.exitLiveStreamTitle.tr,
        description: LKey.exitLiveStreamDescription.tr,
        onTap: () async {
          adsController.showInterstitialAdIfAvailable();
          if (liveData.value.coHostIds?.contains(myUserId) ?? false) {
            closeCoHostStream(myUserId);
          }
          logoutRoom();
        }));
  }

  void pushNotificationToFollowers(Livestream liveData) {
    AppUser? hostUser = liveData.getHostUser([]);
    NotificationService.instance.pushNotification(
        type: NotificationType.liveStream,
        title: LKey.liveStreamNotificationTitle
            .trParams({'name': hostUser?.fullname ?? ''}),
        body: LKey.liveStreamNotificationBody.tr,
        deviceType: 1,
        topic: '${liveData.hostId}_ios',
        data: liveData.toJson());
    NotificationService.instance.pushNotification(
        type: NotificationType.liveStream,
        title: LKey.liveStreamNotificationTitle
            .trParams({'name': hostUser?.fullname ?? ''}),
        body: LKey.liveStreamNotificationBody.tr,
        deviceType: 0,
        topic: '${liveData.hostId}_android',
        data: liveData.toJson());
  }
}

class StreamView {
  String streamId;
  int streamViewId;
  Widget streamView;
  bool isMuted;

  StreamView(this.streamId, this.streamViewId, this.streamView, this.isMuted);
}
