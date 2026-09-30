import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/common_extension.dart';
import 'package:nimiro/common/widget/custom_back_button.dart';
import 'package:nimiro/common/widget/custom_popup_menu_button.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/user_model/user_model.dart';
import 'package:nimiro/screen/coin_wallet_screen/coin_wallet_screen_controller.dart';
import 'package:nimiro/screen/request_withdrawal_screen/request_withdrawal_screen.dart';
import 'package:nimiro/screen/withdrawals_screen/withdrawals_screen.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';

class CoinWalletTopView extends StatelessWidget {
  const CoinWalletTopView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CoinWalletScreenController>();
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0A10), Color(0xFF1A0F2E), Color(0xFF2B1650)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomBackButton(color: Colors.white, width: 35),
                  Text(
                    LKey.coinShop.tr,
                    style: TextStyleCustom.unboundedMedium500(
                        color: Colors.white),
                  ),
                  Visibility(
                    visible: controller.settings?.isWithdrawalOn == 1,
                    replacement: const SizedBox(width: 35),
                    child: CustomPopupMenuButton(
                      items: [
                        MenuItem(LKey.withdrawals.tr, () {
                          Get.to(() => const WithdrawalsScreen());
                        }),
                        MenuItem(LKey.requestWithdrawal.tr, () {
                          Get.to(() => const RequestWithdrawalScreen())
                              ?.then((value) {
                            controller.fetchData();
                          });
                        }),
                      ],
                      child: Container(
                        height: 35,
                        width: 35,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Image.asset(AssetRes.icWallet,
                              color: Colors.white, width: 18, height: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(child: _Balance(controller: controller)),
                  const SizedBox(width: 8),
                  const _CoinArt(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  final CoinWalletScreenController controller;
  const _Balance({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your current balance'.tr,
          style: TextStyleCustom.outFitLight300(
              color: Colors.white.withValues(alpha: .7), fontSize: 14),
        ),
        const SizedBox(height: 6),
        Obx(() {
          User? user = controller.myUser.value;
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              (user?.coinWallet?.toInt() ?? 0).numberFormat,
              style: TextStyleCustom.unboundedExtraBold800(
                  color: Colors.white, fontSize: 44),
            ),
          );
        }),
        const SizedBox(height: 4),
        Row(
          children: [
            Image.asset(AssetRes.icCoin, width: 18, height: 18),
            const SizedBox(width: 6),
            Text(
              LKey.coins.tr,
              style: TextStyleCustom.outFitRegular400(
                  color: Colors.white.withValues(alpha: .85), fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Obx(() {
          User? user = controller.myUser.value;
          final approx =
              controller.approxUsdFor(user?.coinWallet?.toInt() ?? 0);
          if (approx == null) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: .16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.savings_outlined,
                    color: Colors.white.withValues(alpha: .75), size: 15),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '\u2248 $approx',
                    style: TextStyleCustom.outFitRegular400(
                        color: Colors.white.withValues(alpha: .9),
                        fontSize: 13),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_left,
                    color: Colors.white.withValues(alpha: .6), size: 16),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _CoinArt extends StatelessWidget {
  const _CoinArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFB84D).withValues(alpha: .28),
                  const Color(0xFFFFB84D).withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            child: Container(
              width: 112,
              height: 28,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.all(Radius.elliptical(56, 14)),
                gradient: const LinearGradient(
                  colors: [Color(0xFF7A45E0), Color(0xFF2B1650)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9B5CFF).withValues(alpha: .45),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 10,
            child: Image.asset(AssetRes.icCoin, width: 96, height: 96),
          ),
          Positioned(
            top: 6,
            right: 2,
            child: Transform.rotate(
              angle: .5,
              child: Image.asset(AssetRes.icCoin, width: 26, height: 26),
            ),
          ),
          Positioned(
            top: 62,
            left: 0,
            child: Transform.rotate(
              angle: -.5,
              child: Image.asset(AssetRes.icCoin, width: 22, height: 22),
            ),
          ),
        ],
      ),
    );
  }
}
