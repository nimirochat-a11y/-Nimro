import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
      // SECURITY (S1): hand the backend a verifiable Firebase ID token.
      final String? idToken = await credential.user?.getIdToken();
      final user.User? data = await _registration(
          identity: email,
          loginMethod: LoginMethod.email,
          fullname: fullname,
          loginVia: LoginVia.loginInUser,
          idToken: idToken);
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
      // SECURITY (S1): a fresh account also gets a verifiable ID token.
      final String? idToken = await credential.user?.getIdToken();
      await _registration(
          identity: emailController.text.trim(),
          loginMethod: LoginMethod.email,
          fullname: fullNameController.text.trim(),
          loginVia: LoginVia.loginInUser,
          idToken: idToken);
      credential.user?.updateDisplayName(fullNameController.text.trim());
      credential.user?.sendEmailVerification();
      Get.back();
      Get.back();
      showSnackBar(LKey.verificationLinkSent.tr);
    }
  }

  void onGoogleTap() async {
    if (_isLoggingIn) return;
    _isLoggingIn = true;
    showLoader();
    try {
      final profile = await SupabaseService.instance
          .signInWithOAuth(supabase.OAuthProvider.google);
      // SECURITY (S1): Supabase access token proves the Google identity.
      final user.User? data = await _registration(
        identity: profile.email,
        loginMethod: LoginMethod.google,
        fullname: profile.name.isNotEmpty ? profile.name : profile.email.split('@')[0],
        loginVia: LoginVia.loginInUser,
        // FIX(v12): never short-circuit the FCM token with a Supabase id.
        // Storing 'supabase:<uuid>' in device_token made the backend's push
        // call fail with FCM 400 INVALID_ARGUMENT, so no notification ever
        // reached the device. Fall through to the real FCM token.
        idToken: SupabaseService.instance.client.auth.currentSession?.accessToken,
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
      // SECURITY (S1): Supabase access token proves the Apple identity.
      final user.User? data = await _registration(
        identity: profile.email,
        loginMethod: LoginMethod.apple,
        fullname: profile.name.isNotEmpty ? profile.name : profile.email.split('@')[0],
        loginVia: LoginVia.loginInUser,
        // FIX(v12): never short-circuit the FCM token with a Supabase id.
        // Storing 'supabase:<uuid>' in device_token made the backend's push
        // call fail with FCM 400 INVALID_ARGUMENT, so no notification ever
        // reached the device. Fall through to the real FCM token.
        idToken: SupabaseService.instance.client.auth.currentSession?.accessToken,
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
      String? deviceTokenOverride,
      String? idToken}) async {
    String? deviceToken = deviceTokenOverride ??
        await FirebaseNotificationManager.instance.getNotificationToken();
    // FIX(v12): a Supabase/Vendor id is NOT a push target. Only fall back to
    // the synthetic value when no real FCM token exists at all, so the row is
    // still identifiable - but the backend's push attempt is skipped by shape.
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
            token: userData.deviceToken,
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
      // SECURITY (S3): goes to the platform keystore, not GetStorage.
      await SessionManager.instance.setPassword(passwordController.text.trim());
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
