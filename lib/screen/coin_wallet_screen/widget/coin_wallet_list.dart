import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/widget/custom_image.dart';
import 'package:nimiro/common/widget/no_data_widget.dart';
import 'package:nimiro/common/widget/text_button_custom.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/coin_wallet_screen/coin_wallet_screen_controller.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/style_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';
import 'package:nimiro/utilities/theme_res.dart';

/// Coin store list.
///
/// REDESIGN(v14): the rows used to be a flat grey capsule with a generic coin
/// icon. They now use the app's own identity — the brand gradient header, the
/// accent blue, the squircle radius and the Outfit/Unbounded type scale — so
/// the store reads as part of Nimiro rather than a stock widget. The list is
/// brand-led rather than neutral, and each row shows the server image when the
/// dashboard provided one.
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
            padding: const EdgeInsets.only(top: 18, bottom: 24),
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: ShapeDecoration(
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
              cornerRadius: radius, cornerSmoothing: 1),
          side: BorderSide(
            color: ColorRes.themeAccentSolid.withValues(alpha: .18),
            width: 1.2,
          ),
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
      child: ClipSmoothRect(
        radius: SmoothBorderRadius(
            cornerRadius: radius, cornerSmoothing: 1),
        child: Stack(
          children: [
            // Brand accent rail on the leading edge.
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(gradient: StyleRes.themeGradient),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
              child: Row(
                children: [
                  _CoinBadge(image: data.image),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${data.coin} ${LKey.coins.tr}',
                          style: TextStyleCustom.unboundedMedium500(
                            color: ColorRes.textDarkGrey,
                            fontSize: 15,
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
                  const SizedBox(width: 8),
                  TextButtonCustom(
                    onTap: () => controller.onPurchase(data),
                    title: LKey.purchase.tr,
                    backgroundColor: ColorRes.themeAccentSolid,
                    btnHeight: 40,
                    fontSize: 14,
                    titleColor: ColorRes.whitePure,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    horizontalMargin: 0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular brand badge holding the package image, or the app's coin icon.
class _CoinBadge extends StatelessWidget {
  final String? image;

  const _CoinBadge({this.image});

  @override
  Widget build(BuildContext context) {
    final bool hasImage = (image ?? '').trim().isNotEmpty;
    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: StyleRes.themeGradient,
        boxShadow: [
          BoxShadow(
            color: ColorRes.themeAccentSolid.withValues(alpha: .28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: hasImage
            ? ClipOval(
                child: CustomImage(
                  image: image!.addBaseURL(),
                  size: const Size(40, 40),
                  fit: BoxFit.cover,
                  isShowPlaceHolder: true,
                ),
              )
            : Image.asset(AssetRes.icCoin, width: 26, height: 26),
      ),
    );
  }
}
