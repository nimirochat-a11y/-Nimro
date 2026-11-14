import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:nimiro/utilities/const_res.dart';

bool isPurchaseConfig = false;
RxBool isSubscribe = false.obs;

/// RevenueCat public keys look like `goog_...`, `appl_...`, `amzn_...` or
/// `test_...`. The project ships placeholder keys (for example `______`);
/// configuring the SDK with one of those produces `InvalidCredentialsError`
/// on every login, so placeholders must be treated as "not configured".
bool _hasValidRevenueCatKey(String key) {
  final value = key.trim();
  if (value.isEmpty) return false;
  return RegExp(r'^(?:goog|appl|amzn|test)_[A-Za-z0-9_-]+$').hasMatch(value);
}

class SubscriptionManager {
  static var shared = SubscriptionManager();
  List<Package> packages = [];
  List<Package> offering = [];

  /// True only when a real RevenueCat public key is configured for the
  /// current platform. When false the SDK is never configured or called, so
  /// the app keeps working (coin catalogue + ads) without credential errors.
  bool get isEnabled {
    if (Platform.isAndroid) {
      return _hasValidRevenueCatKey(revenueCatAndroidApiKey);
    }
    if (Platform.isIOS) {
      return _hasValidRevenueCatKey(revenueCatAppleApiKey);
    }
    return false;
  }

  /// True once the SDK is configured and safe to call.
  bool get isConfigured => isPurchaseConfig && isEnabled;

  Future<void> initPlatformState() async {
    if (!isEnabled) {
      isPurchaseConfig = false;
      isSubscribe.value = false;
      log('RevenueCat disabled: no valid API key configured for this platform.');
      return;
    }

    final String apiKey =
        Platform.isAndroid ? revenueCatAndroidApiKey : revenueCatAppleApiKey;
    final PurchasesConfiguration configuration =
        PurchasesConfiguration(apiKey);
    Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(configuration);

    await checkIsConfigured();
    await fetchOfferings();
  }

  bool checkSubscription(CustomerInfo customerInfo) {
    if (customerInfo.latestExpirationDate == null ||
        customerInfo.latestExpirationDate!.isEmpty) {
      isSubscribe.value = false;
    } else {
      DateTime dt1 =
          DateTime.parse(customerInfo.latestExpirationDate ?? '').toLocal();
      DateTime dt2 = DateTime.now();

      int leftSecond = dt1.difference(dt2).inSeconds;
      log('⏱️ Expire Time : $dt1 == Current Time : $dt2 || Time Left: ${leftSecond > 0 ? leftSecond : 0} seconds');

      if (dt1.compareTo(dt2) < 0) {
        isSubscribe.value = false;
      }
      if (dt1.compareTo(dt2) > 0) {
        isSubscribe.value = true;
      }
    }

    log('🔔 Subscription Status : ${isSubscribe.value ? 'Active' : 'InActive'}');
    return isSubscribe.value;
  }

  Future<void> subscriptionListener() async {
    if (!isConfigured) return;

    try {
      Purchases.addCustomerInfoUpdateListener((customerInfo) async {
        checkSubscription(customerInfo);
      });
    } on PlatformException catch (e) {
      // Error fetching purchaser info
      log('RevenueCat Error : ${e.message.toString()}');
    }
  }

  Future<void> checkIsConfigured() async {
    if (!isEnabled) {
      isPurchaseConfig = false;
      return;
    }

    try {
      isPurchaseConfig = await Purchases.isConfigured;
    } on PlatformException catch (e) {
      isPurchaseConfig = false;
      log('RevenueCat isConfigured error: ${e.message}');
    }
    log('isPurchaseConfig  :$isPurchaseConfig');
  }

  Future<LogInResult?> login(String appUserID) async {
    if (!isConfigured) {
      log('RevenueCat login skipped: SDK is not configured.');
      return null;
    }

    try {
      return await Purchases.logIn(appUserID);
    } on PlatformException catch (e) {
      log('RevenueCat login error: ${e.message}');
      return null;
    }
  }

  Future<(Offering?, String?)> fetchOfferings() async {
    if (!isConfigured) return (null, null);

    try {
      Offerings offerings = await Purchases.getOfferings();
      // Display current offering with offerings.current
      offering.addAll(offerings.current?.availablePackages
              .where((element) => element.packageType == PackageType.custom) ??
          []);

      packages.addAll(offerings.current?.availablePackages
              .where((element) => element.packageType != PackageType.custom) ??
          []);
      packages
          .sort((a, b) => b.storeProduct.price.compareTo(a.storeProduct.price));

      return (offerings.current, null);
    } on PlatformException catch (e) {
      // Error restoring purchases
      log('Fetch Offering : ${e.message.toString()}');
      return (null, e.message);
    }
  }

  Future<bool?> checkSubscriptionStatus() async {
    if (!isConfigured) return null;

    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return checkSubscription(customerInfo);
    } on PlatformException catch (e) {
      log(e.message.toString());
      // Error fetching purchaser info
    }
    return null;
  }

  Future<bool?> makePurchase(Package package) async {
    if (!isConfigured) return null;

    try {
      CustomerInfo customerInfo =
          (await Purchases.purchase(PurchaseParams.storeProduct(package.storeProduct))).customerInfo;
      return checkSubscription(customerInfo);
    } on PlatformException catch (e) {
      log("makePurchase $e");

      return null;
    }
  }

  Future<CustomerInfo?> makePurchaseCustom(Package package) async {
    if (!isConfigured) return null;

    try {
      CustomerInfo info = (await Purchases.purchase(PurchaseParams.storeProduct(package.storeProduct))).customerInfo;
      return info;
    } on PlatformException catch (e) {
      log("makePurchaseCustom: ${e.message}");
      return null;
    }
  }

  Future<bool?> restorePurchase() async {
    if (!isConfigured) return null;

    try {
      CustomerInfo restoredInfo = await Purchases.restorePurchases();
      return checkSubscription(restoredInfo);
      // ... check restored customerInfo to see if entitlement is now active
    } on PlatformException catch (e) {
      log(e.toString());
      return null;
      // Error restoring purchases
    }
  }
}
