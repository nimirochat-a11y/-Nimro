import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/widget/custom_search_text_field.dart';
import 'package:nimiro/common/widget/loader_widget.dart';
import 'package:nimiro/common/widget/no_data_widget.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/chat/chat_thread.dart';
import 'package:nimiro/screen/message_screen/message_screen_controller.dart';
import 'package:nimiro/screen/message_screen/widget/chat_conversation_user_card.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class MessageScreen extends StatelessWidget {
  const MessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MessageScreenController());
    return Column(
      children: [
        Container(
          color: scaffoldBackgroundColor(context),
          child: SafeArea(
            minimum: const EdgeInsets.only(top: 15),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Text(LKey.messages.tr,
                  style: TextStyleCustom.unboundedMedium500(
                      fontSize: 15, color: textDarkGrey(context))),
            ),
          ),
        ),
        const CustomSearchTextField(),
        Expanded(
          child: Obx(
            () => controller.isLoading.value &&
                    controller.combinedThreads.isEmpty
                ? const LoaderWidget()
                : CombinedThreadsListView(),
          ),
        )
      ],
    );
  }
}

class CombinedThreadsListView extends StatelessWidget {
  const CombinedThreadsListView({super.key});

  @override
  Widget build(BuildContext context) {
    final MessageScreenController controller = Get.find();
    return Obx(() {
      final threads = controller.combinedThreads;
      return NoDataView(
        showShow: threads.isEmpty,
        title: LKey.chatListEmptyTitle.tr,
        description: LKey.chatListEmptyDescription.tr,
        child: ListView.builder(
          itemCount: threads.length,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            ChatThread chatConversation = threads[index];
            chatConversation.bindChatUser();
            return ChatConversationUserCard(chatConversation: chatConversation);
          },
        ),
      );
    });
  }
}
