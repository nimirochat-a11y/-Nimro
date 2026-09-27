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
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

/// REDESIGN(v16): dark hero header matching the new coin-store mockup —
/// a black-to-purple gradient card with the balance front and center, a
/// pill showing the approximate USD value, and a decorative coin badge
/// instead of the old glass stats row.
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
          colors: [
            Color(0xFF0B0B12),
            Color(0xFF1B1030),
            Color(0xFF2E1750),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: Stack(
          children: [
            // Decorative glow.
            Positioned(
              right: -40,
              top: 20,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ColorRes.themeAccentSolid.withValues(alpha: .18),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    shape: BoxShape.circle),
                                child: Center(
                                    child: Image.asset(AssetRes.icWallet,
                                        color: Colors.white,
                                        width: 18,
                                        height: 18)),
                              )),
                        )
                      ],
                    ),
                    const SizedBox(height: 34),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LKey.balance.tr,
                                style: TextStyleCustom.outFitLight300(
                                    color: Colors.white.withValues(alpha: .65),
                                    fontSize: 14),
                              ),
                              const SizedBox(height: 6),
                              Obx(() {
                                User? user = controller.myUser.value;
                                return Text(
                                  (user?.coinWallet?.toInt() ?? 0)
                                      .numberFormat,
                                  style: TextStyleCustom.unboundedExtraBold800(
                                      color: Colors.white, fontSize: 40),
                                );
                              }),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Image.asset(AssetRes.icCoin,
                                      width: 16, height: 16),
                                  const SizedBox(width: 5),
                                  Text(
                                    LKey.coins.tr,
                                    style: TextStyleCustom.outFitRegular400(
                                        color:
                                            Colors.white.withValues(alpha: .8),
                                        fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Obx(() {
                                User? user = controller.myUser.value;
                                final approx = controller
                                    .approxUsdFor(user?.coinWallet?.toInt() ?? 0);
                                if (approx == null) return const SizedBox();
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: .14)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.account_balance_wallet_outlined,
                                          color:
                                              Colors.white.withValues(alpha: .7),
                                          size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        '\u2248 $approx USD',
                                        style: TextStyleCustom.outFitRegular400(
                                            color: Colors.white
                                                .withValues(alpha: .85),
                                            fontSize: 13),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.chevron_right,
                                          color:
                                              Colors.white.withValues(alpha: .6),
                                          size: 16),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        Container(
                          height: 96,
                          width: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFFD76A), Color(0xFFFF9A2E)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF9A2E)
                                    .withValues(alpha: .35),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Image.asset(AssetRes.icStar,
                              color: Colors.white, height: 40, width: 40),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
