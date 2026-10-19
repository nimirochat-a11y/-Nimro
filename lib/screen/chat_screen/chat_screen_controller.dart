import 'dart:async';
import 'dart:convert';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nimiro/common/enum/chat_enum.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/functions/media_picker_helper.dart';
import 'package:nimiro/common/controller/firebase_firestore_controller.dart';
import 'package:nimiro/common/manager/firebase_notification_manager.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/api/common_service.dart';
import 'package:nimiro/common/service/api/notification_service.dart';
import 'package:nimiro/common/service/api/post_service.dart';
import 'package:nimiro/common/service/api/user_service.dart';
import 'package:nimiro/common/service/supabase/chat_api_repository.dart';
import 'package:nimiro/common/service/upload/upload_queue_service.dart';
import 'package:nimiro/common/service/utils/params.dart';
import 'package:nimiro/common/service/utils/web_service.dart';
import 'package:nimiro/utilities/const_res.dart';
import 'package:nimiro/common/widget/confirmation_dialog.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/chat/chat_thread.dart';
import 'package:nimiro/model/chat/message_data.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/model/general/status_model.dart';
import 'package:nimiro/model/user_model/app_user.dart';
import 'package:nimiro/model/post_story/post_model.dart';
import 'package:nimiro/model/post_story/story/story_model.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/blocked_user_screen/block_user_controller.dart';
import 'package:nimiro/screen/chat_screen/message_type_widget/chat_audio_message.dart';
import 'package:nimiro/screen/chat_screen/widget/select_media_sheet.dart';
import 'package:nimiro/screen/chat_screen/widget/send_media_sheet.dart';
import 'package:nimiro/screen/gif_sheet/gif_sheet.dart';
import 'package:nimiro/screen/gift_sheet/send_gift_sheet_controller.dart';
import 'package:nimiro/screen/post_screen/post_screen_controller.dart';
import 'package:nimiro/screen/post_screen/single_post_screen.dart';
import 'package:nimiro/screen/reels_screen/reel/reel_page_controller.dart';
import 'package:nimiro/screen/reels_screen/reels_screen.dart';
import 'package:nimiro/screen/report_sheet/report_sheet.dart';
import 'package:nimiro/screen/story_view_screen/story_view_screen.dart';
import 'package:nimiro/utilities/app_res.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/style_res.dart';

