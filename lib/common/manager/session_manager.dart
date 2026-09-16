import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:nimiro/common/service/api/user_service.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/utilities/app_res.dart';

class SessionManager {
  static var instance = SessionManager();
  var storage = GetStorage('nimiro');

  /// Hardware-backed keystore (Android Keystore / iOS Keychain).
  /// SECURITY (S3): the user's password used to be written to GetStorage,
  /// which on Android is a plain SharedPreferences XML file. Any backup, root,
  /// or adb-accessible copy exposed the password that unlocks every account
  /// service. Sensitive values now live only in the platform keystore.
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  var conversationId = '';
  RxInt notifyCount = 0.obs;
  RxInt isModerator = 0.obs;

  /// Verification/subscription state, kept separate from [isModerator].
  RxInt isSubscriptionActive = 0.obs;

  SessionManager() {
    listenNotifyCount();
    listenModerator();
    listenSubscription();
  }

  void setAuthToken(Token? token) {
    storage.write(SessionKeys.authToken, token);
  }

  String getAuthToken() {
    return getToken()?.authToken ?? 'AUTH TOKEN EMPTY';
  }

  /// SECURITY (S3): stored in the platform keystore, never in GetStorage.
  Future<void> setPassword(String? password) async {
    if (password == null || password.isEmpty) {
      await _secureStorage.delete(key: SessionKeys.password);
      return;
    }
    await _secureStorage.write(key: SessionKeys.password, value: password);
    // Purge any value left behind by older app versions.
    storage.remove(SessionKeys.password);
  }

  Future<String?> getPassword() async {
    final secure = await _secureStorage.read(key: SessionKeys.password);
    if (secure != null) return secure;

    // One-time migration from the legacy plaintext location.
    final legacy = storage.read(SessionKeys.password);
    if (legacy is String && legacy.isNotEmpty) {
      await setPassword(legacy);
      return legacy;
    }
    return null;
  }

  Token? getToken() {
    var token = storage.read(SessionKeys.authToken);
    if (token is Token?) {
      return token;
    } else {
      return Token.fromJson(token);
    }
  }

  void setNotifyCount(int count) {
    int oldCount = getNotifyCount;
    oldCount += count;
    storage.write(SessionKeys.notifyCount, oldCount);
  }

  int get getNotifyCount {
    return storage.read(SessionKeys.notifyCount) ?? 0;
  }

  void listenNotifyCount() {
    notifyCount.value = getNotifyCount;
    storage.listenKey(SessionKeys.notifyCount, (value) {
      notifyCount.value = value;
    });
  }

  void listenModerator() {
    isModerator.value = getUser()?.isModerator ?? 0;
    storage.listenKey(SessionKeys.user, (value) {
      User? user = value as User?;
      isModerator.value = user?.isModerator ?? 0;
    });
  }

  /// QA FIX: this used to write the *isModerator* observable from the user's
  /// *isVerify* flag while [listenModerator] was already listening on the same
  /// storage key — the two listeners raced and whichever fired last won, so a
  /// verified user could be reported as a moderator. Subscription state now has
  /// its own observable and never clobbers the moderator flag.
  void listenSubscription() {
    isSubscriptionActive.value = getUser()?.isVerify ?? 0;
    storage.listenKey(SessionKeys.user, (value) {
      User? user = value as User?;
      isSubscriptionActive.value = user?.isVerify ?? 0;
    });
  }

  void setUser(User? user) {
    if (user != null) {
      // Convert the object to a JSON map and set 'stories' to null
      Map<String, dynamic> json = user.toJson();
      json['stories'] = null;

      // Re-create the User object from the modified JSON map
      User newUser = User.fromJson(json);

      // Log the updated user object and store it
      // Loggers.success(user.toJson());
      storage.write(SessionKeys.user, newUser);
    }
  }

  User? getUser() {
    var user = storage.read(SessionKeys.user);

    if (user == null || user is User?) {
      return user;
    } else if (user is Map<String, dynamic>) {
      return User.fromJson(user);
    } else {
      return null;
    }
  }

  int getUserID() {
    return (getUser()?.id ?? 0).toInt();
  }

  String getCurrency() {
    return getSettings()?.currency ?? AppRes.currency;
  }

  void setSettings(Setting settings) {
    storage.write(SessionKeys.setting, settings.toJson());
  }

  Setting? getSettings() {
    var data = storage.read(SessionKeys.setting);
    if (data is Map<String, dynamic>) {
      return Setting.fromJson(data);
    } else if (data is Setting) {
      return data;
    }
    return null;
  }

  void setLang(String langCode) {
    storage.write(SessionKeys.lang, langCode);
    if (isLogin()) {
      UserService.instance.updateUserDetails(appLanguage: langCode);
    }
  }

  String getLang() {
    return storage.read(SessionKeys.lang) ?? getFallbackLang();
  }

  void setFallbackLang(String langCode) {
    storage.write(SessionKeys.fallbackLang, langCode);
  }

  String getFallbackLang() {
    return storage.read(SessionKeys.fallbackLang) ?? 'ar';
  }

  DateTime? getLastMessageReadDate({required String spaceId}) {
    var date = storage.read(spaceId);
    if (date is DateTime) {
      return date;
    } else {
      return null;
    }
  }

  void setLastMessageReadDate({required String spaceId}) {
    storage.write(spaceId, DateTime.now());
  }

  bool isLogin() {
    return storage.read(SessionKeys.isLogin) ?? false;
  }

  void setLogin(bool isLog) {
    storage.write(SessionKeys.isLogin, true);
  }

  bool get shouldOpenEULASheet {
    return storage.read(SessionKeys.shouldOpenEULA) ?? true;
  }

  Future<void> setOpenEulaSheet(bool isLog) async {
    await storage.write(SessionKeys.shouldOpenEULA, isLog);
  }

  Future<void> setBool(String key, bool value) async {
    await storage.write(key, value);
  }

  bool getBool(String key) {
    return storage.read(key) ?? false;
  }

  bool get isDarkMode => storage.read(SessionKeys.darkMode) ?? false;

  Future<void> setDarkMode(bool value) async {
    await storage.write(SessionKeys.darkMode, value);
  }

  void clear() {
    storage.erase();
  }

  void clearSomeKey() {
    storage.remove(SessionKeys.isLogin);
    storage.remove(SessionKeys.user);
    storage.remove(SessionKeys.authToken);
    storage.remove(SessionKeys.password);
    storage.remove(SessionKeys.notifyCount);
    storage.remove(SessionKeys.fallbackLang);
    storage.remove(SessionKeys.lang);
    _secureStorage.delete(key: SessionKeys.password);
  }
}

class SessionKeys {
  static const isLogin = "login";
  static const shouldOpenEULA = "should_open_eula";
  static const fallbackLang = "fallback_lang";
  static const lang = "lang";
  static const setting = "setting";
  static const user = "user";
  static const authToken = "authToken";
  static const password = "password";
  static const notifyCount = "notify_count";
  static const isLanguageScreenSelect = "is_language_screen_select";
  static const isOnBoardingScreenSelect = "is_on_boarding_screen_select";
  static const darkMode = "dark_mode";
}
