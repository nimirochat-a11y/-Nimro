import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/controller/follow_controller.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/api/user_service.dart';
import 'package:nimiro/model/user_model/follower_model.dart';
import 'package:nimiro/model/user_model/following_model.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/follow_following_screen/follow_following_screen.dart';

class FollowFollowingScreenController extends BaseController {
  RxInt followerCount = 0.obs;
  RxInt followingCount = 0.obs;
  User? user;
  BuildContext context;
  RxBool isFollowUnFollowInProcess = false.obs;

  FollowFollowingType followFollowingType;

  FollowFollowingScreenController(
      this.followFollowingType, this.user, this.context) {
    followerCount.value = user?.followerCount?.toInt() ?? 0;
    followingCount.value = user?.followingCount?.toInt() ?? 0;
  }

  RxList<Follower> followers = <Follower>[].obs;
  RxList<Following> followings = <Following>[].obs;

  RxBool isFollowers = false.obs;
  RxBool isFollowings = false.obs;

  ScrollController followerController = ScrollController();
  ScrollController followingController = ScrollController();

  bool get isFollowersPage =>
      followFollowingType == FollowFollowingType.follower;

  bool get isMyProfile =>
      user?.id?.toInt() == SessionManager.instance.getUserID();

  @override
  void onInit() {
    super.onInit();
    _initData();
  }

  @override
  void onReady() {
    super.onReady();
    fetchScrollData();
  }

  Future<void> _initData() async {
    if (isFollowersPage) {
      await fetchFollowers();
    } else {
      await fetchFollowings();
    }
  }

  Future<void> fetchFollowers() async {
    if (isFollowers.value) return;
    isFollowers.value = true;
    int lastId = followers.isEmpty ? -1 : followers.last.id ?? -1;

    List<Follower> list = await UserService.instance
        .fetchMyFollowers(lastItemId: lastId, userId: user?.id?.toInt());
    if (list.isNotEmpty) {
      followers.addAll(list);
    }
    isFollowers.value = false;
  }

  Future<void> fetchFollowings() async {
    if (isFollowings.value) return;
    isFollowings.value = true;
    int lastId = followings.isEmpty ? -1 : followings.last.id ?? -1;

    List<Following> list = await UserService.instance
        .fetchMyFollowing(lastItemId: lastId, userId: user?.id?.toInt());
    if (list.isNotEmpty) {
      followings.addAll(list);
    }
    isFollowings.value = false;
  }

  Future<void> onFollowUnFollow(dynamic item) async {
    if (isFollowersPage) {
      await _handleFollowerAction(item as Follower);
    } else {
      await _handleFollowingAction(item as Following);
    }
  }

  Future<void> _handleFollowerAction(Follower data) async {
    int userId = data.fromUserId ?? -1;
    FollowController followController;
    if (Get.isRegistered<FollowController>(tag: userId.toString())) {
      followController = Get.find<FollowController>(tag: userId.toString());
    } else {
      followController =
          Get.put(FollowController(data.fromUser.obs), tag: userId.toString());
    }

    User? updatedUser = await followController.followUnFollowUser();
    if (updatedUser == null) return;

    for (var element in followers) {
      if (element.fromUserId == userId) {
        element.fromUser?.isFollowing = updatedUser.isFollowing;
        element.fromUser?.followerCount = updatedUser.followerCount;
        element.fromUser?.followStatus = updatedUser.followStatus;
      }
    }
    followers.refresh();
  }

  Future<void> _handleFollowingAction(Following data) async {
    int userId = data.toUserId ?? -1;
    data.toUser?.isFollowing ??= true;

    FollowController followController;
    if (Get.isRegistered<FollowController>(tag: userId.toString())) {
      followController = Get.find<FollowController>(tag: userId.toString());
    } else {
      followController =
          Get.put(FollowController(data.toUser.obs), tag: userId.toString());
    }

    User? updatedUser = await followController.followUnFollowUser();
    if (updatedUser == null) return;

    // On my own following list, unfollowing removes the person from the list.
    // On someone else's list the row stays because it is their following list.
    if (isMyProfile && updatedUser.isFollowing == false) {
      followings.removeWhere((element) => element.toUserId == userId);
      followingCount.value =
          (followingCount.value - 1).clamp(0, double.infinity).toInt();
      return;
    }

    for (var element in followings) {
      if (element.toUserId == userId) {
        element.toUser?.isFollowing = updatedUser.isFollowing;
        element.toUser?.followerCount = updatedUser.followerCount;
        element.toUser?.followStatus = updatedUser.followStatus;
      }
    }
    followings.refresh();
  }

  void fetchScrollData() {
    if (isFollowersPage) {
      followerController.addListener(() {
        if (followerController.position.pixels ==
            followerController.position.maxScrollExtent) {
          fetchFollowers();
        }
      });
    } else {
      followingController.addListener(() {
        if (followingController.position.pixels ==
            followingController.position.maxScrollExtent) {
          fetchFollowings();
        }
      });
    }
  }

  @override
  void onClose() {
    super.onClose();
    followingController.dispose();
    followerController.dispose();
  }
}
