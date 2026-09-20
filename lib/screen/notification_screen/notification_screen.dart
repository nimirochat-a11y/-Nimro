import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/widget/custom_app_bar.dart';
import 'package:nimiro/common/widget/load_more_widget.dart';
import 'package:nimiro/common/widget/loader_widget.dart';
import 'package:nimiro/common/widget/no_data_widget.dart';
import 'package:nimiro/languages/languages_keys.dart';
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
      backgroundColor: scaffoldBackgroundColor(context),
      body: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: Column(
          children: [
            CustomAppBar(
                title: LKey.notifications.tr,
                titleStyle: TextStyleCustom.unboundedSemiBold600(
                    fontSize: 15, color: textDarkGrey(context))),
            Expanded(
              child: ColoredBox(
                color: scaffoldBackgroundColor(context),
                child: Obx(() {
                  final bool isEmpty =
                      controller.activityNotifications.isEmpty &&
                          controller.adminNotifications.isEmpty;
                  final bool isLoading =
                      (controller.isActivityNotification.value ||
                              controller.isAdminNotification.value) &&
                          isEmpty;
                  if (isLoading) {
                    return const LoaderWidget();
                  }
                  final items = _mergeNotifications(controller);
                  return NoDataView(
                    showShow: isEmpty,
                    child: LoadMoreWidget(
                      loadMore: () async {
                        await Future.wait([
                          controller.fetchActivityNotifications(),
                          controller.fetchAdminNotification(),
                        ]);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            items[index].build(context),
                      ),
                    ),
                  );
                }),
              ),
            )
          ],
        ),
      ),
    );
  }

  List<_MergedNotificationItem> _mergeNotifications(
      NotificationScreenController controller) {
    final List<_MergedNotificationItem> items = [];
    for (final data in controller.activityNotifications) {
      items.add(_MergedNotificationItem(
        time: DateTime.tryParse(data.createdAt ?? '') ?? DateTime(0),
        build: (context) =>
            ActivityNotificationPage(data: data, controller: controller),
      ));
    }
    for (final data in controller.adminNotifications) {
      items.add(_MergedNotificationItem(
        time: DateTime.tryParse(data.createdAt ?? '') ?? DateTime(0),
        build: (context) => SystemNotificationPage(data: data),
      ));
    }
    items.sort((a, b) => b.time.compareTo(a.time));
    return items;
  }
}

class _MergedNotificationItem {
  final DateTime time;
  final Widget Function(BuildContext) build;
  _MergedNotificationItem({required this.time, required this.build});
}
