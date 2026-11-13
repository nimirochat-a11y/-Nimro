import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/api/common_service.dart';
import 'package:nimiro/common/widget/custom_app_bar.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

enum TermAndPrivacyType {
  privacyPolicy,
  termAndCondition;

  String get title {
    switch (this) {
      case TermAndPrivacyType.privacyPolicy:
        return LKey.privacyPolicy;
      case TermAndPrivacyType.termAndCondition:
        return LKey.termsOfUse;
    }
  }
}

class TermAndPrivacyScreen extends StatefulWidget {
  final TermAndPrivacyType type;

  const TermAndPrivacyScreen({super.key, required this.type});

  @override
  State<TermAndPrivacyScreen> createState() => _TermAndPrivacyScreenState();
}

class _TermAndPrivacyScreenState extends State<TermAndPrivacyScreen> {
  Rx<Setting?> settings = Rx(null);
  final RxBool isLoading = false.obs;

  @override
  void initState() {
    super.initState();
    settings.value = SessionManager.instance.getSettings();
    _refreshFromServer();
  }

  /// v1.1.39: legal texts follow the language selected INSIDE the app, and the
  /// server content may be updated at any time. The screen used to render the
  /// settings cached at the last cold start, so a language change or a server
  /// update only appeared after a full restart. Now we refresh silently on
  /// open: cached text shows instantly, then the fresh, correctly-localised
  /// text replaces it when the request succeeds. Offline keeps the cache.
  Future<void> _refreshFromServer() async {
    try {
      isLoading.value = true;
      final ok = await CommonService.instance
          .fetchGlobalSettings()
          .timeout(const Duration(seconds: 12));
      if (ok && mounted) {
        settings.value = SessionManager.instance.getSettings();
      }
    } catch (e) {
      Loggers.error('Legal content refresh failed: $e');
    } finally {
      if (mounted) isLoading.value = false;
    }
  }

  String get _content => widget.type == TermAndPrivacyType.privacyPolicy
      ? settings.value?.privacyPolicy ?? ''
      : settings.value?.termsOfUses ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(title: widget.type.title.tr),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true, // Removes extra top padding
                child: Obx(
                  () {
                    final content = _content;
                    // Only show a spinner when there is nothing cached yet;
                    // otherwise the cached text stays visible while refreshing.
                    if (content.isEmpty && isLoading.value) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return HtmlWidget(
                      content,
                      textStyle: TextStyleCustom.outFitRegular400(
                          fontSize: 15, color: textDarkGrey(context)),
                      renderMode: RenderMode.listView,
                    );
                  },
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
