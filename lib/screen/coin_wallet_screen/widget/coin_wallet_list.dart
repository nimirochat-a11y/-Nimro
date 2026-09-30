import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/widget/custom_image.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/screen/coin_wallet_screen/coin_wallet_screen_controller.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';

class CoinWalletList extends StatelessWidget {
  final CoinWalletScreenController controller;
  const CoinWalletList({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingPlans.value) {
        return const SizedBox(
          height: 120,
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        );
      }
      final plans = controller.coinPlans;
      if (plans.isEmpty) {
        return SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'No coin packages yet',
              style: TextStyleCustom.outFitRegular400(
                  color: ColorRes.textLightGrey, fontSize: 13),
            ),
          ),
        );
      }
      return GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: plans.length,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: 132,
        ),
        itemBuilder: (context, index) =>
            _CoinPlanCard(data: plans[index], controller: controller),
      );
    });
  }
}

class _CoinPlanCard extends StatelessWidget {
  final CoinPlan data;
  final CoinWalletScreenController controller;
  const _CoinPlanCard({required this.data, required this.controller});

  @override
  Widget build(BuildContext context) {
    final bool hasPrice = data.priceString.trim().isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => controller.onPurchase(data),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9EDF5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CoinImage(image: data.image),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${data.coin}',
                style: TextStyleCustom.unboundedExtraBold800(
                    color: ColorRes.textDarkGrey, fontSize: 15),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  LKey.coins.tr,
                  style: TextStyleCustom.outFitRegular400(
                      color: ColorRes.textLightGrey, fontSize: 11),
                ),
                const SizedBox(width: 4),
                Image.asset(AssetRes.icCoin, width: 11, height: 11),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEDF0F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  hasPrice ? data.priceString : LKey.purchase.tr,
                  style: TextStyleCustom.unboundedMedium500(
                      color: ColorRes.textDarkGrey, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinImage extends StatelessWidget {
  final String? image;
  const _CoinImage({this.image});

  @override
  Widget build(BuildContext context) {
    final bool hasImage = (image ?? '').trim().isNotEmpty;
    if (!hasImage) {
      return Image.asset(AssetRes.icCoin, width: 38, height: 38);
    }
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFFD76A), Color(0xFFFF9A2E)],
        ),
      ),
      child: ClipOval(
        child: CustomImage(
          image: image!.addBaseURL(),
          size: const Size(36, 36),
          fit: BoxFit.cover,
          isShowPlaceHolder: true,
        ),
      ),
    );
  }
}
