import 'package:figma_squircle_updated/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nimiro/common/extensions/common_extension.dart';
import 'package:nimiro/common/extensions/string_extension.dart';
import 'package:nimiro/common/widget/custom_image.dart';
import 'package:nimiro/common/widget/full_name_with_blue_tick.dart';
import 'package:nimiro/common/widget/gift_media_viewer.dart';
import 'package:nimiro/languages/languages_keys.dart';
import 'package:nimiro/model/general/settings_model.dart';
import 'package:nimiro/model/user_model/app_user.dart';
import 'package:nimiro/screen/gift_sheet/send_gift_sheet_controller.dart';
import 'package:nimiro/utilities/asset_res.dart';
import 'package:nimiro/utilities/color_res.dart';
import 'package:nimiro/utilities/style_res.dart';
import 'package:nimiro/utilities/text_style_custom.dart';

/// The gift store.
///
/// A bright Nimiro-branded sheet: a gradient balance hero, a horizontal
/// "top gifts" shelf and a soft 3-column grid. Every gift is an open 3D box
/// with a colour that matches its price tier.
class SendGiftSheet extends StatelessWidget {
  final GiftType giftType;
  final BattleView battleViewType;
  final int? userId;
  final List<AppUser> streamUsers;

  const SendGiftSheet(
      {super.key,
      this.giftType = GiftType.none,
      this.battleViewType = BattleView.red,
      required this.userId,
      this.streamUsers = const []});