class ChatScreenController extends BlockUserController
    with GetTickerProviderStateMixin {
  List<UserRequestAction> requestType = UserRequestAction.values;
  User? myUser = SessionManager.instance.getUser();
  final Setting? setting = SessionManager.instance.getSettings();
  User? otherUser;
  RxBool isTextEmpty = true.obs;
  RxBool hasMore = true.obs;
  RxBool isExpanded = false.obs;
  bool isPostAPiCalling = false;
  TextEditingController textController = TextEditingController();
  TextEditingController mediaTextController = TextEditingController();
  Rx<ChatThread> conversationUser;
  ChatThread? myConversationUser;
  late int otherUserId;
  late AnimationController audioAnimationController;
  Animation<double>? audioWidthAnimation;
  final ChatApiRepository _repo = ChatApiRepository.instance;
  MessageType chatType = MessageType.text;
  RxList<MessageData> chatList = <MessageData>[].obs;
  List<ChatSubscription> chatListeners = [];
  List<ChatSubscription> usersStreams = [];
  StreamSubscription<PlayerState>? playerControllerListen;
  String? lastMessageDocumentId;
  RecorderController recorderController = RecorderController();
  PlayerController playerController = PlayerController();
  Rx<PlayerValue> playerValue =
      PlayerValue(state: PlayerState.stopped, id: 0).obs;
  ChatScreenController(this.conversationUser);
  static String chatId = '';
  static String _normConv(String id) {
    final parts = id.split('_');
    if (parts.length != 2) return id;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return id;
    return a <= b ? '${a}_$b' : '${b}_$a';
  }
  @override
  void onInit() {
    super.onInit();
    chatId = conversationUser.value.conversationId ?? 'No CONVERSATION';
    otherUserId = conversationUser.value.chatUser?.userId ?? -1;
  }
  @override
  void onReady() {
    super.onReady();
    _init();
    _getChat();
    _addUsersFirebaseFireStore();
    _markAsRead();
    Timer.periodic(const Duration(seconds: 4), (t) {
      if (chatId.isEmpty) {
        t.cancel();
        return;
      }
      _markAsRead();
    });
  }
  @override
  void onClose() {
    super.onClose();
    chatId = '';
    for (var listener in chatListeners) {
      _repo.unsubscribe(listener);
    }
    for (var listener in usersStreams) {
      _repo.unsubscribe(listener);
    }
    playerControllerListen?.cancel();
    recorderController.dispose();
    playerController.dispose();
    textController.dispose();
    mediaTextController.dispose();
    _markAsRead();
  }
  _init() {
    _initAudioAnimationController();
    _initializePlayerStateListener();
    _fetchOtherUser();
  }
  _initAudioAnimationController() {
    audioAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    final double maxWidth = Get.width - 30;
    audioWidthAnimation = Tween<double>(
      begin: 0,
      end: maxWidth,
    ).animate(CurvedAnimation(
        parent: audioAnimationController, curve: Curves.easeInOut));
  }
  _initializePlayerStateListener() {
    playerControllerListen =
        playerController.onPlayerStateChanged.listen((event) {
      playerValue.update((val) => val?.state = event);
      Loggers.success('Player State: $event');
    });
  }
  _fetchOtherUser() async {
    int userId = conversationUser.value.userId ?? -1;
    if (userId != -1) {
      otherUser = await UserService.instance.fetchUserDetails(userId: userId);
      Loggers.info('Other User Device Token: ${otherUser?.deviceToken}');
    }
  }
  void _listenToChatThreadUser() {
    if (myUser?.id == null) return;
    final otherSub = _repo.subscribeToConversation(
      ownerUserId: myUser!.id!,
      otherUserId: otherUserId,
      onUpdate: (data) {
        conversationUser.value = ChatThread.fromJson(data);
        Loggers.info('Chat Updated: ${conversationUser.value.toJson()}');
      },
      onDelete: () {
        conversationUser.update((val) => val?.chatType = ChatType.approved);
      },
    );
    final mySub = _repo.subscribeToConversation(
      ownerUserId: otherUserId,
      otherUserId: myUser!.id!,
      onUpdate: (data) {
        myConversationUser = ChatThread.fromJson(data);
        Loggers.success('Other Chat Updated: ${myConversationUser?.toJson()}');
      },
      onDelete: () {},
    );
    usersStreams.addAll([otherSub, mySub]);
  }
  void onSendTextMessage() async {
    String text = textController.text.trim();
    textController.clear();
    isTextEmpty.value = true;
    if (conversationUser.value.iAmBlocked ?? false) {
      return showSnackBar(
          'You cannot message ${conversationUser.value.chatUser?.username} because you are blocked by them.');
    }
    sendMessageToFireStore(type: MessageType.text, textMessage: text);
  }
  Future<void> sendMessageToFireStore(
      {required MessageType type,
      String? textMessage,
      String? imageMessage,
      String? videoMessage,
      String? audioMessage,
      String? postMessage,
      String? storyReplyMessage,
      List<double>? waveData}) async {
    int time = DateTime.now().millisecondsSinceEpoch;
    List<int> noDeleteIds = [
      myUser?.id ?? -1,
      conversationUser.value.chatUser?.userId ?? -1,
    ];
    MessageData message = MessageData(
      userId: myUser?.id,
      conversationId: conversationUser.value.conversationId,
      textMessage: textMessage,
      iAmBlocked: false,
      iBlocked: false,
      imageMessage: imageMessage,
      videoMessage: videoMessage,
      postMessage: postMessage,
      storyReplyMessage: storyReplyMessage,
      messageType: type,
      id: time,
      noDeleteIds: noDeleteIds,
      audioMessage: audioMessage,
      waveData: waveData?.join(','),
    );
    Loggers.success('APPWRITE MESSAGE : ${message.toJson()}');
    if (!chatList.any((m) => m.id == message.id)) {
      chatList.add(message);
      chatList.sort((a, b) => b.id?.compareTo(a.id ?? 0) ?? 0);
    }
    try {
      await _repo.createMessage(messageId: time.toString(), data: message.toJson());
    } catch (error) {
      Loggers.error('Chat Collection ERROR : $error');
    }
    if (myUser?.id == null) return;
    String senderLastMessage = getLastMessage(type, message, isSender: true);
    String receiverLastMessage = getLastMessage(type, message, isSender: false);
    ChatThread conversation = conversationUser.value;
    conversation.id = time.toString();
    conversation.lastMsg = senderLastMessage;
    conversation.msgCount = 0;
    conversation.isDeleted = false;
    await _repo.upsertConversation(
      ownerUserId: myUser!.id!,
      otherUserId: otherUserId,
      data: conversation.toJson(),
    );
    final receiverData = await _repo.getConversation(otherUserId, myUser!.id!);
    if (receiverData != null) {
      int currentCount = (receiverData['msg_count'] as num?)?.toInt() ?? 0;
      await _repo.upsertConversation(
        ownerUserId: otherUserId,
        otherUserId: myUser!.id!,
        data: {
          'msg_count': currentCount + 1,
          'last_msg': receiverLastMessage,
          'is_deleted': false,
          'id': time.toString(),
        },
      );
    } else {
      ChatType status = ChatType.approved;
      String? reqType = UserRequestAction.accept.title;
      if (otherUser != null) {
        status = ChatType.approved;
        reqType = UserRequestAction.accept.title;
      }
      ChatThread myConversation = ChatThread(
          id: time.toString(),
          conversationId: conversationUser.value.conversationId,
          chatType: status,
          msgCount: 1,
          lastMsg: receiverLastMessage,
          userId: myUser?.id,
          isDeleted: false,
          deletedId: 0,
          iBlocked: false,
          iAmBlocked: false,
          requestType: reqType);
      myConversationUser = myConversation;
      await _repo.upsertConversation(
        ownerUserId: otherUserId,
        otherUserId: myUser!.id!,
        data: myConversation.toJson(),
      );
    }
    pushNotificationToUser(message);
  }
  void pushNotificationToUser(MessageData message) {
    if (otherUser?.notifyChat == 0) return;
    String bodyMessage = '';
    switch (message.messageType) {
      case MessageType.image:
        bodyMessage =
            'Shared a Photo${(message.textMessage ?? '').isNotEmpty ? ': ${message.textMessage}' : ""}';
      case MessageType.video:
        bodyMessage =
            'Shared a Video${(message.textMessage ?? '').isNotEmpty ? ': ${message.textMessage}' : ""}';
      case MessageType.post:
        bodyMessage = 'Shared a Post';
      case MessageType.audio:
        bodyMessage = '🎙️ Sent a voice message';
      case MessageType.text:
        bodyMessage = message.textMessage ?? '';
      case MessageType.gift:
        bodyMessage = 'Sent a Gift';
      case MessageType.gif:
        bodyMessage = 'Sent a GIF';
      case MessageType.storyReply:
        bodyMessage = 'Sent a Story Reply';
      case null:
        bodyMessage = '';
    }
    NotificationService.instance.pushNotification(
        title: myUser?.fullname ?? '',
        body: bodyMessage,
        toUserId: otherUser?.id?.toString(),
        deviceType: otherUser?.device,
        type: NotificationType.chat,
        data: myConversationUser?.toJson());
  }
  String getLastMessage(MessageType type, MessageData message,
      {bool isSender = true}) {
    String prefix = isSender ? "You: " : "";
    String sentPrefix = isSender ? "You sent " : "Sent you ";
    switch (type) {
      case MessageType.text:
        return "$prefix${message.textMessage ?? ''}";
      case MessageType.image:
        return '${sentPrefix}an Image';
      case MessageType.video:
        return '${sentPrefix}a Video';
      case MessageType.gift:
        return '${sentPrefix}a Gift';
      case MessageType.audio:
        return '${sentPrefix}a voice message';
      case MessageType.gif:
        return '${sentPrefix}a GIF';
      case MessageType.post:
        Post post = Post.fromJson(jsonDecode(message.postMessage ?? ''));
        return '$sentPrefix@${post.user?.username ?? ''}\'s post';
      case MessageType.storyReply:
        return '${sentPrefix}a Story Reply';
    }
  }
  void onTextFieldChanged(String value) {
    if (value.trim().isNotEmpty) {
      isTextEmpty.value = false;
    } else {
      isTextEmpty.value = true;
    }
  }
  void _getChat() async {
    _listenToChatThreadUser();
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      final result = await _repo.listMessages(
        conversationId: chatId,
        limit: AppRes.chatPaginationLimit,
      );
      for (var doc in result.rows) {
        final message = MessageData.fromJson(doc.data);
        chatList.add(message);
      }
      if (result.rows.isNotEmpty) {
        lastMessageDocumentId = result.rows.last.$id;
      }
    } catch (e) {
      Loggers.error('Initial chat fetch error: $e');
    }
    final sub = _repo.subscribeToMessages(
      conversationId: chatId,
      onEvent: (event, payload) {
      if (_normConv('${payload['conversation_id']}') != _normConv(chatId)) return;
      final message = MessageData.fromJson(payload);
      switch (event) {
        case 'create':
          if (!chatList.any((m) => m.id == message.id)) {
            chatList.add(message);
          }
          break;
        case 'update':
          chatList.removeWhere((element) => element.id == message.id);
          chatList.add(message);
          break;
        case 'delete':
          chatList.removeWhere((element) => element.id == message.id);
          break;
      }
      chatList.sort((a, b) => b.id?.compareTo(a.id ?? 0) ?? 0);
    });
    chatListeners.add(sub);
    chatList.sort((a, b) => b.id?.compareTo(a.id ?? 0) ?? 0);
  }
  Future<void> fetchMoreChatList() async {
    if (!hasMore.value || isLoading.value) return;
    isLoading.value = true;
    try {
      final result = await _repo.listMessages(
        conversationId: chatId,
        limit: AppRes.chatPaginationLimit,
        cursorAfterDocumentId: lastMessageDocumentId,
      );
      if (result.rows.isEmpty) {
        hasMore.value = false;
        return;
      }
      lastMessageDocumentId = result.rows.last.$id;
      for (var doc in result.rows) {
        final message = MessageData.fromJson(doc.data);
        if (!chatList.any((m) => m.id == message.id)) {
          chatList.add(message);
        }
      }
      chatList.sort((a, b) => b.id?.compareTo(a.id ?? 0) ?? 0);
    } catch (e) {
      Loggers.error("Error in paginated fetch: $e");
    } finally {
      isLoading.value = false;
    }
  }
  RxBool isLoading = false.obs;
  onChatActionTap(ChatAction action) {
    if (conversationUser.value.iAmBlocked ?? false) {
      return showSnackBar(
          'You cannot message ${conversationUser.value.chatUser?.username} because you are blocked by them.');
    }
    FocusManager.instance.primaryFocus?.unfocus();
    switch (action) {
      case ChatAction.gift:
        pickGift();
        break;
      case ChatAction.audio:
        _pickAudio();
        break;
      case ChatAction.sticker:
        pickSticker();
        break;
      case ChatAction.media:
        pickAndSendMedia();
        break;
    }
  }
  void onCameraTap() {
    if (conversationUser.value.iAmBlocked ?? false) {
      return showSnackBar(
          'You cannot message ${conversationUser.value.chatUser?.username} because you are blocked by them.');
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Get.bottomSheet(SelectMediaSheet(
      onSelectMedia: (mediaFile) {
        Get.back();
        _showSendMediaSheet(mediaFile);
      },
    ), isScrollControlled: true);
  }
  void pickGift() {
    int? userId = conversationUser.value.chatUser?.userId;
    GiftManager.openGiftSheet(
        userId: userId ?? -1,
        onCompletion: (giftManager) {
          sendMessageToFireStore(
              type: MessageType.gift,
              textMessage: giftManager.gift.coinPrice.toString(),
              imageMessage: giftManager.gift.image);
        });
  }
  void pickSticker() {
    Get.bottomSheet<String?>(const GifSheet(), isScrollControlled: true)
        .then((value) {
      if (value != null) {
        sendMessageToFireStore(type: MessageType.gif, imageMessage: value);
      }
    });
  }
  void pickAndSendMedia() async {
    MediaFile? mediaFile = await MediaPickerHelper.shared.pickMedia();
    if (mediaFile == null) return;
    mediaTextController.clear();
    _showSendMediaSheet(mediaFile);
  }
  void _showSendMediaSheet(MediaFile mediaFile) {
    Get.bottomSheet(
      SendMediaSheet(
          controller: this,
          image: mediaFile.thumbNail.path,
          onSendBtnClick: () {
            Get.back();
            _uploadAndSendMessage(mediaFile);
          }),
      isScrollControlled: true,
    );
  }
  Future<void> _uploadAndSendMessage(MediaFile mediaFile) async {
    showLoader();
    final bool isImageMessage = mediaFile.type == MediaType.image;
    final int time = DateTime.now().millisecondsSinceEpoch;
    final int myId = myUser?.id ?? -1;
    final int otherId = conversationUser.value.chatUser?.userId ?? -1;

    // Background upload queue: the attachment keeps uploading (and the
    // message keeps sending) even if the user closes the app.
    final steps = <Map<String, dynamic>>[
      {
        'kind': 'multipart',
        'url': WebService.setting.uploadFileGivePath,
        'fields': {},
        'files': [
          {'field': '${Params.file}', 'path': mediaFile.file.path},
        ],
      },
      if (!isImageMessage)
        {
          'kind': 'multipart',
          'url': WebService.setting.uploadFileGivePath,
          'fields': {},
          'files': [
            {'field': '${Params.file}', 'path': mediaFile.thumbNail.path},
          ],
        },
      {
        'kind': 'api',
        'url': '${apiURL}chat/sendMessage',
        'fields': {
          'doc_id': '$time',
          'id': '$time',
          'conversation_id': '${conversationUser.value.conversationId}',
          'message_type':
              isImageMessage ? MessageType.image.value : MessageType.video.value,
          'text_message': mediaTextController.text.trim(),
          if (isImageMessage) 'image_message': '@s0.data',
          if (!isImageMessage) 'video_message': '@s0.data',
          if (!isImageMessage) 'image_message': '@s1.data',
          'i_blocked': false,
          'i_am_blocked': false,
          'no_delete_ids': [myId, otherId],
        },
      },
    ];
    stopLoader();

    final response = await UploadQueueService.instance.submit(steps);
    if (response == null ||
        response['__error'] != null ||
        response['status'] != true) {
      Loggers.error('Background chat media send failed: ${response?['__error'] ?? response?['message']}');
      showSnackBar(LKey.somethingWentWrong.tr);
    }
  }
  Future<String> _uploadFile(XFile file) async {
    return (await CommonService.instance.uploadFileGivePath(file)).data ?? '';
  }
  void toggleAnimation() {
    if (isExpanded.value) {
      audioAnimationController.reverse();
    } else {
      audioAnimationController.forward();
    }
    isExpanded.value = !isExpanded.value;
  }
  void _pickAudio() async {
    recorderController = RecorderController();
    bool isGranted = await recorderController.checkPermission();
    if (isGranted) {
      audioAnimationController.forward();
      recorderController.record(
          androidEncoder: AndroidEncoder.aac,
          androidOutputFormat: AndroidOutputFormat.mpeg4,
          iosEncoder: IosEncoder.kAudioFormatMPEG4AAC);
    } else {
      Get.bottomSheet(
          ConfirmationSheet(
              title: LKey.enableMicrophoneAccessTitle.tr,
              description: LKey.enableMicrophoneAccessDescription.tr,
              onTap: openAppSettings,
              positiveText: LKey.settings.tr),
          isScrollControlled: true);
    }
  }
  void deleteRecordedAudio() async {
    audioAnimationController.reverse();
    recorderController.reset();
    recorderController.dispose();
  }
  void sendRecordedAudio() async {
    audioAnimationController.reverse();
    showLoader();
    try {
      String? recordedFilePath = await recorderController.stop();
      if (recordedFilePath != null) {
        List<double> waveData = await playerController.extractWaveformData(
          path: recordedFilePath,
          noOfSamples: playerWaveStyle.getSamplesForWidth(wavesWidth),
        );
        Loggers.info('Recorded file path: $recordedFilePath');
        String audioUrl = await _uploadFile(XFile(recordedFilePath));
        sendMessageToFireStore(
          type: MessageType.audio,
          audioMessage: audioUrl,
          waveData: waveData,
        );
      } else {
        Loggers.error('Audio path not found');
      }
    } catch (e) {
      Loggers.error('Audio recording error: $e');
    } finally {
      stopLoader();
      recorderController.dispose();
    }
  }
  void startAudioPlayback() async {
    await playerController.startPlayer();
    playerController.setFinishMode(finishMode: FinishMode.pause);
  }
  void pauseAudioPlayback() async {
    await playerController.pausePlayer();
  }
  void toggleAudioPlayback(MessageData message) {
    if (playerValue.value.id == message.id) {
      switch (playerValue.value.state) {
        case PlayerState.initialized:
        case PlayerState.playing:
          pauseAudioPlayback();
          break;
        case PlayerState.paused:
          startAudioPlayback();
          break;
        case PlayerState.stopped:
          break;
      }
    } else {
      playAudioMessage(message);
    }
  }
  void playAudioMessage(MessageData message) async {
    String audioUrl = message.audioMessage?.addBaseURL() ?? '';
    if (audioUrl.isEmpty) return;
    DefaultCacheManager().getSingleFile(audioUrl).then((file) async {
      playerController.release();
      await playerController.preparePlayer(
        path: file.path,
        noOfSamples: playerWaveStyle.getSamplesForWidth(wavesWidth),
      );
      playerValue.value =
          PlayerValue(state: PlayerState.initialized, id: message.id ?? 0);
      startAudioPlayback();
    });
  }
  void onDeleteForYou(MessageData message) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      final data = await _repo.getMessage(message.id.toString());
      if (data != null) {
        MessageData existing = MessageData.fromJson(data);
        List<int> ids = existing.noDeleteIds ?? [];
        if (ids.length < 2) {
          await _repo.deleteMessage(message.id.toString());
          await _deleteAssociatedFiles(message);
        } else {
          ids.remove(myUser?.id);
          await _repo.updateMessage(message.id.toString(), {'no_delete_ids': ids});
          chatList.removeWhere((element) => element.id == existing.id);
        }
      }
    } catch (e) {
      Loggers.error('On Delete For You error : $e');
    }
  }
  void onUnSend(MessageData message) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      await _repo.deleteMessage(message.id.toString());
      await _deleteAssociatedFiles(message);
    } catch (e) {
      Loggers.error('Un-send message error: $e');
    }
  }
  Future<void> _deleteAssociatedFiles(MessageData message) async {
    switch (message.messageType) {
      case MessageType.text:
        break;
      case MessageType.image:
        await deleteFile(message.imageMessage ?? '');
        break;
      case MessageType.video:
        await deleteFile(message.videoMessage ?? '');
        await deleteFile(message.imageMessage ?? '');
        break;
      case MessageType.audio:
        await deleteFile(message.audioMessage ?? '');
        break;
      case MessageType.gift:
        break;
      case MessageType.gif:
        break;
      case MessageType.post:
        break;
      case MessageType.storyReply:
        break;
      case null:
        break;
    }
  }
  Future<bool> deleteFile(String file) async {
    StatusModel response = await CommonService.instance.deleteFile(file);
    if (response.status == true) return true;
    return false;
  }
  void onChatRequestTap(
      UserRequestAction requestType, ChatThread conversation) async {
    if (myUser?.id == null) return;
    switch (requestType) {
      case UserRequestAction.block:
        AppUser? user = conversation.chatUser;
        blockUser(
            User(
                id: user?.userId,
                profilePhoto: user?.profile,
                username: user?.fullname,
                fullname: user?.fullname,
                isVerify: user?.isVerify),
            () {});
        break;
      case UserRequestAction.reject:
        await _repo.upsertConversation(
          ownerUserId: myUser!.id!,
          otherUserId: otherUserId,
          data: {
            'request_type': UserRequestAction.reject.title,
            'deleted_id': DateTime.now().millisecondsSinceEpoch,
            'is_deleted': true,
          },
        );
        Get.back();
        break;
      case UserRequestAction.accept:
        await _repo.upsertConversation(
          ownerUserId: myUser!.id!,
          otherUserId: otherUserId,
          data: {
            'chat_type': ChatType.approved.value,
            'request_type': UserRequestAction.accept.title,
          },
        );
        break;
    }
  }
  void onPostTap(Post post) async {
    PostType type = post.postType;
    playerController.pausePlayer();
    fetchPost(postType: post.postType, post: post);
    switch (type) {
      case PostType.reel:
      case PostType.video:
        Get.to(() =>
            ReelsScreen(reels: [post].obs, position: 0, isFromChat: true));
        break;
      case PostType.image:
      case PostType.text:
        Get.to(() => SinglePostScreen(post: post, isFromNotification: false));
        break;
      case PostType.none:
        break;
    }
  }
  void fetchPost({required PostType postType, Post? post}) async {
    Post? _post =
        (await PostService.instance.fetchPostById(postId: post?.id ?? -1))
            .data
            ?.post;
    if (_post == null) return;
    switch (postType) {
      case PostType.image:
      case PostType.text:
        Get.find<PostScreenController>(tag: _post.id.toString())
            .updatePost(_post);
        break;
      case PostType.reel:
      case PostType.video:
        Get.find<ReelController>(tag: _post.id.toString())
            .updateReelData(reel: _post);
        break;
      case PostType.none:
        break;
    }
  }
  void onReportUser(ChatThread chatThread) {
    Get.bottomSheet(
        ReportSheet(
            reportType: ReportType.user, id: chatThread.chatUser?.userId),
        isScrollControlled: true);
  }
  void toggleBlockUnblock(ChatThread chatThread) {
    if (chatThread.iBlocked ?? false) {
      unblockUser(otherUser, () {});
    } else {
      blockUser(otherUser, () {});
    }
  }
  void sendStoryReply(
      {required Story story, required String textReply, String? imageReply}) {
    sendMessageToFireStore(
        type: MessageType.storyReply,
        imageMessage: imageReply,
        textMessage: textReply,
        storyReplyMessage: jsonEncode(story.toJsonWithUser()));
  }
  _markAsRead() async {
    if (myUser?.id == null) return;
    final data = await _repo.getConversation(myUser!.id!, otherUserId);
    if (data != null) {
      await _repo.upsertConversation(
        ownerUserId: myUser!.id!,
        otherUserId: otherUserId,
        data: {'msg_count': 0},
      );
    }
  }
  void removeStoryFromChat(MessageData message) async {
    try {
      final data = await _repo.getMessage(message.id.toString());
      if (data != null) {
        await _repo.updateMessage(message.id.toString(), {
          'story_reply_message': jsonEncode(Story()),
        });
      }
    } catch (e) {
      Loggers.error('removeStoryFromChat error: $e');
    }
  }
  void onStoryTap(MessageData message, Story story) {
    final createdAtStr = story.createdAt;
    if (createdAtStr == null || createdAtStr.isEmpty) {
      removeStoryFromChat(message);
      return;
    }
    DateTime? storyDate;
    try {
      storyDate = DateTime.parse(createdAtStr);
    } catch (e) {
      removeStoryFromChat(message);
      return;
    }
    final isExpired = DateTime.now().difference(storyDate).inHours >= 24;
    if (isExpired) {
      removeStoryFromChat(message);
      return;
    }
    if (story.id == null) {
      removeStoryFromChat(message);
      return;
    }
    final user = User(
      id: story.userId,
      username: story.user?.fullname ?? '',
      fullname: story.user?.fullname ?? '',
      profilePhoto: story.user?.profilePhoto ?? '',
      isVerify: story.user?.isVerify,
      bio: story.user?.bio ?? '',
      stories: [story],
    );
    Get.bottomSheet(
      StoryViewSheet(
        stories: [user],
        userIndex: 0,
        onUpdateDeleteStory: (_) {},
      ),
      isScrollControlled: true,
      ignoreSafeArea: false,
      useRootNavigator: true,
    );
  }
  void _addUsersFirebaseFireStore() async {
    if (myUser != null) {
      FirebaseFirestoreController.instance.addUser(myUser);
    }
    if (otherUser != null) {
      FirebaseFirestoreController.instance.addUser(otherUser);
    }
  }
}
final playerWaveStyle = PlayerWaveStyle(
    fixedWaveColor: ColorRes.bgGrey,
    spacing: 3,
    waveThickness: 1.5,
    scaleFactor: 50,
    liveWaveGradient: StyleRes.wavesGradient);
class PlayerValue {
  PlayerState state;
  int id;
  PlayerValue({required this.state, required this.id});
}
