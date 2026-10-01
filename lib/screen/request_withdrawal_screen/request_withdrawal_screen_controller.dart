import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/controller/base_controller.dart';
import 'package:nimiro/common/manager/session_manager.dart';
import 'package:nimiro/common/service/api/gift_wallet_service.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/model/general/status_model.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/utilities/currency_by_country.dart';

class RequestWithdrawalScreenController extends BaseController {
  Rx<Setting?> settings = Rx<Setting?>(null);
  Rx<User?> myUser = Rx<User?>(null);

  RxString selectedGateway = ''.obs;
  TextEditingController amountController = TextEditingController();
  Rx<TextEditingController> estimatedAmountController =
      Rx(TextEditingController(text: '0'));
  TextEditingController accountDetailsController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    _fetchLocalData();
  }

  void _fetchLocalData() {
    settings.value = SessionManager.instance.getSettings();
    myUser.value = SessionManager.instance.getUser();
  }

  String? get userCountryCode {
    final c = myUser.value?.countryCode;
    if (c != null && c.trim().isNotEmpty) return c.trim();
    final d = Get.deviceLocale?.countryCode;
    if (d != null && d.trim().isNotEmpty) return d.trim();
    return null;
  }

  String get localCurrencyCode {
    final code = CurrencyByCountry.codeFor(userCountryCode);
    if (code == 'USD') return 'USD';
    return settings.value?.exchangeRates?[code] == null ? 'USD' : code;
  }

  double get localRate {
    final code = localCurrencyCode;
    if (code == 'USD') return 1;
    return settings.value?.exchangeRates?[code] ?? 1;
  }

  String get localFlag {
    final cc = (localCurrencyCode == 'USD' ? 'US' : (userCountryCode ?? 'US'))
        .toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(cc)) return '';
    return String.fromCharCodes(cc.codeUnits.map((c) => 0x1F1E6 + c - 65));
  }

  String formatLocal(double usd) {
    final v = usd * localRate;
    return v.toStringAsFixed(v < 10 ? 2 : 0);
  }

  int get coinsPerUsd {
    final v = settings.value?.coinValue ?? 0;
    return v > 0 ? (1 / v).round() : 0;
  }

  void onChanged(String value) {
    if (value.isEmpty) {
      estimatedAmountController.value.text = '0';
      return;
    }

    int maxAllowedCoins =
        myUser.value?.coinWallet?.toInt() ?? 0; // Dynamic max value
    int inputValue = int.tryParse(value) ?? 0;

    if (inputValue > maxAllowedCoins) {
      showSnackBar(LKey.youCanNotEnterMoreThanEtc
          .trParams({'coin': maxAllowedCoins.toString()}));
      amountController.text =
          maxAllowedCoins.toString(); // Set max value dynamically
      amountController.selection = TextSelection.fromPosition(
        TextPosition(offset: amountController.text.length),
      );
    } else {
      estimatedAmountController.value.text =
          formatLocal((settings.value?.coinValue?.toDouble() ?? 0) * inputValue);
    }
  }

  void onSubmit() async {
    if ((settings.value?.redeemGateways ?? []).isEmpty) {
      return showSnackBar(LKey.redeemGatewayNotFound.tr);
    }
    int amount = amountController.text.trim().isEmpty
        ? 0
        : int.parse(amountController.text.trim());

    if (amount <= (settings.value?.minRedeemCoins ?? 0)) {
      return showSnackBar(LKey.redeemMinCoinDescription.tr);
    }

    showLoader();

    StatusModel model = await GiftWalletService.instance
        .submitWithdrawalRequest(
            coins: amountController.text.trim(),
            gateway: selectedGateway.value,
            account: accountDetailsController.text.trim());

    stopLoader();
    if (model.status == true) {
      Get.back();
    }
    myUser.value?.coinWallet = (myUser.value?.coinWallet ?? 0) -
        int.parse(amountController.text.trim());
    SessionManager.instance.setUser(myUser.value);
    showSnackBar(model.message);
  }
}
