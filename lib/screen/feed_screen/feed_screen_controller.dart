import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/api/post_service.dart';
import 'package:nimiro/common/service/api/user_service.dart';
import 'package:nimiro/common/service/location/location_service.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/post_story/post_model.dart';
import 'package:nimiro/model/post_story/story/story_model.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/camera_screen/camera_screen.dart';
import 'package:nimiro/screen/profile_screen/profile_screen_controller.dart';
import 'package:nimiro/screen/story_view_screen/story_view_screen.dart';
import 'package:nimiro/utilities/app_res.dart';

class FeedScreenController extends BaseController {
  RxList<Post> posts = RxList();
  RxList<User> stories = RxList();
  Rx<PostCategory> selectedPostCategory = PostCategory.discover.obs;
  ScrollController postScrollController = ScrollController();
  RxBool isStoriesLoading = false.obs;
  Rx<User?> myUser;

  // Personalised "For You" posts feed. The server returns a stable ranked
  // order, so the app advances the page only when a full page comes back.
  int _forYouPage = 0;
  bool _forYouHasMore = true;
  bool _forYouFallbackUsed = false;

  FeedScreenController(this.myUser);

  final GlobalKey<RefreshIndicatorState> refreshKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void onInit() {
    super.onInit();
    initData();
    postScrollController.addListener(_loadMoreData);
  }

  initData() {
    Future.wait([fetchDiscoverPost(), _fetchStory()]);
  }

  Future<void> _fetchMyUser() async {
    myUser.value = await UserService.instance.fetchUserDetails();
  }

  Future<void> _fetchStory({bool isEmpty = false}) async {
    isStoriesLoading.value = true;
    List<User> items = await PostService.instance.fetchStory();
    if (isEmpty) {
      stories.clear();
    }
    stories.addAll(items);
    isStoriesLoading.value = false;
  }

  Future<void> fetchDiscoverPost({bool isEmpty = false}) async {
    if (isLoading.value) return;
    if (!isEmpty && !_forYouHasMore) return;
    isLoading.value = true;
    try {
      if (isEmpty) {
        _forYouPage = 0;
        _forYouHasMore = true;
        _forYouFallbackUsed = false;
      }

      List<Post> ranked = await PostService.instance.fetchForYou(
          page: _forYouPage,
          limit: AppRes.paginationLimit,
          types: PostType.posts);

      if (ranked.length < AppRes.paginationLimit) {
        _forYouHasMore = false;
      }
      if (ranked.isNotEmpty) {
        _forYouPage++;
      }

      // An empty personalised feed (new account, no ranked candidates) falls
      // back to the legacy discover list instead of showing a blank tab.
      if (isEmpty && ranked.isEmpty) {
        await _appendDiscoverFallback(isEmpty: true);
        return;
      }

      _addDataInPostList(ranked, isEmpty);

      // The posts catalogue is still small. Once the ranked feed is
      // exhausted, top it up once with the legacy discover list so the tab
      // does not stop after one or two posts. Duplicates are removed by
      // _addDataInPostList.
      if (!_forYouHasMore &&
          !_forYouFallbackUsed &&
          posts.length < AppRes.paginationLimit) {
        _forYouFallbackUsed = true;
        final legacy = await PostService.instance
            .fetchPostsDiscover(type: PostType.posts);
        _addDataInPostList(legacy, false);
      }
    } catch (e) {
      Loggers.error('Fetch Discover Post Error : $e');
      if (isEmpty && !_forYouFallbackUsed) {
        try {
          await _appendDiscoverFallback(isEmpty: true);
          return;
        } catch (fallbackError) {
          Loggers.error('Fetch Discover Fallback Error : $fallbackError');
        }
      }
      isLoading.value = false;
    }
  }

  Future<void> _appendDiscoverFallback({bool isEmpty = false}) async {
    _forYouFallbackUsed = true;
    _forYouHasMore = false;
    final legacy =
        await PostService.instance.fetchPostsDiscover(type: PostType.posts);
    _addDataInPostList(legacy, isEmpty);
  }

