import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/functions/debounce_action.dart';
import 'package:nimiro/common/service/api/user_service.dart';
import 'package:nimiro/common/widget/bottom_sheet_top_view.dart';
import 'package:nimiro/common/widget/custom_search_text_field.dart';
import 'package:nimiro/common/widget/loader_widget.dart';
import 'package:nimiro/common/widget/user_list.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/comment_sheet/helper/comment_helper.dart';
import 'package:nimiro/screen/create_feed_screen/create_feed_screen_controller.dart';
import 'package:nimiro/utilities/app_res.dart';
import 'package:nimiro/utilities/theme_res.dart';

class MentionSheet extends StatefulWidget {
  const MentionSheet({super.key});

  @override
  State<MentionSheet> createState() => _MentionSheetState();
}

class _MentionSheetState extends State<MentionSheet> {
  final controller = Get.find<CreateFeedScreenController>();
  late CommentHelper helper;
  RxBool isLoading = false.obs;
  RxList<User> users = <User>[].obs;
  TextEditingController textEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    helper = controller.commentHelper;
    searchUsers();
  }

  Future<void> searchUsers({bool reset = false}) async {
    isLoading.value = true;
    DebounceAction.shared.call(() async {
      final data = await UserService.instance.searchUsers(
          keyWord: textEditingController.text.trim(),
          lastItemId: reset
              ? null
              : users.isEmpty
                  ? null
                  : users.last.id?.toInt(),
          limit: AppRes.paginationLimit);
      if (reset) {
        users.clear();
      }
      isLoading.value = false;
      users.addAll(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: EdgeInsets.only(top: AppBar().preferredSize.height * 2),
        decoration: ShapeDecoration(
            color: whitePure(context),
            shape: const SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius.vertical(
                    top: SmoothRadius(cornerRadius: 30, cornerSmoothing: 1)))),
        child: Column(
          children: [
            BottomSheetTopView(
                title: LKey.mention.tr, sideBtnVisibility: false),
            CustomSearchTextField(
                controller: textEditingController,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                onChanged: (value) => searchUsers(reset: true)),
            const SizedBox(height: 10),
            Expanded(
                child: Obx(
              () => isLoading.value && users.isEmpty
                  ? const LoaderWidget()
                  : UserList(
                      onTap: (user) => controller.commentHelper
                          .appendDetection(user, DetectType.atSign, type: 0),
                      users: users,
                      isLoading: controller.isLoading,
                      getFullName: (p0) => p0.fullname ?? '',
                      getProfilePhoto: (p0) => p0.profilePhoto ?? '',
                      getUserName: (p0) => p0.username ?? '',
                      getVerified: (p0) => p0.isVerify ?? 0,
                      loadMore: searchUsers),
            ))
          ],
        ));
  }
}
