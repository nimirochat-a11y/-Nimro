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
import 'package:nimiro/utilities/style_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

/// REDESIGN(v15): the hero header now reads as one polished card instead of a
/// flat square - softened corners, a subtle glow behind the balance figure,
/// and the lifetime stats moved into a glass pill so they sit apart from the
/// background instead of floating loose text on a gradient.
class CoinWalletTopView extends StatelessWidget {
  const CoinWalletTopView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CoinWalletScreenController>();
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                height: constraints.maxHeight - 46,
                decoration: BoxDecoration(
                  gradient: StyleRes.themeGradient,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ColorRes.themeAccentSolid.withValues(alpha: .28),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                  child: Stack(
                    children: [
                      // Soft glow behind the balance figure for depth.
                      Positioned(
                        top: 60,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: whitePure(context).withValues(alpha: .08),
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        minimum: const EdgeInsets.symmetric(vertical: 5),
                        bottom: false,
                        child: Column(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 15.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  CustomBackButton(
                                      color: whitePure(context), width: 35),
                                  Text(
                                    LKey.coinWallet.tr,
                                    style: TextStyleCustom.unboundedMedium500(
                                        color: whitePure(context)),
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
                                            Get.to(() =>
                                                    const RequestWithdrawalScreen())
                                                ?.then((value) {
                                              controller.fetchData();
                                            });
                                          }),
                                        ],
                                        child: Container(
                                          height: 35,
                                          width: 35,
                                          decoration: BoxDecoration(
                                              color: whitePure(context)
                                                  .withValues(alpha: .2),
                                              shape: BoxShape.circle),
                                          child: Center(
                                              child: Image.asset(AssetRes.icMore,
                                                  color: whitePure(context),
                                                  width: 22,
                                                  height: 22)),
                                        )),
                                  )
                                ],
                              ),
                            ),
                            const Spacer(),
                            Column(
                              children: [
                                Obx(() {
                                  User? user = controller.myUser.value;
                                  return Text(
                                    (user?.coinWallet?.toInt() ?? 0).numberFormat,
                                    style: TextStyleCustom.unboundedExtraBold800(
                                        color: whitePure(context), fontSize: 42),
                                  );
                                }),
                                const SizedBox(height: 4),
                                Text(
                                  LKey.balance.tr,
                                  style: TextStyleCustom.outFitLight300(
                                      color: whitePure(context).withValues(alpha: .8),
                                      fontSize: 15),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 6),
                                decoration: BoxDecoration(
                                  color: whitePure(context).withValues(alpha: .14),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: whitePure(context).withValues(alpha: .18),
                                    width: 1,
                                  ),
                                ),
                                child: Obx(() {
                                  User? user = controller.myUser.value;
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      CoinWalletStatistics(
                                        value:
                                            user?.coinCollectedLifetime?.toInt() ?? 0,
                                        title: LKey.collected.tr,
                                      ),
                                      Container(
                                          height: 26,
                                          width: 1,
                                          color: whitePure(context).withValues(alpha: .25)),
                                      CoinWalletStatistics(
                                        value: user?.coinGiftedLifetime?.toInt() ?? 0,
                                        title: LKey.gifted.tr,
                                      ),
                                      Container(
                                          height: 26,
                                          width: 1,
                                          color: whitePure(context).withValues(alpha: .25)),
                                      CoinWalletStatistics(
                                        value:
                                            user?.coinPurchasedLifetime?.toInt() ?? 0,
                                        title: LKey.purchased.tr,
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: 6),
                            Align(
                                alignment: AlignmentDirectional.bottomEnd,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 14.0),
                                  child: Text(
                                    LKey.lifetime.tr,
                                    style: TextStyleCustom.outFitLight300(
                                        fontSize: 12,
                                        color: whitePure(context).withValues(alpha: .6)),
                                  ),
                                ))
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 96,
                width: 96,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                        color: ColorRes.themeAccentSolid.withValues(alpha: .12),
                        width: 4),
                    boxShadow: [
                      BoxShadow(
                          color: ColorRes.themeColor.withValues(alpha: .18),
                          blurRadius: 20,
                          offset: const Offset(0, 6))
                    ]),
                alignment: Alignment.center,
                child: Image.asset(AssetRes.icCoin, height: 84, width: 84),
              ))
        ],
      ),
    );
  }
}

class CoinWalletStatistics extends StatelessWidget {
  final String title;
  final int value;
  const CoinWalletStatistics(
      {super.key, required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value.numberFormat,
            style: TextStyleCustom.unboundedMedium500(
                color: whitePure(context), fontSize: 15)),
        const SizedBox(height: 2),
        Text(title,
            style: TextStyleCustom.outFitLight300(
                color: whitePure(context).withValues(alpha: .75),
                fontSize: 13))
      ],
    );
  }
}