  @override
  Widget build(BuildContext context) {
    final controller =
        Get.put(SendGiftSheetController(giftType, userId, streamUsers));

    return Container(
      height: Get.height * .9,
      margin: EdgeInsets.only(top: Get.height * .05),
      decoration: const ShapeDecoration(
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.vertical(
            top: SmoothRadius(cornerRadius: 36, cornerSmoothing: 1),
          ),
        ),
        gradient: LinearGradient(
          colors: [Color(0xFFF2FAFF), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        child: Stack(
          children: [
            const _SheetBackground(),
            SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _Grabber(),
                  _Header(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BalanceHero(controller: controller),
                          if (giftType == GiftType.battle &&
                              streamUsers.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _BattleBanner(
                                battleViewType: battleViewType,
                                streamUser: streamUsers.first),
                          ],
                          if ((giftType == GiftType.livestream ||
                                  giftType == GiftType.battle) &&
                              streamUsers.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            GiftForLiveStream(
                                controller: controller,
                                streamUsers: streamUsers),
                          ],
                          Obx(() {
                            final gifts = _sortedGifts(controller);
                            if (gifts.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 22),
                                child: _EmptyGifts(),
                              );
                            }
                            final featured = gifts.reversed.take(3).toList();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                _SectionTitle(
                                    title: LKey.topGifts.tr,
                                    icon: Icons.auto_awesome_rounded),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 142,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: featured.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      final gift = featured[index];
                                      return _FeaturedGiftCard(
                                        gift: gift,
                                        onTap: () =>
                                            controller.onGiftTap(gift, context),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _SectionTitle(
                                    title: LKey.allGifts.tr,
                                    icon: Icons.grid_view_rounded),
                                const SizedBox(height: 10),
                                LayoutBuilder(builder: (context, constraints) {
                                  final columns =
                                      constraints.maxWidth >= 360 ? 3 : 2;
                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: gifts.length,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisExtent: 184,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                    itemBuilder: (context, index) {
                                      final gift = gifts[index];
                                      return _GiftCard(
                                        gift: gift,
                                        onTap: () =>
                                            controller.onGiftTap(gift, context),
                                      );
                                    },
                                  );
                                }),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Gift> _sortedGifts(SendGiftSheetController controller) {
    final gifts =
        List<Gift>.from(controller.settings.value?.gifts ?? const <Gift>[]);
    gifts.sort((a, b) => (a.coinPrice ?? 0).compareTo(b.coinPrice ?? 0));
    return gifts;
  }
}

class _Grabber extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0xFFD7E6F2),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: StyleRes.themeGradient,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                    color: Color(0x334C5DFF),
                    blurRadius: 16,
                    offset: Offset(0, 6))
              ],
            ),
            padding: const EdgeInsets.all(11),
            child: Image.asset(AssetRes.icGift,
                color: Colors.white, fit: BoxFit.contain),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(LKey.giftStore.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyleCustom.outFitBold700(
                        fontSize: 19, color: ColorRes.textDarkGrey)),
                const SizedBox(height: 2),
                Text(LKey.pickGiftAndSend.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyleCustom.outFitRegular400(
                        fontSize: 12, color: ColorRes.textLightGrey)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () => Get.back(),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE7F1F9)),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x0F1B5F8A),
                      blurRadius: 10,
                      offset: Offset(0, 3))
                ],
              ),
              child: const Icon(Icons.close_rounded,
                  size: 20, color: ColorRes.textLightGrey),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceHero extends StatelessWidget {
  final SendGiftSheetController controller;

  const _BalanceHero({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final coins = controller.myUser.value?.coinWallet ?? 0;
      return Container(
        height: 102,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF18D6F5), Color(0xFF4C5DFF)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: Color(0x384C5DFF), blurRadius: 22, offset: Offset(0, 10))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned(
                top: -36,
                right: -22,
                child: _glowCircle(122, Colors.white.withValues(alpha: .10)),
              ),
              Positioned(
                bottom: -48,
                left: -16,
                child: _glowCircle(112, Colors.white.withValues(alpha: .07)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .18),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: .25)),
                      ),
                      padding: const EdgeInsets.all(11),
                      child: Image.asset(AssetRes.icCoin),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(LKey.yourCoinBalance.tr,
                              style: TextStyleCustom.outFitMedium500(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: .86))),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(coins.numberFormat,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyleCustom.unboundedBold700(
                                        fontSize: 27, color: Colors.white)),
                              ),
                              const SizedBox(width: 5),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text(LKey.coins.tr,
                                    style: TextStyleCustom.outFitMedium500(
                                        fontSize: 12,
                                        color: Colors.white
                                            .withValues(alpha: .82))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .16),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(AssetRes.icGift,
                          color: Colors.white, fit: BoxFit.contain),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _BattleBanner extends StatelessWidget {
  final BattleView battleViewType;
  final AppUser streamUser;

  const _BattleBanner({required this.battleViewType, required this.streamUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            battleViewType.color,
            battleViewType.color.withValues(alpha: .78)
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: battleViewType.color.withValues(alpha: .22),
              blurRadius: 14,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(
        children: [
          CustomImage(
              size: const Size(34, 34),
              image: streamUser.profile?.addBaseURL(),
              fullName: streamUser.fullname,
              strokeColor: Colors.white,
              strokeWidth: 1.2),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FullNameWithBlueTick(
                    username: streamUser.fullname,
                    fontColor: Colors.white,
                    isVerify: streamUser.isVerify),
                const SizedBox(height: 2),
                Text(
                    LKey.youAreSendingCoinsTo
                        .trParams({'color': battleViewType.value}),
                    style: TextStyleCustom.outFitLight300(
                        color: Colors.white.withValues(alpha: .9),
                        fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: StyleRes.themeGradient,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyleCustom.outFitBold700(
                fontSize: 14, color: ColorRes.textDarkGrey)),
      ],
    );
  }
}

class _FeaturedGiftCard extends StatelessWidget {
  final Gift gift;
  final VoidCallback onTap;

  const _FeaturedGiftCard({required this.gift, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final price = gift.coinPrice ?? 0;
    final tier = _tierFor(price);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: MediaQuery.sizeOf(context).width * .64,
        constraints: const BoxConstraints(minWidth: 210, maxWidth: 270),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [tier.color.withValues(alpha: .20), Colors.white],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: tier.color.withValues(alpha: .28)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x111B5F8A), blurRadius: 14, offset: Offset(0, 6))
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              height: 92,
              child: Stack(
                children: [
                  Center(
                    child: CustomImage(
                        image: gift.image?.addBaseURL(),
                        size: const Size(88, 88),
                        radius: 0,
                        fit: BoxFit.contain),
                  ),
                  if (gift.video?.isNotEmpty ?? false)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: GestureDetector(
                        onTap: () => GiftMediaViewer.open(
                            context, gift.video!.addBaseURL()),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: Colors.black45, shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow_rounded,
                              size: 15, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tier.name.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyleCustom.outFitBold700(
                          fontSize: 13, color: ColorRes.textDarkGrey)),
                  const SizedBox(height: 6),
                  _PriceChip(price: price, color: tier.color),
                  const SizedBox(height: 8),
                  Container(
                    height: 28,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      gradient: StyleRes.themeGradient,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(LKey.send.tr,
                        style: TextStyleCustom.outFitSemiBold600(
                            fontSize: 11, color: Colors.white)),
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

class _GiftCard extends StatelessWidget {
  final Gift gift;
  final VoidCallback onTap;

  const _GiftCard({required this.gift, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final price = gift.coinPrice ?? 0;
    final tier = _tierFor(price);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tier.color.withValues(alpha: .20)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x101B5F8A), blurRadius: 12, offset: Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(7, 7, 7, 0),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      tier.color.withValues(alpha: .18),
                      tier.color.withValues(alpha: .03)
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15), bottom: Radius.circular(12)),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: CustomImage(
                          image: gift.image?.addBaseURL(),
                          size: const Size(84, 84),
                          radius: 0,
                          fit: BoxFit.contain),
                    ),
                    if (gift.video?.isNotEmpty ?? false)
                      Positioned(
                        bottom: 5,
                        left: 5,
                        child: GestureDetector(
                          onTap: () => GiftMediaViewer.open(
                              context, gift.video!.addBaseURL()),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                                color: Colors.black45, shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(7, 6, 7, 8),
              child: Column(
                children: [
                  Text(tier.name.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyleCustom.outFitSemiBold600(
                          fontSize: 11, color: ColorRes.textDarkGrey)),
                  const SizedBox(height: 5),
                  _PriceChip(price: price, color: tier.color, compact: true),
                  const SizedBox(height: 6),
                  Container(
                    height: 26,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: StyleRes.themeGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(LKey.send.tr,
                        style: TextStyleCustom.outFitSemiBold600(
                            fontSize: 10.5, color: Colors.white)),
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

class _PriceChip extends StatelessWidget {
  final int price;
  final Color color;
  final bool compact;

  const _PriceChip(
      {required this.price, required this.color, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(AssetRes.icCoin,
              width: compact ? 12 : 14, height: compact ? 12 : 14),
          const SizedBox(width: 4),
          Flexible(
            child: Text(price.numberFormat,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyleCustom.outFitBold700(
                    fontSize: compact ? 11 : 12, color: color)),
          ),
        ],
      ),
    );
  }
}

class _EmptyGifts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7F1F9)),
      ),
      child: Column(
        children: [
          Image.asset(AssetRes.icGift_1, width: 52, height: 52),
          const SizedBox(height: 10),
          Text(LKey.noGiftsAvailable.tr,
              textAlign: TextAlign.center,
              style: TextStyleCustom.outFitMedium500(
                  fontSize: 13, color: ColorRes.textLightGrey)),
        ],
      ),
    );
  }
}

/// Soft background bubbles behind the whole sheet.
class _SheetBackground extends StatelessWidget {
  const _SheetBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -70,
            right: -50,
            child: _bubble(190, const Color(0x1A18D6F5)),
          ),
          Positioned(
            top: 120,
            left: -70,
            child: _bubble(160, const Color(0x124C5DFF)),
          ),
          Positioned(
            bottom: -80,
            right: -40,
            child: _bubble(210, const Color(0x0D18D6F5)),
          ),
        ],
      ),
    );
  }

  Widget _bubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _GiftTier {
  final Color color;
  final String name;

  const _GiftTier(this.color, this.name);
}

