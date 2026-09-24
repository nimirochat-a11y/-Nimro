import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/coin_wallet_screen/coin_wallet_screen_controller.dart';
import 'package:nimiro/screen/coin_wallet_screen/widget/coin_wallet_list.dart';
import 'package:nimiro/screen/coin_wallet_screen/widget/coin_wallet_top_view.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class CoinWalletScreen extends StatelessWidget {
  const CoinWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CoinWalletScreenController());
    return Scaffold(
      body: Column(
        children: [
          const CoinWalletTopView(),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Text(LKey.rechargeWallet.tr,
                style: TextStyleCustom.outFitLight300(
                    color: textLightGrey(context), fontSize: 16),
                textAlign: TextAlign.center),
          ),
          CoinWalletList(controller: controller)
        ],
      ),
    );
  }
}
