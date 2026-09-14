import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/widget/custom_app_bar.dart';
import 'package:nimiro/common/widget/load_more_widget.dart';
import 'package:nimiro/common/widget/loader_widget.dart';
import 'package:nimiro/common/widget/no_data_widget.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/misc/activity_notification_model.dart';
import 'package:nimiro/model/misc/admin_notification_model.dart';
import 'package:nimiro/screen/notification_screen/notification_screen_controller.dart';
import 'package:nimiro/screen/notification_screen/widget/activity_notification_page.dart';
import 'package:nimiro/screen/notification_screen/widget/system_notification_page.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NotificationScreenController());
    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(
            title: LKey.notifications.tr,
            titleStyle: TextStyleCustom.unboundedSemiBold600(
                fontSize: 15, color: textDarkGrey(context)),
          ),
          Expanded(
            child: Obx(() {
              final items = controller.mergedNotifications;
              if (controller.isMergedLoading && controller.isMergedEmpty) {
                return const LoaderWidget();
              }
              return NoDataView(
                showShow: items.isEmpty,
                child: LoadMoreWidget(
                  loadMore: controller.fetchMoreMerged,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final data = items[index];
                      if (data is ActivityNotification) {
                        return ActivityNotificationPage(
                            data: data, controller: controller);
                      } else if (data is AdminNotificationData) {
                        return SystemNotificationPage(data: data);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              );
            }),
          )
        ],
      ),
    );
  }
}
