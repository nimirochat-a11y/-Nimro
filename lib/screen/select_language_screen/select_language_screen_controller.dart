import 'dart:io';

import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/manager/ads_manager.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/widget/eula_sheet.dart';
import 'package:nimiro/common/widget/restart_widget.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/screen/select_language_screen/select_language_screen.dart';

class SelectLanguageScreenController extends BaseController {
  Rx<Language?> selectedLanguage = Rx(null);
  RxList<Language> languages = <Language>[].obs;
  LanguageNavigationType languageNavigationType;

  Setting? get setting => SessionManager.instance.getSettings();
  SelectLanguageScreenController(this.languageNavigationType);

  @override
  void onInit() {
    super.onInit();
    initLanguage();
  }

  @override
  void onReady() {
    super.onReady();
    if (languageNavigationType == LanguageNavigationType.fromStart) {
      openEULASheet();
    }
    AdsManager.instance.requestConsentInfoUpdate();
  }

  Future<void> openEULASheet() async {
    if (Platform.isIOS) {
      bool shouldOpen = SessionManager.instance.shouldOpenEULASheet;

      await Future.delayed(const Duration(milliseconds: 250));
      Loggers.info('message  $shouldOpen');
      if (shouldOpen) {
        Get.bottomSheet(const EulaSheet(),
            isScrollControlled: true, enableDrag: false);
      }
    }
  }

  void initLanguage() {
    languages.assignAll([
      Language(id: 1, code: 'ar', title: 'Arabic', localizedTitle: 'العربية', status: 1),
      Language(id: 2, code: 'en', title: 'English', localizedTitle: 'English', status: 1),
    ]);
    selectedLanguage.value = languages.firstWhereOrNull(
      (element) => element.code == SessionManager.instance.getLang(),
    );
  }

  void onLanguageChange(Language? value) {
    selectedLanguage.value = value;
    SessionManager.instance.setLang(value?.code ?? 'en');
    RestartWidget.restartApp(Get.context!);
  }
}
