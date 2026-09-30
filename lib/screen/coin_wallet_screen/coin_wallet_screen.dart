import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
    final double bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(
        children: [
          const CoinWalletTopView(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(12, 14, 12, bottomInset + 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: whitePure(context),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F1B2A50),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose a coin package'.tr,
                      style: TextStyleCustom.unboundedMedium500(
                          color: textDarkGrey(context), fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use coins to gift creators'.tr,
                      style: TextStyleCustom.outFitLight300(
                          color: textLightGrey(context), fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    CoinWalletList(controller: controller),
                    const SizedBox(height: 14),
                    const _SupportBanner(),
                    const SizedBox(height: 14),
                    const _SecureNote(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportBanner extends StatelessWidget {
  const _SupportBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14101F),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF5C9A), Color(0xFF8B5CF6)],
              ),
            ),
            child: Image.asset(AssetRes.icGift,
                width: 24, height: 24, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support your favorite creators'.tr,
                  style: TextStyleCustom.unboundedMedium500(
                      color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Every coin makes a difference'.tr,
                        style: TextStyleCustom.outFitLight300(
                            color: Colors.white.withValues(alpha: .65),
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.favorite, size: 12, color: ColorRes.likeRed),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .1),
            ),
            child: Icon(Icons.chevron_left,
                color: Colors.white.withValues(alpha: .7)),
          ),
        ],
      ),
    );
  }
}

class _SecureNote extends StatelessWidget {
  const _SecureNote();

  @override
  Widget build(BuildContext context) {
    final Color c = textLightGrey(context);
    return Row(
      children: [
        Expanded(child: Divider(color: c.withValues(alpha: .25), height: 1)),
        const SizedBox(width: 10),
        Icon(Icons.verified_user_outlined, size: 14, color: c),
        const SizedBox(width: 6),
        Text(
          'Safe and fast transactions'.tr,
          style: TextStyleCustom.outFitLight300(color: c, fontSize: 12),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: c.withValues(alpha: .25), height: 1)),
      ],
    );
  }
}
