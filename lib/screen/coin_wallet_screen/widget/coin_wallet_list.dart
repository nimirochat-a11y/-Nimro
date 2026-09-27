import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/widget/custom_image.dart';
import 'package:nimiro/common/widget/no_data_widget.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/coin_wallet_screen/coin_wallet_screen_controller.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

/// Coin store grid.
///
/// REDESIGN(v16): packages now render as a 2-column
grid of cards, matching
/// the new coin-store mockup, with the first active package badged as the
/// best seller. Tapping a card purchases it directly (no separate button),
/// keeping each card compact.
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
            return const NoDataWidgetWithScroll(
              title: 'No coin packages yet',
              description:
                  'The store is empty right now. New coin packages are on the way.',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
            itemCount: plans.length,
            physics: const ClampingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.92,
            ),
            itemBuilder: (context, index) => _CoinPlanCard(
              data: plans[index],
              controller: controller,
              isBestSeller: index == 0,
            ),
          );
        },
      ),
    );
  }
}

class _CoinPlanCard extends StatelessWidget {
  final CoinPlan data;
  final CoinWalletScreenController controller;
  final bool isBestSeller;
  const _CoinPlanCard(
      {required this.data,
      required this.controller,
      required this.isBestSeller});

  @override
  Widget build(BuildContext context) {
    final bool hasPrice = data.priceString.trim().isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => controller.onPurchase(data),
      child: Container(
        decoration: BoxDecoration(
          color: whitePure(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isBestSeller
                ? ColorRes.themeAccentSolid.withValues(alpha: .55)
                : ColorRes.themeAccentSolid.withValues(alpha: .14),
            width: isBestSeller ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: ColorRes.themeColor.withValues(alpha: .06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CoinBadge(image: data.image),
                  const SizedBox(height: 10),
                  Text(
                    '${data.coin}',
                    style: TextStyleCustom.unboundedExtraBold800(
                      color: ColorRes.textDarkGrey,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        LKey.coins.tr,
                        style: TextStyleCustom.outFitRegular400(
                          color: ColorRes.textLightGrey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Image.asset(AssetRes.icStar, width: 12, height: 12),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isBestSeller
                          ? ColorRes.themeAccentSolid
                          : ColorRes.textLightGrey.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hasPrice ? data.priceString : LKey.rechargeWallet.tr,
                      style: TextStyleCustom.unboundedMedium500(
                        color: isBestSeller
                            ? ColorRes.whitePure
                            : ColorRes.textDarkGrey,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isBestSeller)
              PositionedDirectional(
                top: -4,
                start: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ColorRes.themeAccentSolid,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: ColorRes.themeAccentSolid.withValues(alpha: .4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    'Most Popular'.tr,
                    style: TextStyleCustom.outFitRegular400(
                      color: ColorRes.whitePure,
                      fontSize: 10,
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

/// Circular brand badge holding the package image,
or the app's coin icon.
class _CoinBadge extends StatelessWidget {
  final String? image;
  const _CoinBadge({this.image});

  @override
  Widget build(BuildContext context) {
    final bool hasImage = (image ?? '').trim().isNotEmpty;
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD76A), Color(0xFFFF9A2E)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9A2E).withValues(alpha: .3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: hasImage
            ? ClipOval(
                child: CustomImage(
                  image: image!.addBaseURL(),
                  size: const Size(38, 38),
                  fit: BoxFit.cover,
                  isShowPlaceHolder: true,
                ),
              )
            : Image.asset(AssetRes.icCoin,
                width: 24, height: 24, color: Colors.white),
      ),
    );
  }
}
