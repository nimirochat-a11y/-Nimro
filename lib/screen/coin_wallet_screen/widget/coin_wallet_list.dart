import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/widget/custom_image.dart';
import 'package:nimiro/common/widget/no_data_widget.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/coin_wallet_screen/coin_wallet_screen_controller.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/style_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

/// Coin store list.
///
/// REDESIGN(v16): the rows follow the new store look — a light-blue capsule
/// badge holding a white coin mark, the plan title with its store price under
/// it, and a tall gradient buy button on the trailing side showing the
/// package image (or the app coin) above the purchase label. The old leading
/// gradient rail and the small pill button are gone.
class CoinWalletList extends StatelessWidget {
  final CoinWalletScreenController controller;

  const CoinWalletList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Obx(
        () {
          if (controller.isLoadingPlans.value) {
            return const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            );
          }

          final plans = controller.coinPlans;

          if (plans.isEmpty) {
            // An empty store is a real state (no rows, or all rows disabled) and
            // must be stated instead of rendering a blank white sheet.
            return const NoDataWidgetWithScroll(
              title: 'No coin packages yet',
              description:
                  'The store is empty right now. New coin packages are on the way.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            itemCount: plans.length,
            physics: const ClampingScrollPhysics(),
            itemBuilder: (context, index) => _CoinPlanTile(
              data: plans[index],
              controller: controller,
            ),
          );
        },
      ),
    );
  }
}

class _CoinPlanTile extends StatelessWidget {
  final CoinPlan data;
  final CoinWalletScreenController controller;

  const _CoinPlanTile({required this.data, required this.controller});

  @override
  Widget build(BuildContext context) {
    const double radius = 16;
    final bool hasPrice = data.priceString.trim().isNotEmpty;
    final bool hasImage = (data.image ?? '').trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: ShapeDecoration(
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
              cornerRadius: radius, cornerSmoothing: 1),
        ),
        color: whitePure(context),
        shadows: [
          BoxShadow(
            color: ColorRes.themeColor.withValues(alpha: .07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
        child: Row(
          children: [
            // Light-blue capsule holding the white coin mark.
            Container(
              width: 58,
              height: 40,
              decoration: BoxDecoration(
                color: ColorRes.coinWalletLightBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Image.asset(
                  AssetRes.icCoin,
                  width: 24,
                  height: 24,
                  color: whitePure(context),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${data.coin} ${LKey.coins.tr}',
                    style: TextStyleCustom.unboundedSemiBold600(
                      color: ColorRes.textDarkGrey,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasPrice
                        ? '${data.priceString} ${LKey.only.tr}'
                        : LKey.rechargeWallet.tr,
                    style: TextStyleCustom.outFitRegular400(
                      color: ColorRes.textLightGrey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Tall gradient buy button: package image + purchase label.
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => controller.onPurchase(data),
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: StyleRes.themeGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        hasImage
                            ? ClipOval(
                                child: CustomImage(
                                  image: data.image!.addBaseURL(),
                                  size: const Size(28, 28),
                                  fit: BoxFit.cover,
                                  isShowPlaceHolder: true,
                                ),
                              )
                            : Image.asset(AssetRes.icCoin,
                                width: 28, height: 28),
                        const SizedBox(height: 3),
                        Text(
                          LKey.purchase.tr,
                          style: TextStyleCustom.outFitRegular400(
                            color: whitePure(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