  Future<void> _fetchPostsFollowing({bool isEmpty = false}) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      List<Post> _post =
          await PostService.instance.fetchPostsFollowing(type: PostType.posts);
      _addDataInPostList(_post, isEmpty);
    } catch (e) {
      Loggers.error('Fetch Following Post Error : $e');
      isLoading.value = false;
    }
  }

  Future<void> _fetchPostsNearBy({bool isEmpty = false}) async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      Position position = await LocationService.instance
          .getCurrentLocation(isPermissionDialogShow: true);

      List<Post> _post = await PostService.instance.fetchPostsNearBy(
          type: PostType.posts,
          placeLat: position.latitude,
          placeLon: position.longitude);

      _addDataInPostList(_post, isEmpty);
    } catch (e) {
      Loggers.error('Fetch NearBy Post Error : $e');
      isLoading.value = false;
    }
  }

  _addDataInPostList(List<Post> newList, bool isEmpty) async {
    if (isEmpty) {
      posts.clear();
    }
    // The ranked feed is paginated and the profile can change between
    // requests, so the same post may come back on a later page. Never render
    // the same post twice in one feed.
    final existingIds = posts.map((post) => post.id).whereType<int>().toSet();
    final uniquePosts = <Post>[];
    for (final post in newList) {
      final id = post.id;
      if (id == null || existingIds.add(id)) {
        uniquePosts.add(post);
      }
    }
    posts.addAll(uniquePosts);

    await Future.delayed(const Duration(milliseconds: 200));
    isLoading.value = false;
  }

  void _removeAndDisposeListener() {
    postScrollController.removeListener(_loadMoreData);
    postScrollController.dispose();
  }

  Future<void> onChangeCategory(PostCategory value) async {
    selectedPostCategory.value = value;
    isLoading.value = false;
    switch (value) {
      case PostCategory.discover:
        await fetchDiscoverPost(isEmpty: true);
      case PostCategory.nearby:
        try {
          await _fetchPostsNearBy(isEmpty: true);
        } catch (e) {
          selectedPostCategory.value = PostCategory.discover;
          await fetchDiscoverPost(isEmpty: true);
        }
      case PostCategory.following:
        await _fetchPostsFollowing(isEmpty: true);
    }
  }

  Future<void> onRefresh() async {
    await onChangeCategory(selectedPostCategory.value);
    await _fetchStory(isEmpty: true);
    await _fetchMyUser();
  }

  void onCreateStory() {
    Get.to(() => const CameraScreen(cameraType: CameraScreenType.story));
  }

  void onAddStory(Story? story) {
    if (story == null) return; // Exit early if story is null
    myUser.update((val) {
      val?.stories?.add(story);
    });
  }

  void onWatchStory(List<User> users, int index, String watchType) {
    Get.bottomSheet(
      StoryViewSheet(
        stories: users,
        userIndex: index,
        onUpdateDeleteStory: (story) {
          final userId = story?.userId;
          final storyId = story?.id;

          if (userId == SessionManager.instance.getUserID()) {
            // Update profile screen controller if registered
            if (Get.isRegistered<ProfileScreenController>(
                tag: ProfileScreenController.tag)) {
              final controller = Get.find<ProfileScreenController>(
                  tag: ProfileScreenController.tag);
              controller.userData.update((val) {
                val?.stories?.removeWhere((s) => s.id == storyId);
              });
            }

            // Update current user stories
            myUser.update((val) {
              val?.stories?.removeWhere((s) => s.id == storyId);
            });
          } else {
            // Remove story from other user's list
            final userIndex = stories.indexWhere((u) => u.id == userId);
            if (userIndex != -1) {
              (stories[userIndex].stories ?? [])
                  .removeWhere((s) => s.id == storyId);
            }
          }
        },
      ),
      isScrollControlled: true,
      ignoreSafeArea: false,
      useRootNavigator:
          true, // Ensures the BottomSheet is on top of all navigators
    ).then((value) {
      // For check story view or not
      switch (watchType) {
        case 'my_story':
          _fetchMyUser();
          break;
        case 'other_story':
          _fetchStory(isEmpty: true);
      }
    });
  }

  Future<void> _loadMoreData() async {
    if (postScrollController.position.pixels >=
            (postScrollController.position.maxScrollExtent - 300) &&
        !isLoading.value) {
      switch (selectedPostCategory.value) {
        case PostCategory.discover:
          await fetchDiscoverPost();
        case PostCategory.nearby:
          await _fetchPostsNearBy();
        case PostCategory.following:
          await _fetchPostsFollowing();
      }
    }
  }

  @override
  void onClose() {
    super.onClose();
    _removeAndDisposeListener();
  }
}

enum PostCategory {
  discover,
  nearby,
  following;

  String get title {
    switch (this) {
      case PostCategory.discover:
        return LKey.discover.tr;
      case PostCategory.nearby:
        return LKey.nearby.tr;
      case PostCategory.following:
        return LKey.following.tr;
    }
  }
}
