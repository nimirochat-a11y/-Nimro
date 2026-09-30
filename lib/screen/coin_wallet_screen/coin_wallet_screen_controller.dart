
import 'package:get/get.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/manager/logger.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/api/gift_wallet_service.dart';
import 'package:nimiro/common/service/api/user_service.dart';
import 'package:nimiro/common/service/subscription/subscription_manager.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/utilities/currency_by_country.dart';

class CoinWalletScreenController extends BaseController {
  Rx<User?> myUser = Rx<User?>(null);
  RxList<Package> offerings = <Package>[].obs;

  Setting? get settings => SessionManager.instance.getSettings();
  RxList<CoinPlan> coinPlans = <CoinPlan>[].obs;

  /// True once the store catalogue has been resolved (successfully or not), so
  /// the screen can tell "still loading" apart from "nothing to show".
  RxBool isLoadingPlans = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchData();
    fetchOfferings();
  }

  void fetchData() async {
    myUser.value = SessionManager.instance.getUser();
    final freshUser =
        await UserService.instance.fetchUserDetails(userId: myUser.value?.id);
    if (freshUser != null) {
      myUser.value = freshUser;
      SessionManager.instance.setUser(freshUser);
    }
  }

  /// Build the purchasable coin list.
  ///
  /// FIX(v14): the previous implementation ONLY listed a package when its
  /// `playstore_product_id` / `appstore_product_id` matched an identifier in
  /// the RevenueCat offering. Two things made that render an EMPTY store even
  /// though the backend served the packages fine:
  ///
  ///  1. The revenueCat API key in `const_res.dart` is a `____` placeholder and
  ///     no store product is configured, so `SubscriptionManager.shared.offering`
  ///     is always empty on a fresh release build. The intersection was
  ///     therefore always empty.
  ///  2. The dashboard's coin rows carry placeholder store ids (`ggg`, `tester`)
  ///     that can never match a real store product.
  ///
  /// The server catalogue is now the source of truth: every active package is
  /// shown. When a matching store product IS available its localized store
  /// price string is used; otherwise the admin price from `coin_plan_price` is
  /// used so the row is still readable and purchasable through the backend.
  void fetchOfferings() {
    final List<Package> items = SubscriptionManager.shared.offering;
    offerings.clear();
    offerings.addAll(items);
    coinPlans.clear();

    final packages = settings?.coinPackages ?? [];
    if (packages.isEmpty) {
      isLoadingPlans.value = false;
      Loggers.info('CoinWallet: server returned no coin packages.');
      return;
    }

    for (final data in packages) {
      if (data.status != 1) continue;

      // Prefer a real store product when one is configured and matched.
      Package? matched;
      for (final element in items) {
        if ([data.appstoreProductId, data.playStoreProductId]
            .contains(element.storeProduct.identifier)) {
          matched = element;
          break;
        }
      }

      final int usdPrice = (data.coinPlanPrice ?? 0).round();
      final String fallbackPrice =
          usdPrice > 0 ? formatLocalPrice(usdPrice) : '';

      coinPlans.add(CoinPlan(
        data.coinAmount ?? 0,
        data.id ?? -1,
        matched?.storeProduct.identifier ??
            (data.playStoreProductId ?? data.appstoreProductId ?? ''),
        matched?.storeProduct.priceString ?? fallbackPrice,
        image: data.image,
        isStoreBacked: matched != null,
      ));
    }

    isLoadingPlans.value = false;
    Loggers.info(
        'CoinWallet: ${coinPlans.length} plan(s) rendered out of ${packages.length} served.');
  }

  /// Approximate USD value of [coins] using the admin-configured
  /// `coin_value` (price per single coin) from server settings. This is the
  /// single source of truth the dashboard exposes for coin pricing, so the
  /// estimate updates automatically the moment an admin changes it there -
  /// no app update needed. Returns null when the server hasn't set a
  /// positive coin value, so the caller can hide the estimate instead of
  /// showing a misleading number.
  String? approxUsdFor(int coins) {
    if (coins <= 0) return null;
    final perCoin = settings?.coinValue ?? 0;
    if (perCoin <= 0) return null;
    final formatted = formatLocalPrice(coins * perCoin);
    if (formatted.startsWith(r'$')) {
      return '${formatted.substring(1)} USD';
    }
    return formatted;
  }

  /// Converts a USD admin price to the signed-in user's registration-country
  /// currency using the server-cached exchange rates, and formats it with
  /// that currency's symbol (e.g. "49 ج.م" for an Egyptian account). Falls
  /// back to a plain USD string when no rate is cached yet or the country is
  /// unmapped, so the price is always readable.
  String formatLocalPrice(num usdAmount) {
    final countryCode = userCountryCode;
    final code = CurrencyByCountry.codeFor(countryCode);
    final symbol = CurrencyByCountry.symbolFor(countryCode);
    if (code == 'USD') {
      return '\$${usdAmount.toStringAsFixed(usdAmount < 10 ? 2 : 0)}';
    }
    final rate = settings?.exchangeRates?[code];
    if (rate == null) {
      return '\$${usdAmount.toStringAsFixed(usdAmount < 10 ? 2 : 0)}';
    }
    final converted = usdAmount * rate;
    final display = converted.toStringAsFixed(converted < 10 ? 2 : 0);
    return '$display $symbol';
  }

  String? get userCountryCode {
    final c = myUser.value?.countryCode;
    if (c != null && c.trim().isNotEmpty) return c.trim();
    final d = Get.deviceLocale?.countryCode;
    if (d != null && d.trim().isNotEmpty) return d.trim();
    return null;
  }

  void onPurchase(CoinPlan offer) {
    if (!offer.isStoreBacked) {
      // No store product is wired to this package (placeholder store id, or a
      // release built without RevenueCat credentials). Say so instead of
      // throwing a StateError from firstWhere.
      showSnackBar(
          'This package is not linked to a store product yet. Please contact support.');
      return;
    }
    showLoader(barrierDismissible: false);
    Package package = offerings
        .firstWhere((element) => element.storeProduct.identifier == offer.id);
    SubscriptionManager.shared.makePurchaseCustom(package).then((value) async {
      if (value != null) {
        String isoTime = value.nonSubscriptionTransactions.last.purchaseDate;
        DateTime dt = DateTime.parse(isoTime);
        int millis = dt.millisecondsSinceEpoch;
        User? user = await GiftWalletService.instance
            .buyCoins(id: offer.coinPackageId, purchasedAt: millis.toString());
        stopLoader();
        if (user != null) {
          User? user = await UserService.instance
              .fetchUserDetails(userId: myUser.value?.id);
          if (user != null) {
            myUser.value = user;
            SessionManager.instance.setUser(myUser.value);
          }
        }
      } else {
        stopLoader();
      }
    });
  }

}

class CoinPlan {
  final int coin;
  final int coinPackageId;
  final String id;
  final String priceString;

  /// Server-side image for the package, when the dashboard set one.
  final String? image;

  /// True when a real store product backs this package, so the purchase flow
  /// can actually run. False means the row is display-only.
  final bool isStoreBacked;

  CoinPlan(this.coin, this.coinPackageId, this.id, this.priceString,
      {this.image, this.isStoreBacked = false});
}
