import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/functions/debounce_action.dart';
import 'package:nimiro/common/manager/firebase_notification_manager.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/api/common_service.dart';
import 'package:nimiro/common/service/api/notification_service.dart';
import 'package:nimiro/common/service/api/user_service.dart';
import 'package:nimiro/common/service/supabase/supabase_service.dart';
import 'package:nimiro/common/service/subscription/subscription_manager.dart';
import 'package:nimiro/languages/dynamic_translations.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/model/user_model/user_model.dart' as user;
import 'package:nimiro/screen/dashboard_screen/dashboard_screen.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AuthScreenController extends BaseController {
  TextEditingController fullNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController forgetEmailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPassController = TextEditingController();

  @override
  void onInit() {
    CommonService.instance.fetchGlobalSettings();
    FirebaseNotificationManager.instance;
    super.onInit();
  }

  bool _isLoggingIn = false;

  Future<void> onLogin() async {
    if (_isLoggingIn) return;
    _isLoggingIn = true;
    try {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty) {
      return showSnackBar(LKey.enterEmail.tr);
    }
    if (password.isEmpty) {
      return showSnackBar(LKey.enterAPassword.tr);
    }

    showLoader();

    if (GetUtils.isEmail(email)) {
      final UserCredential? credential = await signInWithEmailAndPassword();

      if (credential == null) {
        stopLoader();
        return showSnackBar(LKey.userNotFound.tr);
      }

      if (credential.user?.emailVerified == false) {
        stopLoader();
        return showSnackBar(LKey.verifyEmailFirst.tr);
      }

      String fullname = credential.user?.displayName ?? email.split('@')[0];
      final firebaseIdToken = await credential.user?.getIdToken();
      final user.User? data = await _registration(
          identity: email,
          loginMethod: LoginMethod.email,
          fullname: fullname,
          loginVia: LoginVia.loginInUser,
          idToken: firebaseIdToken);
      stopLoader();

      if (data != null) {
        _navigateScreen(data);
      }
    } else {
      stopLoader();
      return showSnackBar(LKey.invalidEmail.tr);
    }
  } finally {
      _isLoggingIn = false;
    }
  }

  Future<void> onCreateAccount() async {
    if (fullNameController.text.trim().isEmpty) {
      return showSnackBar(LKey.fullNameEmpty.tr);
    }
    if (emailController.text.trim().isEmpty) {
      return showSnackBar(LKey.enterEmail.tr);
    }
    if (passwordController.text.trim().isEmpty) {
      return showSnackBar(LKey.enterAPassword.tr);
    }
    if (confirmPassController.text.trim().isEmpty) {
      return showSnackBar(LKey.confirmPasswordEmpty.tr);
    }
    if (!GetUtils.isEmail(emailController.text.trim())) {
      return showSnackBar(LKey.invalidEmail.tr);
    }
    if (passwordController.text.trim() != confirmPassController.text.trim()) {
      return showSnackBar(LKey.passwordMismatch.tr);
    }
    showLoader();
    UserCredential? credential = await createUserWithEmailAndPassword();
    if (credential != null) {
      final firebaseIdToken = await credential.user?.getIdToken();
      await _registration(
          identity: emailController.text.trim(),
          loginMethod: LoginMethod.email,
          fullname: fullNameController.text.trim(),
          loginVia: LoginVia.loginInUser,
          idToken: firebaseIdToken);
      credential.user?.updateDisplayName(fullNameController.text.trim());
      credential.user?.sendEmailVerification();
      Get.back();
      Get.back();
      showSnackBar(LKey.verificationLinkSent.tr);
    }
  }

  static const String _accountKey = 'nimiro_fcm_account';

  void onGoogleTap() async {
    if (_isLoggingIn) return;
    _isLoggingIn = true;
    showLoader();
    try {
      final profile = await SupabaseService.instance
          .signInWithOAuth(supabase.OAuthProvider.google);
      final user.User? data = await _registration(
        identity: profile.email,
        loginMethod: LoginMethod.google,
        fullname: profile.name.isNotEmpty ? profile.name : profile.email.split('@')[0],
        loginVia: LoginVia.loginInUser,
        idToken: profile.accessToken,
        deviceTokenOverride: 'supabase:${profile.id}',
      );
      stopLoader();
      if (data != null) _navigateScreen(data);
    } catch (e) {
      Loggers.error('Google OAuth failed: $e');
      stopLoader();
      showSnackBar('خطأ تسجيل الدخول: $e');
    } finally {
      _isLoggingIn = false;
    }
  }

  void onAppleTap() async {
    showLoader();
    try {
      final profile = await SupabaseService.instance
          .signInWithOAuth(supabase.OAuthProvider.apple);
      final user.User? data = await _registration(
        identity: profile.email,
        loginMethod: LoginMethod.apple,
        fullname: profile.name.isNotEmpty ? profile.name : profile.email.split('@')[0],
        loginVia: LoginVia.loginInUser,
        idToken: profile.accessToken,
        deviceTokenOverride: 'supabase:${profile.id}',
      );
      stopLoader();
      if (data != null) _navigateScreen(data);
    } catch (e) {
      Loggers.error(e);
      stopLoader();
      showSnackBar('Apple sign-in could not be completed');
    }
  }

  Future<user.User?> _registration(
      {required String identity,
      required LoginMethod loginMethod,
      String? fullname,
      required LoginVia loginVia,
      String? idToken,
      String? deviceTokenOverride}) async {
    String? deviceToken = deviceTokenOverride ??
        await FirebaseNotificationManager.instance.getNotificationToken();
    // FIX(v13): the FCM token must survive a re-login. The plugin can return
    // null (Play Services not ready yet, permission not yet granted, first
    // launch) even when the device ALREADY has a valid token cached from an
    // earlier session. Falling back to 'nimiro:<identity>' in that case is what
    // left rows in `device_token` holding a value Firebase answers with 400
    // INVALID_ARGUMENT, so no push could ever reach the device. When this
    // account already registered a real token, reuse it instead of
    // overwriting it with the synthetic placeholder. The placeholder is now
    // only used for a genuinely first-ever login that has no token yet.
    if ((deviceToken ?? '').isEmpty) {
      final stored = GetStorage().read<String>(_accountKey);
      if (stored != null && stored.isNotEmpty) {
        deviceToken = stored;
        Loggers.info('DeviceToken reused from storage for this account.');
      }
    } else {
      GetStorage().write(_accountKey, deviceToken);
    }
    deviceToken ??= 'nimiro:$identity';

    user.User? userData;
    switch (loginVia) {
      case LoginVia.loginInUser:
        userData = await UserService.instance.logInUser(
            identity: identity,
            loginMethod: loginMethod,
            deviceToken: deviceToken,
            fullName: fullname,
            idToken: idToken);
    }

    Setting? setting = SessionManager.instance.getSettings();
    if (userData?.isDummy == 0 && userData?.newRegister == true && setting?.registrationBonusStatus == 1) {
      _sendRegistrationBonusSafely(userData);
    }
    if (userData != null) {
      _loginToSubscriptionsSafely(userData.id);
      // Subscribe My Following Ids For Live streaming notification
      return userData;
    }
    return null;
  }

  Future<void> _loginToSubscriptionsSafely(int? userId) async {
    if (userId == null) return;
    try {
      await SubscriptionManager.shared.login('$userId');
    } catch (e) {
      Loggers.error('Subscription login skipped: $e');
    }
  }

  Future<void> _sendRegistrationBonusSafely(user.User? userData) async {
    if (userData == null) return;
    try {
      final translations = Get.find<DynamicTranslations>();
      final languageData = translations.keys[userData.appLanguage] ?? {};
      await NotificationService.instance
          .pushNotification(
            title: languageData[LKey.registrationBonusTitle] ?? LKey.registrationBonusTitle.tr,
            body: languageData[LKey.registrationBonusDescription] ?? LKey.registrationBonusDescription.tr,
            type: NotificationType.other,
            deviceType: userData.device,
            toUserId: userData.id?.toString(),
            authorizationToken: userData.token?.authToken,
          )
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      Loggers.error('Registration bonus notification skipped: $e');
    }
  }

  Future<UserCredential?> createUserWithEmailAndPassword() async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      SessionManager.instance.setPassword(passwordController.text.trim());
      return credential;
    } on FirebaseAuthException catch (e) {
      stopLoader();
      Loggers.error(e.message);
      if (e.code == 'weak-password') {
        showSnackBar(LKey.weakPassword.tr);
      } else if (e.code == 'email-already-in-use') {
        showSnackBar(LKey.accountExists.tr);
      } else {
        showSnackBar(e.message);
      }
      return null;
    }
  }

  Future<UserCredential?> signInWithEmailAndPassword() async {
    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      return credential;
    } on FirebaseAuthException catch (e) {
      stopLoader();
      if (e.code == 'user-not-found') {
        showSnackBar(LKey.noUserFound.tr);
        Loggers.info(LKey.noUserFound.tr);
      } else if (e.code == 'wrong-password') {
        showSnackBar(LKey.incorrectPassword.tr);
        Loggers.info(LKey.incorrectPassword.tr);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(serverClientId: '28441059803-78ro06cusr82bc0d9ksf3eoo12rvhat1.apps.googleusercontent.com');
    GoogleSignInAccount account = await googleSignIn.authenticate();

    // Create a new credential
    final credential = GoogleAuthProvider.credential(idToken: account.authentication.idToken);

    // Once signed in, return the UserCredential
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithApple() async {
    // Request credential for the currently signed in Apple account.
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );

    // Create an `OAuthCredential` from the credential returned by Apple.
    final oauthCredential = OAuthProvider("apple.com")
        .credential(idToken: appleCredential.identityToken, accessToken: appleCredential.authorizationCode);

    return await FirebaseAuth.instance.signInWithCredential(oauthCredential);
  }

  void forgetPassword() async {
    final email = forgetEmailController.text.trim();
    if (email.isEmpty) {
      showSnackBar(LKey.enterEmail.tr);
      return;
    }
    showLoader();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      stopLoader();
      Get.back(); // Close the BottomSheet
      showSnackBar(LKey.resetPasswordLinkSent.tr);
    } on FirebaseAuthException catch (e) {
      stopLoader();
      showSnackBar(e.message ?? "An error occurred. Please try again.");
    }
  }

  void _navigateScreen(user.User? data) {
    DebounceAction.shared.call(() async {
      SessionManager.instance.setLogin(true);
      SessionManager.instance.setUser(data);
      Get.offAll(() => DashboardScreen(myUser: data));
    }, milliseconds: 250);
  }
}

enum LoginVia { loginInUser }
