import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/manager/firebase_notification_manager.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/manager/share_manager.dart';
import 'package:nimiro/common/service/api/api_service.dart';
import 'package:nimiro/common/service/api/common_service.dart';
import 'package:nimiro/common/service/api/post_service.dart';
import 'package:nimiro/common/service/api/user_service.dart';
import 'package:nimiro/common/service/location/location_service.dart';
import 'package:nimiro/common/service/navigation/navigate_with_controller.dart';
import 'package:nimiro/model/general/place_detail.dart';
import 'package:nimiro/model/post_story/post_by_id.dart';
import 'package:nimiro/model/post_story/post_model.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/post_screen/single_post_screen.dart';
import 'package:nimiro/screen/reels_screen/reels_screen.dart';
import 'package:nimiro/screen/reels_screen/reels_screen_controller.dart';
import 'package:nimiro/utilities/app_res.dart';

class HomeScreenController extends BaseController with GetSingleTickerProviderStateMixin {
  Rx<TabType> selectedReelCategory = TabType.values.first.obs;
  RxList<Post> reels = <Post>[].obs;
  late AnimationController controller;
  late Animation<double> animation;
  RxBool isAnimateTab = false.obs;
  StreamSubscription<Map>? streamSubscription;
  CancelToken token = CancelToken();

  // "For You" pagination: the server returns a stable ranked order, so the
  // app only needs to advance the page when a full page comes back.
  int _forYouPage = 0;
  bool _forYouHasMore = true;

  // New token for every fresh load (first open / pull to refresh) so the
  // server rotates the order; the pages of one load reuse it.
  String _feedToken = '';

  Rx<User?> get myUser => Rx(SessionManager.instance.getUser());

  @override
  void onInit() {
    controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    animation = CurvedAnimation(parent: controller, curve: Curves.linear);

    // Call both methods concurrently
    Future.wait([
      onRefreshPage(),
      _onNotificationTap(),
      _fetchLocation(),
      _readDeepLink(),
    ]);

    super.onInit();
  }

  @override
  void onReady() {
    isLoading.value = true;
    super.onReady();
  }

  @override
  void onClose() {
    super.onClose();
    controller.dispose();
    streamSubscription?.cancel();
  }

  Future<void> _onNotificationTap() async {
    if (Platform.isIOS) {
      // Handle the iOS notification payload once
      final payload = FirebaseNotificationManager.instance.notificationPayload.value;
      if (payload.isNotEmpty) {
        FirebaseNotificationManager.instance.handleNotification(payload);
      }
    } else {
      // Set up a listener to handle future payload changes
      // Android: Get the message if the app was opened via notification
      RemoteMessage? message = await FirebaseMessaging.instance.getInitialMessage();

      if (message != null) {
        await FirebaseNotificationManager.instance.handleNotification(jsonEncode(message.toMap()));
      }
    }

    FirebaseNotificationManager.instance.notificationPayload.listen((p0) {
      if (p0.isNotEmpty) {
        FirebaseNotificationManager.instance.handleNotification(p0);
      }
    });
  }