_GiftTier _tierFor(int price) {
  switch (price) {
    case 10:
      return const _GiftTier(Color(0xFF0FB6B0), LKey.giftTierFresh);
    case 25:
      return const _GiftTier(Color(0xFFE84C8B), LKey.giftTierRose);
    case 50:
      return const _GiftTier(Color(0xFF2F8BFF), LKey.giftTierSky);
    case 100:
      return const _GiftTier(Color(0xFF7C4DFF), LKey.giftTierRoyal);
    case 250:
      return const _GiftTier(Color(0xFF12A67A), LKey.giftTierEmerald);
    case 500:
      return const _GiftTier(Color(0xFF2451D8), LKey.giftTierSapphire);
    case 1000:
      return const _GiftTier(Color(0xFFE09A1A), LKey.giftTierGolden);
    case 2500:
      return const _GiftTier(Color(0xFF2B2F45), LKey.giftTierLegendary);
    default:
      return const _GiftTier(Color(0xFF237BFF), LKey.gift);
  }
}

class GiftForLiveStream extends StatelessWidget {
  final SendGiftSheetController controller;
  final List<AppUser> streamUsers;

  const GiftForLiveStream(
      {super.key, required this.controller, required this.streamUsers});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7F1F9)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F1B5F8A), blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Obx(() {
            AppUser? giftUser =
                controller.livestreamController.selectedGiftUser.value;
            if (giftUser == null) return const SizedBox();
            return streamUsers.length <= 1
                ? _PopupMenuItemCustom(streamUser: giftUser)
                : PopupMenuButton<AppUser>(
                    initialValue: giftUser,
                    onSelected: (AppUser value) {
                      controller.livestreamController.selectedGiftUser.value =
                          value;
                    },
                    shape: const RoundedRectangleBorder(
                      borderRadius: SmoothBorderRadius.vertical(
                          bottom: SmoothRadius(
                              cornerRadius: 15, cornerSmoothing: 1)),
                    ),
                    position: PopupMenuPosition.under,
                    constraints: const BoxConstraints(
                        maxWidth: double.infinity, minWidth: double.infinity),
                    itemBuilder: (BuildContext context) {
                      return List.generate(
                        streamUsers.length,
                        (index) => PopupMenuItem(
                            value: streamUsers[index],
                            padding: EdgeInsets.zero,
                            child: _PopupMenuItemCustom(
                                streamUser: streamUsers[index])),
                      );
                    },
                    child: _PopupMenuItemCustom(
                        isPopupChild: true, streamUser: giftUser),
                  );
          }),
          const SizedBox(height: 3),
          Text(LKey.sendingCoinsMessage.tr,
              textAlign: TextAlign.center,
              style: TextStyleCustom.outFitLight300(
                  color: ColorRes.textLightGrey, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PopupMenuItemCustom extends StatelessWidget {
  final bool isPopupChild;
  final AppUser streamUser;

  const _PopupMenuItemCustom(
      {this.isPopupChild = false, required this.streamUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isPopupChild ? const Color(0xFFF7FAFD) : null,
      height: 42,
      width: MediaQuery.of(context).size.width - 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomImage(
              size: const Size(28, 28),
              image: streamUser.profile?.addBaseURL(),
              fullName: streamUser.fullname,
              strokeColor: Colors.white,
              strokeWidth: 1),
          const SizedBox(width: 6),
          FullNameWithBlueTick(
              username: streamUser.fullname,
              isVerify: streamUser.isVerify,
              iconSize: 14),
          if (isPopupChild)
            Image.asset(AssetRes.icDownArrow_1, width: 24, height: 24),
        ],
      ),
    );
  }
}

enum GiftType { none, livestream, battle }

enum BattleView {
  red('red'),
  blue('blue');

  final String value;

  const BattleView(this.value);

  Color get color {
    switch (this) {
      case BattleView.red:
        return ColorRes.likeRed;
      case BattleView.blue:
        return ColorRes.battleProgressColor;
    }
  }
}
