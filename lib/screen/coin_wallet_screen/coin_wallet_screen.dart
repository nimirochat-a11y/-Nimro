import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/coin_wallet_screen/coin_wallet_screen_controller.dart';
import 'package:nimiro/screen/coin_wallet_screen/widget/coin_wallet_list.dart';
import 'package:nimiro/screen/coin_wallet_screen/widget/coin_wallet_top_view.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

class CoinWalletScreen extends StatelessWidget {
  const CoinWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CoinWalletScreenController());
    return Scaffold(
      backgroundColor: whitePure(context),
      body: Column(
        children: [
          const CoinWalletTopView(),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(LKey.coinShop.tr,
                    style: TextStyleCustom.unboundedMedium500(
                      color: textDarkGrey(context),
                      fontSize: 16,
                    )),
                const SizedBox(height: 2),
                Text(LKey.rechargeWallet.tr,
                    style: TextStyleCustom.outFitLight300(
                        color: textLightGrey(context), fontSize: 11)),
              ],
            ),
          ),
          CoinWalletList(controller: controller),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF14101F),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ColorRes.themeAccentSolid.withValues(alpha: .2),
                    ),
                    alignment: Alignment.center,
                    child: Image.asset(AssetRes.icGift,
                        width: 24, height: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Support your favorite creators'.tr,
                            style: TextStyleCustom.unboundedMedium500(
                                color: Colors.white, fontSize: 14)),
                        const SizedBox(height: 3),
                        Text('Every coin makes a difference'.tr,
                            style: TextStyleCustom.outFitLight300(
                                color: Colors.white.withValues(alpha: .65),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: Colors.white.withValues(alpha: .6)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 14, color: textLightGrey(context)),
                const SizedBox(width: 6),
                Text('Safe and fast transactions'.tr,
                    style: TextStyleCustom.outFitLight300(
                        color: textLightGrey(context), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