  Future<void> _readDeepLink() async {
    ShareManager.shared.listen((key, value) async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (key == ShareKeys.post.value) {
        PostByIdModel model = await PostService.instance.fetchPostById(postId: value);
        if (model.status == true) {
          Post? post = model.data?.post;
          if (post != null) {
            await Get.to(() => SinglePostScreen(post: post, isFromNotification: true), preventDuplicates: false);
          }
        }
      } else if (key == ShareKeys.reel.value) {
        PostByIdModel model = await PostService.instance.fetchPostById(postId: value);
        if (model.status == true) {
          Post? post = model.data?.post;
          if (post != null) {
            await Get.to(() => ReelsScreen(reels: [post].obs, position: 0), preventDuplicates: false);
          }
        }
      } else if (key == ShareKeys.user.value) {
        User? user = await UserService.instance.fetchUserDetails(userId: value);
        if (user != null) {
          await NavigationService.shared.openProfileScreen(user);
        }
      }
    });
  }

  Future<void> onRefreshPage({bool reset = true}) async {
    if (reset) {
      isLoading.value = true;
    }
    switch (selectedReelCategory.value) {
      case TabType.discover:
        await fetchDiscoverPost(reset);
        break;
      case TabType.following:
        await _fetchFollowingPost(reset);
        break;
      case TabType.nearby:
        try {
          await _fetchPostsNearBy(reset);
        } catch (e) {
          selectedReelCategory.value = TabType.discover;
        }
        break;
    }
  }

  onTabTypeChanged(TabType tabType) async {
    onAnimationBack();
    if (selectedReelCategory.value == tabType) {
      return;
    }
    selectedReelCategory.value = tabType;
    await onRefreshPage.call(reset: true);
  }

  onToggleDropDown() {
    if (animation.status != AnimationStatus.completed) {
      controller.forward();
      isAnimateTab.value = true;
    } else {
      onAnimationBack();
    }
  }

  onAnimationBack() {
    isAnimateTab.value = false;
    controller.animateBack(0, duration: const Duration(milliseconds: 250), curve: Curves.linear);
  }

  Future<void> fetchDiscoverPost(bool resetData) async {
    if (!resetData && !_forYouHasMore) return;
    if (resetData) {
      _forYouPage = 0;
      _forYouHasMore = true;
      _feedToken = DateTime.now().microsecondsSinceEpoch.toString();
    }

    isLoading.value = true;
    try {
      List<Post> newPosts = await PostService.instance.fetchForYou(
          page: _forYouPage,
          limit: AppRes.paginationLimit,
          types: PostType.reels,
          feedToken: _feedToken,
          cancelToken: token);
      if (newPosts.length < AppRes.paginationLimit) {
        _forYouHasMore = false;
      }
      if (newPosts.isNotEmpty) {
        _forYouPage++;
      }
      addResponseData(newPosts, resetData);
    } catch (e) {
      Loggers.error('For You fetch failed: $e');
      isLoading.value = false;
    }
  }

  Future<void> _fetchFollowingPost(bool resetData) async {
    isLoading.value = true;
    List<Post> newPosts = await PostService.instance.fetchPostsFollowing(type: PostType.reels, cancelToken: token);

    addResponseData(newPosts, resetData);
  }

  Future<void> _fetchPostsNearBy(bool resetData) async {
    isLoading.value = true;
    Position position = await LocationService.instance.getCurrentLocation(isPermissionDialogShow: true);
    List<Post> newPosts = await PostService.instance.fetchPostsNearBy(
        type: PostType.reels, placeLat: position.latitude, placeLon: position.longitude, cancelToken: token);
    addResponseData(newPosts, resetData);
  }

  void addResponseData(List<Post> newPosts, bool resetData) {
    if (resetData) {
      reels.clear();
      if (Get.isRegistered<ReelsScreenController>(tag: ReelsScreenController.tag)) {
        var controller = Get.find<ReelsScreenController>(tag: ReelsScreenController.tag);
        controller.handleRefresh(() async {});
      }
    }
    // The ranked feed is paginated, but a changing profile can still make a
    // post appear twice. Never render the same reel twice in one feed.
    final existingIds = reels.map((post) => post.id).whereType<int>().toSet();
    final uniquePosts = <Post>[];
    for (final post in newPosts) {
      final id = post.id;
      if (id == null || existingIds.add(id)) {
        uniquePosts.add(post);
      }
    }
    if (uniquePosts.isNotEmpty) {
      reels.addAll(uniquePosts);
    }

    isLoading.value = false;
  }

  Future<void> _fetchLocation() async {
    PlaceDetail? detail;
    try {
      detail = await CommonService.instance.getIPPlaceDetail();
    } catch (e) {
      Loggers.error('Location error : $e');
    }

    if (detail != null) {
      UserService.instance
          .updateUserDetails(region: detail.region, regionName: detail.regionName, timezone: detail.timezone);
    }
  }
}
